import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/booking_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/fare_card.dart';
import '../../core/widgets/route_map.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../providers/providers.dart';

/// UC-14: inspect a trip and its bookings; cancel it if necessary.
class AdminTripDetailScreen extends ConsumerStatefulWidget {
  const AdminTripDetailScreen({super.key, required this.tripId});
  final String tripId;
  @override
  ConsumerState<AdminTripDetailScreen> createState() => _State();
}

class _State extends ConsumerState<AdminTripDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripProvider(widget.tripId));
    final admin = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trip (admin)')),
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
        data: (t) {
          if (t == null || admin == null) return const EmptyState(icon: Icons.search_off, title: 'Trip not found');
          final bookings = ref.watch(tripBookingsProvider((tripId: t.id, driverId: t.driverId)));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            RouteMap(route: t.route, origin: t.origin.latLng, destination: t.destination.latLng),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Trip',
              trailing: tripStatusChip(t.status),
              child: Column(children: [
                InfoRow(icon: Icons.person_outline, label: 'Driver', value: t.driverName),
                InfoRow(icon: Icons.trip_origin, label: 'From', value: t.origin.name),
                InfoRow(icon: Icons.location_on_outlined, label: 'To', value: t.destination.name),
                InfoRow(icon: Icons.event_outlined, label: 'Departure', value: Fmt.dateTime(t.departureTime)),
                InfoRow(icon: Icons.event_seat_outlined, label: 'Seats', value: '${t.availableSeats} free of ${t.totalSeats}'),
                InfoRow(icon: Icons.directions_car_outlined, label: 'Vehicle', value: t.vehicle.summary),
              ]),
            ),
            FareCard(trip: t),
            Text('Bookings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            bookings.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ErrorState(error: e),
              data: (list) => list.isEmpty ? const Text('No bookings.', style: TextStyle(color: AppColors.muted)) : Column(children: [for (final b in list) BookingCard(booking: b, showPassenger: true)]),
            ),
            if (t.status == TripStatus.scheduled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                onPressed: _busy
                    ? null
                    : () async {
                        final reason = await promptText(context, title: 'Cancel trip as administrator', hint: 'Reason', confirmLabel: 'Cancel trip');
                        if (reason == null || !mounted) return;
                        setState(() => _busy = true);
                        await runAction(context, () => ref.read(adminRepositoryProvider).cancelTrip(trip: t, admin: admin, reason: reason), success: 'Trip cancelled.');
                        if (mounted) setState(() => _busy = false);
                      },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel trip'),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
