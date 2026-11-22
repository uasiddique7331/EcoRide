import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import 'geo_utils.dart';

/// Result of a route-distance calculation (FR-74).
class RouteInfo {
  const RouteInfo({required this.distanceKm, required this.points, required this.isEstimate});

  final double distanceKm;
  final List<LatLng> points;

  /// True when the road route was unavailable and distance was estimated
  /// from the straight line (UC-04 A5).
  final bool isEstimate;
}

/// Road distance + geometry using the public OSRM demo server (no API key).
/// For production traffic, self-host OSRM or swap in another provider here.
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<RouteInfo> route(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&alternatives=false&steps=false',
      );
      final res = await _client
          .get(uri, headers: {'User-Agent': AppConfig.httpUserAgent}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = json['routes'];
        if (json['code'] == 'Ok' && routes is List && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final meters = (r['distance'] as num).toDouble();
          final coords = (r['geometry']['coordinates'] as List)
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          if (coords.length >= 2) {
            return RouteInfo(
              distanceKm: double.parse((meters / 1000).toStringAsFixed(1)),
              points: GeoUtils.downsample(coords, maxPoints: 120),
              isEstimate: false,
            );
          }
        }
      }
    } catch (_) {
      // fall through to the estimate below
    }
    return estimate(from, to);
  }

  /// Straight-line estimate with a road factor, used as a fallback.
  RouteInfo estimate(LatLng from, LatLng to) {
    final straight = GeoUtils.haversineKm(from, to);
    return RouteInfo(
      distanceKm: double.parse((straight * AppConfig.roadFactorForEstimate).toStringAsFixed(1)),
      points: GeoUtils.interpolate(from, to, count: 60),
      isEstimate: true,
    );
  }
}
