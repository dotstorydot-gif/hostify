import "package:flutter/material.dart";
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:hostify/legacy/screens/splash_screen.dart';
import 'package:hostify/legacy/services/language_service.dart';
import 'package:hostify/legacy/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hostify/legacy/core/config/supabase_config.dart';

import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/providers/booking_provider.dart';
import 'package:hostify/legacy/providers/service_request_provider.dart';
import 'package:hostify/legacy/providers/document_provider.dart';
import 'package:hostify/legacy/providers/property_provider.dart';
import 'package:hostify/legacy/providers/review_provider.dart';
import 'package:hostify/legacy/providers/admin_analytics_provider.dart';
import 'package:hostify/legacy/providers/notification_provider.dart';
import 'package:hostify/legacy/providers/admin_booking_provider.dart';
import 'package:hostify/legacy/providers/admin_review_provider.dart';
import 'package:hostify/legacy/providers/expense_provider.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) print('Firebase initialization failed: \$e');
  }
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  final languageService = LanguageService();
  await languageService.loadLanguage();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageService),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ServiceRequestProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => PropertyProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => AdminBookingProvider()),
        ChangeNotifierProvider(create: (_) => AdminAnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AdminReviewProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    
    return MaterialApp(
      title: '.Hostify',
      debugShowCheckedModeBanner: false,
      
      // Localization setup
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LanguageService.supportedLocales,
      locale: languageService.currentLocale,
      
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          surface: Colors.white,
          background: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
          secondary: Colors.black,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      ),
      home: const SplashScreen(),
    );
  }
}
