import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SeedService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> seedDummyData() async {
    // Hardcode a consistent UUID for the dummy landlord so properties are globally consistent
    // regardless of who pushes the button (guest, admin, etc).
    const String landlordId = '00000000-0000-0000-0000-000000000000';

    // 1. Create Dummy Properties
    final propertyIds = await _seedProperties(landlordId);
    
    // 2. Create Dummy Bookings for these properties
    await _seedBookings(landlordId, propertyIds);
    
    // 3. Create Dummy Expenses
    await _seedExpenses(landlordId, propertyIds);
    
    // 4. Create Dummy Service Requests
    await _seedServiceRequests(landlordId, propertyIds);
  }

  Future<List<String>> _seedProperties(String landlordId) async {
    // We'll try to find the actual IDs for these emails first
    String adminId = '00000000-0000-0000-0000-000000000001';
    String landlordId = '00000000-0000-0000-0000-000000000002';

    try {
      final adminProfile = await _supabase.from('user_profiles').select('id').eq('email', 'admin@dot-story.com').maybeSingle();
      final landlordProfile = await _supabase.from('user_profiles').select('id').eq('email', 'landlord@dot-story.com').maybeSingle();
      
      if (adminProfile != null) adminId = adminProfile['id'];
      if (landlordProfile != null) landlordId = landlordProfile['id'];
    } catch (e) {
      if (kDebugMode) print('Warning: Could not fetch real user IDs, using defaults: $e');
    }

    final List<Map<String, dynamic>> propertiesToSeed = [
      // 4 properties for Admin
      {
        'landlord_id': adminId,
        'name': 'Luxury Cairo Tower Suite',
        'description': 'Premium 3-bedroom suite with views of the Nile and Cairo Tower.',
        'location': 'Zamalek, Cairo, Egypt',
        'address': 'Cairo Tower St, Zamalek',
        'property_type': 'apartment',
        'bedrooms': 3,
        'bathrooms': 3,
        'max_guests': 6,
        'price_per_night': 450.0,
        'status': 'active',
      },
      {
        'landlord_id': adminId,
        'name': 'Alexandria Mediterranean Villa',
        'description': 'Stunning sea-front villa with direct beach access in Montaza.',
        'location': 'Montaza, Alexandria, Egypt',
        'address': 'Kings Road, Alexandria',
        'property_type': 'villa',
        'bedrooms': 4,
        'bathrooms': 3,
        'max_guests': 8,
        'price_per_night': 320.0,
        'status': 'active',
      },
      {
        'landlord_id': adminId,
        'name': 'Sharm El Sheikh Royal Resort',
        'description': 'Full resort experience with private beach and coral reef access.',
        'location': 'Sharm El Sheikh, South Sinai, Egypt',
        'address': 'Naama Bay, Sharm El Sheikh',
        'property_type': 'villa',
        'bedrooms': 6,
        'bathrooms': 5,
        'max_guests': 12,
        'price_per_night': 800.0,
        'status': 'active',
      },
      {
        'landlord_id': adminId,
        'name': 'Luxor Ancient Heritage House',
        'description': 'Authentic Luxor experience near the Valley of the Kings.',
        'location': 'Luxor, Upper Egypt',
        'address': 'West Bank, Luxor',
        'property_type': 'villa',
        'bedrooms': 4,
        'bathrooms': 2,
        'max_guests': 8,
        'price_per_night': 180.0,
        'status': 'active',
      },
      // 1 property for Landlord
      {
        'landlord_id': landlordId,
        'name': 'Dahab Blue Hole Shack',
        'description': 'Cozy diver\'s paradise near the Blue Hole Dahab.',
        'location': 'Dahab, South Sinai, Egypt',
        'address': 'Lighthouse Area, Dahab',
        'property_type': 'apartment',
        'bedrooms': 2,
        'bathrooms': 1,
        'max_guests': 4,
        'price_per_night': 95.0,
        'status': 'active',
      },
    ];

    final List<String> ids = [];

    for (var prop in propertiesToSeed) {
      // Check if property with same name already exists for this landlord
      final existing = await _supabase.from('properties')
          .select('id')
          .eq('landlord_id', landlordId)
          .eq('name', prop['name'])
          .maybeSingle();

      if (existing != null) {
        ids.add(existing['id']);
        continue;
      }

      final response = await _supabase.from('properties').insert(prop).select().single();
      final id = response['id'] as String;
      ids.add(id);

      // Add dummy primary image
      await _supabase.from('property_images').insert({
        'property_id': id,
        'image_url': 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=800&q=80',
        'is_primary': true,
      });

      // Add dummy amenities
      await _supabase.from('property_amenities').insert([
        {'property_id': id, 'amenity': 'wifi'},
        {'property_id': id, 'amenity': 'pool'},
        {'property_id': id, 'amenity': 'air_conditioning'},
        {'property_id': id, 'amenity': 'kitchen'},
      ]);
    }

    return ids;
  }

  Future<void> _seedBookings(String landlordId, List<String> propertyIds) async {
    final random = Random();
    final now = DateTime.now();

    for (var propId in propertyIds) {
      // Create 5-10 bookings for each property over the last 6 months
      final numBookings = 5 + random.nextInt(5);
      
      for (int i = 0; i < numBookings; i++) {
        final monthsAgo = random.nextInt(6);
        final checkIn = now.subtract(Duration(days: monthsAgo * 30 + random.nextInt(20)));
        final nights = 2 + random.nextInt(5);
        final checkOut = checkIn.add(Duration(days: nights));
        
        // Skip if check-in is in future (or keep some for future?)
        // Let's have some confirmed and some past
        final status = checkIn.isBefore(now) ? 'confirmed' : 'pending';

        await _supabase.from('bookings').insert({
          'property_id': propId,
          'guest_id': '00000000-0000-0000-0000-000000000003', // Test Guest ID
          'check_in': checkIn.toIso8601String(),
          'check_out': checkOut.toIso8601String(),
          'total_price': (100 + random.nextInt(200)) * nights,
          'status': status,
          'booking_source': ['hostify', 'airbnb', 'booking.com'][random.nextInt(3)],
        });
      }
    }
  }

  Future<void> _seedExpenses(String landlordId, List<String> propertyIds) async {
    final random = Random();
    final categories = ['maintenance', 'cleaning', 'utilities', 'other'];
    final now = DateTime.now();

    for (var propId in propertyIds) {
      final numExpenses = 3 + random.nextInt(4);
      
      for (int i = 0; i < numExpenses; i++) {
        final daysAgo = random.nextInt(90);
        final date = now.subtract(Duration(days: daysAgo));

        await _supabase.from('expenses').insert({
          'property_id': propId,
          'owner_id': landlordId,
          'category': categories[random.nextInt(categories.length)],
          'amount': 20.0 + random.nextInt(150),
          'description': 'Dummy expense for property',
          'date': date.toIso8601String(),
        });
      }
    }
  }

  Future<void> _seedServiceRequests(String landlordId, List<String> propertyIds) async {
    final random = Random();
    final categories = ['Cleaning', 'Maintenance', 'Transport', 'Other'];
    final types = ['Deep Clean', 'AC Repair', 'Airport Shuttle', 'Room Service'];

    for (var propId in propertyIds) {
      // Find a booking for this property to link service request
      final booking = await _supabase.from('bookings')
          .select('id')
          .eq('property_id', propId)
          .limit(1)
          .maybeSingle();

      if (booking == null) continue;

      final numRequests = 2 + random.nextInt(3);
      
      for (int i = 0; i < numRequests; i++) {
        await _supabase.from('service_requests').insert({
          'booking_id': booking['id'],
          'guest_id': '00000000-0000-0000-0000-000000000003',
          'property_id': propId,
          'category': categories[random.nextInt(categories.length)],
          'service_type': types[random.nextInt(types.length)],
          'details': 'Need urgent assistance with service',
          'status': ['pending', 'completed', 'cancelled'][random.nextInt(3)],
        });
      }
    }
  }
  Future<void> seedTestUsers() async {
    final List<Map<String, String>> usersToSeed = [
      {
        'email': 'guest@dot-story.com',
        'password': 'guest123',
        'full_name': 'Test Guest',
        'role': 'guest'
      },
      {
        'email': 'landlord@dot-story.com',
        'password': 'landlord123',
        'full_name': 'Test Landlord',
        'role': 'landlord'
      },
      {
        'email': 'admin@dot-story.com',
        'password': 'admin123',
        'full_name': 'Test Admin',
        'role': 'admin'
      },
    ];

    for (var user in usersToSeed) {
      try {
        String? userId;
        try {
          // 1. Try to sign up user
          final response = await _supabase.auth.signUp(
            email: user['email']!,
            password: user['password']!,
            data: {'full_name': user['full_name']},
          );
          userId = response.user?.id;
        } catch (e) {
          // User might already exist, try to sign in to get ID or fetch from profile
          if (kDebugMode) print('User ${user['email']} might already exist: $e');
        }

        // If signup didn't give US an ID, find it by email in user_profiles
        if (userId == null) {
          final profile = await _supabase.from('user_profiles')
              .select('id')
              .eq('email', user['email']!)
              .maybeSingle();
          userId = profile?['id'];
        }

        // If still null, try to sign in to get the ID (Supabase Auth usually gives the ID on sign-in)
        if (userId == null) {
          try {
            final authResponse = await _supabase.auth.signInWithPassword(
              email: user['email']!,
              password: user['password']!,
            );
            userId = authResponse.user?.id;
          } catch (e) {
            if (kDebugMode) print('Could not retrieve ID via sign-in for ${user['email']}: $e');
          }
        }

        if (userId != null) {
          // 2. Ensure profile exists
          await _supabase.from('user_profiles').upsert({
            'id': userId,
            'email': user['email'],
            'full_name': user['full_name'],
          });

          // 3. Add role
          await _supabase.from('user_roles').upsert({
            'user_id': userId,
            'role': user['role'],
            'is_active': true,
          }, onConflict: 'user_id,role');
        }
      } catch (e) {
        if (kDebugMode) {
          final errorStr = e.toString();
          if (errorStr.contains('42501') || errorStr.contains('Forbidden')) {
            print('Note: Role/Profile for ${user['email']} already exists or restricted (RLS). Skipping update.');
          } else {
            print('Error seeding user ${user['email']}: $e');
          }
        }
      }
    }
  }
}
