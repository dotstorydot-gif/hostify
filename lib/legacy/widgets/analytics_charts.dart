import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:fl_chart/fl_chart.dart";
import 'package:hostify/legacy/core/theme/app_colors.dart';


class RevenueByPropertyChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const RevenueByPropertyChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No revenue data available'));
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    
    // Take top 5 for better display
    final displayedEntries = sortedEntries.take(5).toList();
    final maxValue = displayedEntries.first.value as num;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Properties by Revenue',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
        ),
        const SizedBox(height: 16),
        ...displayedEntries.map((entry) {
          final double value = (entry.value as num).toDouble();
          final double percentage = maxValue > 0 ? value / maxValue : 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      NumberFormat.simpleCurrency(decimalDigits: 0).format(value),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: AppColors.lightGrey,
                    color: AppColors.yellow,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class BookingSourcePieChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const BookingSourcePieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Expected keys: 'app_bookings', 'ical_bookings'
    final double appCount = (data['app_bookings'] ?? 0).toDouble();
    final double icalCount = (data['ical_bookings'] ?? 0).toDouble();
    final total = appCount + icalCount;

    if (total == 0) {
      return const Center(child: Text('No booking data available'));
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  color: AppColors.info,
                  value: appCount,
                  title: '${((appCount / total) * 100).toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                PieChartSectionData(
                  color: AppColors.warning,
                  value: icalCount,
                  title: '${((icalCount / total) * 100).toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('App', AppColors.info),
            const SizedBox(width: 20),
            _buildLegendItem('iCal', AppColors.warning),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class GuestNationalityList extends StatelessWidget {
  final Map<String, dynamic> data;

  const GuestNationalityList({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    final sorted = data.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Guest Nationalities',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sorted.take(6).map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                '${e.key}: ${e.value}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
