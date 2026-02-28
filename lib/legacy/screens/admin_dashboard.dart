import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:hostify/legacy/l10n/app_localizations.dart';
import 'package:hostify/legacy/screens/admin_property_management.dart';
import 'package:hostify/legacy/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/screens/admin_bookings.dart';
import 'package:hostify/legacy/screens/admin_financials.dart';
import 'package:hostify/legacy/screens/admin_content_creator.dart';
import 'package:hostify/legacy/screens/admin_expense_management.dart';
import 'package:hostify/legacy/screens/enhanced_admin_analytics.dart';
import 'package:hostify/legacy/screens/admin_review_management.dart';
import 'package:hostify/legacy/screens/notifications_screen.dart';
import 'package:hostify/legacy/screens/auth_screen.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/screens/admin_booking_requests_screen.dart';
import 'package:hostify/legacy/screens/admin_edit_profile_screen.dart';
import 'package:hostify/legacy/services/booking_service.dart';
import 'package:hostify/legacy/providers/admin_analytics_provider.dart';
import 'package:hostify/legacy/services/icalendar_sync_service.dart';
import 'package:hostify/legacy/screens/guest_document_upload_screen.dart';
import 'package:hostify/legacy/screens/settings_screen.dart';
import 'package:hostify/legacy/screens/admin_service_requests_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hostify/legacy/services/language_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final BookingService _bookingService = BookingService();
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
    // Fetch notifications and analytics
    Future.microtask(() {
      context.read<NotificationProvider>().fetchNotifications();
      // Pass default dates (current year) to prevent RPC failures
      final now = DateTime.now();
      context.read<AdminAnalyticsProvider>().fetchAnalytics(
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31, 23, 59, 59),
      );
    });
  }

  Future<void> _loadPendingCount() async {
    final bookings = await _bookingService.getPendingBookings();
    if (mounted) {
      setState(() => _pendingCount = bookings.length);
    }
  }

  Future<void> _syncCalendars() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing all calendars... please wait')),
      );
      
      await ICalendarSyncService().syncAllPropertiesAndPersist();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete! Refreshing dashboard...')),
        );
        context.read<AdminAnalyticsProvider>().fetchAnalytics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(l10n.adminDashboard),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Hide back button
        actions: [
          IconButton(
            icon: const Icon(Icons.sync), 
            tooltip: 'Sync Calendars',
            onPressed: _syncCalendars,
          ),
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              return Stack(
                children: [
                   IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (provider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${provider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          const AdminBookingRequestsScreen(),
          const AdminBookings(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold);
            }
            return const TextStyle(color: Colors.black54);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFFFFD700));
            }
            return const IconThemeData(color: Colors.black54);
          }),
        ),
        child: NavigationBar(
          height: 70,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('$_pendingCount'),
                isLabelVisible: _pendingCount > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: const Icon(Icons.notifications),
              label: 'Requests',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Bookings',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pending Requests Banner
          InkWell(
            onTap: () => setState(() => _selectedIndex = 1), // Switch to Requests tab
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFF000000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking Requests',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_pendingCount pending approvals',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Analytics Summary Cards
          Consumer<AdminAnalyticsProvider>(
            builder: (context, analytics, _) {
              if (analytics.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (analytics.error != null) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD700)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          analytics.error!,
                          style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Revenue',
                          '\$${analytics.totalRevenue.toStringAsFixed(0)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Bookings',
                          '${analytics.totalBookings}',
                          Icons.calendar_month,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Occupancy',
                          '${analytics.occupancyRate.toStringAsFixed(1)}%',
                          Icons.home,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Rating',
                          analytics.avgRating.toStringAsFixed(1),
                          Icons.star,
                          Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          
          // Grid Menu
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMenuCard(context, l10n.propertyManagement, Icons.home_work, const AdminPropertyManagement()),
              _buildMenuCard(context, l10n.financialReports, Icons.attach_money, const AdminFinancials()),
              _buildMenuCard(context, l10n.trackRevenueExpenses, Icons.receipt_long, const AdminExpenseManagement()),
              _buildMenuCard(context, l10n.guestReviews, Icons.rate_review, const AdminReviewManagementScreen()),
              _buildMenuCard(context, l10n.contentCreator, Icons.campaign, const AdminContentCreator()),
              _buildMenuCard(context, l10n.analytics, Icons.bar_chart, const EnhancedAdminAnalytics()),
              _buildMenuCard(
                context, 
                l10n.serviceRequests, 
                Icons.room_service_outlined, 
                const AdminServiceRequestsScreen()
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // White Header with Profile Info
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Consumer<AppStateProvider>(
                  builder: (context, provider, _) => Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          backgroundImage: provider.userAvatar != null ? NetworkImage(provider.userAvatar!) : null,
                          child: provider.userAvatar == null 
                              ? const Icon(Icons.admin_panel_settings, size: 32, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, ${provider.userName?.split(' ').first ?? 'Admin'}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'System Administrator',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Hostify Logo / Banner Space
                Center(
                  child: Image.asset(
                    'assets/images/hostifylogo.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_user, color: Color(0xFFFFD700), size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full System Access',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage all properties, bookings & users',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Profile Menu Sections
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language Section
                _buildMenuTile(
                  context,
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () {
                    _showLanguageDialog(context);
                  },
                ),
                const SizedBox(height: 12),
                
                // Manage Account Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMenuTile(
                        context,
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        subtitle: 'Update your information',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminEditProfileScreen(),
                            ),
                          );
                        },
                        showDivider: true,
                      ),
                      _buildMenuTile(
                        context,
                        icon: Icons.upload_file,
                        title: 'My Documents',
                        subtitle: 'ID & verification documents',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GuestDocumentUploadScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Settings & Support Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMenuTile(
                        context,
                        icon: Icons.settings_outlined,
                        title: 'App Preferences',
                        subtitle: 'Notifications & settings',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                        showDivider: true,
                      ),
                      _buildMenuTile(
                        context,
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        subtitle: 'Contact us',
                        onTap: () {
                          _showHelpSupportDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
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

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'en', 'English'),
            _buildLanguageOption(context, 'ar', 'العربية'),
            _buildLanguageOption(context, 'fr', 'Français'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String code, String name) {
    return ListTile(
      title: Text(name),
      onTap: () {
        context.read<LanguageService>().changeLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Color(0xFFFFD700)),
            SizedBox(width: 12),
            Text('Help & Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Us',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFFFFD700)),
              title: const Text('Email'),
              subtitle: const Text('info@dot-story.com'),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                launchUrl(Uri.parse('mailto:info@dot-story.com'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFFFFD700)),
              title: const Text('Phone'),
              subtitle: const Text('+201006119667'),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                launchUrl(Uri.parse('tel:+201006119667'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFFFFD700)),
              title: const Text('WhatsApp'),
              subtitle: const Text('+201006119667'),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                launchUrl(Uri.parse('https://wa.me/201006119667'));
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Widget destination) {
    return Card(
      elevation: 2,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Use GoRouter if available, otherwise fallback to Navigator
          try {
            if (destination is AdminPropertyManagement) {
              context.push('/properties');
            } else if (destination is AdminFinancials) {
              context.push('/financials');
            } else if (destination is SettingsScreen) {
              context.push('/settings');
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
            }
          } catch (e) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: const Color(0xFFFFD700)),
              const SizedBox(height: 12),
              Text(
                title, 
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
