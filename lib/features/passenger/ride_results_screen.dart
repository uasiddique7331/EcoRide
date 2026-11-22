import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/trip_card.dart';
import '../../providers/providers.dart';
import '../../services/ride_matcher.dart';

/// UC-05 steps 8-17: matching results (FR-50, FR-52, FR-59).
class RideResultsScreen extends ConsumerWidget {
  const RideResultsScreen({super.key, required this.query});
  final RideQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(rideSearchProvider(query));
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Available rides')),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.colorScheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${query.pickup.name}  →  ${query.dropoff.name}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${Fmt.dateTime(query.desiredTime)} • ${query.seats} seat(s)', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
        ),
        Expanded(
          child: results.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(rideSearchProvider(query))),
            data: (matches) {
              if (matches.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matching rides found',
                  message: 'Try a different time, a nearby pickup point or fewer seats. New trips are published all the time.',
                  action: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(160, 46)),
                    onPressed: () => context.pop(),
                    child: const Text('Change search'),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.refresh(rideSearchProvider(query).future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: matches.length,
                  itemBuilder: (_, i) {
                    final m = matches[i];
                    return TripCard(
                      trip: m.trip,
                      showDriver: true,
                      onTap: () => context.push('/passenger/ride/${m.trip.id}', extra: query),
                      footer: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              '${Fmt.km(m.pickupDistanceKm)} from your pickup • '
                              '${m.timeDifference.inMinutes} min from your time',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('~${Fmt.pkr(m.estimatedShare)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                        ]),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
