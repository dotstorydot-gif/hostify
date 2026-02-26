import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/providers/document_provider.dart';
import 'package:hostify/legacy/screens/auth_screen.dart';
import 'package:hostify/legacy/screens/guest_edit_profile_screen.dart';
import 'package:hostify/legacy/screens/guest_my_bookings_screen.dart';
import 'package:hostify/legacy/screens/guest_my_requests_screen.dart';
import 'package:hostify/legacy/screens/guest_documents_screen.dart';
import 'package:hostify/legacy/screens/settings_screen.dart';
import 'package:hostify/legacy/services/language_service.dart';
import 'package:hostify/legacy/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hostify/legacy/services/seed_service.dart';
import 'package:hostify/legacy/providers/property_provider.dart';
import 'package:hostify/legacy/providers/admin_analytics_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String userRole; // 'admin', 'landlord', 'guest', 'traveler'
  
  const ProfileScreen({super.key, this.userRole = 'guest'});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isEditing = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final user = context.read<AppStateProvider>();
      if (user.currentUser != null) {
        _nameController.text = user.userName ?? '';
        _emailController.text = user.userEmail ?? '';
        _phoneController.text = user.userProfile?['phone'] ?? '';
        
        // Fetch documents safely after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<DocumentProvider>().fetchUserDocuments(user.currentUser!.id);
          }
        });
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final provider = context.read<AppStateProvider>();
    try {
      await provider.updateProfile({
        'full_name': _nameController.text,
        'phone': _phoneController.text,
        // Email update usually requires re-verification, so skipping for now or handling via Auth API
      });
      
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  Future<void> _uploadDocument() async {
    final user = context.read<AppStateProvider>().currentUser;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      
      try {
        await context.read<DocumentProvider>().uploadDocument(
          userId: user.id,
          documentType: result.files.single.extension ?? 'doc',
          file: file,
        );
        
        // Refresh list
        if (mounted) {
           await context.read<DocumentProvider>().fetchUserDocuments(user.id);
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Document uploaded successfully')),
           );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      }
    }
  }
  


  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action is permanent and will delete all your data. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<AppStateProvider>().deleteAccount();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final provider = context.read<AppStateProvider>();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (image != null) {
        final imageUrl = await provider.uploadAvatar(image);
        await provider.updateProfile({'avatar_url': imageUrl});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar updated!'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar upload failed: $e')),
        );
      }
    }
  }

  Future<void> _seedData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Dummy Data?'),
        content: const Text('This will populate your account with sample properties, bookings, and analytics for demonstration. This cannot be easily undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seed Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isInit = true); // Trigger UI loading state if desired, or just show snackbar
      try {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seeding data... please wait')));
        await SeedService().seedDummyData();
        
        if (mounted) {
           final user = context.read<AppStateProvider>().currentUser;
           if (user != null) {
              await context.read<PropertyProvider>().fetchLandlordProperties(user.id);
              await context.read<AdminAnalyticsProvider>().fetchAnalytics(
                startDate: DateTime(2026, 1, 1),
                endDate: DateTime(2026, 12, 31),
              );
           }
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dummy data seeded successfully!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seeding failed: $e')));
        }
      }
    }
  }
  
  void _showLanguageDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('en', 'English'),
            _buildLanguageOption('ar', 'العربية'),
            _buildLanguageOption('fr', 'Français'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String code, String name) {
    return ListTile(
      title: Text(name),
      onTap: () {
        context.read<LanguageService>().changeLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  void _showHelpSupportDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.contactUs),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: const Text('info@dot-story.com'),
              onTap: () => launchUrl(Uri.parse('mailto:info@dot-story.com')),
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('WhatsApp'),
              subtitle: const Text('+201006119667'),
              onTap: () => launchUrl(Uri.parse('https://wa.me/201006119667')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer2<AppStateProvider, DocumentProvider>(
      builder: (context, userProvider, docProvider, child) {
        final user = userProvider.currentUser;
        
        // If not editing, ensure fields match provider data (in case of background updates)
        if (!_isEditing && user != null) {
           if (_nameController.text != (userProvider.userName ?? '')) {
             _nameController.text = userProvider.userName ?? '';
           }
           if (_emailController.text != (userProvider.userEmail ?? '')) {
             _emailController.text = userProvider.userEmail ?? '';
           }
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.myProfile),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (_isEditing)
                TextButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.check, color: Color(0xFFFFD700)),
                  label: Text(l10n.save, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => setState(() => _isEditing = true),
                ),
            ],
          ),
          body: user == null 
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 24),
                        const Text(
                          "You are not signed in",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Sign in to manage your profile, view trips, and customize your experience.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Sign In / Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Picture
                Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFF000000)],
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: userProvider.userAvatar != null
                        ? Image.network(userProvider.userAvatar!, fit: BoxFit.cover)
                        : const Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _uploadAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: userProvider.isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Reference ID Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(
                    '${l10n.refId}: ${user.id.substring(0, 8)}...',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.bold),
                    onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ID: ${user.id}')));
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // User Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5E92F3), Color(0xFF4FC3F7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (userProvider.userRole ?? widget.userRole).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Profile Information Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.personalInformation,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(l10n.fullName, _nameController, Icons.person_outline),
                      const SizedBox(height: 16),
                      _buildTextField(l10n.email, _emailController, Icons.email_outlined),
                      const SizedBox(height: 16),
                      _buildTextField(l10n.phone, _phoneController, Icons.phone_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                            l10n.documents,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                           ),
                           if (docProvider.isLoading)
                             const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                         ],
                       ),
                      const SizedBox(height: 16),
                      
                      if (docProvider.isLoading && docProvider.userDocuments.isEmpty)
                        const Center(child: Text("Loading documents..."))
                      else if (docProvider.userDocuments.isEmpty)
                        const Text("No documents uploaded")
                      else
                        Column(
                          children: docProvider.userDocuments.map((doc) => _buildDocumentItem(
                            doc['document_type'] ?? 'Doc',
                            doc['file_name'] ?? 'file',
                            '${((doc['file_size'] ?? 0) / 1024).toStringAsFixed(1)} KB'
                          )).toList(),
                        ),

                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _uploadDocument,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Document'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFD700),
                          side: const BorderSide(color: Color(0xFFFFD700)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Settings & Preferences (New Section moved from Home)
                if (widget.userRole == 'guest' || widget.userRole == 'traveler') ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildMenuTile(
                          context,
                          icon: Icons.language,
                          title: AppLocalizations.of(context)!.language,
                          subtitle: Localizations.localeOf(context).languageCode == 'ar' ? 'العربية' : 
                                    Localizations.localeOf(context).languageCode == 'fr' ? 'Français' : 'English',
                          onTap: _showLanguageDialog,
                          showDivider: true,
                        ),
                        _buildMenuTile(
                          context,
                          icon: Icons.calendar_today_outlined,
                          title: l10n.myBookings,
                          subtitle: l10n.viewBookingHistory,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GuestMyBookingsScreen(),
                              ),
                            );
                          },
                          showDivider: true,
                        ),
                        _buildMenuTileWithBadge(
                          context,
                          icon: Icons.room_service_outlined,
                          title: l10n.serviceRequests,
                          subtitle: l10n.viewServiceRequests,
                          badgeCount: 2,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GuestMyRequestsScreen(),
                              ),
                            );
                          },
                          showDivider: true,
                        ),
                        _buildMenuTile(
                          context,
                          icon: Icons.settings_outlined,
                          title: AppLocalizations.of(context)!.settings,
                          subtitle: AppLocalizations.of(context)!.notifications,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          },
                          showDivider: true,
                        ),
                        _buildMenuTile(
                          context,
                          icon: Icons.help_outline,
                          title: AppLocalizations.of(context)!.contactUs,
                          subtitle: AppLocalizations.of(context)!.learnMoreAboutUs,
                          onTap: _showHelpSupportDialog,
                        ),
                      ],
                    ),
                  ),
                ],
                // Security Card omitted for brevity or can be re-added
                const SizedBox(height: 32),
                
                // Danger Zone
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.dangerZone,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.deleteDescription,
                        style: TextStyle(color: Colors.red.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(Icons.delete_forever),
                        label: Text(l10n.deleteMyAccount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Debug Zone
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Debug Zone',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use this button to quickly populate the database with dummy properties for testing.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () async {
                           try {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Seeding Database...')),
                             );
                             await SeedService().seedDummyData();
                             // Refresh properties
                             await context.read<PropertyProvider>().fetchProperties();
                             if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Seed successful! Check Explore tab.')),
                               );
                             }
                           } catch (e) {
                              if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red,),
                               );
                             }
                           }
                        },
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Seed Dummy Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),

                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _seedData,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Seed Dummy Data'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.blue[200]!),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                           await context.read<AppStateProvider>().signOut();
                           if (mounted) {
                             Navigator.of(context).pushAndRemoveUntil(
                               MaterialPageRoute(builder: (_) => const AuthScreen()),
                               (route) => false,
                             );
                           }
                        },
                        icon: const Icon(Icons.logout),
                        label: Text(l10n.logout),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      enabled: _isEditing,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      ),
    );
  }

  Widget _buildDocumentItem(String title, String fileName, String? fileSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF5E92F3).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description, color: Color(0xFF5E92F3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3748))),
                const SizedBox(height: 2),
                Text(fileSize != null ? '$fileName • $fileSize' : fileName, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.download, color: Color(0xFFFFD700)), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFFD700), size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
        if (showDivider) const Divider(height: 1, indent: 72),
      ],
    );
  }

  Widget _buildMenuTileWithBadge(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int badgeCount,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFFFD700), size: 24),
          ),
          title: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
        if (showDivider) const Divider(height: 1, indent: 72),
      ],
    );
  }
}
