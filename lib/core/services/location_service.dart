import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationFailure { serviceDisabled, permissionDenied, permissionDeniedForever, unavailable }

class LocationResult {
  const LocationResult.ok(this.point) : failure = null;
  const LocationResult.fail(this.failure) : point = null;

  final LatLng? point;
  final LocationFailure? failure;
  bool get isOk => point != null;

  String get message => switch (failure) {
        LocationFailure.serviceDisabled =>
          'Location services are turned off. Enable GPS or choose a location on the map.',
        LocationFailure.permissionDenied =>
          'Location permission was denied. Allow it, or choose your location on the map.',
        LocationFailure.permissionDeniedForever =>
          'Location permission is permanently denied. Enable it in app settings, or choose a location on the map.',
        LocationFailure.unavailable =>
          'Could not determine your location. Try again or choose a location on the map.',
        null => '',
      };
}

/// GPS access with explicit permission handling (FR-29, FR-30, FR-36).
class LocationService {
  Future<LocationResult> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.fail(LocationFailure.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.fail(LocationFailure.permissionDenied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.fail(LocationFailure.permissionDeniedForever);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult.ok(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      return const LocationResult.fail(LocationFailure.unavailable);
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
