import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/utils/app_exception.dart';
import '../models/admin_log.dart';
import '../models/app_user.dart';
import '../models/document_record.dart';
import '../models/enums.dart';
import '../models/trip.dart';
import 'trip_repository.dart';

/// Aggregated figures for the admin dashboard (FR-85).
class AdminStats {
  const AdminStats({
    required this.drivers,
    required this.passengers,
    required this.pendingDocuments,
    required this.trips,
    required this.scheduledTrips,
    required this.bookings,
    required this.pendingBookings,
  });

  final int drivers;
  final int passengers;
  final int pendingDocuments;
  final int trips;
  final int scheduledTrips;
  final int bookings;
  final int pendingBookings;
}

/// Administrative operations. Every mutation writes an audit log entry in the
/// same atomic batch (FR-99).
class AdminRepository {
  AdminRepository(this._db, this._tripRepo);
  final FirebaseFirestore _db;
  final TripRepository _tripRepo;

  CollectionReference<Map<String, dynamic>> get _logs => _db.collection(FsPaths.adminLogs);

  Map<String, dynamic> _log(AppUser admin, String action, String targetType, String targetId, String details) => {
        'adminId': admin.uid,
        'adminName': admin.fullName,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Stream<List<AdminLog>> watchRecentLogs({int limit = 15}) => _logs
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(AdminLog.fromDoc).toList());

  Future<AdminStats> fetchStats() async {
    Future<int> count(Query<Map<String, dynamic>> q) async => (await q.count().get()).count ?? 0;
    final users = _db.collection(FsPaths.users);
    final trips = _db.collection(FsPaths.trips);
    final bookings = _db.collection(FsPaths.bookings);
    final results = await guarded(
      () => Future.wait([
        count(users.where('role', isEqualTo: UserRole.driver.name)),
        count(users.where('role', isEqualTo: UserRole.passenger.name)),
        count(_db.collection(FsPaths.documents).where('status', isEqualTo: DocStatus.pending.name)),
        count(trips),
        count(trips.where('status', isEqualTo: TripStatus.scheduled.name)),
        count(bookings),
        count(bookings.where('status', isEqualTo: BookingStatus.pending.name)),
      ]),
      timeout: const Duration(seconds: 25),
    );
    return AdminStats(
      drivers: results[0],
      passengers: results[1],
      pendingDocuments: results[2],
      trips: results[3],
      scheduledTrips: results[4],
      bookings: results[5],
      pendingBookings: results[6],
    );
  }

  /// UC-12: approve or reject a document. In one atomic batch this updates the
  /// document, the owner's `isVerified` flag and the audit log (FR-89 .. FR-92).
  Future<void> reviewDocument({
    required DocumentRecord document,
    required AppUser admin,
    required bool approve,
    String? rejectionReason,
  }) async {
    if (!approve && (rejectionReason == null || rejectionReason.trim().isEmpty)) {
      throw const AppException('Please provide a reason for rejecting this document.');
    }
    await guarded(() async {
      final ownerDocs =
          await _db.collection(FsPaths.documents).where('ownerId', isEqualTo: document.ownerId).get();
      final newStatus = approve ? DocStatus.approved : DocStatus.rejected;

      final requiredTypes = document.ownerRole == UserRole.driver
          ? {DocType.cnic, DocType.vehicleRegistration}
          : {DocType.cnic};
      final approvedTypes = <DocType>{};
      for (final d in ownerDocs.docs) {
        final rec = DocumentRecord.fromDoc(d);
        final status = rec.id == document.id ? newStatus : rec.status;
        if (status == DocStatus.approved) approvedTypes.add(rec.type);
      }
      final verified = approvedTypes.containsAll(requiredTypes);

      final batch = _db.batch();
      batch.update(_db.collection(FsPaths.documents).doc(document.id), {
        'status': newStatus.name,
        'rejectionReason': approve ? FieldValue.delete() : rejectionReason!.trim(),
        'reviewedBy': admin.uid,
        'reviewedByName': admin.fullName,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection(FsPaths.users).doc(document.ownerId), {
        'isVerified': verified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        _logs.doc(),
        _log(
          admin,
          approve ? 'document_approved' : 'document_rejected',
          'document',
          document.id,
          '${document.type.label} of ${document.ownerName}${approve ? '' : ' — ${rejectionReason!.trim()}'}',
        ),
      );
      await batch.commit();
    }, timeout: const Duration(seconds: 25));
  }

  /// FR-96: restrict / deactivate / re-activate an account.
  Future<void> setAccountStatus({
    required AppUser target,
    required AppUser admin,
    required AccountStatus status,
    String? reason,
  }) async {
    if (target.isAdmin) throw const AppException('Administrator accounts cannot be changed here.');
    if (target.uid == admin.uid) throw const AppException('You cannot change your own account status.');
    await guarded(() async {
      final batch = _db.batch();
      batch.update(_db.collection(FsPaths.users).doc(target.uid), {
        'status': status.name,
        'statusReason': (reason ?? '').trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        _logs.doc(),
        _log(admin, 'account_${status.name}', 'user', target.uid,
            '${target.fullName} → ${status.label}${(reason ?? '').trim().isEmpty ? '' : ' — ${reason!.trim()}'}'),
      );
      await batch.commit();
    });
  }

  /// UC-14: an administrator may cancel a trip (cutoff does not apply).
  Future<void> cancelTrip({required Trip trip, required AppUser admin, required String reason}) async {
    await _tripRepo.cancelTrip(trip: trip, reason: 'Cancelled by administrator: $reason', enforceCutoff: false);
    await guarded(() => _logs.add(_log(admin, 'trip_cancelled', 'trip', trip.id,
        '${trip.origin.name} → ${trip.destination.name} — $reason')));
  }
}
