import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl =
      'https://uvjnmkmrkblgbgfctcxp.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2am5ta21ya2JsZ2JnZmN0Y3hwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4Mzk5ODgsImV4cCI6MjA4NzQxNTk4OH0'
      '.x1FjyUYDo2b0Iyw3jAnkLEcMD1GErplPB_AzFrlW6Bc';

  static SupabaseClient get client => Supabase.instance.client;
}
