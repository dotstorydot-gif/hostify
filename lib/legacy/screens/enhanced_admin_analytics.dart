import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/admin_analytics_provider.dart';
import 'package:hostify/legacy/services/icalendar_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnhancedAdminAnalytics extends StatefulWidget {
  const EnhancedAdminAnalytics({super.key});

  @override
  State<EnhancedAdminAnalytics> createState() => _EnhancedAdminAnalyticsState();
}

class _EnhancedAdminAnalyticsState extends State<EnhancedAdminAnalytics> {
  String _selectedView = 'Overview';
  String _selectedTimeRange = 'YTD';
  String? _selectedPropertyId; // null = All Properties
  List<Map<String, dynamic>> _properties = [];
  
  final List<String> _views = ['Overview', 'Sources', 'Properties', 'Nationality', 'Guest Type'];
  final List<String> _timeRanges = ['YTD', 'This Year', '2025', '2024', 'This Month', 'Last 30 Days', 'Custom'];
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadProperties();
      _fetchAnalytics();
    });
  }

  Future<void> _loadProperties() async {
    try {
      final response = await Supabase.instance.client
          .from('property-images')
          .select('id, name')
          .order('name');
      setState(() {
        _properties = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading properties: $e');
    }
  }

  void _fetchAnalytics() {
    final provider = Provider.of<AdminAnalyticsProvider>(context, listen: false);
    
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    if (_selectedTimeRange == 'This Year') {
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year, 12, 31, 23, 59, 59);
    } else if (_selectedTimeRange == 'YTD') {
      startDate = DateTime(now.year, 1, 1);
      endDate = now;
    } else if (_selectedTimeRange == '2025') {
      startDate = DateTime(2025, 1, 1);
      endDate = DateTime(2025, 12, 31, 23, 59, 59);
    } else if (_selectedTimeRange == '2024') {
      startDate = DateTime(2024, 1, 1);
      endDate = DateTime(2024, 12, 31, 23, 59, 59);
    } else if (_selectedTimeRange == 'Last 30 Days') {
      startDate = now.subtract(const Duration(days: 30));
      endDate = now;
    } else if (_selectedTimeRange == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } 
    // For 'Custom', dates are passed separately, but if we just switched to 'Custom' without picking dates, 
    // rely on provider's current dates or default.
    // Actually, 'Custom' should trigger a picker.

    provider.fetchAnalytics(startDate: startDate, endDate: endDate, propertyId: _selectedPropertyId);
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFFFFD700),
            colorScheme: const ColorScheme.light(primary: Color(0xFFFFD700)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTimeRange = 'Custom');
      Provider.of<AdminAnalyticsProvider>(context, listen: false)
          .fetchAnalytics(startDate: picked.start, endDate: picked.end, propertyId: _selectedPropertyId);
    }
  }

  Future<void> _syncCalendars() async {
    debugPrint('SYNC BUTTON CLICKED in Analytics');
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing all calendars... please wait')),
      );
      
      await ICalendarSyncService().syncAllPropertiesAndPersist();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete! Refreshing data...')),
        );
        _fetchAnalytics(); // Reload data
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
      body: Consumer<AdminAnalyticsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (provider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Text('Error: ${provider.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _fetchAnalytics(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Green Header
              Container(
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
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Title & Back Button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Analytics Dashboard',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.sync, color: Colors.white),
                              tooltip: 'Sync iCal Bookings',
                              onPressed: _syncCalendars,
                            ),
                          ],
                        ),
                      ),
                    
                    // Property Selector
                    if (_properties.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedPropertyId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFFFFD700),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                            hint: const Text('All Properties', style: TextStyle(color: Colors.white)),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Properties', style: TextStyle(color: Colors.white)),
                              ),
                              ..._properties.map((property) {
                                return DropdownMenuItem<String?>(
                                  value: property['id'] as String,
                                  child: Text(
                                    property['name'] as String,
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedPropertyId = value);
                              _fetchAnalytics();
                            },
                          ),
                        ),
                      ),
                    
                    // Time Range Selector
                      Container(
                         height: 50, // Increased height
                         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         child: ListView.builder(
                           scrollDirection: Axis.horizontal,
                           itemCount: _timeRanges.length,
                           itemBuilder: (context, index) {
                             final range = _timeRanges[index];
                             final isSelected = _selectedTimeRange == range;
                             return Padding(
                               padding: const EdgeInsets.only(right: 8),
                               child: ChoiceChip(
                                 label: Text(range),
                                 selected: isSelected,
                                 onSelected: (selected) {
                                   if (selected) {
                                     if (range == 'Custom') {
                                       _selectCustomDateRange();
                                     } else {
                                       setState(() => _selectedTimeRange = range);
                                       _fetchAnalytics();
                                     }
                                   }
                                 },
                                 selectedColor: Colors.white,
                                 backgroundColor: Colors.white.withOpacity(0.2), // Use opacity
                                 labelStyle: TextStyle(
                                   color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF1A2E1A),
                                   fontWeight: FontWeight.bold,
                                 ),
                                 checkmarkColor: const Color(0xFFFFD700),
                                 side: BorderSide.none, 
                               ),
                             );
                           },
                         ),
                      ),

                      // View Selector Tabs
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _views.length,
                          itemBuilder: (context, index) {
                            final view = _views[index];
                            final isSelected = _selectedView == view;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedView = view),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(25),
                                  border: isSelected ? null : Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  view,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildSelectedView(provider),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectedView(AdminAnalyticsProvider provider) {
    // Add logic to switch views
    switch (_selectedView) {
      case 'Overview':
        return _buildOverviewTab(provider);
      case 'Sources':
        return _buildSourcesTab(provider);
      case 'Properties':
        return _buildPropertiesTab(provider);
      case 'Nationality':
        return _buildNationalityTab(provider);
      // For now, other tabs fall back to overview or placeholders
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  Widget _buildOverviewTab(AdminAnalyticsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Cards Grid
        Row(
          children: [
            Expanded(
              child: _buildGradientCard('Total Bookings', '${provider.totalBookings}', Icons.book,
                const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)])),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGradientCard('Revenue', '\$${provider.totalRevenue.toStringAsFixed(0)}', Icons.attach_money,
                const LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF43A047)])),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGradientCard('Avg Rating', provider.avgRating.toString(), Icons.star,
                const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)])),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGradientCard('Occupancy', '${provider.occupancyRate}%', Icons.home,
                const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)])),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Revenue Breakdown
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Financial Breakdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildFinancialRow('Total Revenue', provider.totalRevenue, Colors.green),
              const Divider(),
              _buildFinancialRow('Total Expenses', provider.totalExpenses, Colors.red, isNegative: true),
              const Divider(),
              _buildFinancialRow('Management Fees', provider.managementFees, Colors.orange, isNegative: true),
              const Divider(thickness: 2),
              _buildFinancialRow('Landlord Share', provider.landlordShare, const Color(0xFFFFD700), isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Quick Stats
        _buildQuickStatsCard(provider),
      ],
    );
  }

  Widget _buildFinancialRow(String label, double amount, Color color, {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            '${isNegative ? "-" : ""}\$${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientCard(String title, String value, IconData icon, LinearGradient gradient) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(AdminAnalyticsProvider provider) {
     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.05),
             blurRadius: 10,
             offset: const Offset(0, 2),
           ),
         ],
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text('Booking Sources Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
           const SizedBox(height: 16),
           _buildStatRow('App Bookings', provider.appBookings.toString()),
           const Divider(),
           _buildStatRow('External (iCal)', provider.icalBookings.toString()),
           const Divider(),
           _buildStatRow('Most Booked Property', provider.mostBookedProperty ?? 'N/A'),
         ],
       ),
     );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Placeholder builders for other tabs
  Widget _buildSourcesTab(AdminAnalyticsProvider provider) {
    final sources = provider.bookingsBySource;
    if (sources.isEmpty) return const Center(child: Text('No source data available'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Bookings by Source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                       sideTitles: SideTitles(
                         showTitles: true,
                         getTitlesWidget: (value, meta) {
                            final keys = sources.keys.toList();
                            if (value.toInt() >= 0 && value.toInt() < keys.length) {
                              return Text(keys[value.toInt()], style: const TextStyle(fontSize: 10));
                            }
                            return const Text('');
                         },
                       ),
                    ),
                  ),
                  barGroups: sources.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final value = (entry.value.value as num).toDouble();
                    return BarChartGroupData(
                      x: index,
                      barRods: [BarChartRodData(toY: value, color: const Color(0xFFFFD700))],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesTab(AdminAnalyticsProvider provider) {
     final ratings = provider.propertyRatings;
     if (ratings.isEmpty) return const Center(child: Text('No property data available'));
     
     return ListView.builder(
       shrinkWrap: true,
       physics: const NeverScrollableScrollPhysics(),
       itemCount: ratings.length,
       itemBuilder: (context, index) {
         final key = ratings.keys.elementAt(index);
         final value = ratings[key];
         return Card(
           margin: const EdgeInsets.only(bottom: 8),
           child: ListTile(
             title: Text(key),
             trailing: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 const Icon(Icons.star, color: Colors.amber, size: 20),
                 Text(value.toString()),
               ],
             ),
           ),
         );
       },
     );
  }

  Widget _buildNationalityTab(AdminAnalyticsProvider provider) {
    final nationalities = provider.bookingsByNationality;
    if (nationalities.isEmpty) return const Center(child: Text('No nationality data available'));

    return Column(
      children: nationalities.entries.map((e) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.flag),
            title: Text(e.key),
            trailing: Text('${e.value} bookings', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }
}
