import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAnalyticsProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _analyticsData;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get data => _analyticsData;

  DateTime? _startDate;
  DateTime? _endDate;
  String? _propertyId;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get propertyId => _propertyId;

  /// Fetch analytics. If arguments are provided, they update the filter.
  /// If arguments are null, previous filter values are used.
  Future<void> fetchAnalytics({DateTime? startDate, DateTime? endDate, String? propertyId}) async {
    _isLoading = true;
    _error = null;
    
    // Update state only if arguments are provided (allow null propertyId to explicitly clear if we wanted, 
    // but here we treat 'passed null' as 'keep existing' for date, 
    // and for propertyId usually we pass it explicitly. 
    // However, to support 'switching to All', the caller usually passes null? 
    // No, usually caller passes a value. 
    // To support "Keep existing if not passed", we use ?? _propertyId.
    // But if we WANT to clear property, we need a way.
    // The Dashboard passes `_selectedPropertyId` which is `null` for "All".
    // So if Dashboard calls `fetchAnalytics(propertyId: null)`, does it mean "Clear" or "Keep"?
    // In Dashboard, `_selectedPropertyId` is `null` for All.
    // So if we pass `null`, we want `null`.
    // But `AnalyticsScreen` calls `fetchAnalytics()` (no args).
    // So we need to distinguish "No Argument" from "Argument is Null".
    // Dart optional named parameters are null if omitted.
    // We cannot detect difference easily without a wrapper or flag.
    // 
    // Strategy: 
    // IF called from Dashboard (args present), update state.
    // IF called from AnalyticsScreen (no args), use state.
    // 
    // But if Dashboard passes `null` for propertyId (All Properties), we must update `_propertyId` to `null`.
    // 
    // I will implicitly assume that if `startDate` AND `endDate` are null, we are "Taking Existing".
    // But Dashboard might call with `startDate` set and `propertyId` null.
    // 
    // Let's rely on the fact that Dashboard ALWAYS passes `startDate` and `endDate` when it calls.
    // So if `startDate` is provided, we update ALL fields (including propertyId).
    // If `startDate` is NOT provided, we use EXISTING fields.
    
    if (startDate != null && endDate != null) {
      _startDate = startDate;
      _endDate = endDate;
      _propertyId = propertyId; // Accept null here as "All"
    }
    
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Get Landlord ID (either from metadata or user ID)
      final landlordId = user.id; 

      final response = await _supabase.rpc(
        'get_landlord_analytics_with_expenses',
        params: {
          'p_landlord_id': landlordId,
          'p_start_date': _startDate?.toIso8601String(),
          'p_end_date': _endDate?.toIso8601String(),
          'p_property_id': _propertyId,
        },
      );

      _analyticsData = Map<String, dynamic>.from(response as Map);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Getters for specific metrics
  double get totalRevenue => (_analyticsData?['total_revenue'] ?? 0).toDouble();
  int get totalBookings => (_analyticsData?['total_bookings'] ?? 0).toInt();
  double get occupancyRate => (_analyticsData?['occupancy_rate'] ?? 0).toDouble();
  double get avgRating => (_analyticsData?['avg_rating'] ?? 0).toDouble();
  
  Map<String, dynamic> get bookingsByNationality => 
      Map<String, dynamic>.from(_analyticsData?['bookings_by_nationality'] ?? {});
      
  Map<String, dynamic> get bookingsByUnit => 
      Map<String, dynamic>.from(_analyticsData?['bookings_by_unit'] ?? {});
      
  Map<String, dynamic> get bookingsByGuestType => 
      Map<String, dynamic>.from(_analyticsData?['bookings_by_guest_type'] ?? {});

  // New getters for enhanced analytics
  int get appBookings => (bookingsBySource['app_bookings'] ?? 0).toInt();
  int get icalBookings => (bookingsBySource['ical_bookings'] ?? 0).toInt();
  
  String? get mostBookedProperty => _analyticsData?['most_booked_property'] as String?;
  int get mostBookedCount => (_analyticsData?['most_booked_count'] ?? 0).toInt();
  
  Map<String, dynamic> get propertyRatings => 
      Map<String, dynamic>.from(_analyticsData?['property_ratings'] ?? {});
      
  Map<String, dynamic> get bookingsBySource => 
      Map<String, dynamic>.from(_analyticsData?['bookings_by_source'] ?? {});

  // Expense and Revenue getters
  int get totalBookedNights => (_analyticsData?['total_booked_nights'] ?? 0).toInt();
  double get totalExpenses => (_analyticsData?['total_expenses'] ?? 0).toDouble();
  double get managementFees => (_analyticsData?['total_management_fees'] ?? 0).toDouble();
  double get landlordShare => (_analyticsData?['landlord_share'] ?? 0).toDouble();
  
  Map<String, dynamic> get expensesByCategory => 
      Map<String, dynamic>.from(_analyticsData?['expenses_by_category'] ?? {});
  
  Map<String, dynamic> get expensesByProperty => 
      Map<String, dynamic>.from(_analyticsData?['expenses_by_property'] ?? {});
      
  Map<String, dynamic> get propertyRevenues => 
      Map<String, dynamic>.from(_analyticsData?['property_revenues'] ?? {});
}
