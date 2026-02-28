import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  const supabaseUrl = 'https://uvjnmkmrkblgbgfctcxp.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2am5ta21ya2JsZ2JnZmN0Y3hwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4Mzk5ODgsImV4cCI6MjA4NzQxNTk4OH0.x1FjyUYDo2b0Iyw3jAnkLEcMD1GErplPB_AzFrlW6Bc';

  print('Initializing Supabase...');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final supabase = Supabase.instance.client;

  final users = [
    {'email': 'guest@dot-story.com', 'password': 'guest123', 'role': 'guest', 'name': 'Test Guest'},
    {'email': 'landlord@dot-story.com', 'password': 'landlord123', 'role': 'landlord', 'name': 'Test Landlord'},
    {'email': 'admin@dot-story.com', 'password': 'admin123', 'role': 'admin', 'name': 'Test Admin'},
  ];

  for (var user in users) {
    print('Creating user: ${user['email']}...');
    try {
      final response = await supabase.auth.signUp(
        email: user['email']!,
        password: user['password']!,
        data: {'full_name': user['name']},
      );

      if (response.user != null) {
        final userId = response.user!.id;
        print('User created with ID: $userId. Assigning role: ${user['role']}...');
        
        // Wait a bit for the profile trigger if it exists
        await Future.delayed(const Duration(seconds: 1));

        // Update profile
        await supabase.from('user_profiles').upsert({
          'id': userId,
          'email': user['email'],
          'full_name': user['name'],
        });

        // Add role
        await supabase.from('user_roles').upsert({
          'user_id': userId,
          'role': user['role'],
          'is_active': true,
        });

        print('Successfully configured ${user['email']}');
      }
    } catch (e) {
      print('Error with ${user['email']}: $e');
    }
  }

  print('Done! Please check if accounts are functional. If email confirmation is ON in Supabase, you might need to confirm them manually.');
  exit(0);
}
