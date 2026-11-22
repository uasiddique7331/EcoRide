import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';

const vehicleTypes = ['Car', 'Hatchback', 'SUV', 'Van', 'Other'];

/// Vehicle stored in `vehicles/{driverUid}` (FR-22 .. FR-28).
/// Using the driver's uid as document ID enforces one vehicle per driver.
class Vehicle {
  const Vehicle({
    required this.ownerId,
    required this.ownerName,
    required this.registrationNumber,
    required this.make,
    required this.model,
    required this.color,
    required this.type,
    required this.capacity,
    this.createdAt,
  });

  final String ownerId;
  final String ownerName;
  final String registrationNumber;
  final String make;
  final String model;
  final String color;
  final String type;

  /// Passenger seats (excluding the driver).
  final int capacity;
  final DateTime? createdAt;

  String get title => '$make $model';
  String get summary => '$make $model • $color • $registrationNumber';

  factory Vehicle.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Vehicle(
      ownerId: asString(d['ownerId'], doc.id),
      ownerName: asString(d['ownerName']),
      registrationNumber: asString(d['registrationNumber']),
      make: asString(d['make']),
      model: asString(d['model']),
      color: asString(d['color']),
      type: asString(d['type'], 'Car'),
      capacity: asInt(d['capacity'], 1),
      createdAt: asDate(d['createdAt']),
    );
  }
}
