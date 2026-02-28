import "package:flutter/material.dart";
import 'package:hostify/legacy/l10n/app_localizations.dart';
import 'package:hostify/legacy/screens/guest_my_bookings_screen.dart';
import 'package:hostify/legacy/screens/booking_screen.dart';
import 'package:hostify/legacy/screens/profile_screen.dart';
import 'package:hostify/legacy/screens/guest_service_request_screen.dart';

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
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No saved properties yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on properties you like\nto save them here for later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ), // Saved
          GuestServiceRequestScreen(), // Services
          GuestMyBookingsScreen(), // Bookings
          ProfileScreen(userRole: 'guest'), // My account
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
            const BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite_border, size: 26)),
              activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.favorite, size: 26)),
              label: 'Saved', 
            ),
            const BottomNavigationBarItem(
               icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.room_service_outlined, size: 26)),
               activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.room_service, size: 26)),
               label: 'Services', 
            ),
            const BottomNavigationBarItem(
               icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.cases_outlined, size: 26)),
               activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.cases, size: 26)),
               label: 'Bookings', 
            ),
            const BottomNavigationBarItem(
              icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person_outline, size: 26)),
              activeIcon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.person, size: 26)),
              label: 'My account',
            ),
          ],
        ),
      ),
    );
  }
}
