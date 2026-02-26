import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  String? _error;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  String? get error => _error;

  /// Fetch notifications for current user
  Future<void> fetchNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _notifications = List<Map<String, dynamic>>.from(response);
      _unreadCount = _notifications.where((n) => n['is_read'] == false).length;
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch notifications';
      if (kDebugMode) print('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String id) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
      
      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
        _unreadCount = _notifications.where((n) => n['is_read'] == false).length;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error marking notification as read: $e');
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false); // Only update unread ones
      
      for (var n in _notifications) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error marking all as read: $e');
    }
  }
}
