import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'model_utils.dart';
import 'place_point.dart';

/// A passenger's booking request, `bookings/{tripId}_{passengerId}` (FR-61 .. FR-72).
class Booking {
  const Booking({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.seats,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.originName,
    required this.destinationName,
    required this.estimatedShare,
    required this.tripTotalFare,
    this.driverName,
    this.driverPhone,
    this.statusNote,
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String tripId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final int seats;
  final BookingStatus status;
  final PlacePoint pickup;
  final PlacePoint dropoff;

  /// Static snapshot of the trip's route names, for list display.
  final String originName;
  final String destinationName;

  /// Share estimated when the request was made (FR-62 "applicable fare").
  final int estimatedShare;
  final int tripTotalFare;

  /// Set when the driver accepts so the passenger can pay directly (FR-82).
  final String? driverName;
  final String? driverPhone;
  final String? statusNote;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  bool get isActive => status == BookingStatus.pending || status == BookingStatus.accepted;

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Booking(
      id: doc.id,
      tripId: asString(d['tripId']),
      driverId: asString(d['driverId']),
      passengerId: asString(d['passengerId']),
      passengerName: asString(d['passengerName']),
      passengerPhone: asString(d['passengerPhone']),
      seats: asInt(d['seats'], 1),
      status: enumByName(BookingStatus.values, d['status'], BookingStatus.pending),
      pickup: PlacePoint.fromMap(d['pickup'] as Map<String, dynamic>?),
      dropoff: PlacePoint.fromMap(d['dropoff'] as Map<String, dynamic>?),
      originName: asString(d['originName']),
      destinationName: asString(d['destinationName']),
      estimatedShare: asInt(d['estimatedShare']),
      tripTotalFare: asInt(d['tripTotalFare']),
      driverName: d['driverName'] as String?,
      driverPhone: d['driverPhone'] as String?,
      statusNote: d['statusNote'] as String?,
      createdAt: asDate(d['createdAt']),
      respondedAt: asDate(d['respondedAt']),
    );
  }
}
