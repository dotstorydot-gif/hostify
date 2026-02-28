import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../legacy/screens/admin_dashboard.dart'; // Fixed
import '../../legacy/screens/landlord_dashboard.dart'; // Fixed
import '../../legacy/screens/guest_main_navigation.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import 'package:provider/provider.dart' as legacy_provider;
import '../../legacy/providers/app_state_provider.dart';

// Legacy Screens
import '../../legacy/screens/auth_screen.dart';
import '../../legacy/screens/admin_property_management.dart';
import '../../legacy/screens/admin_property_edit_screen.dart';
import '../../legacy/screens/property_detail_screen.dart';
import '../../legacy/screens/guest_my_bookings_screen.dart';
import '../../legacy/screens/booking_screen.dart';
import '../../legacy/screens/admin_financials.dart';
import '../../legacy/screens/settings_screen.dart';
import '../shell/main_shell.dart';


final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    /* 
    Redirect disabled because authentication is split between Supabase (Legacy) and Firebase (Modern).
    Manual navigation is handled in AuthScreen.
    */
    redirect: (context, state) => null,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const AuthScreen()),
      // Added Legacy Dashboards to GoRouter
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
      GoRoute(path: '/landlord', builder: (_, __) => const LandlordDashboard()),
      GoRoute(path: '/guest', builder: (_, __) => const GuestMainNavigation(initialIndex: 0)),
      
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            redirect: (context, state) {
              final appState = legacy_provider.Provider.of<AppStateProvider>(context, listen: false);
              final role = appState.userRole?.toLowerCase();
              if (role == 'admin') return '/admin';
              if (role == 'landlord') return '/landlord';
              if (role == 'traveler' || role == 'guest') return '/guest';
              return null;
            },
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/properties',
            builder: (_, __) => const AdminPropertyManagement(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const AdminPropertyEditScreen(propertyId: null, propertyName: ''),
              ),
              GoRoute(
                path: ':id',
                builder: (ctx, state) => PropertyDetailScreen(
                  property: {'id': state.pathParameters['id']!},
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/bookings',
            builder: (_, __) => const GuestMyBookingsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const BookingScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/guests',
            builder: (_, __) => const GuestMyBookingsScreen(),
          ),
          GoRoute(
            path: '/financials',
            builder: (_, __) => const AdminFinancials(),
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
