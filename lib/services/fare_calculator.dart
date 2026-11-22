import '../core/config/app_config.dart';

/// Fare rules from the SRS (FR-73 .. FR-81).
///
/// NOTE: the SRS text of FR-75 prints "Distance / 25" but its own worked
/// example (20 km -> PKR 500) and FR-73 (PKR 25 per km) define the formula as
/// Total = Distance x 25, which is what is implemented here.
class FareCalculator {
  FareCalculator._();

  /// Total trip fare in whole rupees (FR-75).
  static int totalFare(double distanceKm, {int ratePerKm = AppConfig.farePerKm}) =>
      (distanceKm * ratePerKm).round();

  /// Equal share per accepted passenger, rounded up to a whole rupee so the
  /// vehicle owner never receives less than the total (FR-78, UC-09 A5).
  /// Returns null when nobody has been accepted (UC-09 A2).
  static int? sharePerPassenger(int totalFare, int acceptedPassengers) {
    if (acceptedPassengers <= 0) return null;
    return (totalFare + acceptedPassengers - 1) ~/ acceptedPassengers;
  }

  /// Share a passenger would pay if [requestedSeats] more passengers are
  /// accepted on top of [alreadyAccepted] (shown before booking, FR-51).
  static int estimatedShare(int totalFare, int alreadyAccepted, int requestedSeats) {
    final n = alreadyAccepted + (requestedSeats < 1 ? 1 : requestedSeats);
    return (totalFare + n - 1) ~/ n;
  }
}
