/// Firestore collection names and Storage path builders.
class FsPaths {
  FsPaths._();

  static const users = 'users';
  static const vehicles = 'vehicles';
  static const documents = 'documents';
  static const trips = 'trips';
  static const bookings = 'bookings';
  static const adminLogs = 'adminLogs';

  /// Deterministic ID: one vehicle per driver (FR-25) is guaranteed by using
  /// the driver's uid as the vehicle document ID.
  static String vehicleId(String driverUid) => driverUid;

  /// Deterministic ID: one document record per owner per type.
  static String documentId(String ownerUid, String typeName) => '${ownerUid}_$typeName';

  /// Deterministic ID: prevents duplicate booking requests (UC-07 A4).
  static String bookingId(String tripId, String passengerUid) => '${tripId}_$passengerUid';

  static String storageDocumentPath(String uid, String typeName, String ext) =>
      'documents/$uid/${typeName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
}
