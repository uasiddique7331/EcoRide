import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';
import 'status_chips.dart';

/// Booking summary used by passengers (history), drivers (requests) and
/// admins. The departure time is read live from the trip so edits show up.
class BookingCard extends ConsumerWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.showPassenger = false,
    this.actions,
  });

  final Booking booking;
  final VoidCallback? onTap;

  /// Driver / admin views show who is travelling.
  final bool showPassenger;
  final Widget? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final trip = ref.watch(tripProvider(booking.tripId)).value;
    return SectionCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              trip == null ? '…' : Fmt.dateTime(trip.departureTime),
              style: t.textTheme.labelLarge?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700),
            ),
          ),
          bookingStatusChip(booking.status),
        ]),
        const SizedBox(height: 8),
        Text('${booking.originName}  →  ${booking.destinationName}',
            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        if (showPassenger) ...[
          Row(children: [
            Avatar(initials: Fmt.initials(booking.passengerName), size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(booking.passengerName, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(booking.passengerPhone, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          InfoRow(icon: Icons.my_location, label: 'Pickup', value: booking.pickup.name),
          InfoRow(icon: Icons.flag_outlined, label: 'Drop-off', value: booking.dropoff.name),
        ],
        Wrap(spacing: 16, runSpacing: 4, children: [
          _meta(Icons.event_seat_outlined, '${booking.seats} seat(s)'),
          _meta(Icons.payments_outlined,
              booking.status == BookingStatus.accepted && trip?.sharePerPassenger != null
                  ? 'Share ${Fmt.pkr(trip!.sharePerPassenger)}'
                  : 'Est. ${Fmt.pkr(booking.estimatedShare)}'),
        ]),
        if (actions != null) ...[const SizedBox(height: 12), actions!],
      ]),
    );
  }

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
      ]);
}
