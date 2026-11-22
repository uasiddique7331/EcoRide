import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Read-only map showing a trip route with start/end markers and optional
/// extra markers (e.g. the passenger's pickup and drop-off).
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.route,
    required this.origin,
    required this.destination,
    this.extraMarkers = const [],
    this.height = 220,
  });

  final List<LatLng> route;
  final LatLng origin;
  final LatLng destination;
  final List<Marker> extraMarkers;
  final double height;

  static Marker pin(LatLng p, Color color, {IconData icon = Icons.location_on}) => Marker(
        point: p,
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: Icon(icon, color: color, size: 38),
      );

  @override
  Widget build(BuildContext context) {
    final pts = route.length >= 2 ? route : [origin, destination];
    final all = [...pts, ...extraMarkers.map((m) => m.point)];
    final degenerate = all.every((p) => p.latitude == all.first.latitude && p.longitude == all.first.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: origin,
            initialZoom: 13,
            initialCameraFit: degenerate
                ? null
                : CameraFit.bounds(bounds: LatLngBounds.fromPoints(all), padding: const EdgeInsets.all(40)),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
          ),
          children: [
            TileLayer(urlTemplate: AppConfig.osmTileUrl, userAgentPackageName: AppConfig.osmPackageName),
            PolylineLayer(polylines: [Polyline(points: pts, strokeWidth: 5, color: AppColors.primary)]),
            MarkerLayer(markers: [
              pin(origin, AppColors.success),
              pin(destination, AppColors.danger),
              ...extraMarkers,
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        ),
      ),
    );
  }
}
