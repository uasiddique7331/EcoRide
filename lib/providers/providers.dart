import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/geocoding_service.dart';
import '../core/services/location_service.dart';
import '../core/services/routing_service.dart';
import '../models/admin_log.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/document_record.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';
import '../repositories/admin_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/booking_repository.dart';
import '../repositories/document_repository.dart';
import '../repositories/storage_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/user_repository.dart';
import '../services/ride_matcher.dart';

/// Tiny generic holder for simple UI state (tab index, flags, messages).
class Holder<T> extends Notifier<T> {
  Holder(this._initial);
  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

// --- UI state -------------------------------------------------------------
final passengerTabProvider = NotifierProvider<Holder<int>, int>(() => Holder<int>(0));
final driverTabProvider = NotifierProvider<Holder<int>, int>(() => Holder<int>(0));
final adminTabProvider = NotifierProvider<Holder<int>, int>(() => Holder<int>(0));

/// True while a registration is in flight (profile doc does not exist yet).
final registrationBusyProvider = NotifierProvider<Holder<bool>, bool>(() => Holder<bool>(false));

/// One-shot message shown on the welcome/login screens (e.g. account restricted).
final authNoticeProvider = NotifierProvider<Holder<String?>, String?>(() => Holder<String?>(null));

// --- Infrastructure -------------------------------------------------------
final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final firebaseStorageProvider = Provider<FirebaseStorage>((_) => FirebaseStorage.instance);

final routingServiceProvider = Provider<RoutingService>((_) => RoutingService());
final geocodingServiceProvider = Provider<GeocodingService>((_) => GeocodingService());
final locationServiceProvider = Provider<LocationService>((_) => LocationService());

// --- Repositories ---------------------------------------------------------
final storageRepositoryProvider =
    Provider<StorageRepository>((ref) => StorageRepository(ref.watch(firebaseStorageProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.watch(firebaseAuthProvider),
      ref.watch(firestoreProvider),
      ref.watch(storageRepositoryProvider),
    ));

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository(ref.watch(firestoreProvider)));

final documentRepositoryProvider = Provider<DocumentRepository>(
    (ref) => DocumentRepository(ref.watch(firestoreProvider), ref.watch(storageRepositoryProvider)));

final tripRepositoryProvider = Provider<TripRepository>((ref) => TripRepository(ref.watch(firestoreProvider)));

final bookingRepositoryProvider =
    Provider<BookingRepository>((ref) => BookingRepository(ref.watch(firestoreProvider)));

final adminRepositoryProvider = Provider<AdminRepository>(
    (ref) => AdminRepository(ref.watch(firestoreProvider), ref.watch(tripRepositoryProvider)));

// --- Session --------------------------------------------------------------
final authStateProvider = StreamProvider<User?>((ref) => ref.watch(authRepositoryProvider).authStateChanges());

/// Live profile of the signed-in user (null when signed out or no profile).
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<AppUser?>.value(null);
  return ref.watch(userRepositoryProvider).watchUser(user.uid);
});

/// Convenience for screens that are only reachable when signed in.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(appUserProvider).value);

// --- Own data ---------------------------------------------------------------
final myVehicleProvider = StreamProvider<Vehicle?>((ref) {
  final u = ref.watch(currentUserProvider);
  if (u == null) return Stream<Vehicle?>.value(null);
  return ref.watch(userRepositoryProvider).watchVehicle(u.uid);
});

final myDocumentsProvider = StreamProvider<List<DocumentRecord>>((ref) {
  final u = ref.watch(currentUserProvider);
  if (u == null) return Stream<List<DocumentRecord>>.value(const []);
  return ref.watch(documentRepositoryProvider).watchOwn(u.uid);
});

final driverTripsProvider = StreamProvider<List<Trip>>((ref) {
  final u = ref.watch(currentUserProvider);
  if (u == null) return Stream<List<Trip>>.value(const []);
  return ref.watch(tripRepositoryProvider).watchDriverTrips(u.uid);
});

final driverBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final u = ref.watch(currentUserProvider);
  if (u == null) return Stream<List<Booking>>.value(const []);
  return ref.watch(bookingRepositoryProvider).watchDriverBookings(u.uid);
});

final passengerBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final u = ref.watch(currentUserProvider);
  if (u == null) return Stream<List<Booking>>.value(const []);
  return ref.watch(bookingRepositoryProvider).watchPassengerBookings(u.uid);
});

// --- Families -----------------------------------------------------------------
final tripProvider = StreamProvider.autoDispose.family<Trip?, String>(
    (ref, id) => ref.watch(tripRepositoryProvider).watchTrip(id));

final bookingProvider = StreamProvider.autoDispose.family<Booking?, String>(
    (ref, id) => ref.watch(bookingRepositoryProvider).watchBooking(id));

/// Bookings of one trip for its driver. Key: (tripId, driverId).
final tripBookingsProvider = StreamProvider.autoDispose.family<List<Booking>, ({String tripId, String driverId})>(
    (ref, k) => ref.watch(bookingRepositoryProvider).watchTripBookings(tripId: k.tripId, driverId: k.driverId));

final documentProvider = StreamProvider.autoDispose.family<DocumentRecord?, String>(
    (ref, id) => ref.watch(documentRepositoryProvider).watchById(id));

final userByIdProvider = StreamProvider.autoDispose.family<AppUser?, String>(
    (ref, uid) => ref.watch(userRepositoryProvider).watchUser(uid));

final vehicleByOwnerProvider = StreamProvider.autoDispose.family<Vehicle?, String>(
    (ref, uid) => ref.watch(userRepositoryProvider).watchVehicle(uid));

final documentsByOwnerProvider = StreamProvider.autoDispose.family<List<DocumentRecord>, String>(
    (ref, uid) => ref.watch(documentRepositoryProvider).watchOwn(uid));

// --- Ride search (UC-05) ----------------------------------------------------
final rideSearchProvider = FutureProvider.autoDispose.family<List<RideMatch>, RideQuery>((ref, q) async {
  const window = Duration(minutes: 90);
  final from = q.desiredTime.subtract(window);
  final now = DateTime.now();
  final trips = await ref.watch(tripRepositoryProvider).candidateTrips(
        from: from.isBefore(now) ? now : from,
        to: q.desiredTime.add(window),
      );
  return RideMatcher.match(trips, q);
});

// --- Admin ------------------------------------------------------------------
final allUsersProvider = StreamProvider.autoDispose<List<AppUser>>(
    (ref) => ref.watch(userRepositoryProvider).watchAllUsers());
final allDocumentsProvider = StreamProvider.autoDispose<List<DocumentRecord>>(
    (ref) => ref.watch(documentRepositoryProvider).watchAll());
final allTripsProvider =
    StreamProvider.autoDispose<List<Trip>>((ref) => ref.watch(tripRepositoryProvider).watchAllTrips());
final allBookingsProvider = StreamProvider.autoDispose<List<Booking>>(
    (ref) => ref.watch(bookingRepositoryProvider).watchAllBookings());
final allVehiclesProvider = StreamProvider.autoDispose<List<Vehicle>>(
    (ref) => ref.watch(userRepositoryProvider).watchAllVehicles());
final adminLogsProvider = StreamProvider.autoDispose<List<AdminLog>>(
    (ref) => ref.watch(adminRepositoryProvider).watchRecentLogs());
final adminStatsProvider =
    FutureProvider.autoDispose<AdminStats>((ref) => ref.watch(adminRepositoryProvider).fetchStats());
