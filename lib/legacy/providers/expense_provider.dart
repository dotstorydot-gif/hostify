import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _expenses = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get expenses => _expenses;

  // Expense categories
  static const List<String> categories = [
    'cleaning',
    'maintenance',
    'problem',
    'enhancement',
    'plumbing',
    'electricity',
    'door',
    'floor',
    'wall',
    'decoration',
    'room',
    'other',
  ];

  Future<void> fetchExpenses({
    String? propertyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var query = _supabase
          .from('expenses')
          .select('*, property:properties(name)');

      if (propertyId != null) {
        query = query.eq('property_id', propertyId);
      }

      if (startDate != null) {
        query = query.gte('expense_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('expense_date', endDate.toIso8601String());
      }

      final response = await query.order('expense_date', ascending: false);
      _expenses = List<Map<String, dynamic>>.from(response);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch expenses: $e';
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) print('Error fetching expenses: $e');
    }
  }

  Future<void> addExpense({
    required String propertyId,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? description,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _supabase.from('expenses').insert({
        'property_id': propertyId,
        'amount': amount,
        'category': category,
        'description': description,
        'expense_date': expenseDate.toIso8601String().split('T')[0],
        'created_by': user.id,
      });

      // Refresh expenses list
      await fetchExpenses();
    } catch (e) {
      _error = 'Failed to add expense: $e';
      notifyListeners();
      if (kDebugMode) print('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await _supabase.from('expenses').delete().eq('id', expenseId);
      
      // Remove from local list
      _expenses.removeWhere((expense) => expense['id'] == expenseId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete expense: $e';
      notifyListeners();
      if (kDebugMode) print('Error deleting expense: $e');
      rethrow;
    }
  }

  Future<void> updatePropertyManagementFee({
    required String propertyId,
    required double feePercentage,
  }) async {
    try {
      // Upsert the management fee
      await _supabase.from('property_settings').upsert({
        'property_id': propertyId,
        'management_fee_percentage': feePercentage,
      });
    } catch (e) {
      _error = 'Failed to update management fee: $e';
      notifyListeners();
      if (kDebugMode) print('Error updating management fee: $e');
      rethrow;
    }
  }

  Future<double?> getPropertyManagementFee(String propertyId) async {
    try {
      final response = await _supabase
          .from('property_settings')
          .select('management_fee_percentage')
          .eq('property_id', propertyId)
          .maybeSingle();

      if (response != null) {
        return (response['management_fee_percentage'] as num).toDouble();
      }
      return 15.0; // Default 15% (Aligned with Analytics)
    } catch (e) {
      if (kDebugMode) print('Error fetching management fee: $e');
      return 15.0; // Default on error
    }
  }
}
