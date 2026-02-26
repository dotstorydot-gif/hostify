import 'package:flutter/material.dart';
import 'package:hostify/screens/guest_dashboard.dart';
import 'package:hostify/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hostify/screens/guest_my_bookings_screen.dart';
import 'package:hostify/screens/booking_screen.dart';
import 'package:hostify/screens/profile_screen.dart';
import 'package:hostify/screens/guest_service_request_screen.dart';

class GuestMainNavigation extends StatefulWidget {
  final int initialIndex;
  const GuestMainNavigation({super.key, this.initialIndex = 0});

  @override
  State<GuestMainNavigation> createState() => _GuestMainNavigationState();
}

class _GuestMainNavigationState extends State<GuestMainNavigation> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const BookingScreen(showNavigation: false), // Search
          const SafeArea(child: Center(child: Text('Saved properties list here...'))), // Saved
          const GuestServiceRequestScreen(), // Services
          const GuestMyBookingsScreen(), // Bookings
          const ProfileScreen(userRole: 'guest'), // My account
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFFFD700), // Hostify Yellow (Booking.com uses Blue)
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, height: 1.5),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.search, size: 26)),
              label: l10n.explore, // "Search"
            ),
            BottomNavigationBarItem(
              icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite_border, size: 26)),
              activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite, size: 26)),
              label: 'Saved', 
            ),
            BottomNavigationBarItem(
               icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.room_service_outlined, size: 26)),
               activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.room_service, size: 26)),
               label: 'Services', 
            ),
            BottomNavigationBarItem(
               icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.cases_outlined, size: 26)),
               activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.cases, size: 26)),
               label: 'Bookings', 
            ),
            BottomNavigationBarItem(
              icon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_outline, size: 26)),
              activeIcon: const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person, size: 26)),
              label: 'My account',
            ),
          ],
        ),
      ),
    );
  }
}
