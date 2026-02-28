import 'package:supabase_flutter/supabase_flutter.dart';

/// Review Service for ratings and feedback management
class ReviewService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create review
  Future<String> createReview({
    required String propertyId,
    String? bookingId,
    required double overallRating,
    required double cleanlinessRating,
    required double locationRating,
    required double valueRating,
    required double amenitiesRating,
    required double serviceRating,
    required double accuracyRating,
    required String reviewText,
    List<String>? imageUrls,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Get user profile for guest name
    final profile = await _supabase
        .from('user_profiles')
        .select('full_name')
        .eq('id', userId)
        .single();

    final response = await _supabase.from('reviews').insert({
      'property_id': propertyId,
      'booking_id': bookingId,
      'guest_id': userId,
      'guest_name': profile['full_name'] ?? 'Anonymous',
      'overall_rating': overallRating,
      'cleanliness_rating': cleanlinessRating,
      'location_rating': locationRating,
      'value_rating': valueRating,
      'amenities_rating': amenitiesRating,
      'service_rating': serviceRating,
      'accuracy_rating': accuracyRating,
      'review_text': reviewText,
      'status': 'published',
    }).select().single();

    final reviewId = response['id'];

    // Add review images if provided
    if (imageUrls != null && imageUrls.isNotEmpty) {
      for (final url in imageUrls) {
        await _supabase.from('review_images').insert({
          'review_id': reviewId,
          'image_url': url,
        });
      }
    }

    return reviewId;
  }

  /// Get property reviews
  Future<List<Map<String, dynamic>>> getPropertyReviews(
    String propertyId, {
    int limit = 10,
  }) async {
    final response = await _supabase
        .from('reviews')
        .select('*, review_images(*)')
        .eq('property_id', propertyId)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get user reviews
  Future<List<Map<String, dynamic>>> getUserReviews() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('reviews')
        .select('*, properties(name), review_images(*)')
        .eq('guest_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Update review
  Future<void> updateReview(
    String reviewId,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _supabase.from('reviews').update(updates).eq('id', reviewId);
  }

  /// Delete review
  Future<void> deleteReview(String reviewId) async {
    await _supabase.from('reviews').delete().eq('id', reviewId);
  }

  /// Get property rating stats
  Future<Map<String, double>> getPropertyRatingStats(String propertyId) async {
    final reviews = await _supabase
        .from('reviews')
        .select(
            'overall_rating, cleanliness_rating, location_rating, value_rating, amenities_rating, service_rating, accuracy_rating')
        .eq('property_id', propertyId)
        .eq('status', 'published');

    if ((reviews as List).isEmpty) {
      return {
        'overall': 0.0,
        'cleanliness': 0.0,
        'location': 0.0,
        'value': 0.0,
        'amenities': 0.0,
        'service': 0.0,
        'accuracy': 0.0,
        'count': 0.0,
      };
    }

    final count = reviews.length.toDouble();
    return {
      'overall': reviews.fold<double>(0, (sum, r) => sum + (r['overall_rating'] as num)) / count,
      'cleanliness': reviews.fold<double>(0, (sum, r) => sum + (r['cleanliness_rating'] as num)) / count,
      'location': reviews.fold<double>(0, (sum, r) => sum + (r['location_rating'] as num)) / count,
      'value': reviews.fold<double>(0, (sum, r) => sum + (r['value_rating'] as num)) / count,
      'amenities': reviews.fold<double>(0, (sum, r) => sum + (r['amenities_rating'] as num)) / count,
      'service': reviews.fold<double>(0, (sum, r) => sum + (r['service_rating'] as num)) / count,
      'accuracy': reviews.fold<double>(0, (sum, r) => sum + (r['accuracy_rating'] as num)) / count,
      'count': count,
    };
  }
}
