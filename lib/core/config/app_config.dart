/// Central, documented configuration for all business rules in the SRS.
///
/// Changing a value here changes the behaviour of the whole app. Server-side
/// limits that must also be enforced by Firebase Security Rules are noted.
class AppConfig {
  AppConfig._();

  static const appName = 'EcoRide';

  // --- Fare (FR-73 .. FR-83) -------------------------------------------
  /// Fixed fare rate in PKR per kilometre (FR-73).
  static const int farePerKm = 25;

  /// When the road route cannot be fetched, straight-line distance is
  /// multiplied by this factor to estimate the road distance (UC-04 A5).
  static const double roadFactorForEstimate = 1.3;

  // --- Ride discovery & matching (FR-49, FR-54 .. FR-58) ---------------
  /// Pickup discovery radius in km (FR-49).
  static const double searchRadiusKm = 10.0;

  /// Departure-time compatibility window (+/-) in minutes (FR-56).
  static const int timeWindowMinutes = 90;

  /// Maximum distance (km) between the passenger's drop-off and the
  /// driver's route for the route to count as compatible (FR-55).
  static const double routeCorridorKm = 3.0;

  // --- Booking rules (FR-61 .. FR-72) ----------------------------------
  /// Max seats one booking request may contain.
  static const int maxSeatsPerBooking = 4;

  /// Passengers / drivers may cancel until this many minutes before departure.
  static const int cancelCutoffMinutes = 30;

  // --- Uploads (FR-21) --------------------------------------------------
  static const int maxUploadBytes = 5 * 1024 * 1024; // 5 MB (also in storage.rules)
  static const List<String> allowedUploadExtensions = ['jpg', 'jpeg', 'png', 'pdf'];

  // --- Validation (FR-03) ----------------------------------------------
  static const int minPasswordLength = 8;
  static const int maxVehicleCapacity = 8;

  // --- Networking --------------------------------------------------------
  static const Duration networkTimeout = Duration(seconds: 15);
  static const Duration uploadTimeout = Duration(seconds: 90);

  /// Nominatim / OSM usage policy requires an identifying User-Agent.
  static const String httpUserAgent = 'EcoRide-FYP/1.0 (carpooling student project)';
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmPackageName = 'com.ecoride.ecoride';

  /// Restrict place search to this country (ISO 3166-1 alpha-2) or null for worldwide.
  static const String? geocodingCountry = 'pk';

  /// Default map centre (Lahore) used before any location is known.
  static const double defaultLat = 31.5204;
  static const double defaultLng = 74.3587;
}
