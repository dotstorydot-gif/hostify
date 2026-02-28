import "package:flutter/material.dart";
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceRequestProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<Map<String, dynamic>> _myRequests = [];
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> get myRequests => _myRequests;
  List<Map<String, dynamic>> get requests => _myRequests; // Alias for backwards compatibility
  List<Map<String, dynamic>> get allRequests => _allRequests;

  /// Submit a new service request
  Future<void> submitRequest({
    required String bookingId,
    required String guestId,
    required String propertyId,
    required String category,
    required String serviceType,
    String? details,
    String? preferredTime,
  }) async {
    try {
      _setLoading(true);

      await _supabase.from('service_requests').insert({
        'booking_id': bookingId,
        'guest_id': guestId,
        'property_id': propertyId,
        'category': category.toLowerCase(), // 'concierge', 'excursions', 'room_service'
        'service_type': serviceType,
        'details': details,
        'preferred_time': preferredTime,
        'status': 'pending',
      });

      // Refresh requests list
      await loadMyRequests(guestId);
      
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Load requests for a specific guest
  Future<void> loadMyRequests(String guestId) async {
    try {
      _setLoading(true);
      
      final response = await _supabase
          .from('service_requests')
          .select('''
            *,
            properties:property_id (name)
          ''')
          .eq('guest_id', guestId)
          .order('created_at', ascending: false);

      _myRequests = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Alias for loadMyRequests (backwards compatibility)
  Future<void> fetchUserRequests(String userId) => loadMyRequests(userId);

  /// Admin: Fetch all service requests
  Future<void> fetchAllRequests() async {
    _setLoading(true);
    _clearError();
    try {
      final response = await _supabase
          .from('service_requests')
          .select('*, user_profiles(full_name), properties(name)')
          .order('created_at', ascending: false);
      
      _allRequests = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch all requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Admin: Update service request status
  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      await _supabase
          .from('service_requests')
          .update({'status': status})
          .eq('id', requestId);
      
      // Update local state
      final index = _allRequests.indexWhere((r) => r['id'] == requestId);
      if (index != -1) {
        _allRequests[index]['status'] = status;
      }
      
      final userIndex = _myRequests.indexWhere((r) => r['id'] == requestId);
      if (userIndex != -1) {
        _myRequests[userIndex]['status'] = status;
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to update request status: $e');
      rethrow;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _error = null;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
