import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'models/app_user.dart';
import 'models/enums.dart';
import 'providers/providers.dart';

class EcoRideApp extends ConsumerWidget {
  const EcoRideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => SessionGuard(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Signs the user out immediately if an administrator restricts or
/// deactivates the account while they are using the app (FR-96, UC-03 A5).
class SessionGuard extends ConsumerWidget {
  const SessionGuard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
      final user = next.value;
      if (user != null && !user.isActive) {
        ref.read(authNoticeProvider.notifier).set(
              user.status == AccountStatus.restricted
                  ? 'Your account has been restricted by an administrator. Contact support for help.'
                  : 'Your account has been deactivated. Contact support if you think this is a mistake.',
            );
        ref.read(authRepositoryProvider).signOut();
      }
    });
    return child;
  }
}
