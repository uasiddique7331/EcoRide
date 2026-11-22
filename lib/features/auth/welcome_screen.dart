import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../providers/providers.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(authNoticeProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primaryDark, AppColors.primary]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.eco_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 22),
              const Text('Share the ride.\nSplit the cost.',
                  style: TextStyle(color: Colors.white, fontSize: 38, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(height: 14),
              Text(
                '${AppConfig.appName} connects drivers and passengers heading the same way — '
                'with a fair fare of PKR ${AppConfig.farePerKm}/km divided equally between riders.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16, height: 1.4),
              ),
              const Spacer(),
              if (notice != null)
                NoticeBanner(message: notice, color: AppColors.accent, icon: Icons.block_rounded),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark),
                onPressed: () {
                  ref.read(authNoticeProvider.notifier).set(null);
                  context.push('/register');
                },
                child: const Text('Create an account'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                onPressed: () => context.push('/login'),
                child: const Text('I already have an account'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
