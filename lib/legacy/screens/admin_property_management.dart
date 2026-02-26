import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/providers/property_provider.dart';
import 'package:hostify/legacy/screens/admin_property_edit_screen.dart';
import 'package:hostify/legacy/widgets/global_error_dialog.dart';

class AdminPropertyManagement extends StatefulWidget {
  const AdminPropertyManagement({super.key});

  @override
  State<AdminPropertyManagement> createState() => _AdminPropertyManagementState();
}

class _AdminPropertyManagementState extends State<AdminPropertyManagement> {
  @override
  void initState() {
    super.initState();
    // Fetch properties when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppStateProvider>().currentUser;
      if (user != null) {
        context.read<PropertyProvider>().fetchLandlordProperties(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Green Header
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Property Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Summary Card
                Consumer<PropertyProvider>(
                  builder: (context, provider, _) {
                    final properties = provider.properties;
                    final unitCount = properties.fold<int>(0, (sum, p) => sum + 1); // Mock unit count logic if needed

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.home_work,
                              color: Color(0xFFFFD700),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Properties',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${properties.length} properties',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
          
          // Properties List
          Expanded(
            child: Consumer<PropertyProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text('Error: ${provider.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            final user = context.read<AppStateProvider>().currentUser;
                            if (user != null) {
                              provider.fetchLandlordProperties(user.id);
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.properties.isEmpty) {
                  return const Center(child: Text('No properties found. Add one!'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: provider.properties.length,
                  itemBuilder: (context, index) {
                    final property = provider.properties[index];
                    final isActive = property['status'] == 'Active';
                    final imageUrl = property['image'];
                    
                    return Dismissible(
                      key: Key(property['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Property?'),
                            content: Text('Are you sure you want to delete "${property['name']}"? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) async {
                        try {
                          final user = context.read<AppStateProvider>().currentUser;
                          if (user != null) {
                            await context.read<PropertyProvider>().deleteProperty(property['id'], user.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Property deleted')),
                              );
                            }
                          }
                        } catch (e) {
                          // Show error dialog and refresh list
                          if (context.mounted) {
                            GlobalDialogs.showError(
                              context,
                              'Failed to delete property',
                              e.toString(),
                            );
                            // Refresh list to bring it back if failed
                            final user = context.read<AppStateProvider>().currentUser;
                            if (user != null) {
                               context.read<PropertyProvider>().fetchLandlordProperties(user.id);
                            }
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                              image: imageUrl != null && imageUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            ),
                            child: (imageUrl == null || imageUrl.isEmpty) 
                              ? const Icon(Icons.apartment, color: Colors.grey)
                              : null,
                          ),
                          title: Text(
                            property['name'] ?? 'Unnamed Property',
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
                                property['location'] ?? 'No location',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.bed,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${property['bedrooms'] ?? 0} beds',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green[50] : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      property['status'] ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isActive ? Colors.green[700] : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFFFFD700)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminPropertyEditScreen(
                                    propertyId: property['id'],
                                    propertyName: property['name'],
                                  ),
                                ),
                              ).then((_) {
                                // Refresh properties after returning from edit
                                final user = context.read<AppStateProvider>().currentUser;
                                if (user != null) {
                                  context.read<PropertyProvider>().fetchLandlordProperties(user.id);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      
      // Add Property FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminPropertyEditScreen(
                propertyId: null, // null means new property
                propertyName: '', 
              ),
            ),
          ).then((_) {
             // Refresh properties after returning
             final user = context.read<AppStateProvider>().currentUser;
             if (user != null) {
               context.read<PropertyProvider>().fetchLandlordProperties(user.id);
             }
          });
        },
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Property'),
      ),
    );
  }
}
