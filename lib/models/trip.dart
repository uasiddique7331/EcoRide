import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../core/config/app_config.dart';
import 'enums.dart';
import 'model_utils.dart';
import 'place_point.dart';
import 'vehicle.dart';

/// Snapshot of the driver's vehicle embedded in a trip (FR-26, FR-40).
class TripVehicle {
  const TripVehicle({
    required this.make,
    required this.model,
    required this.color,
    required this.type,
    required this.registrationNumber,
  });

  final String make;
  final String model;
  final String color;
  final String type;
  final String registrationNumber;

  String get summary => '$make $model • $color • $registrationNumber';

  factory TripVehicle.fromVehicle(Vehicle v) => TripVehicle(
        make: v.make,
        model: v.model,
        color: v.color,
        type: v.type,
        registrationNumber: v.registrationNumber,
      );

  Map<String, dynamic> toMap() => {
        'make': make,
        'model': model,
        'color': color,
        'type': type,
        'registrationNumber': registrationNumber,
      };

  factory TripVehicle.fromMap(Map<String, dynamic>? m) {
    final d = m ?? const <String, dynamic>{};
    return TripVehicle(
      make: asString(d['make']),
      model: asString(d['model']),
      color: asString(d['color']),
      type: asString(d['type']),
      registrationNumber: asString(d['registrationNumber']),
    );
  }
}

/// A published carpool trip, `trips/{id}` (FR-37 .. FR-45).
///
/// Fare fields: [totalFare] is fixed at publication (distance x PKR 25);
/// the per-passenger share is *derived* from [acceptedPassengers], so it is
/// always consistent with the current accepted bookings (FR-81).
class Trip {
  const Trip({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.vehicle,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.totalSeats,
    required this.availableSeats,
    required this.acceptedPassengers,
    required this.status,
    required this.distanceKm,
    required this.distanceIsEstimate,
    required this.totalFare,
    required this.farePerKm,
    required this.route,
    this.cancelReason,
    this.createdAt,
  });

  final String id;
  final String driverId;
  final String driverName;
  final TripVehicle vehicle;
  final PlacePoint origin;
  final PlacePoint destination;
  final DateTime departureTime;
  final int totalSeats;
  final int availableSeats;

  /// Number of accepted *passengers* (sum of seats of accepted bookings).
  final int acceptedPassengers;
  final TripStatus status;
  final double distanceKm;
  final bool distanceIsEstimate;
  final int totalFare;
  final int farePerKm;
  final List<LatLng> route;
  final String? cancelReason;
  final DateTime? createdAt;

  /// Equal share per accepted passenger, rounded up to a whole rupee (FR-78).
  /// Null while nobody is accepted (UC-09 A2).
  int? get sharePerPassenger =>
      acceptedPassengers <= 0 ? null : (totalFare + acceptedPassengers - 1) ~/ acceptedPassengers;

  bool get isUpcoming => status == TripStatus.scheduled && departureTime.isAfter(DateTime.now());

  bool get canAcceptBookings =>
      status == TripStatus.scheduled && availableSeats > 0 && departureTime.isAfter(DateTime.now());

  /// Whether cancellations/edits are still allowed under the cut-off rule.
  bool get isBeforeCutoff => DateTime.now()
      .isBefore(departureTime.subtract(const Duration(minutes: AppConfig.cancelCutoffMinutes)));

  factory Trip.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final rawRoute = d['routePoints'];
    final route = <LatLng>[
      if (rawRoute is List)
        for (final p in rawRoute)
          if (p is GeoPoint) LatLng(p.latitude, p.longitude),
    ];
    return Trip(
      id: doc.id,
      driverId: asString(d['driverId']),
      driverName: asString(d['driverName']),
      vehicle: TripVehicle.fromMap(d['vehicle'] as Map<String, dynamic>?),
      origin: PlacePoint.fromMap(d['origin'] as Map<String, dynamic>?),
      destination: PlacePoint.fromMap(d['destination'] as Map<String, dynamic>?),
      departureTime: asDate(d['departureTime']) ?? DateTime.now(),
      totalSeats: asInt(d['totalSeats']),
      availableSeats: asInt(d['availableSeats']),
      acceptedPassengers: asInt(d['acceptedPassengers']),
      status: enumByName(TripStatus.values, d['status'], TripStatus.scheduled),
      distanceKm: asDouble(d['distanceKm']),
      distanceIsEstimate: d['distanceIsEstimate'] == true,
      totalFare: asInt(d['totalFare']),
      farePerKm: asInt(d['farePerKm'], AppConfig.farePerKm),
      route: route,
      cancelReason: d['cancelReason'] as String?,
      createdAt: asDate(d['createdAt']),
    );
  }
}
