import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeedService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> seedDummyData() async {
    // Hardcode a consistent UUID for the dummy landlord so properties are globally consistent
    // regardless of who pushes the button (guest, admin, etc).
    final String landlordId = '00000000-0000-0000-0000-000000000000';

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
    final List<Map<String, dynamic>> propertiesToSeed = [
      {
        'landlord_id': landlordId,
        'name': 'Boutique Sea View Villa',
        'description': 'Luxury 5-bedroom villa with private pool and panoramic Red Sea views.',
        'location': 'Hurghada, Red Sea, Egypt',
        'address': 'Marina Boulevard, Hurghada',
        'property_type': 'villa',
        'bedrooms': 5,
        'bathrooms': 4,
        'max_guests': 10,
        'price_per_night': 250.0,
        'status': 'active',
      },
      {
        'landlord_id': landlordId,
        'name': 'El Gouna Golf Apartment',
        'description': 'Modern apartment overlooking the championship golf course.',
        'location': 'El Gouna, Red Sea, Egypt',
        'address': 'Kaf Marina, El Gouna',
        'property_type': 'apartment',
        'bedrooms': 2,
        'bathrooms': 2,
        'max_guests': 4,
        'price_per_night': 120.0,
        'status': 'active',
      },
      {
        'landlord_id': landlordId,
        'name': 'Cozy Lagoon Studio',
        'description': 'Compact and stylish studio with direct lagoon access.',
        'location': 'El Gouna, Red Sea, Egypt',
        'address': 'South Marina, El Gouna',
        'property_type': 'apartment',
        'bedrooms': 1,
        'bathrooms': 1,
        'max_guests': 2,
        'price_per_night': 85.0,
        'status': 'active',
      },
      {
        'landlord_id': landlordId,
        'name': 'Downtown Cairo Loft',
        'description': 'Chic loft right in the heart of the city.',
        'location': 'Cairo, Egypt',
        'address': 'Tahrir Square, Cairo',
        'property_type': 'apartment',
        'bedrooms': 2,
        'bathrooms': 1,
        'max_guests': 4,
        'price_per_night': 150.0,
        'status': 'active',
      },
    ];

    final List<String> ids = [];

    for (var prop in propertiesToSeed) {
      // Check if property with same name already exists for this landlord
      final existing = await _supabase.from('property-images')
          .select('id')
          .eq('landlord_id', landlordId)
          .eq('name', prop['name'])
          .maybeSingle();

      if (existing != null) {
        ids.add(existing['id']);
        continue;
      }

      final response = await _supabase.from('property-images').insert(prop).select().single();
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
          'guest_id': landlordId, // Seeding as self-guest for dummy data
          'check_in': checkIn.toIso8601String(),
          'check_out': checkOut.toIso8601String(),
          'nights': nights,
          'total_price': (100 + random.nextInt(200)) * nights,
          'status': status,
          'booking_source': ['hostify', 'airbnb', 'booking.com'][random.nextInt(3)],
          'guests': 2 + random.nextInt(2),
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
          'guest_id': landlordId,
          'property_id': propId,
          'category': categories[random.nextInt(categories.length)],
          'service_type': types[random.nextInt(types.length)],
          'details': 'Need urgent assistance with service',
          'status': ['pending', 'completed', 'cancelled'][random.nextInt(3)],
        });
      }
    }
  }
}
