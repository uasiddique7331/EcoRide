import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/booking_card.dart';
import '../../core/widgets/common.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../providers/providers.dart';

/// UC-11 for passengers: current and past booking requests (FR-67, FR-70).
class MyBookingsTab extends ConsumerStatefulWidget {
  const MyBookingsTab({super.key});

  @override
  ConsumerState<MyBookingsTab> createState() => _MyBookingsTabState();
}

class _MyBookingsTabState extends ConsumerState<MyBookingsTab> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(passengerBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Active')),
                ButtonSegment(value: true, label: Text('History')),
              ],
              selected: {_history},
              onSelectionChanged: (s) => setState(() => _history = s.first),
            ),
          ),
        ),
        Expanded(
          child: AsyncView<List<Booking>>(
            value: bookings,
            onRetry: () => ref.invalidate(passengerBookingsProvider),
            data: (all) {
              final list = all
                  .where((b) => _history
                      ? (b.status == BookingStatus.rejected || b.status == BookingStatus.cancelled)
                      : b.isActive)
                  .toList();
              if (list.isEmpty) {
                return EmptyState(
                  icon: _history ? Icons.history_rounded : Icons.confirmation_number_outlined,
                  title: _history ? 'No past bookings' : 'No active bookings',
                  message: _history
                      ? 'Rejected and cancelled requests will appear here.'
                      : 'Search for a ride and send a booking request to get started.',
                  action: _history
                      ? null
                      : FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(160, 46)),
                          onPressed: () => ref.read(passengerTabProvider.notifier).set(0),
                          child: const Text('Find a ride'),
                        ),
                ); // UC-11 A1
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => BookingCard(
                  booking: list[i],
                  onTap: () => context.push('/passenger/booking/${list[i].id}'),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
