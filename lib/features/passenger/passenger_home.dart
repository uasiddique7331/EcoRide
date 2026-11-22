import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../providers/providers.dart';
import '../profile/profile_view.dart';
import 'my_bookings_tab.dart';
import 'search_tab.dart';

/// Passenger dashboard shell (FR-07).
class PassengerHome extends ConsumerWidget {
  const PassengerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(passengerTabProvider);
    final activeCount = ref
            .watch(passengerBookingsProvider)
            .value
            ?.where((b) => b.status == BookingStatus.pending || b.status == BookingStatus.accepted)
            .length ??
        0;

    return Scaffold(
      body: IndexedStack(index: index, children: const [PassengerSearchTab(), MyBookingsTab(), ProfileView()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(passengerTabProvider.notifier).set,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.search_rounded), label: 'Find ride'),
          NavigationDestination(
            icon: Badge(isLabelVisible: activeCount > 0, label: Text('$activeCount'), child: const Icon(Icons.confirmation_number_outlined)),
            selectedIcon: const Icon(Icons.confirmation_number_rounded),
            label: 'My bookings',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
