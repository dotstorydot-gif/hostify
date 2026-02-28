import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import "package:intl/intl.dart";
import 'package:hostify/legacy/screens/analytics_screen.dart';
import 'package:hostify/legacy/screens/edit_profile_screen.dart';
import 'package:hostify/legacy/screens/settings_screen.dart';
import 'package:hostify/legacy/services/language_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hostify/legacy/widgets/landlord_filter_section.dart';
import 'package:hostify/legacy/services/icalendar_sync_service.dart';
import 'package:hostify/legacy/providers/admin_analytics_provider.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/providers/property_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LandlordDashboard extends StatefulWidget {
  const LandlordDashboard({super.key});

  @override
  State<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  int _selectedIndex = 0;
  // Filter State
  bool _isFilterExpanded = false; // Collapsible filter
  String _selectedPeriod = '2026';
  String? _selectedPropertyId;
  String _rangeMode = 'Year'; // 'Year', 'Month', 'YTD'
  int _selectedYear = 2026;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppStateProvider>().currentUser;
      if (user != null) {
        context.read<PropertyProvider>().fetchLandlordProperties(user.id);
        _updateAnalytics();
      }
    });
  }

  void _updateAnalytics() {
    DateTime start, end;
    final now = DateTime.now();

    if (_rangeMode == 'Year') {
      start = DateTime(_selectedYear, 1, 1);
      end = DateTime(_selectedYear, 12, 31, 23, 59, 59);
      _selectedPeriod = _selectedYear.toString();
    } else if (_rangeMode == 'Month') {
      start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
      _selectedPeriod = 'Month';
    } else if (_rangeMode == 'YTD') {
      start = DateTime(now.year, 1, 1);
      end = now;
      _selectedPeriod = 'YTD';
    } else {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, 12, 31);
      _selectedPeriod = '2026';
    }

    context.read<AdminAnalyticsProvider>().fetchAnalytics(
       startDate: start,
       endDate: end,
       propertyId: _selectedPropertyId,
    );
  }

  void _onFilterChanged(DateTime start, DateTime end, String? propertyId, String label) {
    if (!mounted) return;
    setState(() {
      _selectedPropertyId = propertyId;
      _selectedPeriod = label;
      // Also update local selectedMonth/Year to keep UI in sync if the widget is rebuilt
      // (Though the LandlordFilterSection keeps its own state, this helps if parent rebuilds)
      if (start.day == 1 && end.difference(start).inDays < 32) {
          _rangeMode = 'Month';
          _selectedMonth = start;
          _selectedYear = start.year;
      } else if (start.month == 1 && start.day == 1 && end.month == 12 && end.day == 31) {
          _rangeMode = 'Year';
          _selectedYear = start.year;
      } else {
          _rangeMode = 'YTD';
      }
    });
    
    context.read<AdminAnalyticsProvider>().fetchAnalytics(
      startDate: start,
      endDate: end,
      propertyId: propertyId,
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final properties = context.read<PropertyProvider>().properties;
          
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: Color(0xFFFFD700)),
                    const SizedBox(width: 12),
                    const Text('Filter Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Property
                const Text('Property', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedPropertyId,
                      isExpanded: true,
                      hint: const Text('All Properties'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Properties')),
                        ...properties.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['name'] ?? 'Unknown'))),
                      ],
                      onChanged: (val) => setSheetState(() => _selectedPropertyId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Range
                const Text('Range', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _rangeMode,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Year', child: Text('Year')),
                        DropdownMenuItem(value: 'Month', child: Text('Month')),
                        DropdownMenuItem(value: 'YTD', child: Text('Year to Date')),
                      ],
                      onChanged: (val) => setSheetState(() => _rangeMode = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Specific Selectors (Year or Month)
                if (_rangeMode == 'Year') ...[
                   const Text('Year', style: TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          isExpanded: true,
                          items: [2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                          onChanged: (val) => setSheetState(() => _selectedYear = val!),
                        ),
                      ),
                   ),
                ],
                if (_rangeMode == 'Month') ...[
                   const Text('Month', style: TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   InkWell(
                     onTap: () async {
                       await _showMonthPicker(context);
                       setSheetState(() {}); // Refresh sheet
                     },
                     child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
                            const Icon(Icons.calendar_month, size: 20),
                          ],
                        ),
                     ),
                   ),
                ],
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {}); // Trigger rebuild
                      _updateAnalytics();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apply Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    int pickingYear = _selectedMonth.year;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Month', style: TextStyle(fontSize: 16)),
              Row(
                children: [
                   IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setDialogState(() => pickingYear--)),
                   Text('$pickingYear', style: const TextStyle(fontWeight: FontWeight.bold)),
                   IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setDialogState(() => pickingYear++)),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = _selectedMonth.month == month && _selectedMonth.year == pickingYear;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedMonth = DateTime(pickingYear, month, 1));
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.grey[300]!),
                    ),
                    child: Center(
                      child: Text(DateFormat('MMM').format(DateTime(pickingYear, month)),
                        style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _syncCalendars() async {
    // Wrapper to handle Fix + Real Sync
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Initializing Property Data...')),
        );
      }
      
      // Trigger sync after delay
      Future.delayed(const Duration(seconds: 3), () async {
         final prefs = await SharedPreferences.getInstance();
         if (prefs.getBool('price_fix_v5_applied') != true) {
             await _fixPrices();
             await prefs.setBool('price_fix_v5_applied', true);
         }
         await _performRealSync();
      });
    } catch (e) {
      debugPrint('Init Sync Error: $e');
    }
  }
  
  Future<void> _fixPrices() async {
      debugPrint('STARTING PRICE FIX...');
      final propertUpdates = {
        'Hostify Boutique Stays exclusive six-Ensuite villa': 500.0,
        'Hostify Stays, Lagoons Paradise 3 ensuite Villa': 100.0,
        'Hostify Stays, Amazing 5 master suite &private pool': 250.0,
        'Hostify Stays, Ancient sands apartment': 90.0,
        'Hostify Stays, Beautiful 3 master suite': 85.0,
        'Hostify Stays, Cozy lagoons terrace one ensuite Apt': 100.0,
        'Hostify Stays, Joubal Lagoons flowery apartment': 185.0,
        'Hostify Stays, Luxurious Sea View, F.Marina Apt.': 120.0,
        'Hostify Stays, Joubal Lagoons Terrace': 120.0,
      };

      for (var entry in propertUpdates.entries) {
        final name = entry.key;
        final price = entry.value;
        try {
          final response = await Supabase.instance.client.from('properties').select('id, ical_url').ilike('name', name).maybeSingle();
          if (response != null) {
             final id = response['id'];
             final icalUrl = response['ical_url'];
             await Supabase.instance.client.from('properties').update({'price_per_night': price}).eq('id', id);
             debugPrint('FIXED PRICE: $name -> $price');
             
             // Trigger re-calc
             if (icalUrl != null) {
                await ICalendarSyncService().syncCalendar(propertyId: id, icalUrl: icalUrl);
                debugPrint('SYNCED: $name');
             }
          } else {
             debugPrint('FIX FAILED: Property NOT FOUND: $name');
          }
        } catch (e) {
          debugPrint('FIX ERROR for $name: $e');
        }
      }
      debugPrint('PRICE FIX COMPLETE');
  }

  Future<void> _performRealSync() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Syncing your property calendars...')),
        );
      }

      await ICalendarSyncService().syncAllPropertiesAndPersist();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete! Refreshing data...')),
        );
        _updateAnalytics(); // Refresh analytics after sync
        setState(() {}); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildPropertiesTab(),
          const AnalyticsScreen(propertyName: "All Properties"), // Reusing existing screen
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          height: 70,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Color(0xFFFFD700)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.business_outlined),
              selectedIcon: Icon(Icons.business, color: Color(0xFFFFD700)),
              label: 'Properties',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: Color(0xFFFFD700)),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Color(0xFFFFD700)),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section with Gradient and Colored Metric Cards
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back,',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Landlord Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.fade,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Filter Toggle
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white),
                            onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                            tooltip: 'Toggle Filters',
                          ),
                        ),
                        // Selected Year/Period Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedPeriod == 'Month' 
                                ? '${DateFormat('MMM').format(_selectedMonth)} ${_selectedMonth.year}'
                                : _selectedPeriod,
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.sync, color: Colors.white),
                          onPressed: _syncCalendars,
                          tooltip: 'Sync Calendars',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Embedded Filter Section
                LandlordFilterSection(
                  isExpanded: _isFilterExpanded,
                  onToggle: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                  initialPropertyId: _selectedPropertyId,
                  initialRangeMode: _rangeMode,
                  initialYear: _selectedYear,
                  initialMonth: _selectedMonth,
                  onFilterChanged: _onFilterChanged,
                ),
                
                const SizedBox(height: 30),
                // Colored Metrics Cards
                const SizedBox(height: 30),
                // Colored Metrics Cards
                Consumer<AdminAnalyticsProvider>(
                  builder: (context, analytics, child) {
                    if (analytics.isLoading) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (analytics.error != null) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  analytics.error!,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Landlord Share',
                            '\$${analytics.landlordShare.toStringAsFixed(0)}',
                            Icons.payments,
                            const Color(0xFF4CAF50),
                            subtitle: 'Real-time Earnings',
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildMetricCard(
                            'Occupancy',
                            '${analytics.occupancyRate.toStringAsFixed(1)}%',
                            Icons.home_work,
                            const Color(0xFF2196F3),
                            subtitle: 'Portfolio Active',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Your Properties Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Properties',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                Consumer<PropertyProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.properties.isEmpty) {
                      return const Center(child: Text("No properties assigned yet."));
                    }
                    return Column(
                      children: provider.properties.take(3).map((prop) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPropertyCard(
                            context,
                            prop,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesTab() {
     return ListView(
       padding: const EdgeInsets.all(16),
       children: [
         const SizedBox(height: 40),
         const Text(
           'All Properties',
           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
         ),
         const SizedBox(height: 20),
         const SizedBox(height: 20),
         Consumer<PropertyProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                 return const Center(child: CircularProgressIndicator());
              }
              if (provider.properties.isEmpty) {
                 return const Center(child: Text("No properties found."));
              }
              return Column(
                children: provider.properties.map((prop) {
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 16),
                     child: _buildPropertyCard(context, prop),
                   );
                }).toList(),
              );
            },
         ),
       ],
     );
  }

  Widget _buildProfileTab() {
    return Consumer<AppStateProvider>(
      builder: (context, provider, _) {
        final profile = provider.userProfile ?? {};
        final name = profile['full_name'] ?? 'Landlord';
        final firstName = name.split(' ').first;
        final photoUrl = provider.userAvatar;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section with White Info Cards
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Row
                    Row(
                      children: [
                        // Profile Picture
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null 
                                ? const Icon(Icons.person, size: 32, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Name and Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, $firstName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Property Owner',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // White Info Cards
                    Consumer2<PropertyProvider, AdminAnalyticsProvider>(
                      builder: (context, propertyProvider, analyticsProvider, child) {
                        final properties = propertyProvider.properties;
                        final count = properties.length;
                        final cities = properties
                            .map((p) => (p['city'] as String?) ?? (p['address'] as String?)?.split(',').last.trim() ?? 'Unknown')
                            .toSet()
                            .join(', ');
                        
                        final occupancy = analyticsProvider.occupancyRate;
                        final earnings = analyticsProvider.landlordShare; // Use Landlord Share or Total Revenue based on preference

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.apartment, color: Color(0xFFFFD700), size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$count Active Properties',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D3748),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$cities • ${occupancy.toStringAsFixed(1)}% occupancy',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF6B7280),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.payments, color: Color(0xFFFFD700), size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Total Earnings',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D3748),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${earnings.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFFD700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Language Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildMenuTile(
                        icon: Icons.language,
                        title: 'Language',
                        onTap: () => _showLanguageDialog(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Account Management Section
                    const Text(
                      'Manage account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildMenuTile(
                            icon: Icons.person_outline,
                            title: 'Personal details',
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(userProfile: profile),
                                ),
                              );
                              if (result == true) {
                                setState(() {});
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildMenuTile(
                            icon: Icons.lock_outline,
                            title: 'Security settings',
                            onTap: () => _showSecuritySettings(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Settings & Support Section
                    const Text(
                      'Settings & support',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildMenuTile(
                            icon: Icons.settings_outlined,
                            title: 'App preferences',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            ),
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildMenuTile(
                            icon: Icons.help_outline,
                            title: 'Help & support',
                            onTap: () => _showHelpSupport(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Logout Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildMenuTile(
                        icon: Icons.logout,
                        title: 'Sign out',
                        textColor: Colors.red,
                        showChevron: false,
                        onTap: () => context.go('/login'),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSecuritySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Security settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildMenuTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () {
                      Navigator.pop(context);
                      _showPrivacyPolicy(context);
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuTile(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    onTap: () {
                      Navigator.pop(context);
                      _showTermsConditions(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This privacy policy explains how Hostify Stays collects, uses, and protects your personal information.\n\n'
            '1. Information Collection\n'
            'We collect information you provide directly to us when you create an account, make a booking, or contact us.\n\n'
            '2. Use of Information\n'
            'We use your information to provide and improve our services, process bookings, and communicate with you.\n\n'
            '3. Data Security\n'
            'We implement appropriate security measures to protect your personal information.\n\n'
            '4. Contact Us\n'
            'If you have questions about our privacy practices, please contact us at info@dot-story.com',
            style: TextStyle(height: 1.5),
          ),
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

  void _showTermsConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'Welcome to .Hostify. By using our services, you agree to these terms.\n\n'
            '1. User Responsibilities\n'
            'You are responsible for maintaining the confidentiality of your account and password.\n\n'
            '2. Property Listings\n'
            'Property owners must ensure all information provided is accurate and up-to-date.\n\n'
            '3. Bookings\n'
            'All bookings are subject to availability and confirmation.\n\n'
            '4. Cancellations\n'
            'Cancellation policies vary by property. Please review before booking.\n\n'
            '5. Liability\n'
            '.Hostify acts as a facilitator and is not responsible for disputes between guests and property owners.\n\n'
            '6. Changes to Terms\n'
            'We reserve the right to modify these terms at any time.',
            style: TextStyle(height: 1.5),
          ),
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

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Help & support',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const Text(
                    'Contact Us',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildContactTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: 'info@dot-story.com',
                    onTap: () async {
                      final Uri uri = Uri.parse('mailto:info@dot-story.com');
                      if (!await launchUrl(uri)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open email client')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildContactTile(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: '+20 100 611 9667',
                    onTap: () async {
                      final Uri uri = Uri.parse('tel:+201006119667');
                      if (!await launchUrl(uri)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open phone app')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildContactTile(
                    icon: Icons.chat_outlined,
                    title: 'WhatsApp',
                    value: '+20 100 611 9667',
                    onTap: () async {
                      final Uri uri = Uri.parse('https://wa.me/201006119667');
                      if (!await launchUrl(uri)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open WhatsApp')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildContactTile(
                    icon: Icons.language_outlined,
                    title: 'Website',
                    value: 'dot-story.com',
                    onTap: () async {
                      final Uri uri = Uri.parse('https://dot-story.com');
                      if (!await launchUrl(uri)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open website')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFFFFD700), size: 20),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LanguageService.languageNames.entries.map((entry) {
            final languageCode = entry.key;
            final languageName = entry.value;
            final languageService = Provider.of<LanguageService>(context, listen: false);
            
            return RadioListTile<String>(
              title: Text(languageName),
              value: languageCode,
              groupValue: languageService.currentLocale.languageCode,
              onChanged: (value) async {
                if (value != null) {
                  await languageService.changeLanguage(value);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Language changed to $languageName'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    bool showChevron = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Icon(icon, color: textColor ?? const Color(0xFF2D3748), size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: textColor ?? const Color(0xFF2D3748),
        ),
      ),
      trailing: showChevron 
          ? Icon(Icons.chevron_right, size: 20, color: Colors.grey[400])
          : null,
      onTap: onTap,
    );
  }



  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color accentColor, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildPropertyCard(
    BuildContext context,
    Map<String, dynamic> property,
  ) {
    final title = property['name'] ?? 'Unknown Property';
    // Split location string "Address, City, Country" to get City
    final locationRaw = property['location'] as String? ?? '';
    final locationParts = locationRaw.split(',');
    final location = locationParts.length > 1 ? locationParts[1].trim() : locationRaw;
    
    final price = property['price_per_night']?.toString() ?? '0';
    final status = property['status'] ?? 'Active';
    final imageUrl = property['image'] as String? ?? '';
    final propertyId = property['id'];

    return GestureDetector( // Make entire card clickable
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalyticsScreen(propertyName: title, propertyId: propertyId),
          ),
        );
      },
      child: Container(
        height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700), // App's green color
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background property image with overlay
            Positioned.fill(
              child: Image.network(
                imageUrl.isNotEmpty ? imageUrl : 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFFFD700),
                    child: const Icon(Icons.villa, size: 100, color: Colors.white24),
                  );
                },
              ),
            ),
            // Dark gradient overlay for text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (status.toLowerCase() == 'active') ? Colors.green[400] : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '\$$price/night',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnalyticsScreen(propertyName: title, propertyId: propertyId),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFFD700),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
