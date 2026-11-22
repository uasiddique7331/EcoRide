import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/utils/app_exception.dart';
import '../models/app_user.dart';
import '../models/vehicle.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection(FsPaths.users);
  CollectionReference<Map<String, dynamic>> get _vehicles => _db.collection(FsPaths.vehicles);

  Stream<AppUser?> watchUser(String uid) =>
      _users.doc(uid).snapshots().map((s) => s.exists ? AppUser.fromDoc(s) : null);

  Stream<List<AppUser>> watchAllUsers() => _users
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  /// Users may change only their own name and phone (FR-08, FR-14, FR-20).
  Future<void> updateProfile({required String uid, required String fullName, required String phone}) =>
      guarded(() => _users.doc(uid).update({
            'fullName': fullName.trim(),
            'phone': phone,
            'updatedAt': FieldValue.serverTimestamp(),
          }));

  // --- Vehicles (FR-22 .. FR-28, FR-93) --------------------------------
  Stream<Vehicle?> watchVehicle(String driverUid) =>
      _vehicles.doc(FsPaths.vehicleId(driverUid)).snapshots().map((s) => s.exists ? Vehicle.fromDoc(s) : null);

  Stream<List<Vehicle>> watchAllVehicles() => _vehicles
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map(Vehicle.fromDoc).toList());

  /// Registration number, make and model are locked after registration; the
  /// owner association can never change (FR-27).
  Future<void> updateVehicle({
    required String driverUid,
    required String color,
    required String type,
    required int capacity,
  }) =>
      guarded(() => _vehicles.doc(FsPaths.vehicleId(driverUid)).update({
            'color': color.trim(),
            'type': type,
            'capacity': capacity,
            'updatedAt': FieldValue.serverTimestamp(),
          }));
}
