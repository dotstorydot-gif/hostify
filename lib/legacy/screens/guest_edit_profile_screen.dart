import "package:flutter/material.dart";
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/widgets/global_error_dialog.dart';
import 'package:hostify/legacy/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;

class GuestEditProfileScreen extends StatefulWidget {
  const GuestEditProfileScreen({super.key});

  @override
  State<GuestEditProfileScreen> createState() => _GuestEditProfileScreenState();
}

class _GuestEditProfileScreenState extends State<GuestEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  XFile? _profileImage;
  bool _isLoading = false;
  final bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedNationality = 'Egyptian';
  
  // Common nationalities list
  final List<String> _nationalities = [
    'Egyptian', 'Saudi Arabian', 'Emirati', 'Kuwaiti', 'Qatari', 'Bahraini', 'Omani',
    'Jordanian', 'Lebanese', 'Syrian', 'Iraqi', 'Palestinian', 'Yemeni', 'Libyan',
    'Tunisian', 'Algerian', 'Moroccan', 'Sudanese', 'American', 'British', 'Canadian',
    'Australian', 'German', 'French', 'Italian', 'Spanish', 'Dutch', 'Belgian',
    'Swiss', 'Austrian', 'Swedish', 'Norwegian', 'Danish', 'Finnish', 'Russian',
    'Turkish', 'Iranian', 'Pakistani', 'Indian', 'Bangladeshi', 'Indonesian',
    'Malaysian', 'Singaporean', 'Filipino', 'Thai', 'Vietnamese', 'Chinese',
    'Japanese', 'Korean', 'Brazilian', 'Argentine', 'Mexican', 'Colombian',
    'Chilean', 'Peruvian', 'South African', 'Nigerian', 'Kenyan', 'Ethiopian', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final provider = context.read<AppStateProvider>();
    final profile = provider.userProfile;
    if (profile != null) {
      setState(() {
        _nameController.text = profile['full_name'] ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _emailController.text = provider.userEmail ?? '';
        
        final nationality = profile['nationality'];
        if (nationality != null && _nationalities.contains(nationality)) {
          _selectedNationality = nationality;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _profileImage = image;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = context.read<AppStateProvider>();

    try {
      String? avatarUrl;
      // 1. Upload Avatar if changed
      if (_profileImage != null) {
         avatarUrl = await provider.uploadAvatar(_profileImage!);
      }

      // 2. Update Password if set
      if (_newPasswordController.text.isNotEmpty) {
        // Ideally verify current password first, but Supabase auth separates this.
        // Assuming user is re-authenticated or we trust session (Dev mode)
        await provider.updatePassword(_newPasswordController.text);
      }

      // 3. Update Text Fields
      final Map<String, dynamic> updates = {
         'full_name': _nameController.text.trim(),
         'phone': _phoneController.text.trim(),
         'nationality': _selectedNationality,
         'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (avatarUrl != null) {
        updates['profile_photo_url'] = avatarUrl;
      }

      await provider.updateProfile(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        GlobalDialogs.showError(
          context,
          'Failed to update profile',
          e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Green Header with Profile Picture
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFF000000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          l10n.editProfile,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Profile Picture
                  Stack(
                    children: [
                      Consumer<AppStateProvider>(
                        builder: (context, provider, _) {
                          return CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            child: _profileImage != null
                              ? kIsWeb 
                                ? ClipOval(child: Image.network(_profileImage!.path, fit: BoxFit.cover, width: 100, height: 100))
                                : ClipOval(child: Image.file(io.File(_profileImage!.path), fit: BoxFit.cover, width: 100, height: 100))
                              : provider.userAvatar != null
                                ? ClipOval(child: Image.network(provider.userAvatar!, fit: BoxFit.cover, width: 100, height: 100))
                                : const Icon(Icons.person, size: 50, color: Colors.white),
                          );
                        }
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFFFFD700),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.tapToChangePhoto,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information
                    Text(
                      l10n.personalInformation,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    
                    // Nationality
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedNationality,
                        decoration: const InputDecoration(
                          labelText: 'Nationality',
                          prefixIcon: Icon(Icons.flag_outlined, color: Color(0xFFFFD700)),
                          border: InputBorder.none,
                        ),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD700)),
                        isExpanded: true,
                        items: _nationalities.map((String nationality) {
                          return DropdownMenuItem<String>(
                            value: nationality,
                            child: Text(nationality),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedNationality = newValue;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Change Password
                    Text(
                      l10n.changePassword,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.leaveBlankIfNoChange,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // _buildPasswordField (Current password is often required by API but we skip for dev)
                    
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      obscureText: _obscureNewPassword,
                      onToggle: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm New Password',
                      obscureText: _obscureConfirmPassword,
                      onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      validator: (value) {
                         if (_newPasswordController.text.isNotEmpty && value != _newPasswordController.text) {
                           return 'Passwords do not match';
                         }
                         return null;
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n.saveChanges,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFFD700)),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey[600],
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
