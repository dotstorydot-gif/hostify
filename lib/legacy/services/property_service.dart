import 'package:supabase_flutter/supabase_flutter.dart';

/// Property Service for database operations
class PropertyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all active properties
  Future<List<Map<String, dynamic>>> getActiveProperties() async {
    final response = await _supabase
        .from('property-images')
        .select('*, property_images(*), property_amenities(*)')
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetch properties by landlord
  Future<List<Map<String, dynamic>>> getLandlordProperties(String landlordId) async {
    final response = await _supabase
        .from('property-images')
        .select('*, property_images(*), property_amenities(*)')
        .eq('landlord_id', landlordId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get single property details
  Future<Map<String, dynamic>?> getPropertyById(String propertyId) async {
    final response = await _supabase
        .from('property-images')
        .select('*, property_images(*), property_amenities(*)')
        .eq('id', propertyId)
        .single();

    return response;
  }

  /// Create new property
  Future<String> createProperty({
    required String name,
    required String description,
    required String location,
    required String address,
    required String propertyType,
    required int bedrooms,
    required int bathrooms,
    required int maxGuests,
    required double pricePerNight,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await _supabase.from('property-images').insert({
      'landlord_id': userId,
      'name': name,
      'description': description,
      'location': location,
      'address': address,
      'property_type': propertyType,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'max_guests': maxGuests,
      'price_per_night': pricePerNight,
      'latitude': latitude,
      'longitude': longitude,
      'status': 'active',
    }).select().single();

    return response['id'];
  }

  /// Update property
  Future<void> updateProperty(
    String propertyId,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _supabase.from('property-images').update(updates).eq('id', propertyId);
  }

  /// Delete property
  Future<void> deleteProperty(String propertyId) async {
    await _supabase.from('property-images').delete().eq('id', propertyId);
  }

  /// Add property image
  Future<void> addPropertyImage(
    String propertyId,
    String imageUrl, {
    bool isPrimary = false,
    int displayOrder = 0,
  }) async {
    await _supabase.from('property_images').insert({
      'property_id': propertyId,
      'image_url': imageUrl,
      'is_primary': isPrimary,
      'display_order': displayOrder,
    });
  }

  /// Add property amenity
  Future<void> addPropertyAmenity(String propertyId, String amenity) async {
    await _supabase.from('property_amenities').insert({
      'property_id': propertyId,
      'amenity': amenity,
    });
  }

  /// Get property reviews
  Future<List<Map<String, dynamic>>> getPropertyReviews(String propertyId) async {
    final response = await _supabase
        .from('review-images')
        .select('*, review_images(*)')
        .eq('property_id', propertyId)
        .eq('status', 'published')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get property average rating
  Future<double> getPropertyAverageRating(String propertyId) async {
    final reviews = await getPropertyReviews(propertyId);
    if (reviews.isEmpty) return 0.0;

    final sum = reviews.fold<double>(
      0.0,
      (sum, review) => sum + (review['overall_rating'] as num).toDouble(),
    );

    return sum / reviews.length;
  }

  /// Search properties
  Future<List<Map<String, dynamic>>> searchProperties({
    String? location,
    int? minBedrooms,
    int? maxGuests,
    double? maxPrice,
  }) async {
    var query = _supabase
        .from('property-images')
        .select('*, property_images(*), property_amenities(*)')
        .eq('status', 'active');

    if (location != null) {
      query = query.ilike('location', '%$location%');
    }
    if (minBedrooms != null) {
      query = query.gte('bedrooms', minBedrooms);
    }
    if (maxGuests != null) {
      query = query.gte('max_guests', maxGuests);
    }
    if (maxPrice != null) {
      query = query.lte('price_per_night', maxPrice);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}
