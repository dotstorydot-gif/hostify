import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for managing bookings state
class BookingProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = false;
  String? _error;
  
  List<Map<String, dynamic>> get bookings => _bookings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasBookings => _bookings.isNotEmpty;
  
  /// Load user's bookings
  Future<void> loadBookings({String? userId}) async {
    _setLoading(true);
    _clearError();
    
    try {
      final query = _supabase
          .from('bookings')
          .select('*, properties(*), user_profiles(*)');
      
      if (userId != null) {
        query.eq('guest_id', userId);
      }
      
      final response = await query.order('created_at', ascending: false);
      _bookings = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load bookings: $e');
      if (kDebugMode) {
        print('Error loading bookings: $e');
      }
    } finally {
      _setLoading(false);
    }
  }
  
  /// Create new booking
  Future<String> createBooking({
    required String userId,
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required double totalPrice,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final nights = checkOut.difference(checkIn).inDays;
      
      final bookingData = {
        'guest_id': userId,
        'property_id': propertyId,
        'check_in': checkIn.toIso8601String(),
        'check_out': checkOut.toIso8601String(),
        'guests': guests,
        'nights': nights,
        'total_price': totalPrice,
        'status': 'pending', 
        'booking_source': 'hostify',
      };

      final response = await _supabase
          .from('bookings')
          .insert(bookingData)
          .select()
          .single();
      
      _bookings = [response, ..._bookings];
      notifyListeners();
      return response['id'];
    } catch (e) {
      _setError('Failed to create booking: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _supabase
          .from('bookings')
          .update({'status': status})
          .eq('id', bookingId);
      
      final index = _bookings.indexWhere((b) => b['id'] == bookingId);
      if (index != -1) {
        _bookings[index]['status'] = status;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to update booking: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    await updateBookingStatus(bookingId, 'cancelled');
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
  }
  
  void clearBookings() {
    _bookings = [];
    notifyListeners();
  }
}
