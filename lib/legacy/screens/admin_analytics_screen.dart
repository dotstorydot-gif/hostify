import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/admin_analytics_provider.dart';
import 'package:hostify/legacy/widgets/analytics_charts.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  String _selectedTimeRange = 'Year';
  String _selectedYear = '2026';
  final List<String> _timeRanges = ['Month', 'Year'];
  final List<String> _years = ['2024', '2025', '2026'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _fetchData() {
    DateTime start;
    DateTime end;
    
    if (_selectedTimeRange == 'Year') {
      start = DateTime(int.parse(_selectedYear), 1, 1);
      end = DateTime(int.parse(_selectedYear), 12, 31);
    } else {
      // Default to Current Year YTD if not specific
      start = DateTime(DateTime.now().year, 1, 1);
      end = DateTime.now();
    }

    context.read<AdminAnalyticsProvider>().fetchAnalytics(
      startDate: start,
      endDate: end,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Admin Analytics'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time & Year Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  child: DropdownButton<String>(
                    value: _selectedTimeRange,
                    underline: const SizedBox(),
                    items: _timeRanges.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) {
                      setState(() => _selectedTimeRange = val!);
                      _fetchData();
                    },
                  ),
                ),
                if (_selectedTimeRange == 'Year'|| _selectedTimeRange == 'Quarter')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      underline: const SizedBox(),
                      items: _years.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedYear = val!);
                        _fetchData();
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Consumer<AdminAnalyticsProvider>(
              builder: (context, analytics, child) {
                if (analytics.isLoading) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ));
                }

                final currency = NumberFormat.simpleCurrency(decimalDigits: 0);
                
                return Column(
                  children: [
                    // KPI Cards
                    _buildGradientCard(
                      'TOTAL REVENUE',
                      currency.format(analytics.totalRevenue),
                      Icons.trending_up,
                      const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFFE5196)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGradientCard(
                            'LANDLORD SHARE',
                            currency.format(analytics.landlordShare),
                            Icons.account_balance_wallet,
                            const LinearGradient(
                              colors: [Color(0xFF4FC3F7), Color(0xFF5E92F3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGradientCard(
                            'FEES (15%)',
                            currency.format(analytics.managementFees),
                            Icons.pie_chart,
                            const LinearGradient(
                              colors: [Color(0xFFFF9A56), Color(0xFFFF7E3D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGradientCard(
                            'OCCUPANCY',
                            '${analytics.occupancyRate.toStringAsFixed(1)}%',
                            Icons.bed,
                            const LinearGradient(
                              colors: [Color(0xFFB57BFF), Color(0xFF9B5DE5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGradientCard(
                            'EXPENSES',
                            currency.format(analytics.totalExpenses),
                            Icons.receipt_long,
                            const LinearGradient(
                              colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Financial Summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Financial Summary",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                          ),
                          const SizedBox(height: 16),
                          _buildFinanceRow("Gross Revenue", currency.format(analytics.totalRevenue), isBold: true),
                          const Divider(height: 24),
                          _buildFinanceRow("Management Fees (15%)", "-${currency.format(analytics.managementFees)}", color: Colors.red[400]),
                          _buildFinanceRow("Unit Expenses", "-${currency.format(analytics.totalExpenses)}", color: Colors.red[400]),
                          const Divider(height: 24),
                          _buildFinanceRow("Landlord Payout", currency.format(analytics.landlordShare), isBold: true, color: const Color(0xFF44A08D)),
                        ],
                      ),
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

                            // Revenue by Property
                            if (analytics.propertyRevenues.isNotEmpty) ...[
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
                  ],
                );
              }
            ),
            const SizedBox(height: 24),

            // Info Note
            Container(
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Analytics Overview",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "This dashboard shows the aggregated financial metrics across all properties. For property-specific details, please use the Landlord Dashboard.",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientCard(String label, String value, IconData icon, Gradient gradient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF2D3748),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF2D3748),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double pct, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: 150 * pct,
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
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
