import "package:flutter/material.dart";
import "package:intl/intl.dart";
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/providers/booking_provider.dart';
import 'package:hostify/legacy/providers/service_request_provider.dart';
import 'package:hostify/legacy/screens/auth_screen.dart';
import 'package:hostify/legacy/screens/guest_document_upload_screen.dart';
import 'package:hostify/legacy/core/theme/app_colors.dart';


class GuestServiceRequestScreen extends StatefulWidget {
  const GuestServiceRequestScreen({super.key});

  @override
  State<GuestServiceRequestScreen> createState() => _GuestServiceRequestScreenState();
}

class _GuestServiceRequestScreenState extends State<GuestServiceRequestScreen> {
  String _selectedCategory = 'Concierge';
  bool _isInit = true;

  final Map<String, List<Map<String, dynamic>>> _services = {
    'Concierge': [
      {'icon': Icons.person_outline, 'name': 'Butler', 'emoji': '🎩'},
      {'icon': Icons.local_airport, 'name': 'Airport Shuttle Bus', 'emoji': '✈️'},
      {'icon': Icons.directions_car, 'name': 'Car with Driver', 'emoji': '🚗'},
      {'icon': Icons.restaurant, 'name': 'Book Restaurant', 'emoji': '🍽️'},
      {'icon': Icons.breakfast_dining, 'name': 'Breakfast Special Request', 'emoji': '🥐'},
    ],
    'Excursions': [
      {'icon': Icons.tour, 'name': 'Book Trips', 'emoji': '🗺️'},
      {'icon': Icons.landscape, 'name': 'Book Sightseeing', 'emoji': '🏛️'},
      {'icon': Icons.water, 'name': 'Water Sports', 'emoji': '🏄'},
      {'icon': Icons.hiking, 'name': 'Desert Safari', 'emoji': '🏜️'},
    ],
    'Room Service': [
      {'icon': Icons.room_service, 'name': 'Book Breakfast', 'emoji': '🍳'},
      {'icon': Icons.egg, 'name': 'Extra Egg Request', 'emoji': '🥚'},
      {'icon': Icons.cleaning_services, 'name': 'Book Housekeeping', 'emoji': '🧹'},
      {'icon': Icons.local_laundry_service, 'name': 'Book Laundry', 'emoji': '👔'},
      {'icon': Icons.dry_cleaning, 'name': 'Extra Towels', 'emoji': '🏖️'},
      {'icon': Icons.coffee, 'name': 'Extra Coffee Capsules', 'emoji': '☕'},
      {'icon': Icons.inventory_2, 'name': 'Extra Room Supplies', 'emoji': '📦'},
      {'icon': Icons.note_add, 'name': 'Special Request', 'emoji': '📝'},
    ],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _loadData();
      _isInit = false;
    }
  }

  Future<void> _loadData() async {
    final user = context.read<AppStateProvider>().currentUser;
    if (user != null) {
      // Load bookings to find active stay
      await context.read<BookingProvider>().loadBookings(userId: user.id);
      // Load existing requests
      if (mounted) {
        await context.read<ServiceRequestProvider>().loadMyRequests(user.id);
      }
    }
  }

  void _showRequestDialog(Map<String, dynamic> service) {
    final user = context.read<AppStateProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in to request services.'),
          action: SnackBarAction(
            label: 'Sign In',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    // Check for document verification
    final userProfile = context.read<AppStateProvider>().userProfile;
    final isVerified = userProfile?['is_verified'] == true;

    if (!isVerified) {
       showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Identity Verification Required'),
          content: const Text('To ensure safety, please upload your identity documents before requesting services.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                 if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GuestDocumentUploadScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('Upload Documents'),
            ),
          ],
        ),
      );
      return;
    }

    // 1. Check for active booking
    final bookingProvider = context.read<BookingProvider>();
    final activeBookings = bookingProvider.bookings.where((b) {
      final status = b['status'];
      return status == 'confirmed' || status == 'active';
    }).toList();

    if (activeBookings.isEmpty) {
      _showNoActiveBookingDialog();
      return;
    }

    // Default to the most recent active booking
    final activeBooking = activeBookings.first;

    final detailsController = TextEditingController();
    final timeController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Text(service['emoji']),
              const SizedBox(width: 8),
              Expanded(child: Text(service['name'])),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeBookings.length > 1) ...[
                  const Text(
                    'Select Booking',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: activeBooking['id'],
                    isExpanded: true,
                    items: activeBookings.map((b) {
                      final propName = b['property-images'] != null ? b['property-images']['name'] : 'Property';
                      return DropdownMenuItem<String>(
                        value: b['id'],
                        child: Text(propName, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      // Handle booking selection if needed
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Request Details',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any specific requirements or preferences...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Preferred Time (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: timeController,
                  decoration: InputDecoration(
                    hintText: 'e.g., 9:00 AM, ASAP, Evening',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.room_service),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);
                      try {
                        final user = context.read<AppStateProvider>().currentUser!;
                        
                        await context.read<ServiceRequestProvider>().submitRequest(
                          bookingId: activeBooking['id'],
                          guestId: user.id,
                          propertyId: activeBooking['property_id'],
                          category: _selectedCategory,
                          serviceType: service['name'],
                          details: detailsController.text,
                          preferredTime: timeController.text,
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${service['name']} request submitted!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoActiveBookingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Active Booking'),
        content: const Text(
          'You need to have a confirmed or active booking to make service requests. Please book a stay first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Request Services'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category Tabs
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: _services.keys.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.yellow : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.yellow : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(category),
                              size: 18,
                              color: isSelected ? Colors.white : Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Service Cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: _getCategoryGradient(_selectedCategory),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getCategoryIcon(_selectedCategory),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCategory,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getCategoryDescription(_selectedCategory),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...(_services[_selectedCategory] ?? []).map((service) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildServiceCard(service),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return GestureDetector(
      onTap: () => _showRequestDialog(service),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                service['emoji'],
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                service['name'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Concierge':
        return Icons.room_service;
      case 'Excursions':
        return Icons.explore;
      case 'Room Service':
        return Icons.room_service;
      default:
        return Icons.help;
    }
  }

  String _getCategoryDescription(String category) {
    switch (category) {
      case 'Concierge':
        return 'Transportation, dining & special services';
      case 'Excursions':
        return 'Tours, trips & sightseeing activities';
      case 'Room Service':
        return 'In-room amenities & housekeeping';
      default:
        return '';
    }
  }

  Gradient _getCategoryGradient(String category) {
    switch (category) {
      case 'Concierge':
        return const LinearGradient(
          colors: [Color(0xFF2D3748), Color(0xFF1A202C)], // Hostify Dark Grey
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Excursions':
        return const LinearGradient(
          colors: [AppColors.yellow, Color(0xFFD4AF37)], // Hostify Yellow
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Room Service':
        return const LinearGradient(
          colors: [Color(0xFF718096), Color(0xFF4A5568)], // Hostify Slate
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(colors: [Colors.grey, Colors.grey]);
    }
  }
}
