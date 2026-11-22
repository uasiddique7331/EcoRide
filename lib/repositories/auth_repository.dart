import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_paths.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/enums.dart';
import 'storage_repository.dart';

/// Authentication + registration (FR-01 .. FR-07, FR-09 .. FR-19, UC-01 .. UC-03, UC-15).
class AuthRepository {
  AuthRepository(this._auth, this._db, this._storage);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final StorageRepository _storage;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AppException(friendlyError(e)); // UC-15 A1: never fake a logout
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim()).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw AppException(friendlyError(e));
    }
  }

  Map<String, dynamic> _userDoc({
    required UserRole role,
    required String fullName,
    required String email,
    required String phone,
  }) =>
      {
        'role': role.name,
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': Validators.normalizePhone(phone),
        'status': AccountStatus.active.name,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _docRecord({
    required String uid,
    required String fullName,
    required String email,
    required UserRole role,
    required DocType type,
    required UploadedFile file,
  }) =>
      {
        'ownerId': uid,
        'ownerName': fullName.trim(),
        'ownerEmail': email.trim().toLowerCase(),
        'ownerRole': role.name,
        'type': type.name,
        'storagePath': file.storagePath,
        'fileName': file.fileName,
        'fileSize': file.size,
        'mimeType': file.mimeType,
        'status': DocStatus.pending.name,
        'uploadedAt': FieldValue.serverTimestamp(),
      };

  /// UC-01: Register as a passenger.
  Future<void> registerPassenger({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required PickedUpload cnic,
  }) async {
    User? created;
    final uploaded = <String>[];
    try {
      final cred = await _auth
          .createUserWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 20));
      created = cred.user;
      final uid = created!.uid;

      final cnicFile = await _storage.uploadDocument(uid: uid, type: DocType.cnic, file: cnic);
      uploaded.add(cnicFile.storagePath);

      final batch = _db.batch();
      batch.set(_db.collection(FsPaths.users).doc(uid),
          _userDoc(role: UserRole.passenger, fullName: fullName, email: email, phone: phone));
      batch.set(
        _db.collection(FsPaths.documents).doc(FsPaths.documentId(uid, DocType.cnic.name)),
        _docRecord(uid: uid, fullName: fullName, email: email, role: UserRole.passenger, type: DocType.cnic, file: cnicFile),
      );
      await batch.commit().timeout(const Duration(seconds: 20));
    } catch (e) {
      await _rollback(created, uploaded);
      throw AppException(friendlyError(e));
    }
  }

  /// UC-02: Register as a driver together with exactly one vehicle.
  Future<void> registerDriver({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required PickedUpload cnic,
    required PickedUpload vehicleDoc,
    required String plate,
    required String make,
    required String model,
    required String color,
    required String vehicleType,
    required int capacity,
  }) async {
    User? created;
    final uploaded = <String>[];
    try {
      final cred = await _auth
          .createUserWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 20));
      created = cred.user;
      final uid = created!.uid;

      final cnicFile = await _storage.uploadDocument(uid: uid, type: DocType.cnic, file: cnic);
      uploaded.add(cnicFile.storagePath);
      final vehFile = await _storage.uploadDocument(uid: uid, type: DocType.vehicleRegistration, file: vehicleDoc);
      uploaded.add(vehFile.storagePath);

      final batch = _db.batch();
      batch.set(_db.collection(FsPaths.users).doc(uid),
          _userDoc(role: UserRole.driver, fullName: fullName, email: email, phone: phone));
      batch.set(
        _db.collection(FsPaths.documents).doc(FsPaths.documentId(uid, DocType.cnic.name)),
        _docRecord(uid: uid, fullName: fullName, email: email, role: UserRole.driver, type: DocType.cnic, file: cnicFile),
      );
      batch.set(
        _db.collection(FsPaths.documents).doc(FsPaths.documentId(uid, DocType.vehicleRegistration.name)),
        _docRecord(
            uid: uid,
            fullName: fullName,
            email: email,
            role: UserRole.driver,
            type: DocType.vehicleRegistration,
            file: vehFile),
      );
      batch.set(_db.collection(FsPaths.vehicles).doc(FsPaths.vehicleId(uid)), {
        'ownerId': uid,
        'ownerName': fullName.trim(),
        'registrationNumber': plate.trim().toUpperCase(),
        'make': make.trim(),
        'model': model.trim(),
        'color': color.trim(),
        'type': vehicleType,
        'capacity': capacity,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit().timeout(const Duration(seconds: 20));
    } catch (e) {
      await _rollback(created, uploaded);
      throw AppException(friendlyError(e));
    }
  }

  /// Undo a half-finished registration so the user can retry cleanly.
  Future<void> _rollback(User? user, List<String> uploadedPaths) async {
    for (final p in uploadedPaths) {
      await _storage.deleteQuietly(p);
    }
    try {
      await user?.delete();
    } catch (_) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }
}
