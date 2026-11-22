import 'package:latlong2/latlong.dart';

import '../core/config/app_config.dart';
import '../core/services/geo_utils.dart';
import '../models/enums.dart';
import '../models/place_point.dart';
import '../models/trip.dart';
import 'fare_calculator.dart';

/// A passenger's search criteria (FR-47, FR-48, FR-53). Value-equality lets it
/// be used as a Riverpod family key.
class RideQuery {
  const RideQuery({
    required this.pickup,
    required this.dropoff,
    required this.desiredTime,
    this.seats = 1,
  });

  final PlacePoint pickup;
  final PlacePoint dropoff;
  final DateTime desiredTime;
  final int seats;

  @override
  bool operator ==(Object other) =>
      other is RideQuery &&
      other.pickup == pickup &&
      other.dropoff == dropoff &&
      other.desiredTime == desiredTime &&
      other.seats == seats;

  @override
  int get hashCode => Object.hash(pickup, dropoff, desiredTime, seats);
}

class RideMatch {
  const RideMatch({
    required this.trip,
    required this.pickupDistanceKm,
    required this.dropoffOffsetKm,
    required this.timeDifference,
    required this.estimatedShare,
  });

  final Trip trip;

  /// Distance between passenger pickup and the driver's start (FR-49).
  final double pickupDistanceKm;

  /// Distance between the passenger's drop-off and the driver's route.
  final double dropoffOffsetKm;
  final Duration timeDifference;
  final int estimatedShare;
}

/// Implements FR-54 .. FR-59 as a pure function so it can be unit tested.
///
/// A trip matches when ALL of these hold (FR-58):
///  1. its start is within [AppConfig.searchRadiusKm] of the passenger pickup;
///  2. the route is compatible: the passenger's drop-off lies within
///     [AppConfig.routeCorridorKm] of the driver's route and *after* the
///     point of the route nearest to the pickup (same direction of travel);
///  3. departure is within +/- [AppConfig.timeWindowMinutes] of the request;
///  4. enough seats remain and the trip is still scheduled and in the future.
class RideMatcher {
  RideMatcher._();

  static List<RideMatch> match(List<Trip> trips, RideQuery q, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final window = Duration(minutes: AppConfig.timeWindowMinutes);
    final results = <RideMatch>[];

    for (final t in trips) {
      if (t.status != TripStatus.scheduled) continue;
      if (!t.departureTime.isAfter(clock)) continue;
      if (t.availableSeats < q.seats) continue; // FR-57

      final timeDiff = t.departureTime.difference(q.desiredTime).abs();
      if (timeDiff > window) continue; // FR-56

      final pickupDist = GeoUtils.haversineKm(t.origin.latLng, q.pickup.latLng);
      if (pickupDist > AppConfig.searchRadiusKm) continue; // FR-49, FR-54

      final route = t.route.length >= 2 ? t.route : <LatLng>[t.origin.latLng, t.destination.latLng];
      final pickupIdx = GeoUtils.nearestIndex(route, q.pickup.latLng);
      final dropIdx = GeoUtils.nearestIndex(route, q.dropoff.latLng);
      if (pickupIdx < 0 || dropIdx < 0) continue;
      final dropOffset = GeoUtils.haversineKm(route[dropIdx], q.dropoff.latLng);
      if (dropOffset > AppConfig.routeCorridorKm) continue; // FR-55
      if (dropIdx <= pickupIdx) continue; // wrong direction

      results.add(RideMatch(
        trip: t,
        pickupDistanceKm: pickupDist,
        dropoffOffsetKm: dropOffset,
        timeDifference: timeDiff,
        estimatedShare: FareCalculator.estimatedShare(t.totalFare, t.acceptedPassengers, q.seats),
      ));
    }

    results.sort((a, b) {
      final byTime = a.timeDifference.compareTo(b.timeDifference);
      return byTime != 0 ? byTime : a.pickupDistanceKm.compareTo(b.pickupDistanceKm);
    });
    return results;
  }
}
