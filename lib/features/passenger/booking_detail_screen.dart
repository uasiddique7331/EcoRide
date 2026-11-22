import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launcher.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/fare_card.dart';
import '../../core/widgets/route_map.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../models/trip.dart';
import '../../providers/providers.dart';

/// Booking status, live fare share, driver contact and cancellation
/// (UC-11 steps 5-8, FR-67, FR-69, FR-79, FR-82).
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _busy = false;

  Future<void> _cancel(Booking b) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this booking?',
      message: b.status == BookingStatus.accepted
          ? 'Your seat(s) will be released and the fare shares of the other passengers will be recalculated.'
          : 'Your pending request will be withdrawn.',
      confirmLabel: 'Cancel booking',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final user = ref.read(currentUserProvider);
    await runAction(
      context,
      () => ref.read(bookingRepositoryProvider).cancelByPassenger(bookingId: b.id, passengerId: user!.uid),
      success: 'Booking cancelled.',
    );
    if (mounted) setState(() => _busy = false);
  }

  String _statusMessage(Booking b) => switch (b.status) {
        BookingStatus.pending => 'Waiting for the driver to accept your request.',
        BookingStatus.accepted => 'Your seat is confirmed. Pay your share directly to the driver.',
        BookingStatus.rejected => 'The driver could not accept this request. You can search for another ride.',
        BookingStatus.cancelled => b.statusNote ?? 'This booking was cancelled.',
      };

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: bookingAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(bookingProvider(widget.bookingId))),
        data: (b) {
          if (b == null) return const EmptyState(icon: Icons.search_off, title: 'Booking not found');
          final trip = ref.watch(tripProvider(b.tripId)).value;
          final color = AppColors.forBooking(b.status);
          final canCancel = b.isActive && trip != null && trip.status == TripStatus.scheduled;
          final cutoffPassed = trip != null && !trip.isBeforeCutoff;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.4))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  bookingStatusChip(b.status),
                  const SizedBox(height: 8),
                  Text(_statusMessage(b), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
                ]),
              ),
              const SizedBox(height: 14),
              if (trip != null)
                RouteMap(
                  route: trip.route,
                  origin: trip.origin.latLng,
                  destination: trip.destination.latLng,
                  height: 190,
                  extraMarkers: [
                    RouteMap.pin(b.pickup.latLng, AppColors.info, icon: Icons.person_pin_circle),
                    RouteMap.pin(b.dropoff.latLng, AppColors.accent, icon: Icons.flag_circle),
                  ],
                ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Your booking',
                child: Column(children: [
                  InfoRow(icon: Icons.my_location, label: 'Pickup', value: b.pickup.name),
                  InfoRow(icon: Icons.flag_outlined, label: 'Drop-off', value: b.dropoff.name),
                  InfoRow(icon: Icons.event_seat_outlined, label: 'Seats', value: '${b.seats}'),
                  if (trip != null) InfoRow(icon: Icons.event_outlined, label: 'Departure', value: Fmt.dateTime(trip.departureTime), bold: true),
                  InfoRow(icon: Icons.history_toggle_off, label: 'Requested', value: Fmt.dateTime(b.createdAt)),
                  if (trip != null) InfoRow(icon: Icons.directions_car_outlined, label: 'Vehicle', value: trip.vehicle.summary),
                  if (trip != null) InfoRow(icon: Icons.info_outline, label: 'Trip status', value: trip.status.label),
                ]),
              ),
              if (trip != null) ...[
                FareCard(trip: trip),
                if (b.status == BookingStatus.accepted && trip.sharePerPassenger != null) _YouPay(trip: trip, booking: b),
                if (b.status == BookingStatus.accepted) _DriverContact(booking: b, trip: trip),
              ],
              if (canCancel) ...[
                const SizedBox(height: 4),
                if (cutoffPassed)
                  const NoticeBanner(message: 'Cancellation closes ${AppConfig.cancelCutoffMinutes} minutes before departure.')
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                    onPressed: _busy ? null : () => _cancel(b),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel booking'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _YouPay extends StatelessWidget {
  const _YouPay({required this.trip, required this.booking});
  final Trip trip;
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final each = trip.sharePerPassenger!;
    return SectionCard(
      child: Row(children: [
        const Icon(Icons.payments_rounded, color: AppColors.primary, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('You pay the driver', style: TextStyle(color: AppColors.muted)),
            Text(Fmt.pkr(each * booking.seats), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            if (booking.seats > 1) Text('${Fmt.pkr(each)} × ${booking.seats} seats', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

class _DriverContact extends StatelessWidget {
  const _DriverContact({required this.booking, required this.trip});
  final Booking booking;
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final phone = booking.driverPhone;
    return SectionCard(
      title: 'Driver contact',
      child: Column(children: [
        InfoRow(icon: Icons.person_outline, label: 'Driver', value: booking.driverName ?? trip.driverName),
        if (phone != null) InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: phone),
        if (phone != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => callNumber(context, phone),
              icon: const Icon(Icons.call_rounded),
              label: const Text('Call driver'),
            ),
          ),
      ]),
    );
  }
}
