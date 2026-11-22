import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_config.dart';
import '../core/constants/firestore_paths.dart';
import '../core/services/routing_service.dart';
import '../core/utils/app_exception.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/enums.dart';
import '../models/place_point.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';
import '../services/fare_calculator.dart';

class TripRepository {
  TripRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _trips => _db.collection(FsPaths.trips);
  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection(FsPaths.bookings);

  // --- Reads --------------------------------------------------------------

  Stream<Trip?> watchTrip(String id) =>
      _trips.doc(id).snapshots().map((s) => s.exists ? Trip.fromDoc(s) : null);

  /// FR-45: all trips of one driver, newest departure first.
  Stream<List<Trip>> watchDriverTrips(String driverId) => _trips
      .where('driverId', isEqualTo: driverId)
      .snapshots()
      .map((s) => s.docs.map(Trip.fromDoc).toList()..sort((a, b) => b.departureTime.compareTo(a.departureTime)));

  /// Admin: latest trips across the platform (FR-94).
  Stream<List<Trip>> watchAllTrips() => _trips
      .orderBy('departureTime', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(Trip.fromDoc).toList());

  /// Candidate trips for a search: a single range filter on departure time
  /// (no composite index needed). Matching rules are applied client-side by
  /// [RideMatcher] (FR-54 .. FR-58).
  Future<List<Trip>> candidateTrips({required DateTime from, required DateTime to}) async {
    final snap = await guarded(() => _trips
        .where('departureTime', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('departureTime', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('departureTime')
        .limit(300)
        .get());
    return snap.docs.map(Trip.fromDoc).toList();
  }

  // --- Writes -------------------------------------------------------------

  /// UC-04: publish a trip. Validates, then stores in Firestore (FR-37 .. FR-40).
  Future<String> publish({
    required AppUser driver,
    required Vehicle vehicle,
    required PlacePoint origin,
    required PlacePoint destination,
    required DateTime departure,
    required int seats,
    required RouteInfo route,
  }) async {
    if (!driver.isVerified) {
      throw const AppException('Your documents must be approved by an administrator before you can publish trips.');
    }
    if (!departure.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw const AppException('Departure must be at least 5 minutes in the future.');
    }
    if (seats < 1 || seats > vehicle.capacity) {
      throw AppException('Available seats must be between 1 and ${vehicle.capacity} (your vehicle capacity).');
    }
    final total = FareCalculator.totalFare(route.distanceKm);
    final ref = _trips.doc();
    await guarded(() => ref.set({
          'driverId': driver.uid,
          'driverName': driver.fullName,
          'vehicleId': vehicle.ownerId,
          'vehicle': {
            'make': vehicle.make,
            'model': vehicle.model,
            'color': vehicle.color,
            'type': vehicle.type,
            'registrationNumber': vehicle.registrationNumber,
          },
          'origin': origin.toMap(),
          'destination': destination.toMap(),
          'departureTime': Timestamp.fromDate(departure),
          'totalSeats': seats,
          'availableSeats': seats,
          'acceptedPassengers': 0,
          'status': TripStatus.scheduled.name,
          'distanceKm': route.distanceKm,
          'distanceIsEstimate': route.isEstimate,
          'farePerKm': AppConfig.farePerKm,
          'totalFare': total,
          'routePoints': [for (final p in route.points) GeoPoint(p.latitude, p.longitude)],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }));
    return ref.id;
  }

  /// FR-41: change departure time and/or seats while the trip is Scheduled.
  /// Route changes require cancelling and republishing (fare and matches depend on it).
  Future<void> updateTrip({required String tripId, required DateTime departure, required int seats}) async {
    if (!departure.isAfter(DateTime.now())) throw const AppException('Departure must be in the future.');
    await guarded(() => _db.runTransaction((tx) async {
          final ref = _trips.doc(tripId);
          final snap = await tx.get(ref);
          if (!snap.exists) throw const AppException('Trip not found.');
          final t = Trip.fromDoc(snap);
          if (t.status != TripStatus.scheduled) {
            throw AppException('A ${t.status.label.toLowerCase()} trip can no longer be edited.');
          }
          if (seats < t.acceptedPassengers) {
            throw AppException('${t.acceptedPassengers} passengers are already accepted; seats cannot go below that.');
          }
          tx.update(ref, {
            'departureTime': Timestamp.fromDate(departure),
            'totalSeats': seats,
            'availableSeats': seats - t.acceptedPassengers,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }));
  }

  Future<void> startTrip(String tripId) => _transition(tripId, from: TripStatus.scheduled, to: TripStatus.active);

  Future<void> completeTrip(String tripId) => _transition(tripId, from: TripStatus.active, to: TripStatus.completed);

  Future<void> _transition(String tripId, {required TripStatus from, required TripStatus to}) => guarded(
        () => _db.runTransaction((tx) async {
          final ref = _trips.doc(tripId);
          final snap = await tx.get(ref);
          if (!snap.exists) throw const AppException('Trip not found.');
          final t = Trip.fromDoc(snap);
          if (t.status != from) throw AppException('Trip is ${t.status.label.toLowerCase()}; action not allowed.');
          tx.update(ref, {'status': to.name, 'updatedAt': FieldValue.serverTimestamp()});
        }),
      );

  /// FR-42 / UC-10 A4: cancel a trip and every pending/accepted booking on it,
  /// so affected passengers see the new status. Used by drivers and admins.
  Future<void> cancelTrip({required Trip trip, required String reason, bool enforceCutoff = true}) async {
    if (trip.status != TripStatus.scheduled) {
      throw AppException('Only scheduled trips can be cancelled (this one is ${trip.status.label.toLowerCase()}).');
    }
    if (enforceCutoff && !trip.isBeforeCutoff) {
      throw const AppException(
          'This trip departs in less than ${AppConfig.cancelCutoffMinutes} minutes and can no longer be cancelled.');
    }
    await guarded(() async {
      final affected = await _bookings
          .where('tripId', isEqualTo: trip.id)
          .where('driverId', isEqualTo: trip.driverId)
          .get();
      final batch = _db.batch();
      batch.update(_trips.doc(trip.id), {
        'status': TripStatus.cancelled.name,
        'cancelReason': reason.trim().isEmpty ? 'Cancelled by driver' : reason.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final d in affected.docs) {
        final b = Booking.fromDoc(d);
        if (b.isActive) {
          batch.update(d.reference, {
            'status': BookingStatus.cancelled.name,
            'statusNote': 'Trip was cancelled',
            'respondedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    }, timeout: const Duration(seconds: 25));
  }
}
