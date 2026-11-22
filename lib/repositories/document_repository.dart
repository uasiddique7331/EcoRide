import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/utils/app_exception.dart';
import '../models/document_record.dart';
import '../models/enums.dart';
import 'storage_repository.dart';

class DocumentRepository {
  DocumentRepository(this._db, this._storage);
  final FirebaseFirestore _db;
  final StorageRepository _storage;

  CollectionReference<Map<String, dynamic>> get _docs => _db.collection(FsPaths.documents);

  /// The signed-in user's own documents (FR-12, FR-13, FR-19, FR-102).
  Stream<List<DocumentRecord>> watchOwn(String uid) => _docs
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(DocumentRecord.fromDoc).toList());

  /// All documents (administrators only, enforced by security rules).
  Stream<List<DocumentRecord>> watchAll() => _docs
      .orderBy('uploadedAt', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map(DocumentRecord.fromDoc).toList());

  Stream<DocumentRecord?> watchById(String id) =>
      _docs.doc(id).snapshots().map((s) => s.exists ? DocumentRecord.fromDoc(s) : null);

  /// Replace a rejected (or pending) document; status returns to Pending.
  Future<void> resubmit({required DocumentRecord existing, required PickedUpload file}) async {
    final uploaded = await _storage.uploadDocument(uid: existing.ownerId, type: existing.type, file: file);
    try {
      await guarded(() => _docs.doc(existing.id).update({
            'storagePath': uploaded.storagePath,
            'fileName': uploaded.fileName,
            'fileSize': uploaded.size,
            'mimeType': uploaded.mimeType,
            'status': DocStatus.pending.name,
            'rejectionReason': FieldValue.delete(),
            'uploadedAt': FieldValue.serverTimestamp(),
          }));
    } catch (_) {
      await _storage.deleteQuietly(uploaded.storagePath);
      rethrow;
    }
    if (existing.storagePath.isNotEmpty) await _storage.deleteQuietly(existing.storagePath);
  }
}
