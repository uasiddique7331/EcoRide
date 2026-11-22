import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/place_point.dart';
import '../../providers/providers.dart';
import '../config/app_config.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import 'common.dart';

/// Full-screen map to choose a location by searching, using GPS, or moving
/// the map under a centre pin (FR-29, FR-31 .. FR-34). Pops a [PlacePoint].
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, required this.title, this.initial});

  final String title;
  final PlacePoint? initial;

  static Future<PlacePoint?> open(BuildContext context, {required String title, PlacePoint? initial}) =>
      Navigator.of(context).push<PlacePoint>(
        MaterialPageRoute(builder: (_) => LocationPickerScreen(title: title, initial: initial)),
      );

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  late LatLng _center;
  String? _selectedName;
  List<PlacePoint> _results = const [];
  bool _searching = false;
  bool _confirming = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initial?.latLng ?? const LatLng(AppConfig.defaultLat, AppConfig.defaultLng);
    _selectedName = widget.initial?.name;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _searching = true);
      try {
        final res = await ref.read(geocodingServiceProvider).search(q);
        if (mounted) setState(() => _results = res);
      } catch (e) {
        if (mounted) showSnack(context, friendlyError(e), error: true);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _pick(PlacePoint p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _selectedName = p.name;
      _center = p.latLng;
      _searchCtrl.text = p.name;
    });
    _map.move(p.latLng, 16);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final res = await ref.read(locationServiceProvider).currentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (res.isOk) {
      _selectedName = null; // resolve a fresh name on confirm
      _center = res.point!;
      _map.move(res.point!, 16);
    } else {
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(
        content: Text(res.message),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 6),
        action: res.failure == LocationFailure.permissionDeniedForever
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => ref.read(locationServiceProvider).openAppSettings())
            : null,
      ));
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    final name = _selectedName ?? await ref.read(geocodingServiceProvider).reverse(_center);
    if (!mounted) return;
    Navigator.of(context).pop(PlacePoint(lat: _center.latitude, lng: _center.longitude, name: name));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: widget.initial == null ? 12 : 16,
            onPositionChanged: (camera, hasGesture) {
              _center = camera.center;
              if (hasGesture && _selectedName != null) setState(() => _selectedName = null);
            },
          ),
          children: [
            TileLayer(urlTemplate: AppConfig.osmTileUrl, userAgentPackageName: AppConfig.osmPackageName),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        ),
        // Centre pin
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on, size: 48, color: AppColors.danger),
            ),
          ),
        ),
        // Search
        Positioned(
          left: 12,
          right: 12,
          top: 8,
          child: Column(children: [
            Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(14),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search a place, area or address',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : (_searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                    _searchCtrl.clear();
                                    _results = const [];
                                  }))),
                ),
              ),
            ),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(color: t.colorScheme.surface, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)]),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(_results[i].name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _pick(_results[i]),
                  ),
                ),
              ),
          ]),
        ),
        // My location
        Positioned(
          right: 14,
          bottom: 120,
          child: FloatingActionButton.small(
            heroTag: 'loc_${widget.title}',
            onPressed: _locating ? null : _useMyLocation,
            child: _locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
        ),
        // Confirm
        Positioned(
          left: 14,
          right: 14,
          bottom: 20,
          child: SafeArea(
            child: PrimaryButton(
              label: 'Confirm this location',
              icon: Icons.check_rounded,
              loading: _confirming,
              onPressed: _confirm,
            ),
          ),
        ),
      ]),
    );
  }
}
