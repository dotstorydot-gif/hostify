import 'package:flutter/material.dart';
import 'package:hostify/screens/admin_dashboard.dart';
import 'package:hostify/screens/landlord_dashboard.dart';
import 'package:hostify/screens/guest_main_navigation.dart';
import 'package:hostify/screens/guest_terms_screen.dart';
import 'package:provider/provider.dart';
import 'package:hostify/providers/app_state_provider.dart';
import 'package:hostify/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hostify/core/theme/app_colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // final AuthService _authService = AuthService(); // Removed: Handled by provider
  bool _isLogin = true;
  String _selectedRole = 'guest';
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      final provider = context.read<AppStateProvider>();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLogin ? l10n.loggingIn : l10n.creatingAccount),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      try {
        if (_isLogin) {
          await provider.signIn(_emailController.text.trim(), _passwordController.text.trim());
        } else {
          await provider.signUp(
            _emailController.text.trim(), 
            _passwordController.text.trim(), 
            _nameController.text.trim(),
            role: _selectedRole,
          );
        }
        
        if (mounted) {
          _checkAndEnableBiometrics();
          _navigateByRole();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.authFailed(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<AppStateProvider>().signInWithGoogle();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loginSuccessful('Google'))),
        );
        _checkAndEnableBiometrics();
        _navigateByRole();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  Future<void> _handleAppleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<AppStateProvider>().signInWithApple();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loginSuccessful('Apple'))),
        );
        _checkAndEnableBiometrics();
        _navigateByRole();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<AppStateProvider>().signInWithBiometrics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loginSuccessful('Biometric'))),
        );
        _navigateByRole();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.biometricAuthFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _checkAndEnableBiometrics() async {
    final l10n = AppLocalizations.of(context)!;
    // simplified prompt - in production, check if already enabled
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.enableBiometricLoginPrompt),
        content: Text(l10n.biometricLoginDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<AppStateProvider>().enableBiometrics();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.biometricEnabled)),
                  );
                }
              } catch (e) {
                 // ignore or show error
              }
            },
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }

  void _navigateByRole() {
    final provider = context.read<AppStateProvider>();
    // Prefer the role from the database if available (login), otherwise use selected role (signup)
    final role = provider.userRole ?? _selectedRole;

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    } else if (role == 'landlord') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LandlordDashboard()),
      );
    } else if (role == 'traveler') {
      // New users who want to book properties
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GuestMainNavigation(initialIndex: 0)),
      );
    } else if (role == 'guest') {
      // Verified guests with active bookings
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GuestMainNavigation()),
      );
    } else {
      // Default to guest terms for unknown roles
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GuestTermsScreen()),
      );
    }
  }

  /// Upload Avatar
  Future<String> uploadAvatar(XFile imageFile) async {
     final _currentUser = Supabase.instance.client.auth.currentUser;
     if (_currentUser == null) throw Exception('User not logged in');
     
     final fileExt = imageFile.path.split('.').last;
     final fileName = '${_currentUser.id}/${DateTime.now().toIso8601String()}.$fileExt';
     
     try {
       final bytes = await imageFile.readAsBytes();
       await Supabase.instance.client.storage.from('user-avatars').uploadBinary(
         fileName,
         bytes,
         fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
       );
       return fileName;
     } on StorageException catch (e) {
       if (e.statusCode == '409') { // Conflict, file already exists
         return fileName; // Assume it's the same file, return existing path
       }
       rethrow;
     } catch (e) {
       rethrow;
     }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minimal Logo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/hostifylogo.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 40),

                // Compact Auth Card
                Container(
                  padding: const EdgeInsets.all(24), // Reduced padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24), // More rounded
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              hintText: l10n.fullName,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              isDense: true,
                            ),
                            validator: (value) =>
                                value!.isEmpty ? l10n.required : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined, size: 20),
                            hintText: l10n.email,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            isDense: true,
                          ),
                          validator: (value) => !value!.contains('@')
                              ? l10n.invalidEmail
                              : null,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            hintText: l10n.password,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            isDense: true,
                          ),
                          validator: (value) => value!.length < 6
                              ? l10n.minChars(6)
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // Role Selector (Modern Cards)
                        Text(
                          l10n.joinAs,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: buildRoleCard('guest', Icons.person_outline, l10n.guest)),
                            const SizedBox(width: 8),
                            Expanded(child: buildRoleCard('traveler', Icons.beach_access_outlined, l10n.traveler)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: buildRoleCard('landlord', Icons.home_work_outlined, l10n.landlord)),
                            const SizedBox(width: 8),
                            Expanded(child: buildRoleCard('admin', Icons.admin_panel_settings_outlined, l10n.admin)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.yellow,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _isLogin ? l10n.signIn : l10n.signUp,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        
                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                l10n.or,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        
                        const SizedBox(height: 20),

                        // Social Login (Compact)
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _handleGoogleLogin,
                                    icon: const Icon(Icons.g_mobiledata, size: 28),
                                    label: Text(l10n.continueWithGoogle),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(color: Colors.grey[300]!),
                                      foregroundColor: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _handleAppleLogin,
                                    icon: const Icon(Icons.apple, size: 20),
                                    label: const Text('Apple'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      side: BorderSide(color: Colors.grey[300]!),
                                      foregroundColor: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _handleBiometricLogin,
                                icon: const Icon(Icons.fingerprint, size: 22),
                                label: Text(
                                  l10n.biometricLogin,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                                  foregroundColor: Colors.black,
                                  backgroundColor: Colors.grey[50],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                
                // Toggle Auth Mode
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      text: _isLogin ? "${l10n.dontHaveAccount} " : "${l10n.alreadyHaveAccount} ",
                      style: const TextStyle(color: Colors.black87),
                      children: [
                        TextSpan(
                          text: _isLogin ? l10n.signUp : l10n.signIn,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Skip / Continue as Guest
              TextButton(
                onPressed: () {
                  // Navigate to Guest Main Navigation without signing in
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GuestMainNavigation(initialIndex: 0),
                    ),
                  );
                },
                child: Text(
                  l10n.continueAsGuest,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.black,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
        ],
      ),
    ),),),
    );
  }
  Widget buildRoleCard(String role, IconData icon, String label) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.yellow : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.yellow : Colors.grey[200]!,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.yellow.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
