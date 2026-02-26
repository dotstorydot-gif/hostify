import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Authentication Service using Supabase
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // iOS needs the iOS Client ID. Android uses SHA-1 and doesn't need this.
    clientId: defaultTargetPlatform == TargetPlatform.iOS
        ? '232497998897-inp16shguj4qcub38qaau64ihgao2d98.apps.googleusercontent.com'
        : null,
    // This MUST be the Web Client ID for Supabase to verify the token
    serverClientId: '232497998897-ck9l1k69mq4jn0cmf1e4tkkf48rg7ekd.apps.googleusercontent.com',
  );
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    // Update auto-created user profile
    if (response.user != null) {
      await _supabase.from('user_profiles').update({
        'full_name': fullName,
      }).eq('id', response.user!.id);
    }

    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }

  /// Sign In with Google
  Future<AuthResponse> signInWithGoogle() async {
    // Web implementation (simplified)
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(OAuthProvider.google);
      throw Exception('Redirecting to Google for Web Login...');
    }

    // Native implementation (iOS/Android/macOS)
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In canceled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No ID Token found. Please ensure the Web Client ID is correctly set in the GoogleSignIn constructor.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      // Auto-create profile if needed
      await _ensureUserProfile(response.user, googleUser.displayName);
      
      return response;
    } catch (e) {
      // Handle Google Sign-In specific errors if possible
      final errorStr = e.toString();
      if (errorStr.contains('GoogleSignInException')) {
        throw Exception('Google Sign-In Error: $errorStr');
      }
      throw Exception('Google Sign-In failed: $e');
    }
  }

  /// Sign In with Apple
  Future<AuthResponse> signInWithApple() async {
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(OAuthProvider.apple);
      throw Exception('Redirecting to Apple for Web Login...');
    }

    try {
      final rawNonce = _supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw Exception('No Identity Token found from Apple Sign-In.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      // Auto-create profile if needed
      String? fullName;
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        fullName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
      }
      
      await _ensureUserProfile(response.user, fullName);

      return response;
    } catch (e) {
      throw Exception('Apple Sign-In failed: $e');
    }
  }

  /// Delete Account
  /// Note: Full deletion of the Auth user usually requires a service role or edge function.
  /// This deletes user-specific data and signs out, fulfilling the App Store requirement to initiate deletion.
  Future<void> deleteAccount() async {
    final userId = currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Delete user profile and roles (Cascade might handle this if configured in DB)
      await _supabase.from('user_profiles').delete().eq('id', userId);
      await _supabase.from('user_roles').delete().eq('user_id', userId);
      
      // 2. Sign out
      await signOut();
      
      // 3. Clear local biometric storage
      await _secureStorage.delete(key: 'supabase_refresh_token');
      
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  /// Sign In with Biometrics (FaceID / TouchID)
  /// Checks valid local biometric -> retrieves Secure Token -> Signs in
  Future<void> signInWithBiometrics() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    if (!canCheckBiometrics) throw Exception('Biometrics not available on this device');

    bool authenticated = await _localAuth.authenticate(
      localizedReason: 'Please authenticate to login',
      options: const AuthenticationOptions(biometricOnly: true),
    );

    if (authenticated) {
      // Retrieve stored refresh token
      final refreshToken = await _secureStorage.read(key: 'supabase_refresh_token');
      if (refreshToken == null) {
        throw Exception('No credentials stored. Please login manually first.');
      }

      // Exchange refresh token for new session
      await _supabase.auth.setSession(refreshToken);
    } else {
      throw Exception('Biometric authentication failed');
    }
  }

  /// Enable Biometric Login (Store credentials)
  Future<void> enableBiometrics() async {
    final session = _supabase.auth.currentSession;
    if (session == null || session.refreshToken == null) {
      throw Exception('No active session to store');
    }

    // Authenticate first to verify intent
    bool authenticated = await _localAuth.authenticate(
      localizedReason: 'Authenticate to enable biometric login',
    );

    if (authenticated) {
      await _secureStorage.write(key: 'supabase_refresh_token', value: session.refreshToken);
    }
  }

  /// Helper: Ensure profile exists
  Future<void> _ensureUserProfile(User? user, String? name) async {
    if (user == null) return;
    
    final existing = await _supabase.from('user_profiles').select().eq('id', user.id).maybeSingle();
    if (existing == null) {
      await _supabase.from('user_profiles').insert({
        'id': user.id,
        'email': user.email,
        'full_name': name ?? 'Google User',
      });
    }
  }

  /// Add role to user
  Future<void> addUserRole(String role) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await _supabase.from('user_roles').insert({
      'user_id': userId,
      'role': role,
      'is_active': true,
    });
  }

  /// Get user roles
  Future<List<String>> getUserRoles() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .eq('is_active', true);

    return (response as List).map((r) => r['role'] as String).toList();
  }

  /// Check if user has specific role
  Future<bool> hasRole(String role) async {
    final roles = await getUserRoles();
    return roles.contains(role);
  }

  /// Update user profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (profilePhotoUrl != null) updates['profile_photo_url'] = profilePhotoUrl;

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('user_profiles').update(updates).eq('id', userId);
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .single();

    return response;
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
