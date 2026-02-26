import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hostify/providers/app_state_provider.dart';
import 'package:hostify/providers/property_provider.dart';
import 'package:hostify/screens/property_detail_screen.dart';
import 'package:hostify/screens/guest_service_request_screen.dart';
import 'package:hostify/screens/guest_document_upload_screen.dart';
import 'package:hostify/screens/auth_screen.dart';
import 'package:hostify/providers/document_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hostify/core/theme/app_colors.dart';

class BookingScreen extends StatefulWidget {
  final bool showNavigation;
  
  const BookingScreen({super.key, this.showNavigation = true});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // Search parameters
  String _selectedLocation = 'El Gouna';
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  int _rooms = 1;
  int _adults = 2;
  int _children = 0;
  
  bool _showAnnouncement = true;
  final String _announcementText = "🎉 Extra 5% Discount for Direct Booking Requests!";
  bool _isInit = true;

  Map<String, int> _cityCounts = {};

  Future<void> _fetchCityCounts() async {
    final supabase = Supabase.instance.client;
    final cities = ['Cairo', 'Hurghada', 'El Gouna', 'Dahab'];
    for (String city in cities) {
      try {
        final res = await supabase.from('property-images').select('id').ilike('location', '%$city%');
        if (mounted) {
          setState(() {
            _cityCounts[city] = (res as List).length;
          });
        }
      } catch (e) {
        // Silently skip if error occurs
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      // Initial fetch of properties safely after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _performSearch();
          _fetchCityCounts();
        }
      });
      _isInit = false;
    }
  }

  void _showDatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DatePickerModal(
        checkIn: _checkInDate,
        checkOut: _checkOutDate,
        onApply: (checkIn, checkOut) {
          setState(() {
            _checkInDate = checkIn;
            _checkOutDate = checkOut;
          });
        },
      ),
    );
  }

  Future<void> _performSearch() async {
    // Dismiss keyboard if open
    FocusScope.of(context).unfocus();

    await context.read<PropertyProvider>().fetchProperties(
      location: _selectedLocation == 'El Gouna' ? null : _selectedLocation, // If default, fetch all or handle logic
      checkIn: _checkInDate,
      checkOut: _checkOutDate,
      guests: _adults + _children,
      rooms: _rooms,
    );

    if (mounted) {
      final count = context.read<PropertyProvider>().properties.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found $count properties'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  final List<String> _locations = [
    'El Gouna',
    'Hurghada',
    'Sahl Hasheesh',
    'Cairo',
    'Marsa Alam',
  ];

  void _showLocationSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Select Destination',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._locations.map((location) => ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(location),
              trailing: _selectedLocation == location 
                  ? const Icon(Icons.check, color: AppColors.yellow)
                  : null,
              onTap: () {
                setState(() => _selectedLocation = location);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showGuestSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _GuestSelectorModal(
        rooms: _rooms,
        adults: _adults,
        children: _children,
        onApply: (rooms, adults, children) {
          setState(() {
            _rooms = rooms;
            _adults = adults;
            _children = children;
          });
        },
      ),
    );
  }




  bool _isVerified = false;
  bool _isLoadingVerification = true;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    final user = context.read<AppStateProvider>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingVerification = false);
      return;
    }

    try {
      await context.read<DocumentProvider>().fetchUserDocuments(user.id);
      if (mounted) {
        final docs = context.read<DocumentProvider>().userDocuments;
        setState(() {
          _isVerified = docs.isNotEmpty;
          _isLoadingVerification = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVerification = false);
    }
  }

  void _handleIdUpload() {
    // Navigate to real upload screen instead of mock state change
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => GuestDocumentUploadScreen())
    ).then((_) => _checkVerificationStatus());
  }

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_isLoadingVerification) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.yellow)),
      );
    }

    // Removed blocking verification check to allow browsing
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: widget.showNavigation ? AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/hostifylogo.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 12),
            const Text('.Hostify'),
          ],
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ) : null,
      body: widget.showNavigation ? IndexedStack(
        index: _selectedIndex,
        children: [
          _buildExploreTab(),
          const GuestServiceRequestScreen(),
          _buildTripsTab(),
          _buildProfileTab(),
        ],
      ) : _buildExploreTab(),
      bottomNavigationBar: widget.showNavigation ? NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.yellow.withValues(alpha: 0.2),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: Color(0xFFFFD700)),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.cleaning_services_outlined),
            selectedIcon: Icon(Icons.cleaning_services, color: Color(0xFFFFD700)),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage, color: Color(0xFFFFD700)),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.yellow),
            label: 'Profile',
          ),
        ],
      ) : null,
    );
  }

  // Verification Screen
  Widget _buildVerificationScreen() {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Identity Verification'),
          backgroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) => const AuthScreen())
              ),
            )
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 80,
                  color: AppColors.yellow,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify your Identity',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'To access booking services, please verify your identity by uploading your ID.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _handleIdUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload ID Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _checkVerificationStatus,
                  child: const Text('Already uploaded? Refresh status'),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildExploreTab() {
    return Container(
      color: Colors.grey[50],
      child: Stack(
        children: [
          // Solid Black Header Background (mimics Booking.com Blue Header)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              color: Colors.black,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Navigation Chips (Stays only)
                      Row(
                        children: [
                          _buildHeaderChip(Icons.bed, 'Stays', isActive: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Main Scrollable Content
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.yellow,
              onRefresh: () async => _performSearch(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 70), // Push down to overlap header
                        
                        // Floating Search Card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.yellow, width: 3), // Distinct Hostify Yellow Border
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Location
                              _buildCompactSearchField(
                                icon: Icons.search,
                                label: _selectedLocation,
                                isFirst: true,
                                onTap: _showLocationSelector,
                              ),
                              const Divider(height: 1, thickness: 1, indent: 48),
                              
                              // Dates
                              _buildCompactSearchField(
                                icon: Icons.calendar_today,
                                label: _checkInDate != null && _checkOutDate != null 
                                    ? '${_checkInDate!.day}/${_checkInDate!.month} - ${_checkOutDate!.day}/${_checkOutDate!.month}' 
                                    : 'Select dates',
                                onTap: _showDatePicker,
                              ),
                              const Divider(height: 1, thickness: 1, indent: 48),
                              
                              // Guests & Rooms
                              _buildCompactSearchField(
                                icon: Icons.person_outline,
                                label: '$_rooms room · $_adults adults · $_children children',
                                isLast: true,
                                onTap: _showGuestSelector,
                              ),
                              
                              // Search Button attached to bottom of card
                              Consumer<PropertyProvider>(
                                builder: (context, provider, _) {
                                  return InkWell(
                                    onTap: provider.isLoading ? null : _performSearch,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      decoration: const BoxDecoration(
                                        color: Colors.black, // Sharp black button
                                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                                      ),
                                      alignment: Alignment.center,
                                      child: provider.isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Search',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  );
                                }
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // New Sections go here (Destinations, Offers, etc)
                        _buildExploreDestinations(),
                        const SizedBox(height: 32),
                        
                        _buildRewardsSection(),
                        const SizedBox(height: 32),
                        
                        // Property List Title
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Continue your search',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Properties List (Sliver format)
                  Consumer<PropertyProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading && provider.properties.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: CircularProgressIndicator(color: AppColors.yellow)),
                          ),
                        );
                      }

                      if (provider.error != null) {
                        return SliverToBoxAdapter(
                          child: Center(child: Text('Error: ${provider.error}')),
                        );
                      }

                      if (provider.properties.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.house_siding, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No properties found matched your search.', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final property = provider.properties[index];
                              return _buildPropertyCard(property);
                            },
                            childCount: provider.properties.length,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label, {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.white : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreDestinations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Egypt',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'These popular destinations have a lot to offer',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _buildDestinationCard('Cairo', '${_cityCounts['Cairo'] ?? 0} properties', 'https://images.pexels.com/photos/356844/pexels-photo-356844.jpeg?auto=compress&cs=tinysrgb&w=400'),
              const SizedBox(width: 12),
              _buildDestinationCard('Hurghada', '${_cityCounts['Hurghada'] ?? 0} properties', 'https://images.pexels.com/photos/3225524/pexels-photo-3225524.jpeg?auto=compress&cs=tinysrgb&w=400'),
              const SizedBox(width: 12),
              _buildDestinationCard('El Gouna', '${_cityCounts['El Gouna'] ?? 0} properties', 'https://images.pexels.com/photos/1483053/pexels-photo-1483053.jpeg?auto=compress&cs=tinysrgb&w=400'),
              const SizedBox(width: 12),
              _buildDestinationCard('Dahab', '${_cityCounts['Dahab'] ?? 0} properties', 'https://images.pexels.com/photos/3354346/pexels-photo-3354346.jpeg?auto=compress&cs=tinysrgb&w=400'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationCard(String title, String subtitle, String imageUrl) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLocation = title;
          _performSearch();
        });
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.all(12),
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Offers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Promotions, deals, and special offers for you',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              // Hostify Gold Card (Mimicking Genius)
              Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Unlock rewards for life',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Level up with every booking! Progress from Level 0 to 5 and unlock increasing discounts on stays: 5%, 8%, 10%, 12%, and 15%.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700), // Hostify Yellow Button
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Learn more', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Early 2026 Deal Card
              Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                          'Services Deal',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const Icon(Icons.flight_takeoff, color: Colors.black),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Save 5% on Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Get an exclusive 5% discount on all Hostify concierge and excursion services.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Explore Deals', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.luggage, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No trips booked... yet!',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedIndex = 0),
            child: const Text('Start Exploring'),
          )
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = context.read<AppStateProvider>().currentUser;
    
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person_outline, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Sign in to view profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Sign In / Sign Up'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFFFFD700),
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text('Guest Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {
               Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildPropertyCard(Map<String, dynamic> property) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                Image.network(
                  property['image'] ?? '',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Image Unavailable', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  },
                ),
                // Favorite & Share Buttons
                Positioned(
                  top: 12,
                  left: 12,
                  child: Consumer<AppStateProvider>(
                    builder: (context, appState, _) {
                      final isFav = appState.isFavorite(property['id'].toString());
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.red : const Color(0xFFFFD700),
                                size: 20,
                              ),
                              onPressed: () {
                                if (!appState.isAuthenticated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please sign in to save favorites')),
                                  );
                                  return;
                                }
                                appState.toggleFavorite(property['id'].toString());
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.share,
                                color: Color(0xFFFFD700),
                                size: 20,
                              ),
                              onPressed: () {
                                Share.share(
                                  'Check out this amazing property: ${property['name']} in ${property['location']}! Price: \$${property['price']}/night.',
                                  subject: 'Amazing Stay at .Hostify',
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Rating Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          property['rating'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Property Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        property['location'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Amenities
                Row(
                  children: [
                    _buildAmenityChip(Icons.bed, '${property['bedrooms'] ?? 1} beds'),
                    const SizedBox(width: 8),
                    _buildAmenityChip(Icons.bathtub, '${property['bathrooms'] ?? 1} baths'),
                    const SizedBox(width: 8),
                    _buildAmenityChip(Icons.people, '${property['max_guests'] ?? property['guests'] ?? 2} guests'),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Price & Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${property['price'].toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        Text(
                          'per night',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PropertyDetailScreen(
                              property: property,
                              checkIn: _checkInDate,
                              checkOut: _checkOutDate,
                              adults: _adults,
                              children: _children,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildCompactSearchField({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Reduced padding
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// Date Picker Modal
class _DatePickerModal extends StatefulWidget {
  final DateTime? checkIn;
  final DateTime? checkOut;
  final Function(DateTime?, DateTime?) onApply;

  const _DatePickerModal({
    required this.checkIn,
    required this.checkOut,
    required this.onApply,
  });

  @override
  State<_DatePickerModal> createState() => _DatePickerModalState();
}

class _DatePickerModalState extends State<_DatePickerModal> {
  DateTime? _selectedCheckIn;
  DateTime? _selectedCheckOut;

  @override
  void initState() {
    super.initState();
    _selectedCheckIn = widget.checkIn;
    _selectedCheckOut = widget.checkOut;
  }

  Future<void> _selectDates() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _selectedCheckIn != null && _selectedCheckOut != null
          ? DateTimeRange(start: _selectedCheckIn!, end: _selectedCheckOut!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFD700),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2D3748),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedCheckIn = picked.start;
        _selectedCheckOut = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select dates',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          InkWell(
            onTap: _selectDates,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    _selectedCheckIn != null && _selectedCheckOut != null
                        ? '${_selectedCheckIn!.day}/${_selectedCheckIn!.month} - ${_selectedCheckOut!.day}/${_selectedCheckOut!.month}'
                        : 'Tap to select dates',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.calendar_today, color: Color(0xFFFFD700)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_selectedCheckIn, _selectedCheckOut);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply Dates'),
            ),
          ),
        ],
      ),
    );
  }

}

// Guest Selector Modal
class _GuestSelectorModal extends StatefulWidget {
  final int rooms;
  final int adults;
  final int children;
  final Function(int, int, int) onApply;

  const _GuestSelectorModal({
    required this.rooms,
    required this.adults,
    required this.children,
    required this.onApply,
  });

  @override
  State<_GuestSelectorModal> createState() => _GuestSelectorModalState();
}

class _GuestSelectorModalState extends State<_GuestSelectorModal> {
  late int _rooms;
  late int _adults;
  late int _children;

  @override
  void initState() {
    super.initState();
    _rooms = widget.rooms;
    _adults = widget.adults;
    _children = widget.children;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select rooms and guests',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildCounter('Rooms', _rooms, (value) => setState(() => _rooms = value)),
          const SizedBox(height: 16),
          _buildCounter('Adults', _adults, (value) => setState(() => _adults = value)),
          const SizedBox(height: 16),
          _buildCounter('Children', _children, (value) => setState(() => _children = value)),
          
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_rooms, _adults, _children);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Row(
          children: [
            IconButton(
              onPressed: value > (label == 'Rooms' || label == 'Adults' ? 1 : 0)
                  ? () => onChanged(value - 1)
                  : null,
              icon: Icon(
                Icons.remove_circle_outline,
                color: value > (label == 'Rooms' || label == 'Adults' ? 1 : 0)
                    ? const Color(0xFFFFD700)
                    : Colors.grey,
              ),
            ),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFFFFD700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
