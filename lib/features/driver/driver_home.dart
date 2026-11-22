import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/booking_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/trip_card.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../models/trip.dart';
import '../../providers/providers.dart';
import '../profile/profile_view.dart';

/// Driver dashboard shell (FR-07).
class DriverHome extends ConsumerWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(driverTabProvider);
    final pending = ref.watch(driverBookingsProvider).value?.where((b) => b.status == BookingStatus.pending).length ?? 0;
    return Scaffold(
      body: IndexedStack(index: index, children: const [_DashboardTab(), _MyTripsTab(), _RequestsTab(), ProfileView()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(driverTabProvider.notifier).set,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: 'My trips'),
          NavigationDestination(
            icon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.inbox_outlined)),
            selectedIcon: const Icon(Icons.inbox_rounded),
            label: 'Requests',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final trips = ref.watch(driverTripsProvider).value ?? const <Trip>[];
    final bookings = ref.watch(driverBookingsProvider).value ?? const <Booking>[];
    final vehicle = ref.watch(myVehicleProvider).value;
    final docs = ref.watch(myDocumentsProvider).value ?? const [];
    final upcoming = trips.where((t) => t.isUpcoming).length;
    final pending = bookings.where((b) => b.status == BookingStatus.pending).length;
    final accepted = bookings.where((b) => b.status == BookingStatus.accepted).length;
    final rejectedDocs = docs.where((d) => d.status == DocStatus.rejected).length;
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Driver dashboard')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Text('Hi, ${(user?.fullName ?? '').split(' ').first} 👋', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        if (user != null && !user.isVerified)
          NoticeBanner(
            icon: rejectedDocs > 0 ? Icons.report_gmailerrorred_outlined : Icons.hourglass_top_rounded,
            color: rejectedDocs > 0 ? AppColors.danger : AppColors.warning,
            message: rejectedDocs > 0
                ? 'A document was rejected. Open Profile to see the reason and upload a new one.'
                : 'Your documents are awaiting administrator approval. You can publish trips once approved.',
          ),
        Row(children: [
          _Stat('Upcoming', '$upcoming', Icons.event_available_outlined),
          const SizedBox(width: 10),
          _Stat('Pending', '$pending', Icons.hourglass_empty_rounded),
          const SizedBox(width: 10),
          _Stat('Accepted', '$accepted', Icons.groups_outlined),
        ]),
        const SizedBox(height: 14),
        if (vehicle != null)
          SectionCard(
            onTap: () => context.push('/driver/vehicle'),
            child: Row(children: [
              const Icon(Icons.directions_car_filled_rounded, color: AppColors.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(vehicle.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${vehicle.color} • ${vehicle.registrationNumber} • ${vehicle.capacity} seats', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        PrimaryButton(
          label: 'Publish a trip',
          icon: Icons.add_road_rounded,
          onPressed: () => context.push('/driver/publish'),
        ),
        const SizedBox(height: 20),
        Text('Next trips', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),

        ...(() {
          final next = trips.where((x) => x.isUpcoming).toList();

          next.sort(
                (a, b) => a.departureTime.compareTo(b.departureTime),
          );

          if (next.isEmpty) {
            return <Widget>[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No upcoming trips. Publish one to get started.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ];
          }

          return next.take(3).map((x) => TripCard(
            trip: x,
            onTap: () => context.push('/driver/trip/${x.id}'),
          )).toList();
        })(),

      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: SectionCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        ),
      );
}

/// UC-10 / FR-45: trips list.
class _MyTripsTab extends ConsumerStatefulWidget {
  const _MyTripsTab();
  @override
  ConsumerState<_MyTripsTab> createState() => _MyTripsTabState();
}

class _MyTripsTabState extends ConsumerState<_MyTripsTab> {
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(driverTripsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My trips')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/driver/publish'),
        icon: const Icon(Icons.add),
        label: const Text('Publish'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: false, label: Text('Current')), ButtonSegment(value: true, label: Text('Past'))],
              selected: {_past},
              onSelectionChanged: (s) => setState(() => _past = s.first),
            ),
          ),
        ),
        Expanded(
          child: AsyncView<List<Trip>>(
            value: trips,
            onRetry: () => ref.invalidate(driverTripsProvider),
            data: (all) {
              final list = all.where((t) {
                final current = t.status == TripStatus.active || (t.status == TripStatus.scheduled);
                return _past ? !current : current;
              }).toList();
              if (list.isEmpty) {
                return EmptyState(icon: Icons.route_outlined, title: _past ? 'No past trips' : 'No current trips', message: _past ? 'Completed and cancelled trips appear here.' : 'Publish a trip so passengers can find you.'); // UC-10 A1
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                itemCount: list.length,
                itemBuilder: (_, i) => TripCard(trip: list[i], onTap: () => context.push('/driver/trip/${list[i].id}')),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// UC-08 / UC-11: booking requests across all of the driver's trips.
class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab();
  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(driverBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking requests')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: false, label: Text('Pending')), ButtonSegment(value: true, label: Text('History'))],
              selected: {_history},
              onSelectionChanged: (s) => setState(() => _history = s.first),
            ),
          ),
        ),
        Expanded(
          child: AsyncView<List<Booking>>(
            value: bookings,
            onRetry: () => ref.invalidate(driverBookingsProvider),
            data: (all) {
              final list = all.where((b) => _history ? b.status != BookingStatus.pending : b.status == BookingStatus.pending).toList();
              if (list.isEmpty) {
                return EmptyState(icon: Icons.inbox_outlined, title: _history ? 'No booking history' : 'No pending requests', message: 'Passenger requests for your trips will appear here.');
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => BookingCard(
                  booking: list[i],
                  showPassenger: true,
                  onTap: () => context.push('/driver/trip/${list[i].tripId}'),
                  actions: list[i].status == BookingStatus.pending ? BookingActions(booking: list[i]) : null,
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Accept / Reject buttons for a pending request (UC-08).
class BookingActions extends ConsumerStatefulWidget {
  const BookingActions({super.key, required this.booking});
  final Booking booking;

  @override
  ConsumerState<BookingActions> createState() => _BookingActionsState();
}

class _BookingActionsState extends ConsumerState<BookingActions> {
  bool _busy = false;

  Future<void> _run(bool accept) async {
    final driver = ref.read(currentUserProvider);
    if (driver == null) return;
    setState(() => _busy = true);
    final repo = ref.read(bookingRepositoryProvider);
    await runAction(
      context,
      () => accept
          ? repo.accept(bookingId: widget.booking.id, driver: driver)
          : repo.reject(bookingId: widget.booking.id, driver: driver),
      success: accept ? 'Booking accepted. Fare shares updated.' : 'Booking rejected.',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) return const Center(child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator()));
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: AppColors.danger),
          onPressed: () => _run(false),
          child: const Text('Reject'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)), onPressed: () => _run(true), child: const Text('Accept')),
      ),
    ]);
  }
}
