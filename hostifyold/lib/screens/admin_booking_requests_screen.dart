import 'package:flutter/material.dart';
import 'package:hostify/services/booking_service.dart';

class AdminBookingRequestsScreen extends StatefulWidget {
  const AdminBookingRequestsScreen({super.key});

  @override
  State<AdminBookingRequestsScreen> createState() => _AdminBookingRequestsScreenState();
}

class _AdminBookingRequestsScreenState extends State<AdminBookingRequestsScreen> {
  final BookingService _bookingService = BookingService();
  List<Map<String, dynamic>> _pendingBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingBookings();
  }

  Future<void> _loadPendingBookings() async {
    try {
      final bookings = await _bookingService.getPendingBookings();
      if (mounted) {
        setState(() {
          _pendingBookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading requests: $e')),
        );
      }
    }
  }

  Future<void> _processRequest(String bookingId, bool approve) async {
    try {
      await _bookingService.updateBookingStatus(
        bookingId, 
        approve ? 'confirmed' : 'cancelled'
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Booking Approved' : 'Booking Rejected'),
            backgroundColor: approve ? const Color(0xFFFFD700) : Colors.red,
          ),
        );
        _loadPendingBookings(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing request: $e')),
        );
      }
    }
  }

  Widget _buildBookingSourceBadge(String? source) {
    Color color;
    String label;
    
    switch (source) {
      case 'booking_com':
        color = Colors.blue;
        label = 'Booking.com';
        break;
      case 'airbnb':
        color = Colors.red;
        label = 'Airbnb';
        break;
      default:
        color = const Color(0xFFFFD700);
        label = 'Direct';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pending Requests'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _pendingBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No pending requests',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingBookings.length,
                  itemBuilder: (context, index) {
                    final booking = _pendingBookings[index];
                    final guest = booking['user_profiles'] ?? {};
                    final property = booking['property-images'] ?? {};
                    final checkIn = DateTime.parse(booking['check_in']);
                    final checkOut = DateTime.parse(booking['check_out']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildBookingSourceBadge(booking['booking_source']),
                                Text(
                                  '${booking['nights']} Nights',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              property['name'] ?? 'Unknown Property',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Guest: ${guest['full_name'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              '${checkIn.day}/${checkIn.month} - ${checkOut.day}/${checkOut.month}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                             Text(
                              'Total: \$${booking['total_price']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _processRequest(booking['id'], false),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _processRequest(booking['id'], true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
