import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pure geometry helpers (no platform dependencies, fully unit-testable).
class GeoUtils {
  GeoUtils._();

  static const _earthRadiusKm = 6371.0088;

  static double _rad(double deg) => deg * math.pi / 180.0;

  /// Great-circle distance in kilometres.
  static double haversineKm(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusKm * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Total length of a polyline in km.
  static double pathLengthKm(List<LatLng> pts) {
    var sum = 0.0;
    for (var i = 1; i < pts.length; i++) {
      sum += haversineKm(pts[i - 1], pts[i]);
    }
    return sum;
  }

  /// Index of the polyline vertex nearest to [p], or -1 for an empty path.
  static int nearestIndex(List<LatLng> path, LatLng p) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < path.length; i++) {
      final d = haversineKm(path[i], p);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// Reduces [pts] to at most [maxPoints] evenly spaced vertices, always
  /// keeping the first and last point.
  static List<LatLng> downsample(List<LatLng> pts, {int maxPoints = 120}) {
    if (pts.length <= maxPoints || maxPoints < 2) return List<LatLng>.of(pts);
    final out = <LatLng>[];
    final step = (pts.length - 1) / (maxPoints - 1);
    for (var i = 0; i < maxPoints; i++) {
      out.add(pts[(i * step).round().clamp(0, pts.length - 1)]);
    }
    return out;
  }

  /// Linearly interpolates [count]+1 points between [a] and [b].
  static List<LatLng> interpolate(LatLng a, LatLng b, {int count = 60}) => [
        for (var i = 0; i <= count; i++)
          LatLng(a.latitude + (b.latitude - a.latitude) * i / count,
              a.longitude + (b.longitude - a.longitude) * i / count),
      ];
}
