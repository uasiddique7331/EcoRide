import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/booking_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_chips.dart';
import '../../core/widgets/trip_card.dart';
import '../../models/app_user.dart';
import '../../models/document_record.dart';
import '../../models/enums.dart';
import '../../models/vehicle.dart';
import '../../providers/providers.dart';
import '../profile/profile_view.dart';

/// Administrator shell (FR-84, FR-85).
class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(adminTabProvider);
    return Scaffold(
      body: IndexedStack(index: index, children: const [_Dashboard(), _Documents(), _Users(), _Records(), ProfileView()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(adminTabProvider.notifier).set,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check_rounded), label: 'Documents'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.storage_outlined), selectedIcon: Icon(Icons.storage_rounded), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final logs = ref.watch(adminLogsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin overview'), actions: [IconButton(onPressed: () => ref.invalidate(adminStatsProvider), icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        stats.when(
          loading: () => const Padding(padding: EdgeInsets.all(32), child: LoadingView()),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(adminStatsProvider)),
          data: (s) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _Tile('Drivers', s.drivers, Icons.directions_car_outlined, AppColors.primary),
              _Tile('Passengers', s.passengers, Icons.person_outline, AppColors.info),
              _Tile('Docs to review', s.pendingDocuments, Icons.pending_actions_outlined, AppColors.warning),
              _Tile('Trips', s.trips, Icons.route_outlined, AppColors.primary),
              _Tile('Scheduled', s.scheduledTrips, Icons.event_available_outlined, AppColors.info),
              _Tile('Pending bookings', s.pendingBookings, Icons.inbox_outlined, AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Recent admin activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        logs.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) => list.isEmpty
              ? const Text('No actions recorded yet.', style: TextStyle(color: AppColors.muted))
              : Column(children: [
                  for (final l in list)
                    SectionCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.details, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('${l.adminName} • ${l.action.replaceAll('_', ' ')} • ${Fmt.dateTime(l.createdAt)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color),
          const Spacer(),
          Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ]),
      );
}

class _Documents extends ConsumerStatefulWidget {
  const _Documents();
  @override
  ConsumerState<_Documents> createState() => _DocumentsState();
}

class _DocumentsState extends ConsumerState<_Documents> {
  DocStatus _filter = DocStatus.pending;

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(allDocumentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Document review')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<DocStatus>(
              showSelectedIcon: false,
              segments: [for (final s in DocStatus.values) ButtonSegment(value: s, label: Text(s.name[0].toUpperCase() + s.name.substring(1)))],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
        Expanded(
          child: AsyncView<List<DocumentRecord>>(
            value: docs,
            onRetry: () => ref.invalidate(allDocumentsProvider),
            data: (all) {
              final list = all.where((d) => d.status == _filter).toList();
              if (list.isEmpty) return EmptyState(icon: Icons.fact_check_outlined, title: 'No ${_filter.name} documents'); // UC-12 A1
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final d = list[i];
                  return SectionCard(
                    onTap: () => context.push('/admin/document/${d.id}'),
                    child: Row(children: [
                      Icon(d.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: AppColors.primary, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d.ownerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${d.type.label} • ${d.ownerRole.label}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          Text(Fmt.dateTime(d.uploadedAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ]),
                      ),
                      docStatusChip(d.status),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Users extends ConsumerStatefulWidget {
  const _Users();
  @override
  ConsumerState<_Users> createState() => _UsersState();
}

class _UsersState extends ConsumerState<_Users> {
  String _q = '';
  UserRole? _role;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(onChanged: (v) => setState(() => _q = v.toLowerCase()), decoration: const InputDecoration(hintText: 'Search name, email or phone', prefixIcon: Icon(Icons.search))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('All'), selected: _role == null, onSelected: (_) => setState(() => _role = null)),
            ChoiceChip(label: const Text('Drivers'), selected: _role == UserRole.driver, onSelected: (_) => setState(() => _role = UserRole.driver)),
            ChoiceChip(label: const Text('Passengers'), selected: _role == UserRole.passenger, onSelected: (_) => setState(() => _role = UserRole.passenger)),
          ]),
        ),
        Expanded(
          child: AsyncView<List<AppUser>>(
            value: users,
            onRetry: () => ref.invalidate(allUsersProvider),
            data: (all) {
              final list = all.where((u) => !u.isAdmin && (_role == null || u.role == _role) && (_q.isEmpty || '${u.fullName} ${u.email} ${u.phone}'.toLowerCase().contains(_q))).toList();
              if (list.isEmpty) return const EmptyState(icon: Icons.people_outline, title: 'No users found'); // UC-13 A1
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final u = list[i];
                  return SectionCard(
                    onTap: () => context.push('/admin/user/${u.uid}'),
                    child: Row(children: [
                      Avatar(initials: Fmt.initials(u.fullName)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${u.role.label} • ${u.email}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ]),
                      ),
                      accountStatusChip(u.status),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Records extends ConsumerWidget {
  const _Records();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Records'), bottom: const TabBar(tabs: [Tab(text: 'Trips'), Tab(text: 'Bookings'), Tab(text: 'Vehicles')])),
        body: TabBarView(children: [
          AsyncView(
            value: ref.watch(allTripsProvider),
            onRetry: () => ref.invalidate(allTripsProvider),
            data: (list) => list.isEmpty
                ? const EmptyState(icon: Icons.route_outlined, title: 'No trips yet')
                : ListView(padding: const EdgeInsets.all(16), children: [for (final t in list) TripCard(trip: t, showDriver: true, onTap: () => context.push('/admin/trip/${t.id}'))]),
          ),
          AsyncView(
            value: ref.watch(allBookingsProvider),
            onRetry: () => ref.invalidate(allBookingsProvider),
            data: (list) => list.isEmpty
                ? const EmptyState(icon: Icons.inbox_outlined, title: 'No bookings yet')
                : ListView(padding: const EdgeInsets.all(16), children: [for (final b in list) BookingCard(booking: b, showPassenger: true, onTap: () => context.push('/admin/trip/${b.tripId}'))]),
          ),
          AsyncView<List<Vehicle>>(
            value: ref.watch(allVehiclesProvider),
            onRetry: () => ref.invalidate(allVehiclesProvider),
            data: (list) => list.isEmpty
                ? const EmptyState(icon: Icons.directions_car_outlined, title: 'No vehicles yet')
                : ListView(padding: const EdgeInsets.all(16), children: [
                    for (final v in list)
                      SectionCard(
                        onTap: () => context.push('/admin/user/${v.ownerId}'),
                        child: Row(children: [
                          const Icon(Icons.directions_car_filled_outlined, color: AppColors.primary, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${v.title} • ${v.registrationNumber}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${v.color} • ${v.type} • ${v.capacity} seats', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              Text('Owner: ${v.ownerName}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
