import 'package:latlong2/latlong.dart';

import 'model_utils.dart';

/// A named geographic point (pickup, drop-off, trip origin/destination).
class PlacePoint {
  const PlacePoint({required this.lat, required this.lng, required this.name});

  final double lat;
  final double lng;
  final String name;

  LatLng get latLng => LatLng(lat, lng);

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'name': name};

  factory PlacePoint.fromMap(Map<String, dynamic>? m) {
    final map = m ?? const <String, dynamic>{};
    return PlacePoint(
      lat: asDouble(map['lat']),
      lng: asDouble(map['lng']),
      name: asString(map['name'], 'Unknown place'),
    );
  }

  PlacePoint copyWith({String? name}) => PlacePoint(lat: lat, lng: lng, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      other is PlacePoint && other.lat == lat && other.lng == lng && other.name == name;

  @override
  int get hashCode => Object.hash(lat, lng, name);
}
