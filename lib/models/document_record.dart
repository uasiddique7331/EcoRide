import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'model_utils.dart';

/// Metadata of an uploaded identity/vehicle document, `documents/{uid}_{type}`
/// (FR-10, FR-12, FR-16, FR-17, FR-19, FR-88 .. FR-92).
class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerRole,
    required this.type,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.uploadedAt,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final UserRole ownerRole;
  final DocType type;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DocStatus status;
  final String? rejectionReason;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final DateTime? uploadedAt;

  bool get isPdf => mimeType == 'application/pdf';

  factory DocumentRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return DocumentRecord(
      id: doc.id,
      ownerId: asString(d['ownerId']),
      ownerName: asString(d['ownerName']),
      ownerEmail: asString(d['ownerEmail']),
      ownerRole: enumByName(UserRole.values, d['ownerRole'], UserRole.passenger),
      type: enumByName(DocType.values, d['type'], DocType.cnic),
      storagePath: asString(d['storagePath']),
      fileName: asString(d['fileName']),
      fileSize: asInt(d['fileSize']),
      mimeType: asString(d['mimeType']),
      status: enumByName(DocStatus.values, d['status'], DocStatus.pending),
      rejectionReason: d['rejectionReason'] as String?,
      reviewedBy: d['reviewedBy'] as String?,
      reviewedByName: d['reviewedByName'] as String?,
      reviewedAt: asDate(d['reviewedAt']),
      uploadedAt: asDate(d['uploadedAt']),
    );
  }
}
