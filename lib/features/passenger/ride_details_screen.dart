import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/fare_card.dart';
import '../../core/widgets/route_map.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/place_point.dart';
import '../../models/trip.dart';
import '../../providers/providers.dart';
import '../../services/fare_calculator.dart';
import '../../services/ride_matcher.dart';

/// UC-06 (view ride details) and UC-07 (submit a booking request).
class RideDetailsScreen extends ConsumerStatefulWidget {
  const RideDetailsScreen({super.key, required this.tripId, this.query});

  final String tripId;
  final RideQuery? query;

  @override
  ConsumerState<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends ConsumerState<RideDetailsScreen> {
  late int _seats = widget.query?.seats ?? 1;
  bool _loading = false;

  Future<void> _book(Trip trip, PlacePoint pickup, PlacePoint dropoff) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final share = FareCalculator.estimatedShare(trip.totalFare, trip.acceptedPassengers, _seats);
    final ok = await confirmDialog(
      context,
      title: 'Request booking?',
      message: '$_seats seat(s) on ${trip.origin.name} → ${trip.destination.name}\n'
          '${Fmt.dateTime(trip.departureTime)}\n\n'
          'Estimated share: ${Fmt.pkr(share)} per passenger. The driver must accept your request first; '
          'you pay the driver directly.',
      confirmLabel: 'Send request',
    );
    if (!ok || !mounted) return;

    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final success = await runAction(
      context,
      () => ref.read(bookingRepositoryProvider).requestBooking(
            tripId: trip.id,
            passenger: user,
            seats: _seats,
            pickup: pickup,
            dropoff: dropoff,
          ),
    );
    if (mounted) setState(() => _loading = false);
    if (success) {
      ref.read(passengerTabProvider.notifier).set(1);
      router.go('/passenger');
      messenger.showSnackBar(const SnackBar(
        content: Text('Booking request sent. You will see the driver\'s decision in My bookings.'),
        backgroundColor: AppColors.primaryDark,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ride details')),
      body: tripAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(tripProvider(widget.tripId))), // A3
        data: (trip) {
          if (trip == null) {
            return const EmptyState(icon: Icons.event_busy_outlined, title: 'Ride no longer available', message: 'This trip has been removed.'); // A1
          }
          final q = widget.query;
          final pickup = q?.pickup;
          final dropoff = q?.dropoff;
          final existing = ref.watch(passengerBookingsProvider).value?.where(
                (b) => b.id == FsPaths.bookingId(trip.id, user?.uid ?? '') && b.isActive,
              );
          final hasActive = existing != null && existing.isNotEmpty;
          final maxSeats = math.max(1, math.min(trip.availableSeats, AppConfig.maxSeatsPerBooking));
          if (_seats > maxSeats) _seats = maxSeats;

          String? blockReason;
          if (trip.status == TripStatus.cancelled) {
            blockReason = 'This trip has been cancelled.'; // A2
          } else if (!trip.canAcceptBookings) {
            blockReason = trip.availableSeats <= 0 ? 'This ride is fully booked.' : 'This ride is no longer open for booking.';
          } else if (user != null && !user.isVerified) {
            blockReason = 'Your identity document must be approved by an administrator before you can book.';
          } else if (pickup == null || dropoff == null) {
            blockReason = 'Search for this ride again to choose your pickup and drop-off.';
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              RouteMap(
                route: trip.route,
                origin: trip.origin.latLng,
                destination: trip.destination.latLng,
                extraMarkers: [
                  if (pickup != null) RouteMap.pin(pickup.latLng, AppColors.info, icon: Icons.person_pin_circle),
                  if (dropoff != null) RouteMap.pin(dropoff.latLng, AppColors.accent, icon: Icons.flag_circle),
                ],
              ),
              const SizedBox(height: 6),
              const Wrap(spacing: 14, children: [
                _Legend(AppColors.success, 'Driver start'),
                _Legend(AppColors.danger, 'Driver destination'),
                _Legend(AppColors.info, 'Your pickup'),
                _Legend(AppColors.accent, 'Your drop-off'),
              ]),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Trip',
                trailing: tripStatusChip(trip.status),
                child: Column(children: [
                  InfoRow(icon: Icons.trip_origin, label: 'From', value: trip.origin.name),
                  InfoRow(icon: Icons.location_on_outlined, label: 'To', value: trip.destination.name),
                  InfoRow(icon: Icons.event_outlined, label: 'Departure', value: Fmt.dateTime(trip.departureTime), bold: true),
                  InfoRow(icon: Icons.event_seat_outlined, label: 'Seats left', value: '${trip.availableSeats} of ${trip.totalSeats}'),
                  InfoRow(icon: Icons.route_outlined, label: 'Distance', value: Fmt.km(trip.distanceKm)),
                ]),
              ),
              SectionCard(
                title: 'Driver & vehicle',
                child: Column(children: [
                  InfoRow(icon: Icons.person_outline, label: 'Driver', value: trip.driverName),
                  InfoRow(icon: Icons.directions_car_outlined, label: 'Vehicle', value: '${trip.vehicle.make} ${trip.vehicle.model} (${trip.vehicle.type})'),
                  InfoRow(icon: Icons.palette_outlined, label: 'Colour', value: trip.vehicle.color),
                  InfoRow(icon: Icons.pin_outlined, label: 'Plate', value: trip.vehicle.registrationNumber),
                ]),
              ),
              FareCard(trip: trip, estimatedShare: FareCalculator.estimatedShare(trip.totalFare, trip.acceptedPassengers, _seats)),
              const SizedBox(height: 4),
              if (hasActive)
                NoticeBanner(
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                  message: 'You already have a ${existing.first.status.label.toLowerCase()} request for this ride.',
                  action: TextButton(
                    onPressed: () => context.push('/passenger/booking/${existing.first.id}'),
                    child: const Text('View'),
                  ),
                )
              else ...[
                if (blockReason != null) NoticeBanner(message: blockReason, icon: Icons.info_outline),
                if (blockReason == null || blockReason.startsWith('Search for')) ...[
                  Row(children: [
                    const Icon(Icons.event_seat_outlined, color: AppColors.muted),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Seats to book', style: TextStyle(fontWeight: FontWeight.w700))),
                    IconButton.filledTonal(onPressed: _seats > 1 ? () => setState(() => _seats--) : null, icon: const Icon(Icons.remove)),
                    SizedBox(width: 36, child: Center(child: Text('$_seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
                    IconButton.filledTonal(onPressed: _seats < maxSeats ? () => setState(() => _seats++) : null, icon: const Icon(Icons.add)),
                  ]),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  label: 'Request booking',
                  icon: Icons.send_rounded,
                  loading: _loading,
                  onPressed: blockReason == null ? () => _book(trip, pickup!, dropoff!) : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);
}
