import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';
import 'status_chips.dart';

/// Compact summary of a trip for lists.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap, this.footer, this.showDriver = false});

  final Trip trip;
  final VoidCallback? onTap;
  final Widget? footer;
  final bool showDriver;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SectionCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(Fmt.dateTime(trip.departureTime), style: t.textTheme.labelLarge?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700))),
          tripStatusChip(trip.status),
        ]),
        const SizedBox(height: 10),
        _routeLine(context, Icons.trip_origin, AppColors.success, trip.origin.name),
        Padding(
          padding: const EdgeInsets.only(left: 9),
          child: Container(width: 2, height: 14, color: t.colorScheme.outlineVariant),
        ),
        _routeLine(context, Icons.location_on, AppColors.danger, trip.destination.name),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 6, children: [
          _meta(Icons.event_seat_outlined, '${trip.availableSeats}/${trip.totalSeats} seats'),
          _meta(Icons.route_outlined, Fmt.km(trip.distanceKm)),
          _meta(Icons.payments_outlined, Fmt.pkr(trip.totalFare)),
          if (showDriver) _meta(Icons.person_outline, trip.driverName),
        ]),
        if (footer != null) ...[const SizedBox(height: 10), footer!],
      ]),
    );
  }

  Widget _routeLine(BuildContext c, IconData icon, Color color, String text) => Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]);

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
      ]);
}
