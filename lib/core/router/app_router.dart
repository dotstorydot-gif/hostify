import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/properties/screens/properties_screen.dart';
import '../../features/properties/screens/property_detail_screen.dart';
import '../../features/properties/screens/add_property_screen.dart';
import '../../features/bookings/screens/bookings_screen.dart';
import '../../features/bookings/screens/add_booking_screen.dart';
import '../../features/guests/screens/guests_screen.dart';
import '../../features/financials/screens/financials_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/signup';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/properties',
            builder: (_, __) => const PropertiesScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const AddPropertyScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (ctx, state) => PropertyDetailScreen(
                  propertyId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/bookings',
            builder: (_, __) => const BookingsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const AddBookingScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/guests',
            builder: (_, __) => const GuestsScreen(),
          ),
          GoRoute(
            path: '/financials',
            builder: (_, __) => const FinancialsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
