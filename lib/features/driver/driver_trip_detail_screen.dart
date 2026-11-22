import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/booking_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/fare_card.dart';
import '../../core/widgets/route_map.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../models/trip.dart';
import '../../providers/providers.dart';
import 'driver_home.dart' show BookingActions;

/// UC-10: manage one trip (edit, start, complete, cancel) with its bookings and fare.
class DriverTripDetailScreen extends ConsumerStatefulWidget {
  const DriverTripDetailScreen({super.key, required this.tripId});
  final String tripId;
  @override
  ConsumerState<DriverTripDetailScreen> createState() => _State();
}

class _State extends ConsumerState<DriverTripDetailScreen> {
  bool _busy = false;

  Future<void> _do(Future<void> Function() fn, String ok) async {
    setState(() => _busy = true);
    await runAction(context, fn, success: ok);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel(Trip t) async {
    final reason = await promptText(context, title: 'Cancel this trip?', hint: 'Reason (shown to passengers)', confirmLabel: 'Cancel trip');
    if (reason == null || !mounted) return;
    await _do(() => ref.read(tripRepositoryProvider).cancelTrip(trip: t, reason: reason), 'Trip cancelled. Passengers have been notified.');
  }

  Future<void> _edit(Trip t) async {
    var when = t.departureTime;
    var seats = t.totalSeats;
    final maxSeats = ref.read(myVehicleProvider).value?.capacity ?? t.totalSeats;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit trip', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('To change the route, cancel this trip and publish a new one.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: when.isBefore(DateTime.now()) ? DateTime.now() : when, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) setS(() => when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(Fmt.date(when)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final x = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                    if (x != null) setS(() => when = DateTime(when.year, when.month, when.day, x.hour, x.minute));
                  },
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(Fmt.time(when)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Text('Total seats', style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton.filledTonal(onPressed: seats > 1 ? () => setS(() => seats--) : null, icon: const Icon(Icons.remove)),
              SizedBox(width: 34, child: Center(child: Text('$seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
              IconButton.filledTonal(onPressed: seats < maxSeats ? () => setS(() => seats++) : null, icon: const Icon(Icons.add)),
            ]),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Save changes', onPressed: () => Navigator.pop(ctx, true)),
          ]),
        ),
      ),
    );
    if (saved == true && mounted) {
      await _do(() => ref.read(tripRepositoryProvider).updateTrip(tripId: t.id, departure: when, seats: seats), 'Trip updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip details')),
      body: tripAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(tripProvider(widget.tripId))),
        data: (t) {
          if (t == null || me == null) return const EmptyState(icon: Icons.search_off, title: 'Trip not found');
          final bookings = ref.watch(tripBookingsProvider((tripId: t.id, driverId: t.driverId)));
          final scheduled = t.status == TripStatus.scheduled;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            RouteMap(route: t.route, origin: t.origin.latLng, destination: t.destination.latLng),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Trip',
              trailing: tripStatusChip(t.status),
              child: Column(children: [
                InfoRow(icon: Icons.trip_origin, label: 'From', value: t.origin.name),
                InfoRow(icon: Icons.location_on_outlined, label: 'To', value: t.destination.name),
                InfoRow(icon: Icons.event_outlined, label: 'Departure', value: Fmt.dateTime(t.departureTime), bold: true),
                InfoRow(icon: Icons.event_seat_outlined, label: 'Seats', value: '${t.availableSeats} free of ${t.totalSeats}'),
                InfoRow(icon: Icons.directions_car_outlined, label: 'Vehicle', value: t.vehicle.summary),
                if (t.cancelReason != null) InfoRow(icon: Icons.info_outline, label: 'Cancelled', value: t.cancelReason!),
              ]),
            ),
            FareCard(trip: t, viewerIsOwner: true),
            Text('Passenger requests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            bookings.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(tripBookingsProvider((tripId: t.id, driverId: t.driverId)))),
              data: (List<Booking> list) => list.isEmpty
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No requests yet.', style: TextStyle(color: AppColors.muted)))
                  : Column(children: [
                      for (final b in list)
                        BookingCard(booking: b, showPassenger: true, actions: b.status == BookingStatus.pending && scheduled ? BookingActions(booking: b) : null),
                    ]),
            ),
            const SizedBox(height: 8),
            if (scheduled) ...[
              PrimaryButton(label: 'Start trip', icon: Icons.play_arrow_rounded, loading: _busy, onPressed: () => _do(() => ref.read(tripRepositoryProvider).startTrip(t.id), 'Trip started.')),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _busy || !t.isBeforeCutoff ? null : () => _edit(t), icon: const Icon(Icons.edit_outlined), label: const Text('Edit time / seats')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                onPressed: _busy || !t.isBeforeCutoff ? null : () => _cancel(t),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel trip'),
              ),
              if (!t.isBeforeCutoff) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Editing and cancelling close ${AppConfig.cancelCutoffMinutes} minutes before departure.', style: TextStyle(color: AppColors.muted, fontSize: 12.5))),
            ],
            if (t.status == TripStatus.active)
              PrimaryButton(label: 'Complete trip', icon: Icons.flag_rounded, loading: _busy, onPressed: () => _do(() => ref.read(tripRepositoryProvider).completeTrip(t.id), 'Trip completed.')),
            if (t.status == TripStatus.completed || t.status == TripStatus.cancelled)
              OutlinedButton(onPressed: () => context.pop(), child: const Text('Back')),
          ]);
        },
      ),
    );
  }
}
