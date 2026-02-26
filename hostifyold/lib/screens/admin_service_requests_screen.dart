import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostify/providers/service_request_provider.dart';
import 'package:intl/intl.dart';
import 'package:hostify/l10n/app_localizations.dart';

class AdminServiceRequestsScreen extends StatefulWidget {
  const AdminServiceRequestsScreen({super.key});

  @override
  State<AdminServiceRequestsScreen> createState() => _AdminServiceRequestsScreenState();
}

class _AdminServiceRequestsScreenState extends State<AdminServiceRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceRequestProvider>().fetchAllRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(l10n.serviceRequests),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ServiceRequestProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
          }

          if (provider.allRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.room_service_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noServiceRequests,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.allRequests.length,
            itemBuilder: (context, index) {
              final request = provider.allRequests[index];
              return _buildRequestCard(context, request, l10n);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request, AppLocalizations l10n) {
    final status = request['status'] ?? 'pending';
    final serviceType = request['service_type'] ?? 'other';
    final guestName = request['user_profiles']?['full_name'] ?? 'Unknown Guest';
    final propertyName = request['property-images']?['name'] ?? 'Unknown Property';
    final createdAt = DateTime.parse(request['created_at']);
    final dateStr = DateFormat.yMMMd().add_Hm().format(createdAt);

    Color statusColor;
    String statusText;
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = l10n.pending;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusText = l10n.inProgress;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = l10n.completed;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = l10n.cancelled;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getLocalizedServiceType(serviceType, l10n),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Guest: $guestName', style: const TextStyle(fontSize: 14)),
            Text('Property: $propertyName', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            if (request['details'] != null && request['details'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request['details'],
                style: TextStyle(color: Colors.grey[800], fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                _buildActionButton(context, request['id'], 'in_progress', Colors.blue, l10n.inProgress),
                const SizedBox(width: 8),
                _buildActionButton(context, request['id'], 'completed', Colors.green, l10n.completed),
                const SizedBox(width: 8),
                _buildActionButton(context, request['id'], 'cancelled', Colors.red, l10n.cancelled),
              ],
            ),
          ],
        ),
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

  Widget _buildActionButton(BuildContext context, String requestId, String status, Color color, String label) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: () => _updateStatus(context, requestId, status),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String requestId, String status) async {
    try {
      await context.read<ServiceRequestProvider>().updateRequestStatus(requestId, status);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.statusUpdatedTo(status))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
