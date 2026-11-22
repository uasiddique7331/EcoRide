import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/place_point.dart';
import '../../providers/providers.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'location_picker_screen.dart';

/// Tappable field that opens [LocationPickerScreen]. When [allowGps] is true a
/// quick "use my location" button is shown (passenger pickup, FR-29).
class LocationField extends ConsumerStatefulWidget {
  const LocationField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.place_outlined,
    this.allowGps = false,
    this.errorText,
  });

  final String label;
  final PlacePoint? value;
  final ValueChanged<PlacePoint> onChanged;
  final IconData icon;
  final bool allowGps;
  final String? errorText;

  @override
  ConsumerState<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends ConsumerState<LocationField> {
  bool _locating = false;

  Future<void> _open() async {
    final p = await LocationPickerScreen.open(context, title: widget.label, initial: widget.value);
    if (p != null) widget.onChanged(p);
  }

  Future<void> _gps() async {
    setState(() => _locating = true);
    final res = await ref.read(locationServiceProvider).currentLocation();
    if (!mounted) return;
    if (!res.isOk) {
      setState(() => _locating = false);
      showSnack(context, res.message, error: true); // FR-36: message + manual fallback
      return;
    }
    final name = await ref.read(geocodingServiceProvider).reverse(res.point!);
    if (!mounted) return;
    setState(() => _locating = false);
    widget.onChanged(PlacePoint(lat: res.point!.latitude, lng: res.point!.longitude, name: name));
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _open,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon, color: hasValue ? AppColors.primary : null),
          errorText: widget.errorText,
          suffixIcon: widget.allowGps
              ? (_locating
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(tooltip: 'Use my current location', icon: const Icon(Icons.my_location), onPressed: _gps))
              : const Icon(Icons.map_outlined),
        ),
        child: Text(
          widget.value?.name ?? 'Tap to choose on map',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: hasValue ? null : AppColors.muted),
        ),
      ),
    );
  }
}
