import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hostify/legacy/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'core/config/firebase_options.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

// Legacy Providers
import 'legacy/providers/app_state_provider.dart';
import 'legacy/providers/booking_provider.dart';
import 'legacy/providers/property_provider.dart';
import 'legacy/providers/review_provider.dart';
import 'legacy/providers/notification_provider.dart';
import 'legacy/providers/expense_provider.dart';
import 'legacy/providers/service_request_provider.dart';
import 'legacy/providers/admin_booking_provider.dart';
import 'legacy/providers/admin_review_provider.dart';
import 'legacy/providers/admin_analytics_provider.dart';
import 'legacy/providers/document_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Ignore duplicate app initialization errors that occur on some iOS setups
    // where GoogleService-Info.plist auto-initializes the default app.
    if (!e.toString().contains('core/duplicate-app')) {
      rethrow;
    }
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      child: legacy_provider.MultiProvider(
        providers: [
          legacy_provider.ChangeNotifierProvider(create: (_) => AppStateProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => PropertyProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => BookingProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => ReviewProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => NotificationProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => ServiceRequestProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => AdminBookingProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => AdminReviewProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => AdminAnalyticsProvider()),
          legacy_provider.ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}



class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Hostify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('fr', ''),
        Locale('es', ''),
      ],
    );
  }
}

