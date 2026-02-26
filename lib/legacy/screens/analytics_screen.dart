import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/admin_analytics_provider.dart';
import 'package:hostify/legacy/providers/admin_booking_provider.dart';
import 'package:hostify/legacy/providers/admin_review_provider.dart';
import 'package:hostify/legacy/providers/property_provider.dart';
import 'package:hostify/legacy/widgets/landlord_filter_section.dart';
import 'package:hostify/legacy/widgets/analytics_charts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsScreen extends StatefulWidget {
  final String? propertyName;
  final String? propertyId;
  
  const AnalyticsScreen({super.key, this.propertyName, this.propertyId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final String _selectedPeriod = 'YTD'; // Year to Date, Month, Year
  bool _isFilterExpanded = false;
  final bool _showNetProfitDetails = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Local state for filter syncing
  late String _rangeMode;
  late int _selectedYear;
  late DateTime _selectedMonth;
  
  // Mock booked dates removed - will come from provider if needed, or we just show calendar for visual
  final List<DateTime> _bookedDates = []; 

  @override
  void initState() {
    super.initState();
    _initFilterState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminAnalyticsProvider>().fetchAnalytics(propertyId: widget.propertyId);
      context.read<AdminReviewProvider>().fetchAllReviews();
      
      // Fetch bookings for calendar
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        context.read<AdminBookingProvider>().fetchBookingsForLandlord(user.id);
      }
      
      _showAnnouncementPopup();
    });
  }

  void _initFilterState() {
     // Default values
     _rangeMode = 'Year';
     _selectedYear = DateTime.now().year;
     _selectedMonth = DateTime.now();
  }

  void _onFilterChanged(DateTime start, DateTime end, String? propertyId, String label) {
    if (!mounted) return;
    setState(() {
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

  void _showAnnouncementPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign, color: Color(0xFFFFD700), size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'System Update',
                style: TextStyle(
                  color: Color(0xFF2D3748),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'System maintenance scheduled for next Saturday from 2 AM to 4 AM. Please plan accordingly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getBookingsForDay(DateTime day) {
    // Normalize date to UTC midnight for map lookup
    final key = DateTime.utc(day.year, day.month, day.day);
    final allBookings = context.read<AdminBookingProvider>().bookings[key] ?? [];
    
    // If viewing specific property, filter
    if (widget.propertyName != null && widget.propertyName != 'All Properties') {
       // Ideally filter by ID but we only have name here. 
       // For now, show all bookings if 'All Properties', or try to match name.
       // Since propertyName is just a String in this widget, matching is hard without ID.
       // We'll show all Landlord bookings for now to ensure data visibility as requested.
       return allBookings;
    }
    return allBookings;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.propertyName ?? 'All Properties';
    
    return Consumer3<AdminAnalyticsProvider, AdminReviewProvider, PropertyProvider>(
      builder: (context, analytics, reviewsProvider, propertyProvider, child) {
        // ... (loading check)
        if (analytics.isLoading) {
          return Scaffold(
            appBar: AppBar(title: Text('$displayName Analytics'), backgroundColor: Colors.black),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);
        
        // Use real data
        final totalRevenue = analytics.totalRevenue;
        final landlordShare = analytics.landlordShare; // Net Revenue
        final totalBookings = analytics.totalBookings;
        final occupancyRate = analytics.occupancyRate;
        final avgRating = analytics.avgRating;

        // Use real expenses from DB (0 if none uploaded)
        final expenses = analytics.totalExpenses;
        
        // Filter reviews for this landlord
        final landlordPropertyIds = propertyProvider.properties.map((p) => p['id']).toSet();
        final reviews = reviewsProvider.reviews.where((r) => landlordPropertyIds.contains(r['property_id'])).toList();

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text('$displayName Analytics'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
               IconButton(
                 icon: Icon(_isFilterExpanded ? Icons.filter_list_off : Icons.filter_list, color: Colors.white),
                 onPressed: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                 tooltip: 'Toggle Filters',
               ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LandlordFilterSection(
                  isExpanded: _isFilterExpanded,
                  onToggle: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
                  // Prioritize widget.propertyId (Navigation Intent) over provider state (Stale/Global)
                  initialPropertyId: widget.propertyId ?? analytics.propertyId,
                  initialRangeMode: _rangeMode,
                  initialYear: _selectedYear,
                  initialMonth: _selectedMonth,
                  onFilterChanged: _onFilterChanged,
                ),
                
                const SizedBox(height: 12),
                // Stats
                _buildStatCard(
                  'NET REVENUE',
                  currencyFormat.format(landlordShare),
                  Icons.payments,
                  const Color(0xFF4CAF50),
                  subtitle: 'After 15% Management Fee',
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'BOOKINGS',
                        totalBookings.toString(),
                        Icons.bookmark_added,
                        const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'TOTAL NIGHTS',
                        analytics.totalBookedNights.toString(),
                        Icons.nights_stay,
                        const Color(0xFF9C27B0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'OCCUPANCY',
                        '${occupancyRate.toStringAsFixed(1)}%',
                        Icons.home_work,
                        const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'EXPENSES',
                        currencyFormat.format(expenses),
                        Icons.receipt_long,
                        const Color(0xFF009688),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                 _buildStatCard(
                  'AVG RATING',
                  avgRating.toStringAsFixed(1),
                  Icons.star,
                  const Color(0xFFFFC107),
                  subtitle: '${reviews.length} reviews',
                ),
                const SizedBox(height: 24),

                // Detailed Insights Section
                if (analytics.propertyRevenues.isNotEmpty || analytics.bookingsBySource.isNotEmpty || analytics.bookingsByNationality.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detailed Insights',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // Booking Source
                        if (analytics.bookingsBySource.isNotEmpty) ...[
                          const Text(
                            'Booking Sources',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 16),
                          BookingSourcePieChart(data: analytics.bookingsBySource),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                        ],

                        // Revenue by Property (only if multiple properties are being viewed)
                        if (analytics.propertyId == null && analytics.propertyRevenues.isNotEmpty) ...[
                          RevenueByPropertyChart(data: analytics.propertyRevenues),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                        ],
                        
                        // Nationalities
                        if (analytics.bookingsByNationality.isNotEmpty) ...[
                          GuestNationalityList(data: analytics.bookingsByNationality),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
                
                // Calendar Section
                Consumer<AdminBookingProvider>(
                  builder: (context, bookingProvider, _) {
                    return Container(
                       margin: const EdgeInsets.only(bottom: 20),
                       padding: const EdgeInsets.all(16),
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
                            const Text(
                              'Booking Calendar',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                            ),
                            const SizedBox(height: 8),
                           TableCalendar(
                              firstDay: DateTime.utc(2025, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: _focusedDay,
                              currentDay: DateTime.now(),
                              calendarFormat: CalendarFormat.month, // Fixed format
                              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              calendarStyle: CalendarStyle(
                                todayDecoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: const BoxDecoration(
                                  color: Color(0xFFFFD700),
                                  shape: BoxShape.circle,
                                ),
                                markerDecoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, date, events) {
                                  if (events.isEmpty) return const SizedBox();
                                  return Positioned(
                                    bottom: 1,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: events.take(3).map((_) => Container(
                                        width: 6, height: 6,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                      )).toList(),
                                    ),
                                  );
                                },
                              ),
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                              ),
                              eventLoader: _getBookingsForDay,
                            ),
                            if (_selectedDay != null) ...[
                               const SizedBox(height: 12),
                               const Divider(),
                               ..._getBookingsForDay(_selectedDay!).map((booking) => Padding(
                                 padding: const EdgeInsets.symmetric(vertical: 4),
                                 child: Row(
                                   children: [
                                     Icon(Icons.circle, size: 8, color: booking['source'] == 'hostify' ? Colors.blue : Colors.orange),
                                     const SizedBox(width: 8),
                                     Expanded(child: Text(booking['property'] ?? 'Property', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                     Text(booking['status'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                   ],
                                 ),
                               )),
                            ],
                            
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            // Summary Stats
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildCalendarStat('Total Nights', '${analytics.totalBookedNights}', Icons.nights_stay, Colors.purple),
                                _buildCalendarStat('App Bookings', '${analytics.appBookings}', Icons.phone_android, Colors.blue),
                                _buildCalendarStat('iCal Bookings', '${analytics.icalBookings}', Icons.sync, Colors.orange),
                              ],
                            ),
                         ],
                       ),
                    );
                  }
                ),

                // Reviews Section
                Container(
                  padding: const EdgeInsets.all(20),
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
                          const Text(
                            'Recent Reviews',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          Text(
                            '${reviews.length} reviews',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      reviews.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text("No reviews yet")),
                            )
                          : CarouselSlider(
                              options: CarouselOptions(
                                height: 180,
                                viewportFraction: 0.9,
                                enlargeCenterPage: true,
                                autoPlay: false,
                              ),
                              items: reviews.take(5).map((review) {
                                final guestName = review['guest_name'] ?? 'Guest';
                                final rating = (review['overall_rating'] ?? 5.0).toDouble();
                                final comment = review['review_text'] ?? review['comment'] ?? '';
                                final date = review['created_at'] != null 
                                    ? DateFormat.yMMMd().format(DateTime.parse(review['created_at'])) 
                                    : 'Recent';
                                return _buildReviewCard(guestName, rating, comment, date);
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildStatCard(String label, String value, IconData icon, Color accentColor, {String? subtitle}) {
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
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
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarWithValue(String label, double pct, Color color, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 140 * pct,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.7), color],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildExpenseRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF44A08D),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2D3748),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(String name, double rating, String review, String date) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.black,
                child: Text(
                  name[0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.floor() ? Icons.star : Icons.star_border,
                            size: 14,
                            color: const Color(0xFFFFB800),
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          rating.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRating(IconData icon, String label, String rating, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          rating,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
