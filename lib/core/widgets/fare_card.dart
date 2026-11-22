import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';

/// Shows the shared-fare breakdown for a trip (FR-75 .. FR-82, UC-09).
class FareCard extends StatelessWidget {
  const FareCard({super.key, required this.trip, this.estimatedShare, this.viewerIsOwner = false});

  final Trip trip;

  /// Share the viewer would pay if they join (pre-booking view).
  final int? estimatedShare;
  final bool viewerIsOwner;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final share = trip.sharePerPassenger;
    return SectionCard(
      title: 'Fare',
      trailing: const Icon(Icons.payments_outlined, color: AppColors.primary),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(Fmt.pkr(trip.totalFare), style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('total trip fare', style: t.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ),
        ]),
        const SizedBox(height: 2),
        Text(
          '${Fmt.km(trip.distanceKm)} × PKR ${trip.farePerKm}/km'
          '${trip.distanceIsEstimate ? ' (estimated distance)' : ''}',
          style: t.textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const Divider(height: 24),
        InfoRow(icon: Icons.groups_outlined, label: 'Accepted', value: '${trip.acceptedPassengers} passenger(s)'),
        InfoRow(
          icon: Icons.call_split_rounded,
          label: 'Each pays',
          value: share == null ? 'Calculated when a booking is accepted' : Fmt.pkr(share),
          bold: share != null,
          valueColor: share == null ? null : AppColors.primaryDark,
        ),
        if (estimatedShare != null)
          InfoRow(icon: Icons.calculate_outlined, label: 'Your estimate', value: '${Fmt.pkr(estimatedShare)} if accepted', bold: true),
        InfoRow(
          icon: Icons.person_pin_outlined,
          label: 'Paid to',
          value: viewerIsOwner ? 'You (vehicle owner)' : '${trip.driverName} (vehicle owner)',
        ),
        const SizedBox(height: 8),
        NoticeBanner(
          color: AppColors.info,
          message: viewerIsOwner
              ? 'Passengers pay their share to you directly, in person. EcoRide does not process payments.'
              : 'Pay your share directly to the vehicle owner. EcoRide does not process payments or hold money. '
                  'The share is divided equally among accepted passengers and updates when bookings change.',
        ),
      ]),
    );
  }
}

/// Tiny helper so screens can mention the rate without importing config.
String get fareRateLabel => 'PKR ${AppConfig.farePerKm}/km';
