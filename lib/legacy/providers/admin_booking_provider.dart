import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminBookingProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;
  
  // Cache of bookings mapped by date (for calendar)
  Map<DateTime, List<Map<String, dynamic>>> _bookingsMap = {};
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<DateTime, List<Map<String, dynamic>>> get bookings => _bookingsMap;

  Future<void> fetchBookingsForLandlord(String landlordId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Get Property IDs for this landlord (Owned + Managed) via RPC
      final properties = await _supabase
          .rpc('get_my_properties', params: {'p_user_id': landlordId});
      
      final propertyIds = (properties as List).map((p) => p['id'] as String).toList();
      
      if (propertyIds.isEmpty) {
        _bookingsMap = {};
        return;
      }

      // 2. Fetch Bookings for these properties
      // Fetching all bookings for now. For production, fetch by month range.
      final response = await _supabase
          .from('bookings')
          .select('''
            *,
            property:properties(name, price_per_night),
            guest:guest_id(full_name, email, phone)
          ''')
          .inFilter('property_id', propertyIds)
          .order('check_in', ascending: true);

      // 3. Process into Map<DateTime, List>
      _bookingsMap = {};
      
      for (var booking in response) {
        final checkIn = DateTime.parse(booking['check_in']);
        final checkOut = DateTime.parse(booking['check_out']);
        
        // Add entry for every day of the booking
        int days = checkOut.difference(checkIn).inDays;
        for (int i = 0; i < days; i++) {
          final date = checkIn.add(Duration(days: i));
          final key = DateTime.utc(date.year, date.month, date.day);
          
          if (_bookingsMap[key] == null) {
            _bookingsMap[key] = [];
          }
          
          _bookingsMap[key]!.add({
            'id': booking['id'],
            'property_id': booking['property_id'],
            'property': booking['property']?['name'] ?? 'Unknown Property',
            'guest': booking['guest']?['full_name'] ?? 'External Guest',
            'email': booking['guest']?['email'] ?? '',
            'phone': booking['guest']?['phone'] ?? '',
            'checkIn': checkIn,
            'checkOut': checkOut,
            'status': booking['status'],
            'total': (booking['total_price'] != null && booking['total_price'] > 0) 
                ? (booking['total_price'] as num).toDouble() 
                : 150.0, // Fallback if total_price is null
            'source': booking['booking_source'],
            'external_id': booking['external_booking_id'],
          });
        }
      }

    } catch (e) {
      _error = 'Failed to fetch bookings: $e';
      if (kDebugMode) print('Error fetching admin bookings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      await _supabase
          .from('bookings')
          .update({'status': newStatus})
          .eq('id', bookingId);
      
      // Refresh local state if needed, or caller handles refresh
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await fetchBookingsForLandlord(userId);
      }
    } catch (e) {
      if (kDebugMode) print('Error updating booking status: $e');
      rethrow;
    }
  }
}
