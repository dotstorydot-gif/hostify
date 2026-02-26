import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/services/icalendar_sync_service.dart';
import 'package:hostify/legacy/providers/property_provider.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';

class AdminICalManagementScreen extends StatefulWidget {
  const AdminICalManagementScreen({super.key});

  @override
  State<AdminICalManagementScreen> createState() => _AdminICalManagementScreenState();
}

class _AdminICalManagementScreenState extends State<AdminICalManagementScreen> {
  final ICalendarSyncService _syncService = ICalendarSyncService();
  String? _selectedPropertyId;
  String? _selectedPropertyName;
  List<BookingData> _bookings = [];
  List<Map<String, dynamic>> _currentFeeds = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProperties();
    });
  }

  Future<void> _fetchProperties() async {
    final user = context.read<AppStateProvider>().currentUser;
    if (user != null) {
      await context.read<PropertyProvider>().fetchLandlordProperties(user.id);
      final properties = context.read<PropertyProvider>().properties;
      
      if (properties.isNotEmpty && mounted) {
        setState(() {
          _selectedPropertyId = properties.first['id'];
          _selectedPropertyName = properties.first['name'];
        });
        _loadBookings();
      }
    }
  }

  Future<void> _loadBookings() async {
    if (_selectedPropertyId == null) return;
    
    setState(() => _loading = true);
    try {
      final bookings = await _syncService.syncPropertyBookings(_selectedPropertyId!);
      final feeds = await _syncService.getFeeds(_selectedPropertyId!);
      
      setState(() {
        _bookings = bookings;
        _currentFeeds = feeds;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _showAddFeedDialog(String platform) async {
    if (_selectedPropertyId == null) return;
    
    final controller = TextEditingController();
    
    // Fetch existing feeds for pre-filling
    final feeds = await _syncService.getFeeds(_selectedPropertyId!);
    final existingUrl = feeds.firstWhere(
      (f) => (f['calendar_source'] as String).toLowerCase().contains(platform.toLowerCase()) || 
             (f['feed_url'] as String).toLowerCase().contains(platform.toLowerCase()),
      orElse: () => {'feed_url': ''},
    )['feed_url'] as String;

    controller.text = existingUrl;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$platform iCal Feed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the iCalendar feed URL from $platform for $_selectedPropertyName',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'iCal URL',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'https://...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How to get this URL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    platform == 'Booking.com'
                        ? '1. Go to Booking.com Extranet\n2. Select "Calendar"\n3. "Sync calendars" -> "Export calendar"'
                        : '1. Go to Airbnb "Calendar"\n2. "Availability settings"\n3. "Export calendar"',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Syncs ALL bookings: past years (2024, 2025) + future',
                            style: TextStyle(fontSize: 10, color: Colors.blue[900]),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                String source = platform;
                
                await _syncService.addFeed(_selectedPropertyId!, controller.text, source);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$platform feed saved. Click refresh to sync!')),
                  );
                  _loadBookings(); // Reload to refresh feeds list and bookings
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Error saving feed: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('Save & Sync'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iCalendar Sync'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Refresh & Sync All',
          ),
        ],
      ),
      body: Consumer<PropertyProvider>(
        builder: (context, propertyProvider, _) {
          final properties = propertyProvider.properties;
          
          if (propertyProvider.isLoading && properties.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (properties.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_work, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No properties found',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add properties first in Property Management',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Property Selector
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Property', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPropertyId,
                            isExpanded: true,
                            items: properties.map((p) {
                              return DropdownMenuItem<String>(
                                value: p['id'],
                                child: Text(p['name'] ?? 'Unknown'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final property = properties.firstWhere((p) => p['id'] == val);
                                setState(() {
                                  _selectedPropertyId = val;
                                  _selectedPropertyName = property['name'];
                                });
                                _loadBookings();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Platform Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildPlatformCard('Booking.com', Icons.hotel, const Color(0xFF003580)),
                      const SizedBox(height: 12),
                      _buildPlatformCard('Airbnb', Icons.home, const Color(0xFFFF5A5F)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Synced Bookings Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Synced Bookings (${_bookings.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_loading) const CircularProgressIndicator(strokeWidth: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bookings List
                _loading && _bookings.isEmpty 
                  ? const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                  : _bookings.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.calendar_today, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No bookings found for $_selectedPropertyName',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add iCal feeds above to sync bookings',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) {
                            final booking = _bookings[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getSourceColor(booking.source).withValues(alpha: 0.1),
                                  child: Icon(_getSourceIcon(booking.source), color: _getSourceColor(booking.source), size: 20),
                                ),
                                title: Text(booking.guestName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${_formatDate(booking.startDate)} - ${_formatDate(booking.endDate)}'),
                                trailing: Chip(
                                  label: Text(booking.source, style: const TextStyle(color: Colors.white, fontSize: 10)),
                                  backgroundColor: _getSourceColor(booking.source),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            );
                          },
                        ),
                 const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlatformCard(String platform, IconData icon, Color color) {
    final isConnected = _currentFeeds.any((f) => 
        (f['calendar_source'] as String?)?.toLowerCase().contains(platform.toLowerCase()) ?? false
        || (f['feed_url'] as String).toLowerCase().contains(platform.toLowerCase())
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(platform, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          isConnected ? 'Connected • Syncing all dates' : 'Not connected',
          style: TextStyle(color: isConnected ? Colors.green : Colors.grey),
        ),
        trailing: ElevatedButton(
          onPressed: () => _showAddFeedDialog(platform),
          style: ElevatedButton.styleFrom(
            backgroundColor: isConnected ? Colors.grey[200] : color,
            foregroundColor: isConnected ? Colors.black87 : Colors.white,
            elevation: 0,
          ),
          child: Text(isConnected ? 'Configure' : 'Connect'),
        ),
      ),
    );
  }

  Color _getSourceColor(String source) {
    if (source.toLowerCase().contains('booking')) return const Color(0xFF003580);
    if (source.toLowerCase().contains('airbnb')) return const Color(0xFFFF5A5F);
    return const Color(0xFFFFD700);
  }

  IconData _getSourceIcon(String source) {
    if (source.toLowerCase().contains('booking')) return Icons.hotel;
    if (source.toLowerCase().contains('airbnb')) return Icons.home;
    return Icons.villa;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
