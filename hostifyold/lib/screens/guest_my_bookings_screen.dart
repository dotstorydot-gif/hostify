import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hostify/providers/booking_provider.dart';
import 'package:hostify/providers/app_state_provider.dart';
import 'package:hostify/utils/loading_utils.dart';

class GuestMyBookingsScreen extends StatefulWidget {
  const GuestMyBookingsScreen({super.key});

  @override
  State<GuestMyBookingsScreen> createState() => _GuestMyBookingsScreenState();
}

class _GuestMyBookingsScreenState extends State<GuestMyBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  Future<void> _loadBookings() async {
    final user = context.read<AppStateProvider>().currentUser;
    if (user != null) {
      context.read<BookingProvider>().loadBookings(userId: user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bookings', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.black, // Dark Header mimicking Booking.com Blue
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          )
        ],
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return LoadingUtils.skeletonLoader(
               itemCount: 3,
               height: 80,
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}'),
                  TextButton(
                    onPressed: _loadBookings,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings found',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: provider.bookings.length,
            separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final booking = provider.bookings[index];
              final property = booking['property-images'] ?? {'name': 'Unknown Property'};
              
              final status = (booking['status'] as String? ?? 'pending').toLowerCase();
              final checkIn = DateTime.parse(booking['check_in']);
              final checkOut = DateTime.parse(booking['check_out']);
              
              final dateString = '${checkIn.day}–${checkOut.day} ${DateFormat('MMM yyyy').format(checkIn)}';
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  property['name'] ?? 'Unknown Location',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      dateString,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Status: ${toBeginningOfSentenceCase(status)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.more_vert, color: Colors.black54),
                onTap: () {
                  // Navigate to booking details
                },
              );
            },
          );
        },
      ),
    );
  }
}
