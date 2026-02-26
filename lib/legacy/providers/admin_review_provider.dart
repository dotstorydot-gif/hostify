import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReviewProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _properties = [];
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get reviews => _reviews;
  List<Map<String, dynamic>> get properties => _properties;
  
  /// Fetch all reviews for admin
  Future<void> fetchAllReviews() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Fetch all reviews with property details
      final response = await _supabase
          .from('review-images')
          .select('''
            *,
            properties (id, name),
            review_images (image_url)
          ''')
          .order('created_at', ascending: false);
      
      _reviews = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch reviews: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Fetch all properties for filter dropdown
  Future<void> fetchProperties() async {
    try {
      final response = await _supabase
          .from('property-images')
          .select('id, name')
          .order('name');
      
      _properties = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch properties: $e';
      notifyListeners();
    }
  }
  
  /// Get reviews for specific property
  List<Map<String, dynamic>> getReviewsForProperty(String? propertyId) {
    if (propertyId == null || propertyId == 'all') {
      return _reviews;
    }
    return _reviews.where((r) => r['property_id'] == propertyId).toList();
  }
  
  /// Update review status (approve/reject)
  Future<void> updateReviewStatus(String reviewId, String status) async {
    try {
      await _supabase
          .from('review-images')
          .update({'status': status})
          .eq('id', reviewId);
      
      // Update local state
      final index = _reviews.indexWhere((r) => r['id'] == reviewId);
      if (index != -1) {
        _reviews[index]['status'] = status;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update review: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Delete review
  Future<void> deleteReview(String reviewId) async {
    try {
      await _supabase
          .from('review-images')
          .delete()
          .eq('id', reviewId);
      
      // Update local state
      _reviews.removeWhere((r) => r['id'] == reviewId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete review: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Get average rating for property
  double getAverageRating(String? propertyId) {
    final propertyReviews = getReviewsForProperty(propertyId);
    if (propertyReviews.isEmpty) return 0.0;
    
    final sum = propertyReviews.fold<double>(
      0.0,
      (sum, review) => sum + ((review['overall_rating'] ?? review['rating']) as num).toDouble(),
    );
    
    return sum / propertyReviews.length;
  }
}
