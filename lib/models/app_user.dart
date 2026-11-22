import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'model_utils.dart';

/// Profile stored in `users/{uid}` (FR-01, FR-08, FR-11, FR-18).
class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.status,
    required this.isVerified,
    this.createdAt,
  });

  final String uid;
  final UserRole role;
  final String fullName;
  final String email;
  final String phone;
  final AccountStatus status;

  /// True once an administrator approved all required documents.
  final bool isVerified;
  final DateTime? createdAt;

  bool get isActive => status == AccountStatus.active;
  bool get isDriver => role == UserRole.driver;
  bool get isPassenger => role == UserRole.passenger;
  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      role: enumByName(UserRole.values, d['role'], UserRole.passenger),
      fullName: asString(d['fullName']),
      email: asString(d['email']),
      phone: asString(d['phone']),
      status: enumByName(AccountStatus.values, d['status'], AccountStatus.active),
      isVerified: d['isVerified'] == true,
      createdAt: asDate(d['createdAt']),
    );
  }
}
