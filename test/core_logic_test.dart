import 'package:ecoride/core/services/geo_utils.dart';
import 'package:ecoride/core/utils/validators.dart';
import 'package:ecoride/models/enums.dart';
import 'package:ecoride/models/place_point.dart';
import 'package:ecoride/models/trip.dart';
import 'package:ecoride/models/vehicle.dart';
import 'package:ecoride/services/fare_calculator.dart';
import 'package:ecoride/services/ride_matcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Trip _trip({
  required DateTime departure,
  int available = 3,
  TripStatus status = TripStatus.scheduled,
  LatLng from = const LatLng(31.5204, 74.3587),
  LatLng to = const LatLng(31.4504, 74.2700),
}) {
  return Trip(
    id: 't1',
    driverId: 'd1',
    driverName: 'Driver',
    vehicle: const TripVehicle(make: 'Toyota', model: 'Corolla', color: 'White', type: 'Car', registrationNumber: 'LEA-1234'),
    origin: PlacePoint(lat: from.latitude, lng: from.longitude, name: 'A'),
    destination: PlacePoint(lat: to.latitude, lng: to.longitude, name: 'B'),
    departureTime: departure,
    totalSeats: 3,
    availableSeats: available,
    acceptedPassengers: 0,
    status: status,
    distanceKm: 20,
    distanceIsEstimate: false,
    totalFare: 500,
    farePerKm: 25,
    route: GeoUtils.interpolate(from, to, count: 40),
  );
}

void main() {
  group('FareCalculator (SRS UC-09 example)', () {
    test('20 km x PKR 25 = PKR 500', () => expect(FareCalculator.totalFare(20), 500));
    test('500 / 4 passengers = 125', () => expect(FareCalculator.sharePerPassenger(500, 4), 125));
    test('no accepted passengers -> null', () => expect(FareCalculator.sharePerPassenger(500, 0), isNull));
    test('rounds up to whole rupee', () => expect(FareCalculator.sharePerPassenger(500, 3), 167));
    test('estimated share includes requested seats', () => expect(FareCalculator.estimatedShare(500, 1, 1), 250));
  });

  group('RideMatcher', () {
    final now = DateTime(2026, 1, 1, 8, 0);
    final dep = DateTime(2026, 1, 1, 9, 0);
    final trip0 = _trip(departure: dep);
    const pickup = PlacePoint(lat: 31.5100, lng: 74.3500, name: 'Near start');
    const drop = PlacePoint(lat: 31.4504, lng: 74.2700, name: 'At destination');
    final q = RideQuery(pickup: pickup, dropoff: drop, desiredTime: dep);

    test('matches compatible trip', () => expect(RideMatcher.match([trip0], q, now: now), hasLength(1)));

    test('rejects pickup beyond 10 km', () {
      final far = RideQuery(pickup: const PlacePoint(lat: 31.7, lng: 74.6, name: 'far'), dropoff: drop, desiredTime: dep);
      expect(RideMatcher.match([trip0], far, now: now), isEmpty);
    });

    test('rejects wrong direction', () {
      final back = RideQuery(pickup: drop, dropoff: pickup, desiredTime: dep);
      expect(RideMatcher.match([trip0], back, now: now), isEmpty);
    });

    test('rejects time outside window', () {
      final late = RideQuery(pickup: pickup, dropoff: drop, desiredTime: dep.add(const Duration(hours: 5)));
      expect(RideMatcher.match([trip0], late, now: now), isEmpty);
    });

    test('rejects insufficient seats', () {
      final full = _trip(departure: dep, available: 1);
      final two = RideQuery(pickup: pickup, dropoff: drop, desiredTime: dep, seats: 2);
      expect(RideMatcher.match([full], two, now: now), isEmpty);
    });

    test('rejects cancelled trips', () {
      final c = _trip(departure: dep, status: TripStatus.cancelled);
      expect(RideMatcher.match([c], q, now: now), isEmpty);
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email('a@b.com'), isNull);
      expect(Validators.email('nope'), isNotNull);
    });
    test('pakistani phone + normalisation', () {
      expect(Validators.phone('0300 1234567'), isNull);
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.normalizePhone('0300-1234567'), '+923001234567');
    });
    test('password', () {
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
    });
    test('upload', () {
      expect(Validators.upload(fileName: 'a.pdf', sizeBytes: 1000), isNull);
      expect(Validators.upload(fileName: 'a.exe', sizeBytes: 1000), isNotNull);
      expect(Validators.upload(fileName: 'a.png', sizeBytes: 50 * 1024 * 1024), isNotNull);
    });
  });

  test('haversine Lahore -> Islamabad is roughly 270 km', () {
    final d = GeoUtils.haversineKm(const LatLng(31.5204, 74.3587), const LatLng(33.6844, 73.0479));
    expect(d, inInclusiveRange(240, 300));
  });

  test('vehicleTypes is non-empty', () => expect(vehicleTypes, isNotEmpty));
}
