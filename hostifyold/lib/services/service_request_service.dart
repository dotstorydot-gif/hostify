import 'package:supabase_flutter/supabase_flutter.dart';

/// Service Request Service for guest services management
class ServiceRequestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create service request
  Future<String> createServiceRequest({
    required String bookingId,
    required String propertyId,
    required String category,
    required String serviceType,
    String? details,
    String? preferredTime,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await _supabase.from('service_requests').insert({
      'booking_id': bookingId,
      'guest_id': userId,
      'property_id': propertyId,
      'category': category,
      'service_type': serviceType,
      'details': details,
      'preferred_time': preferredTime,
      'status': 'pending',
    }).select().single();

    return response['id'];
  }

  /// Get guest service requests
  Future<List<Map<String, dynamic>>> getGuestServiceRequests() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('service_requests')
        .select('*, properties(name), bookings(room_number, unit_name)')
        .eq('guest_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get property service requests (for landlords/admins)
  Future<List<Map<String, dynamic>>> getPropertyServiceRequests(
String propertyId,
  ) async {
    final response = await _supabase
        .from('service_requests')
        .select('*, user_profiles(full_name, phone), bookings(room_number, unit_name)')
        .eq('property_id', propertyId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get service requests by status
  Future<List<Map<String, dynamic>>> getServiceRequestsByStatus(
    String status,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('service_requests')
        .select('*, properties(name), bookings(room_number, unit_name)')
        .eq('guest_id', userId)
        .eq('status', status)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Update service request status
  Future<void> updateServiceRequestStatus(
    String requestId,
    String status, {
    String? notes,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (notes != null) {
      updates['notes'] = notes;
    }

    if (status == 'completed') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    await _supabase.from('service_requests').update(updates).eq('id', requestId);
  }

  /// Cancel service request
  Future<void> cancelServiceRequest(String requestId) async {
    await updateServiceRequestStatus(requestId, 'cancelled');
  }

  /// Get pending requests count for property
  Future<int> getPendingRequestsCount(String propertyId) async {
    final response = await _supabase
        .from('service_requests')
        .count()
        .eq('property_id', propertyId)
        .eq('status', 'pending');

    return response;
  }
}
