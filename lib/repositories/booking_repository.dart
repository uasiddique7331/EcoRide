import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_config.dart';
import '../core/constants/firestore_paths.dart';
import '../core/utils/app_exception.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/enums.dart';
import '../models/place_point.dart';
import '../models/trip.dart';
import '../services/fare_calculator.dart';

/// Booking lifecycle. Every state change that touches seat counts runs in a
/// Firestore *transaction*, so two drivers/passengers can never oversell
/// seats (FR-68, FR-72).
class BookingRepository {
  BookingRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection(FsPaths.bookings);
  CollectionReference<Map<String, dynamic>> get _trips => _db.collection(FsPaths.trips);

  static List<Booking> _sorted(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(Booking.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

  Stream<List<Booking>> watchPassengerBookings(String passengerId) =>
      _bookings.where('passengerId', isEqualTo: passengerId).snapshots().map(_sorted);

  Stream<List<Booking>> watchDriverBookings(String driverId) =>
      _bookings.where('driverId', isEqualTo: driverId).snapshots().map(_sorted);

  /// Bookings of one trip. The driverId filter is required so the query
  /// satisfies the security rules (FR-71).
  Stream<List<Booking>> watchTripBookings({required String tripId, required String driverId}) => _bookings
      .where('tripId', isEqualTo: tripId)
      .where('driverId', isEqualTo: driverId)
      .snapshots()
      .map(_sorted);

  Stream<Booking?> watchBooking(String id) =>
      _bookings.doc(id).snapshots().map((s) => s.exists ? Booking.fromDoc(s) : null);

  Stream<List<Booking>> watchAllBookings() => _bookings
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(Booking.fromDoc).toList());

  /// UC-07: submit a booking request (status Pending, seats not reduced yet).
  Future<void> requestBooking({
    required String tripId,
    required AppUser passenger,
    required int seats,
    required PlacePoint pickup,
    required PlacePoint dropoff,
  }) async {
    if (!passenger.isVerified) {
      throw const AppException('Your identity document must be approved before you can book rides.');
    }
    if (seats < 1 || seats > AppConfig.maxSeatsPerBooking) {
      throw const AppException('Choose between 1 and ${AppConfig.maxSeatsPerBooking} seats.'); // UC-07 A3
    }
    final id = FsPaths.bookingId(tripId, passenger.uid);
    await guarded(() => _db.runTransaction((tx) async {
          final tSnap = await tx.get(_trips.doc(tripId));
          if (!tSnap.exists) throw const AppException('This ride is no longer available.');
          final trip = Trip.fromDoc(tSnap);
          if (trip.status == TripStatus.cancelled) throw const AppException('This trip has been cancelled.'); // A2
          if (!trip.canAcceptBookings) throw const AppException('This ride is no longer open for booking.');
          if (trip.driverId == passenger.uid) throw const AppException('You cannot book your own trip.');
          if (trip.availableSeats < seats) {
            throw AppException('Only ${trip.availableSeats} seat(s) left on this ride.'); // A1
          }

          final bRef = _bookings.doc(id);
          final bSnap = await tx.get(bRef);
          if (bSnap.exists) {
            // UC-07 A4: duplicate-booking policy = one request per trip;
            // a cancelled request may be re-submitted.
            final existing = Booking.fromDoc(bSnap);
            if (existing.status != BookingStatus.cancelled) {
              throw AppException('You already have a ${existing.status.label.toLowerCase()} request for this trip.');
            }
          }
          tx.set(bRef, {
            'tripId': tripId,
            'driverId': trip.driverId,
            'passengerId': passenger.uid,
            'passengerName': passenger.fullName,
            'passengerPhone': passenger.phone,
            'seats': seats,
            'status': BookingStatus.pending.name,
            'pickup': pickup.toMap(),
            'dropoff': dropoff.toMap(),
            'originName': trip.origin.name,
            'destinationName': trip.destination.name,
            'estimatedShare': FareCalculator.estimatedShare(trip.totalFare, trip.acceptedPassengers, seats),
            'tripTotalFare': trip.totalFare,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }));
  }

  /// UC-08: accept. Atomically flips the booking and updates seat counts,
  /// which in turn changes every accepted passenger's share (FR-65, FR-81).
  Future<void> accept({required String bookingId, required AppUser driver}) => guarded(
        () => _db.runTransaction((tx) async {
          final bRef = _bookings.doc(bookingId);
          final bSnap = await tx.get(bRef);
          if (!bSnap.exists) throw const AppException('Booking not found.');
          final b = Booking.fromDoc(bSnap);
          if (b.driverId != driver.uid) {
            throw const AppException('You can only manage bookings for your own trips.'); // A3
          }
          if (b.status != BookingStatus.pending) {
            throw AppException('This request is already ${b.status.label.toLowerCase()}.'); // A2
          }
          final tRef = _trips.doc(b.tripId);
          final tSnap = await tx.get(tRef);
          if (!tSnap.exists) throw const AppException('Trip not found.');
          final trip = Trip.fromDoc(tSnap);
          if (trip.status != TripStatus.scheduled) {
            throw AppException('The trip is ${trip.status.label.toLowerCase()}; requests can no longer be accepted.');
          }
          if (trip.availableSeats < b.seats) {
            throw AppException('Not enough seats: ${trip.availableSeats} left, ${b.seats} requested.'); // A1, FR-68
          }
          tx.update(bRef, {
            'status': BookingStatus.accepted.name,
            'driverName': driver.fullName,
            'driverPhone': driver.phone,
            'respondedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.update(tRef, {
            'availableSeats': trip.availableSeats - b.seats,
            'acceptedPassengers': trip.acceptedPassengers + b.seats,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }),
      );

  /// UC-08 alternative flow: reject a pending request (FR-66).
  Future<void> reject({required String bookingId, required AppUser driver}) => guarded(
        () => _db.runTransaction((tx) async {
          final bRef = _bookings.doc(bookingId);
          final snap = await tx.get(bRef);
          if (!snap.exists) throw const AppException('Booking not found.');
          final b = Booking.fromDoc(snap);
          if (b.driverId != driver.uid) throw const AppException('You can only manage bookings for your own trips.');
          if (b.status != BookingStatus.pending) {
            throw AppException('This request is already ${b.status.label.toLowerCase()}.');
          }
          tx.update(bRef, {
            'status': BookingStatus.rejected.name,
            'respondedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }),
      );

  /// FR-69: passenger cancels. If the booking was Accepted, the seats are
  /// returned to the trip and shares are recalculated (FR-72, FR-81).
  Future<void> cancelByPassenger({required String bookingId, required String passengerId}) => guarded(
        () => _db.runTransaction((tx) async {
          final bRef = _bookings.doc(bookingId);
          final bSnap = await tx.get(bRef);
          if (!bSnap.exists) throw const AppException('Booking not found.');
          final b = Booking.fromDoc(bSnap);
          if (b.passengerId != passengerId) throw const AppException('You can only cancel your own bookings.');
          if (!b.isActive) throw AppException('This booking is already ${b.status.label.toLowerCase()}.');

          final tRef = _trips.doc(b.tripId);
          final tSnap = await tx.get(tRef);
          if (!tSnap.exists) throw const AppException('Trip not found.');
          final trip = Trip.fromDoc(tSnap);
          if (trip.status != TripStatus.scheduled || !trip.isBeforeCutoff) {
            throw const AppException(
                'Bookings can only be cancelled for scheduled trips, more than ${AppConfig.cancelCutoffMinutes} minutes before departure.');
          }

          tx.update(bRef, {
            'status': BookingStatus.cancelled.name,
            'statusNote': 'Cancelled by passenger',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (b.status == BookingStatus.accepted) {
            tx.update(tRef, {
              'availableSeats': trip.availableSeats + b.seats,
              'acceptedPassengers': trip.acceptedPassengers - b.seats,
              'lastBookingId': bookingId, // lets security rules verify the release
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }),
      );
}
