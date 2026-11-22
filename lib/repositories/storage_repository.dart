import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../core/config/app_config.dart';
import '../core/constants/firestore_paths.dart';
import '../core/utils/app_exception.dart';
import '../models/enums.dart';

/// A file chosen on the device, validated but not yet uploaded.
class PickedUpload {
  const PickedUpload({required this.path, required this.name, required this.size});

  final String path;
  final String name;
  final int size;

  String get extension => name.contains('.') ? name.split('.').last.toLowerCase() : '';
  String get mimeType => switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };
}

/// Result of a successful upload.
class UploadedFile {
  const UploadedFile({required this.storagePath, required this.fileName, required this.size, required this.mimeType});

  final String storagePath;
  final String fileName;
  final int size;
  final String mimeType;
}

/// Firebase Storage access for sensitive documents (FR-10, FR-28, FR-98).
class StorageRepository {
  StorageRepository(this._storage);
  final FirebaseStorage _storage;

  Future<UploadedFile> uploadDocument({
    required String uid,
    required DocType type,
    required PickedUpload file,
  }) async {
    final path = FsPaths.storageDocumentPath(uid, type.name, file.extension);
    final ref = _storage.ref(path);
    final task = ref.putFile(File(file.path), SettableMetadata(contentType: file.mimeType));
    try {
      await task.timeout(AppConfig.uploadTimeout);
    } on TimeoutException {
      await task.cancel();
      throw AppException.network;
    } catch (e) {
      throw AppException(friendlyError(e));
    }
    return UploadedFile(storagePath: path, fileName: file.name, size: file.size, mimeType: file.mimeType);
  }

  /// Short-lived access URL for an authorised viewer (rules enforce access).
  Future<String> downloadUrl(String path) =>
      guarded(() => _storage.ref(path).getDownloadURL(), timeout: const Duration(seconds: 20));

  Future<void> deleteQuietly(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {}
  }
}
