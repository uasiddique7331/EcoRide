import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_utils.dart';

/// Audit entry written for every administrative action (FR-99).
class AdminLog {
  const AdminLog({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.details,
    this.createdAt,
  });

  final String id;
  final String adminId;
  final String adminName;
  final String action;
  final String targetType;
  final String targetId;
  final String details;
  final DateTime? createdAt;

  factory AdminLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AdminLog(
      id: doc.id,
      adminId: asString(d['adminId']),
      adminName: asString(d['adminName']),
      action: asString(d['action']),
      targetType: asString(d['targetType']),
      targetId: asString(d['targetId']),
      details: asString(d['details']),
      createdAt: asDate(d['createdAt']),
    );
  }
}
