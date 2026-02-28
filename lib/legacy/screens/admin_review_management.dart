import "package:flutter/material.dart";
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/admin_review_provider.dart';

class AdminReviewManagementScreen extends StatefulWidget {
  const AdminReviewManagementScreen({super.key});

  @override
  State<AdminReviewManagementScreen> createState() => _AdminReviewManagementScreenState();
}

class _AdminReviewManagementScreenState extends State<AdminReviewManagementScreen> {
  String? _selectedPropertyId = 'all';
  
  @override
  void initState() {
    super.initState();
    // Fetch reviews and properties on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminReviewProvider>();
      provider.fetchAllReviews();
      provider.fetchProperties();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminReviewProvider>(
      builder: (context, provider, child) {
        final filteredReviews = provider.getReviewsForProperty(_selectedPropertyId);
        final avgRating = provider.getAverageRating(_selectedPropertyId);

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Review Management'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Property Filter
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          const Text(
                            'Property:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPropertyId,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(value: 'all', child: Text('All Properties')),
                                    ...provider.properties.map((property) {
                                      return DropdownMenuItem(
                                        value: property['id'],
                                        child: Text(property['name']),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) => setState(() => _selectedPropertyId = value),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Summary Stats
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Reviews',
                              filteredReviews.length.toString(),
                              Icons.rate_review,
                              const Color(0xFF4FC3F7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Avg Rating',
                              avgRating.toStringAsFixed(1),
                              Icons.star,
                              const Color(0xFFFFB800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Reviews List
                    Expanded(
                      child: filteredReviews.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No reviews yet',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredReviews.length,
                              itemBuilder: (context, index) {
                                final review = filteredReviews[index];
                                final propertyName = review['property-images']?['name'] ?? 'Unknown Property';
                                final guestName = review['guest_name'] ?? 'Anonymous';
                                final rating = (review['overall_rating'] ?? review['rating'] ?? 0).toDouble();
                                final comment = review['review_text'] ?? review['comment'] ?? '';
                                final date = review['created_at'] != null 
                                    ? DateTime.parse(review['created_at']).toString().split(' ')[0]
                                    : '';
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.black,
                                              child: Text(
                                                guestName.isNotEmpty ? guestName[0].toUpperCase() : '?',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    guestName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  Text(
                                                    propertyName,
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                  ),
                                                  Row(
                                                    children: [
                                                      ...List.generate(5, (i) {
                                                        return Icon(
                                                          i < rating.floor() ? Icons.star : Icons.star_border,
                                                          size: 16,
                                                          color: const Color(0xFFFFB800),
                                                        );
                                                      }),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        rating.toStringAsFixed(1),
                                                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              date,
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          comment,
                                          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () async {
                                                try {
                                                  await provider.deleteReview(review['id']);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Review deleted')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Error: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                              icon: const Icon(Icons.delete, size: 18),
                                              label: const Text('Delete'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
