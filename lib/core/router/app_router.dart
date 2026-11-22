import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_home.dart';
import '../../features/admin/admin_trip_detail_screen.dart';
import '../../features/admin/admin_user_detail_screen.dart';
import '../../features/admin/document_review_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_driver_screen.dart';
import '../../features/auth/register_passenger_screen.dart';
import '../../features/auth/role_select_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/driver/driver_home.dart';
import '../../features/driver/driver_trip_detail_screen.dart';
import '../../features/driver/publish_trip_screen.dart';
import '../../features/driver/vehicle_screen.dart';
import '../../features/passenger/booking_detail_screen.dart';
import '../../features/passenger/passenger_home.dart';
import '../../features/passenger/ride_details_screen.dart';
import '../../features/passenger/ride_results_screen.dart';
import '../../models/enums.dart';
import '../../providers/providers.dart';
import '../../services/ride_matcher.dart';

/// Re-evaluates the router redirect whenever session state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(appUserProvider, (_, __) => notifyListeners());
    _ref.listen(registrationBusyProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;

  static const _publicExact = {'/welcome', '/login', '/forgot-password'};

  bool _isPublic(String loc) => _publicExact.contains(loc) || loc.startsWith('/register');

  static String homeFor(UserRole role) => switch (role) {
        UserRole.driver => '/driver',
        UserRole.passenger => '/passenger',
        UserRole.admin => '/admin',
      };

  /// FR-07 role-based navigation + FR-84/FR-97 area protection.
  String? redirect(GoRouterState state) {
    final loc = state.matchedLocation;
    final auth = _ref.read(authStateProvider);

    if (auth.isLoading && !auth.hasValue) return loc == '/splash' ? null : '/splash';

    final firebaseUser = auth.value;
    if (firebaseUser == null) {
      return _isPublic(loc) ? null : '/welcome';
    }

    final profile = _ref.read(appUserProvider);
    final user = profile.value;
    if (user == null) {
      if (profile.isLoading || _ref.read(registrationBusyProvider)) {
        return (loc == '/splash' || _isPublic(loc)) ? null : '/splash';
      }
      return loc == '/setup-incomplete' ? null : '/setup-incomplete';
    }

    final home = homeFor(user.role);
    if (loc == '/splash' || loc == '/setup-incomplete' || _isPublic(loc)) return home;

    final area = loc.split('/').length > 1 ? '/${loc.split('/')[1]}' : loc;
    final allowed = homeFor(user.role);
    if (area != allowed) return home; // e.g. a passenger opening /admin
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => refresh.redirect(state),
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(child: TextButton(onPressed: () => context.go('/splash'), child: const Text('Go home'))),
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/setup-incomplete', builder: (_, __) => const SetupIncompleteScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RoleSelectScreen()),
      GoRoute(path: '/register/passenger', builder: (_, __) => const RegisterPassengerScreen()),
      GoRoute(path: '/register/driver', builder: (_, __) => const RegisterDriverScreen()),

      // Passenger
      GoRoute(path: '/passenger', builder: (_, __) => const PassengerHome()),
      GoRoute(
        path: '/passenger/results',
        builder: (_, s) {
          final q = s.extra;
          return q is RideQuery ? RideResultsScreen(query: q) : const PassengerHome();
        },
      ),
      GoRoute(
        path: '/passenger/ride/:id',
        builder: (_, s) => RideDetailsScreen(tripId: s.pathParameters['id']!, query: s.extra is RideQuery ? s.extra as RideQuery : null),
      ),
      GoRoute(
        path: '/passenger/booking/:id',
        builder: (_, s) => BookingDetailScreen(bookingId: s.pathParameters['id']!),
      ),

      // Driver
      GoRoute(path: '/driver', builder: (_, __) => const DriverHome()),
      GoRoute(path: '/driver/publish', builder: (_, __) => const PublishTripScreen()),
      GoRoute(path: '/driver/vehicle', builder: (_, __) => const VehicleScreen()),
      GoRoute(
        path: '/driver/trip/:id',
        builder: (_, s) => DriverTripDetailScreen(tripId: s.pathParameters['id']!),
      ),

      // Administrator
      GoRoute(path: '/admin', builder: (_, __) => const AdminHome()),
      GoRoute(
        path: '/admin/document/:id',
        builder: (_, s) => DocumentReviewScreen(documentId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/user/:id',
        builder: (_, s) => AdminUserDetailScreen(userId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/trip/:id',
        builder: (_, s) => AdminTripDetailScreen(tripId: s.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
