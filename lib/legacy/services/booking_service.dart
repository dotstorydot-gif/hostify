import 'package:hostify/legacy/services/icalendar_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Booking Service for reservation management
class BookingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create new booking
  Future<String> createBooking({
    required String propertyId,
    required String unitName,
    required String roomNumber,
    required DateTime checkIn,
    required DateTime checkOut,
    required int nights,
    required double totalPrice,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await _supabase.from('bookings').insert({
      'property_id': propertyId,
      'guest_id': userId,
      'unit_name': unitName,
      'room_number': roomNumber,
      'check_in': checkIn.toIso8601String(),
      'check_out': checkOut.toIso8601String(),
      'total_price': totalPrice,
      'status': 'pending',
      'booking_source': 'hostify',
    }).select().single();

    return response['id'];
  }

  /// Get user bookings
  Future<List<Map<String, dynamic>>> getUserBookings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('bookings')
        .select('*, properties(*)')
        .eq('guest_id', userId)
        .order('check_in', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get property bookings (for landlords)
  Future<List<Map<String, dynamic>>> getPropertyBookings(String propertyId) async {
    final response = await _supabase
        .from('bookings')
        .select('*, user_profiles(full_name, email, phone)')
        .eq('property_id', propertyId)
        .order('check_in', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get pending bookings (for admin)
  Future<List<Map<String, dynamic>>> getPendingBookings() async {
    final response = await _supabase
        .from('bookings')
        .select('*, properties(*), user_profiles(full_name, email, phone)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _supabase.from('bookings').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    await updateBookingStatus(bookingId, 'cancelled');
  }

  /// Check availability
  Future<bool> checkAvailability({
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    // 1. Check strict database availability (fast)
    final dbResponse = await _supabase
        .from('bookings')
        .select('id')
        .eq('property_id', propertyId)
        .filter('status', 'in', ['confirmed', 'active'])
        .or('check_in.lte.${checkOut.toIso8601String()},check_out.gte.${checkIn.toIso8601String()}');
    
    if ((dbResponse as List).isNotEmpty) return false;

    // 2. Check iCal availability (comprehensive)
    final iCalService = ICalendarSyncService();
    return await iCalService.isDateRangeAvailable(propertyId, checkIn, checkOut);
  }

  /// Get current booking for guest
  Future<Map<String, dynamic>?> getCurrentBooking() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final today = DateTime.now();
    
    final response = await _supabase
        .from('bookings')
        .select('*, properties(*)')
        .eq('guest_id', userId)
        .filter('status', 'in', ['confirmed', 'active'])
        .lte('check_in', today.toIso8601String())
        .gte('check_out', today.toIso8601String())
        .maybeSingle();

    return response;
  }
}
