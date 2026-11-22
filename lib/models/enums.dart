/// Domain enumerations. Each value is persisted in Firestore by its [name].
enum UserRole {
  driver('Driver'),
  passenger('Passenger'),
  admin('Administrator');

  const UserRole(this.label);
  final String label;
}

enum AccountStatus {
  active('Active'),
  restricted('Restricted'),
  deactivated('Deactivated');

  const AccountStatus(this.label);
  final String label;
}

enum DocType {
  cnic('CNIC / Identity document'),
  vehicleRegistration('Vehicle registration card');

  const DocType(this.label);
  final String label;
}

enum DocStatus {
  pending('Pending review'),
  approved('Approved'),
  rejected('Rejected');

  const DocStatus(this.label);
  final String label;
}

enum TripStatus {
  scheduled('Scheduled'),
  active('Active'),
  completed('Completed'),
  cancelled('Cancelled');

  const TripStatus(this.label);
  final String label;
}

enum BookingStatus {
  pending('Pending'),
  accepted('Accepted'),
  rejected('Rejected'),
  cancelled('Cancelled');

  const BookingStatus(this.label);
  final String label;
}

/// Parses an enum from its stored name, falling back to [fallback].
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
