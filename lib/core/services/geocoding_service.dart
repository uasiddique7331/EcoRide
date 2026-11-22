import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/place_point.dart';
import '../config/app_config.dart';
import '../utils/app_exception.dart';

/// Place search & reverse geocoding via OpenStreetMap Nominatim.
/// Usage policy: max 1 request/second, identify the app via User-Agent.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _headers = {'User-Agent': AppConfig.httpUserAgent, 'Accept-Language': 'en'};

  Future<List<PlacePoint>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final params = {
      'q': q,
      'format': 'jsonv2',
      'limit': '6',
      if (AppConfig.geocodingCountry != null) 'countrycodes': AppConfig.geocodingCountry!,
    };
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    try {
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw const AppException('Place search is unavailable right now.');
      final list = jsonDecode(res.body) as List;
      return [
        for (final e in list)
          PlacePoint(
            lat: double.parse(e['lat'].toString()),
            lng: double.parse(e['lon'].toString()),
            name: _shorten(e['display_name'] as String),
          ),
      ];
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException.network;
    }
  }

  /// Returns a human-readable name for a coordinate; never throws.
  Future<String> reverse(LatLng p) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': p.latitude.toString(),
        'lon': p.longitude.toString(),
        'format': 'jsonv2',
        'zoom': '17',
      });
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final name = json['display_name'] as String?;
        if (name != null && name.isNotEmpty) return _shorten(name);
      }
    } catch (_) {}
    return '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
  }

  static String _shorten(String displayName) {
    final parts = displayName.split(',').map((s) => s.trim()).toList();
    return parts.length <= 3 ? displayName : parts.take(3).join(', ');
  }
}
