import "package:flutter/material.dart";
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle iCalendar integration with Booking.com, Airbnb, and internal bookings
class ICalendarSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sync bookings from all platforms for a property
  Future<List<BookingData>> syncPropertyBookings(String propertyId) async {
    final List<BookingData> allBookings = [];
    
    // 1. Fetch external iCal feeds from database
    try {
      final feedsResponse = await _supabase
          .from('icalendar_feeds')
          .select()
          .eq('property_id', propertyId);
      
      final feeds = List<Map<String, dynamic>>.from(feedsResponse);

      for (final feed in feeds) {
        final feedUrl = feed['feed_url'] as String;
        final source = feed['calendar_source'] as String? ?? 'External';
        
        try {
          final bookings = await _fetchICalFeed(feedUrl, source);
          allBookings.addAll(bookings);
        } catch (e) {
          debugPrint('Error fetching iCal feed from $source: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching feeds configuration: $e');
    }
    
    // 2. Add internal app bookings
    final internalBookings = await _getInternalBookings(propertyId);
    allBookings.addAll(internalBookings);
    
    return allBookings;
  }

  /// Get defined feeds for a property
  Future<List<Map<String, dynamic>>> getFeeds(String propertyId) async {
    try {
      final response = await _supabase
          .from('icalendar_feeds')
          .select()
          .eq('property_id', propertyId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting feeds: $e');
      return [];
    }
  }

  /// Add a new iCalendar feed
  Future<void> addFeed(String propertyId, String feedUrl, String source) async {
    await _supabase.from('icalendar_feeds').insert({
      'property_id': propertyId,
      'feed_url': feedUrl,
      'calendar_source': source,
    });
  }

  /// Remove a feed
  Future<void> removeFeed(String feedUrl) async {
    await _supabase
        .from('icalendar_feeds')
        .delete()
        .eq('feed_url', feedUrl);
  }

  /// Fetch and parse iCalendar feed from external URL
  Future<List<BookingData>> _fetchICalFeed(String feedUrl, String source) async {
    try {
      final response = await http.get(Uri.parse(feedUrl));
      
      if (response.statusCode == 200) {
        return _parseICalData(response.body, source);
      } else {
        throw Exception('Failed to load iCal feed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching iCal feed ($source): $e');
      return [];
    }
  }

  /// Parse iCalendar (ICS) format data
  List<BookingData> _parseICalData(String icsData, String source) {
    final List<BookingData> bookings = [];
    final events = icsData.split('BEGIN:VEVENT');
    
    for (int i = 1; i < events.length; i++) {
      final event = events[i];
      
      final dtStartMatch = RegExp(r'DTSTART[;:]([^\r\n]+)').firstMatch(event);
      final dtEndMatch = RegExp(r'DTEND[;:]([^\r\n]+)').firstMatch(event);
      final summaryMatch = RegExp(r'SUMMARY:([^\r\n]+)').firstMatch(event);
      final uidMatch = RegExp(r'UID:([^\r\n]+)').firstMatch(event);
      
      if (dtStartMatch != null && dtEndMatch != null) {
        final startDate = _parseICalDate(dtStartMatch.group(1)!);
        final endDate = _parseICalDate(dtEndMatch.group(1)!);
        final guestName = summaryMatch?.group(1)?.trim() ?? 'Guest';
        final bookingId = uidMatch?.group(1)?.trim() ?? DateTime.now().toString();
        
        if (startDate != null && endDate != null) {
          // Verify source based on URL content if needed, but we pass it effectively now
          String effectiveSource = source;
          if (source == 'External') {
             effectiveSource = _extractPlatform(guestName); 
          }

          debugPrint('Parsed iCal: $guestName ($startDate - $endDate) via $effectiveSource');
          bookings.add(BookingData(
            id: bookingId,
            propertyId: '', // Context doesn't always have this, relying on caller
            guestName: guestName,
            startDate: startDate,
            endDate: endDate,
            source: effectiveSource,
            nights: endDate.difference(startDate).inDays,
          ));
        }
      }
    }
    return bookings;
  }

  /// Parse iCalendar date format (YYYYMMDD or YYYYMMDDTHHMMSSZ)
  DateTime? _parseICalDate(String dateStr) {
    try {
      dateStr = dateStr.replaceAll(RegExp(r'VALUE=DATE:|TZID=[^:]+:'), '');
      if (dateStr.length >= 8) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      }
    } catch (e) {
      debugPrint('Error parsing date: $dateStr');
    }
    return null;
  }

  /// Extract platform check
  String _extractPlatform(String text) {
    if (text.toLowerCase().contains('booking.com')) return 'Booking.com';
    if (text.toLowerCase().contains('airbnb')) return 'Airbnb';
    return 'External';
  }

  /// Get bookings from Supabase database
  Future<List<BookingData>> _getInternalBookings(String propertyId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('id, check_in, check_out, status, user_profiles(full_name)')
          .eq('property_id', propertyId)
          .filter('status', 'in', ['confirmed', 'active']); // Using filter for v2
      
      final bookingsList = List<Map<String, dynamic>>.from(response);
      
      return bookingsList.map((b) {
        final checkIn = DateTime.parse(b['check_in']);
        final checkOut = DateTime.parse(b['check_out']);
        final profile = b['user_profiles'] as Map<String, dynamic>?;
        
        return BookingData(
          id: b['id'],
          propertyId: propertyId,
          guestName: profile?['full_name'] ?? 'Hostify Guest',
          startDate: checkIn,
          endDate: checkOut,
          source: '.Hostify',
          nights: checkOut.difference(checkIn).inDays,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching internal bookings: $e');
      return [];
    }
  }

  /// Check if a date range is available
  Future<bool> isDateRangeAvailable(String propertyId, DateTime checkIn, DateTime checkOut) async {
    final bookings = await syncPropertyBookings(propertyId);
    
    for (final booking in bookings) {
      // Check for overlap: (StartA < EndB) and (EndA > StartB)
      if (checkIn.isBefore(booking.endDate) && checkOut.isAfter(booking.startDate)) {
        return false; // Conflict found, not available
      }
    }
    return true; 
  }

  /// Get all unavailable dates for a property (for calendar highlighting)
  Future<List<DateTime>> getUnavailableDates(String propertyId) async {
    final bookings = await syncPropertyBookings(propertyId);
    final List<DateTime> unavailableDates = [];
    
    for (final booking in bookings) {
      DateTime current = booking.startDate;
      // Exclude checkout date as it's available for check-in
      while (current.isBefore(booking.endDate)) {
        unavailableDates.add(DateTime(current.year, current.month, current.day));
        current = current.add(const Duration(days: 1));
      }
    }
    return unavailableDates;
  }

  Future<void> syncAllPropertiesAndPersist() async {
    debugPrint('STARTING syncAllPropertiesAndPersist()');
    try {
      debugPrint('Starting Client-Side Sync...');
      
      // 1. Get all properties that might have iCal URLs
      final props = await _supabase.from('properties').select('id, ical_url, name');
      debugPrint('Syncing ${props.length} properties found in database');
      
      for (final prop in props) {
        final propId = prop['id'] as String;
        // final propName = prop['name']; // Unused
        final directUrl = prop['ical_url']?.toString();
        
        await syncCalendar(propertyId: propId, icalUrl: directUrl);
      }
      debugPrint('Client-Side Sync Complete');
    } catch (e) {
      debugPrint('Global Sync Error: $e');
      rethrow;
    }
  }

  /// Sync a specific property and persist bookings
  Future<void> syncCalendar({required String propertyId, String? icalUrl}) async {
    try {
      // 2. Sync configured feeds from table
      final feeds = await getFeeds(propertyId);
      
      for (final feed in feeds) {
         await _processFeedAndPersist(propertyId, feed['feed_url'], feed['calendar_source']);
      }
      
      // 3. Sync from properties.ical_url if provided
      if (icalUrl != null && icalUrl.isNotEmpty) {
        await _processFeedAndPersist(propertyId, icalUrl, 'External');
      }
    } catch (e) {
      debugPrint('Error syncing property $propertyId: $e');
    }
  }

  Future<void> _processFeedAndPersist(String propId, String url, String source) async {
    try {
       // Fetch property pricing and discounts
       final propData = await _supabase
           .from('properties')
           .select('price_per_night, weekly_discount_percent, monthly_discount_percent')
           .eq('id', propId)
           .maybeSingle();
           
       num basePricePerNight = propData != null ? (propData['price_per_night'] ?? 150) : 150;
       if (basePricePerNight <= 0) basePricePerNight = 150; // Fallback to $150 if price is 0 or negative
       
       num weeklyDiscount = propData != null ? (propData['weekly_discount_percent'] ?? 0) : 0;
       num monthlyDiscount = propData != null ? (propData['monthly_discount_percent'] ?? 0) : 0;
       
       debugPrint('Property ID: $propId | Base Price: $basePricePerNight | Weekly: $weeklyDiscount% | Monthly: $monthlyDiscount%');

     final bookings = await _fetchICalFeed(url, source);
     debugPrint('Fetched ${bookings.length} potential iCal events from $source');
     
     int newCount = 0;
     int updatedCount = 0;
     
     for (final b in bookings) {
       debugPrint('Booking Detail: ${b.guestName} | Nights: ${b.nights} | Calc Price: ${b.nights * basePricePerNight}');
       // Check existence by external ID
       final existing = await _supabase.from('bookings')
          .select('id')
          .eq('external_booking_id', b.id)
          .maybeSingle();
          
       if (existing == null) {
         // Insert new booking with Real Revenue Calculation
         await _supabase.from('bookings').insert({
           'property_id': propId,
           'check_in': b.startDate.toIso8601String(),
           'check_out': b.endDate.toIso8601String(),
           'nights': b.nights,
           'total_price': b.nights * basePricePerNight, // Real calculation: Nights * Price
           'status': 'confirmed',
           'booking_source': b.source == 'External' ? 'hostify' : b.source == 'Booking.com' ? 'booking_com' : 'airbnb',
           'external_booking_id': b.id,
           'unit_name': 'Imported Unit', 
           'room_number': '1',
         });
         newCount++;
       } else {
         // Update existing booking if dates or price might have changed
         await _supabase.from('bookings').update({
           'check_in': b.startDate.toIso8601String(),
           'check_out': b.endDate.toIso8601String(),
           'nights': b.nights,
           'total_price': b.nights * basePricePerNight,
         }).eq('id', existing['id']);
         updatedCount++;
       }
     }
     debugPrint('Sync Result for $source: $newCount new, $updatedCount updated.');
   } catch (e) {
     debugPrint('Error processing feed $url: $e');
   }
 }

}

/// Data model for booking information
class BookingData {
  final String id;
  final String propertyId;
  final String guestName;
  final DateTime startDate;
  final DateTime endDate;
  final String source; // 'Booking.com', 'Airbnb', '.Hostify'
  final int nights;

  BookingData({
    required this.id,
    required this.propertyId,
    required this.guestName,
    required this.startDate,
    required this.endDate,
    required this.source,
    required this.nights,
  });

  @override
  String toString() => 'Booking($guestName, $startDate - $endDate, $source)';
}
