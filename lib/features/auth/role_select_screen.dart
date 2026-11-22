import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// FR-02: choose the account type before registering.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('How will you use EcoRide?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Choose your account type. You can only pick one per account.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            _RoleCard(
              icon: Icons.person_search_rounded,
              title: 'Passenger',
              subtitle: 'Find rides along your route and share the fare with other riders.',
              bullets: const ['Search rides within 10 km', 'Book seats & track status', 'Upload your CNIC for verification'],
              onTap: () => context.push('/register/passenger'),
            ),
            const SizedBox(height: 14),
            _RoleCard(
              icon: Icons.directions_car_filled_rounded,
              title: 'Driver',
              subtitle: 'Publish your trips, accept passengers and cover your fuel costs.',
              bullets: const ['Register one vehicle', 'Publish trips & manage requests', 'Upload CNIC and vehicle card'],
              onTap: () => context.push('/register/driver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.title, required this.subtitle, required this.bullets, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: t.colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          const Icon(Icons.arrow_forward_rounded),
        ]),
        const SizedBox(height: 12),
        Text(subtitle),
        const SizedBox(height: 10),
        for (final b in bullets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text(b, style: const TextStyle(fontSize: 13.5))),
            ]),
          ),
      ]),
    );
  }
}
