import 'package:flutter/material.dart';
import 'package:hostify/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hostify/providers/app_state_provider.dart';
import 'package:hostify/providers/service_request_provider.dart';
import 'package:hostify/providers/notification_provider.dart';
import 'package:hostify/widgets/notification_bell.dart';
import 'package:hostify/screens/guest_service_request_screen.dart';
import 'package:hostify/screens/guest_rating_screen.dart';
import 'package:hostify/screens/guest_my_bookings_screen.dart';
import 'package:hostify/screens/guest_my_requests_screen.dart';
import 'package:hostify/screens/profile_screen.dart';

class GuestDashboard extends StatefulWidget {
  const GuestDashboard({super.key});

  @override
  State<GuestDashboard> createState() => _GuestDashboardState();
}

class _GuestDashboardState extends State<GuestDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppStateProvider>().currentUser;
      if (user != null) {
        context.read<ServiceRequestProvider>().loadMyRequests(user.id);
        context.read<NotificationProvider>().fetchNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // For now, mockup active booking
    final Map<String, dynamic>? booking = null; 

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
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
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: const Icon(Icons.person, size: 32, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.hello}!',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            Consumer<AppStateProvider>(
                              builder: (context, appState, child) {
                                final name = appState.userName ?? l10n.guest;
                                return Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Booking Card
                  if (booking != null)
                    _buildCurrentBookingCard(booking, l10n)
                  else
                    _buildNoBookingCard(l10n),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.quickActions,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          l10n.requestServices,
                          Icons.room_service,
                          [const Color(0xFF2D3748), const Color(0xFF1A202C)], // Hostify Dark Grey
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestServiceRequestScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          l10n.rateStay,
                          Icons.star,
                          [const Color(0xFFFFD700), const Color(0xFFD4AF37)], // Hostify Yellow
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestRatingScreen(propertyId: '', bookingId: ''))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // My Requests Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.serviceRequests,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestMyRequestsScreen())),
                        child: Text(l10n.viewAll),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Consumer<ServiceRequestProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading && provider.requests.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (provider.requests.isEmpty) {
                        return _buildEmptyRequestsState(l10n);
                      }
                      return Column(
                        children: provider.requests.take(3).map((req) => _buildRequestItem(req, l10n)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBookingCard(Map<String, dynamic> booking, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.currentStay, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                child: Text(booking['status'], style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(booking['propertyName'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(l10n.unit(booking['unitName']), style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildNoBookingCard( AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Icon(Icons.event_busy, color: Colors.grey, size: 48),
          const SizedBox(height: 12),
          Text(l10n.noUpcomingBookings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(l10n.welcomeMessage, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, List<Color> colors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRequestsState(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(l10n.noServiceRequests, style: TextStyle(color: Colors.grey[600])),
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request, AppLocalizations l10n) {
    final status = request['status'] ?? 'pending';
    final type = request['service_type'] ?? 'other';
    
    Color statusColor = Colors.orange;
    if (status == 'completed') statusColor = Colors.green;
    if (status == 'in_progress') statusColor = Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.room_service, color: statusColor),
        title: Text(_getLocalizedServiceType(type, l10n)),
        subtitle: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestMyRequestsScreen())),
      ),
    );
  }

  String _getLocalizedServiceType(String type, AppLocalizations l10n) {
    switch (type.toLowerCase()) {
      case 'room_service': return l10n.roomService;
      case 'concierge': return l10n.concierge;
      case 'maintenance': return l10n.maintenance;
      case 'excursions': return l10n.excursions;
      case 'transport': return l10n.transport;
      default: return l10n.other;
    }
  }
}
