import "package:flutter/material.dart";
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _reviews = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get reviews => _reviews;

  /// Fetch reviews for a specific property
  Future<void> fetchPropertyReviews(String propertyId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            *,
            review_images (image_url)
          ''')
          .eq('property_id', propertyId)
          .eq('status', 'published')
          .order('created_at', ascending: false);
          
      _reviews = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch reviews: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> submitReview({
    required String propertyId,
    required String bookingId,
    required String userId,
    required String userName,
    required double overallRating,
    required double cleanlinessRating,
    required double locationRating,
    required double valueRating,
    required double amenitiesRating,
    required String reviewText,
    List<File>? photos,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // 1. Insert Review to 'review-images' table
      final reviewResponse = await _supabase.from('reviews').insert({
        'property_id': propertyId,
        'booking_id': bookingId,
        'guest_id': userId,
        'guest_name': userName,
        'overall_rating': overallRating,
        'cleanliness_rating': cleanlinessRating,
        'location_rating': locationRating,
        'value_rating': valueRating,
        'amenities_rating': amenitiesRating,
        // Default other ratings to overall if not provided (simplified)
        'service_rating': overallRating,
        'accuracy_rating': overallRating,
        'review_text': reviewText,
        'status': 'published',
      }).select().single();

      final reviewId = reviewResponse['id'] as String;

      // 2. Upload Photos & Insert to 'review_images' table
      if (photos != null && photos.isNotEmpty) {
        for (final photo in photos) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${photo.path.split('/').last}';
          final path = '$reviewId/$fileName';

          // Upload to Supabase Storage
          await _supabase.storage.from('reviews').upload(path, photo);
          
          final imageUrl = _supabase.storage.from('reviews').getPublicUrl(path);

          // Insert image record
          await _supabase.from('review_images').insert({
            'review_id': reviewId,
            'image_url': imageUrl,
          });
        }
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to submit review: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
