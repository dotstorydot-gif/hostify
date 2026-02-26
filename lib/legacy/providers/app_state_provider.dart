import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hostify/legacy/screens/guest_dashboard.dart';
import 'package:hostify/legacy/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/services/auth_service.dart';
import 'package:hostify/legacy/services/push_notification_service.dart';
import 'package:hostify/legacy/core/config/supabase_config.dart';

/// Global app state provider managing user authentication and profile
class AppStateProvider extends ChangeNotifier {
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  String? _userRole;
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  String? _error;
  
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  
  String? get userRole => _userRole ?? _userProfile?['role']; // Fallback for backward compatibility
  String? get userName => _userProfile?['full_name'];
  String? get userEmail => _currentUser?.email;
  String? get userAvatar => _userProfile?['avatar_url'];
  
  final SupabaseClient _supabase = Supabase.instance.client;
  
  AppStateProvider() {
    _initializeAuth();
  }
  
  /// Initialize authentication and listen to auth state changes
  void _initializeAuth() {
    _currentUser = _supabase.auth.currentUser;
    if (_currentUser != null) {
      _loadUserProfile();
      loadFavorites();
      PushNotificationService.initialize();
    }
    
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      if (event == AuthChangeEvent.signedIn) {
        _currentUser = session?.user;
        _loadUserProfile();
        loadFavorites();
        PushNotificationService.initialize();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _userProfile = null;
        _userRole = null; // Fix: Clear role on sign out
        notifyListeners();
      }
    });
  }
  
  /// Load user profile from database
  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;
    
    // Reset role before loading to prevent stale state
    _userRole = null;

    try {
      // Fetch profile using correct primary key 'id'
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', _currentUser!.id)
          .maybeSingle();
      
      _userProfile = response;

      // Fetch user role using AuthService
      final roles = await _authService.getUserRoles();
      if (roles.isNotEmpty) {
        _userRole = roles.first;
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user profile: $e');
      }
      _setError('Failed to load profile');
    }
  }
  
  /// Update user profile in database
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      await _supabase
          .from('user_profiles')
          .update(updates)
          .eq('id', _currentUser!.id);
      
      _userProfile = {...?_userProfile, ...updates};
      notifyListeners();
    } catch (e) {
      _setError('Failed to update profile: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Sign In with Email & Password
  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signIn(email: email, password: password);
      // _initializeAuth will handle the update via listener
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign Up with Email & Password
  Future<void> signUp(String email, String password, String fullName, {String role = 'guest'}) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signUp(email: email, password: password, fullName: fullName);
      
      // Assign role (if auto-confirm is enabled or session exists)
      if (_supabase.auth.currentSession != null) {
        await _authService.addUserRole(role);
      }
      
      // _initializeAuth will handle the update via listener
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign In with Google
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign In with Apple
  Future<void> signInWithApple() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithApple();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign In with Biometrics
  Future<void> signInWithBiometrics() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithBiometrics();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Enable Biometrics
  Future<void> enableBiometrics() async {
    try {
      await _authService.enableBiometrics();
    } catch (e) {
       _setError(e.toString());
       rethrow;
    }
  }

  /// Upload Avatar
  Future<String> uploadAvatar(XFile imageFile) async {
     if (_currentUser == null) throw Exception('User not logged in');
     
     final fileExt = imageFile.path.split('.').last;
     final fileName = 'avatars/${_currentUser!.id}_\${DateTime.now().millisecondsSinceEpoch}.\$fileExt';
     
     try {
       final bytes = await imageFile.readAsBytes();
       await _supabase.storage.from('user-avatars').uploadBinary(
         fileName,
         bytes,
         fileOptions: FileOptions(
           contentType: 'image/\$fileExt',
           cacheControl: '3600',
           upsert: true,
         ),
       );
       
       final imageUrl = _supabase.storage.from('user-avatars').getPublicUrl(fileName);
       return imageUrl;
     } catch (e) {
       throw Exception('Failed to upload image: $e');
     }
  }

  /// Update Password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(
        password: newPassword,
      ));
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signOut();
      _currentUser = null;
      _userProfile = null;
      _userRole = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to sign out: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.deleteAccount();
      _currentUser = null;
      _userProfile = null;
      _userRole = null;
      _favoritePropertyIds.clear();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete account: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Favorites Management
  List<String> _favoritePropertyIds = [];
  List<String> get favoritePropertyIds => _favoritePropertyIds;

  Future<void> loadFavorites() async {
    if (_currentUser == null) return;
    try {
      final response = await _supabase
          .from('favorites')
          .select('property_id')
          .eq('user_id', _currentUser!.id);
      
      _favoritePropertyIds = (response as List).map((e) => e['property_id'] as String).toList();
      notifyListeners();
    } catch (e) {
      // If table doesn't exist or error, just log silently or handle
      if (kDebugMode) print('Error loading favorites: $e');
    }
  }

  bool isFavorite(String propertyId) {
    return _favoritePropertyIds.contains(propertyId);
  }

  Future<void> toggleFavorite(String propertyId) async {
    if (_currentUser == null) return;
    
    // Optimistic update
    final isFav = _favoritePropertyIds.contains(propertyId);
    if (isFav) {
      _favoritePropertyIds.remove(propertyId);
    } else {
      _favoritePropertyIds.add(propertyId);
    }
    notifyListeners();

    try {
      if (isFav) {
        await _supabase
            .from('favorites')
            .delete()
            .match({'user_id': _currentUser!.id, 'property_id': propertyId});
      } else {
        await _supabase
            .from('favorites')
            .insert({'user_id': _currentUser!.id, 'property_id': propertyId});
      }
    } catch (e) {
      // Revert on error
      if (isFav) {
        _favoritePropertyIds.add(propertyId);
      } else {
        _favoritePropertyIds.remove(propertyId);
      }
      notifyListeners();
      _setError('Failed to update favorite: $e');
    }
  }
  
  /// Refresh user data from server
  Future<void> refresh() async {
    if (_currentUser == null) return;
    await _loadUserProfile();
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
}
