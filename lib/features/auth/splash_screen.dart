import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primaryDark, AppColors.primary]),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.eco_rounded, size: 72, color: Colors.white),
            SizedBox(height: 12),
            Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            SizedBox(height: 28),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

/// Shown when a signed-in account has no profile document (e.g. an
/// interrupted registration) so the user is never stuck.
class SetupIncompleteScreen extends ConsumerWidget {
  const SetupIncompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.person_off_outlined, size: 64, color: AppColors.warning),
            const SizedBox(height: 16),
            Text('Your profile is incomplete', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'We could not find your EcoRide profile. This can happen if registration was interrupted. Please sign out and register again, or contact support.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Sign out'),
            ),
          ]),
        ),
      ),
    );
  }
}
