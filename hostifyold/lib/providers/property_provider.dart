import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:hostify/services/icalendar_sync_service.dart';

class PropertyProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _properties = [];
  Set<String> _favoriteIds = {}; // New: Track favorite property IDs
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get properties => _properties;
  Set<String> get favoriteIds => _favoriteIds; // New
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch properties for a specific landlord
  Future<void> fetchLandlordProperties(String landlordId) async {
    _setLoading(true);
    _clearError();
    try {
      // Use RPC to fetch owned + managed properties
      final response = await _supabase
          .rpc('get_my_properties', params: {'p_user_id': landlordId});

      final List<dynamic> data = response as List<dynamic>;
      
      // Since RPC returns just property rows, fetch details for these IDs
      // to get images efficiently without complex joins in RPC if not set up yet.
      // Or if RPC data is enough, use it. But we need images.
      
      final propertyIds = data.map((e) => e['id']).toList();
      
      if (propertyIds.isEmpty) {
        _properties = [];
        notifyListeners();
        return;
      }
      
      // Fetch properties without images first to avoid duplicates
      final propertiesResponse = await _supabase.from('property-images')
        .select('*')
        .inFilter('id', propertyIds)
        .order('created_at', ascending: false);
      
      // Fetch images separately
      final imagesResponse = await _supabase.from('property_images')
        .select('property_id, image_url, is_primary')
        .inFilter('property_id', propertyIds);
      
      // Group images by property_id
      final imagesByProperty = <String, List<Map<String, dynamic>>>{};
      for (var img in imagesResponse as List) {
        final propId = img['property_id'] as String;
        if (!imagesByProperty.containsKey(propId)) {
          imagesByProperty[propId] = [];
        }
        imagesByProperty[propId]!.add(img as Map<String, dynamic>);
      }
      
      // Combine properties with their images
      _properties = List<Map<String, dynamic>>.from(propertiesResponse).map((prop) {
        final propId = prop['id'] as String;
        final images = imagesByProperty[propId] ?? [];
        String imageUrl = '';
        
        if (images.isNotEmpty) {
          final primary = images.firstWhere(
            (img) => img['is_primary'] == true, 
            orElse: () => images.first
          );
          imageUrl = primary['image_url'];
        }
        
        return { 
          ...prop, 
          'image': imageUrl,
          'property_images': images,
        };
      }).toList();
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch properties: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new property
  Future<void> addProperty({
    required String name,
    required String description,
    required double price,
    required String location,
    required String city,
    required String country,
    required int bedrooms,
    required int bathrooms,
    required int guests,
    required String landlordId,
    required List<String> amenities,
    String? icalUrl, // New
    File? primaryImage,
    List<File>? otherImages,
  }) async {
    _setLoading(true);
    try {
      // 1. Insert Property
      final response = await _supabase.from('property-images').insert({
        'name': name,
        'description': description,
        'price_per_night': price,
        'location': '$location, $city, $country',
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'max_guests': guests,
        'landlord_id': landlordId,
        'ical_url': icalUrl, // New
        'status': 'Active', 
      }).select().single();

      final propertyId = response['id'] as String;

      // 2. Upload Images
      if (primaryImage != null) {
        await _uploadAndLinkImage(propertyId, primaryImage, true);
      }
      if (otherImages != null) {
        for (final img in otherImages) {
          await _uploadAndLinkImage(propertyId, img, false);
        }
      }

      // 3. Insert Amenities
      if (amenities.isNotEmpty) {
        final amenitiesData = amenities.map((a) => {
          'property_id': propertyId,
          'amenity': a,
        }).toList();
        await _supabase.from('property_amenities').insert(amenitiesData);
      }

      await fetchLandlordProperties(landlordId); // Refresh list
    } catch (e) {
      _setError('Failed to add property: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing property
  Future<void> updateProperty({
    required String id,
    Map<String, dynamic>? updates,
    List<String>? amenities,
    String? icalUrl, // New
    List<File>? newImages,
  }) async {
     _setLoading(true);
    try {
      // 1. Update fields
      var finalUpdates = updates ?? {};
      if (icalUrl != null) finalUpdates['ical_url'] = icalUrl;

      if (finalUpdates.isNotEmpty) {
        await _supabase.from('property-images').update(finalUpdates).eq('id', id);
      }

      // 2. Update Amenities (Delete all and re-insert for simplicity)
      if (amenities != null) {
        await _supabase.from('property_amenities').delete().eq('property_id', id);
        final amenitiesData = amenities.map((a) => {
          'property_id': id,
          'amenity': a,
        }).toList();
        await _supabase.from('property_amenities').insert(amenitiesData);
      }

      // 3. Add new images
      if (newImages != null) {
        for (final img in newImages) {
          await _uploadAndLinkImage(id, img, false);
        }
      }
      
      // Update local state locally to reflect changes immediately
      final index = _properties.indexWhere((p) => p['id'] == id);
      if (index != -1) {
        final existing = _properties[index];
        final updatedProp = Map<String, dynamic>.from(existing);
        
        // Apply updates
        if (finalUpdates.isNotEmpty) {
           updatedProp.addAll(finalUpdates);
           
           // Ensure numeric types match expectation if changed
           if (finalUpdates.containsKey('price_per_night')) {
             updatedProp['price'] = (finalUpdates['price_per_night'] as num).toDouble();
           }
        }
        
        if (amenities != null) {
          updatedProp['amenities_list'] = amenities;
        }

        // If images added, we should technically re-fetch to get their URLs.
        // For now, we leave images as is or trigger full refresh if images changed.
        
        _properties[index] = updatedProp;
      }
      
      if (newImages != null) {
        // If images changed, hard refresh to get new URLs
        if (index != -1) {
           final landlordId = _properties[index]['landlord_id'];
           if (landlordId != null) {
              await fetchLandlordProperties(landlordId);
              return; // Fetch call handles notifyListeners
           }
        }
      }

      // AUTO-RECALCULATION: 
      // If price changed, or generally after update, we should Sync Calendar to recalculate booking revenues.
      // We need to fetch the ical_url first (if not passed in updates, use existing).
      // If ical_url is null in updates, check existing.
      
      String? currentIcalUrl = icalUrl;
      if (currentIcalUrl == null && index != -1) {
         currentIcalUrl = _properties[index]['ical_url'];
      }
      
      if (currentIcalUrl != null && currentIcalUrl.isNotEmpty) {
         // Trigger Sync (Fire and Forget? Or Await?)
         // Ideally await to ensure user sees updated stats if they go to dashboard immediately.
         // But fetchLandlordProperties might have been called above.
         // Let's call it.
         try {
           await ICalendarSyncService().syncCalendar(
             propertyId: id, 
             icalUrl: currentIcalUrl
           );
           // After sync, bookings table is updated.
           // Analytics/Dashboard will need to re-fetch bookings/analytics data.
           // This is handled by those screens individually.
         } catch (e) {
           if (kDebugMode) print('Auto-Sync failed during update: $e');
           // Don't fail the updateProperty call just because sync failed?
           // User expects recalculation. Could show warning.
         }
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to update property: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a property
  Future<void> deleteProperty(String id, String landlordId) async {
    _setLoading(true);
     try {
      await _supabase.from('property-images').delete().eq('id', id);
      await fetchLandlordProperties(landlordId);
    } catch (e) {
      _setError('Failed to delete property: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _uploadAndLinkImage(String propertyId, File image, bool isPrimary) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
    final path = '$propertyId/$fileName';
    
    await _supabase.storage.from('property-images').upload(path, image);
    final publicUrl = _supabase.storage.from('property-images').getPublicUrl(path);

    await _supabase.from('property_images').insert({
      'property_id': propertyId,
      'image_url': publicUrl,
      'is_primary': isPrimary,
    });
  }

  /// Sync Calendar from iCal URL
  Future<void> syncCalendar(String propertyId, String icalUrl) async {
    _setLoading(true);
    try {
      // 1. Update URL in DB
      await _supabase.from('property-images').update({'ical_url': icalUrl}).eq('id', propertyId);

      // 2. Fetch iCal data
      final response = await http.get(Uri.parse(icalUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch iCal: ${response.statusCode}');
      }

      // 3. Parse
      final iCalendar = ICalendar.fromString(response.body);
      
      // 4. Process Events
      final events = iCalendar.data;
      int importedCount = 0;

      for (var item in events) {
         if (item['type'] == 'VEVENT') {
            final dtstart = item['dtstart'];
            final dtend = item['dtend'];
            final uid = item['uid'] as String?;
            
            if (dtstart != null && dtend != null) {
              final checkIn = _parseIcalDate(dtstart);
              final checkOut = _parseIcalDate(dtend);
              final nights = checkOut.difference(checkIn).inDays;

              if (nights > 0) {
                // Check if already exists
                final existing = await _supabase.from('bookings')
                   .select()
                   .eq('external_booking_id', uid ?? '')
                   .maybeSingle();

                if (existing == null) {
                   await _supabase.from('bookings').insert({
                     'property_id': propertyId,
                     'check_in': checkIn.toIso8601String(),
                     'check_out': checkOut.toIso8601String(),
                     'nights': nights,
                     'status': 'confirmed',
                     'booking_source': 'airbnb',
                     'external_booking_id': uid,
                     'guest_id': null, // External
                     'total_price': null, // Not available
                   });
                   importedCount++;
                }
              }
            }
         }
      }
      
      if (kDebugMode) {
        print('Imported $importedCount iCal events');
      }
      notifyListeners();
    } catch (e) {
      _setError('Failed to sync calendar: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  DateTime _parseIcalDate(dynamic date) {
    // ICalendarDate type not available in icalendar_parser 1.0.0
    // if (date is ICalendarDate) {
    //   return date.toDateTime() ?? DateTime.now();
    // } else 
    if (date is String) {
      // Simple fallback if package returns string (depends on version)
      // Usually YYYYMMDD or YYYYMMDDTHHMMSSZ
      return DateTime.tryParse(date) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Fetch properties with optional search filters
  Future<void> fetchProperties({
    String? location,
    DateTime? checkIn,
    DateTime? checkOut,
    int? guests,
    int? rooms,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      dynamic response;
      
      // Use RPC if filters are present, otherwise simple select (or just always use RPC if flexible)
      // For simplicity/consistency, we can try to use RPC if any filter is set, 
      // but RPC returns just properties, we need to join images/reviews.
      // Supabase RPC returning SETOF records can be joined in client side or we can enhance RPC.
      // For now, let's keep it simple: Use RPC to get IDs, then fetch details, OR
      // just modify the RPC to return JSON with relations, OR
      // Since RPC returns the 'property-images' table rows, we can't easily chain .select('*, ...') on it in older SDKs?
      // Actually, Supabase postgrest allows `rpc(...).select(...)`.
      
      final rpcParams = {
        'check_in_date': checkIn?.toIso8601String(),
        'check_out_date': checkOut?.toIso8601String(),
        'location_query': (location != null && location.isNotEmpty) ? location : null,
        'min_guests': guests,
        'min_rooms': rooms,
      };

      
      // The RPC already returns all columns including 'image' and 'amenities' jsonb
      final responseData = await _supabase.rpc('search_properties', params: rpcParams);
      
      // Process Data to match UI expectations
      final List<Map<String, dynamic>> fetchedProperties = List<Map<String, dynamic>>.from(responseData).map((prop) {
        // Handle Images - Use the main image column
        String imageUrl = prop['image'] ?? '';
        
        // Handle Multiple Images from RPC results
        List<String> images = [];
        if (prop['images'] != null && prop['images'] is List) {
          images = (prop['images'] as List).cast<String>();
        } else if (imageUrl.isNotEmpty) {
          images = [imageUrl];
        }
        
        // Handle Amenities - RPC returns them as JSONB (List)
        List<String> amenities = [];
        if (prop['amenities'] != null) {
           if (prop['amenities'] is List) {
             amenities = (prop['amenities'] as List).map((e) => e.toString()).toList();
           } 
        }
        
        // Handle Ratings - RPC returns average rating directly
        double rating = 0.0;
        if (prop['rating'] != null) {
          rating = (prop['rating'] as num).toDouble();
        }
        
        // RPC doesn't return review count yet, default to 0
        int reviewCount = 0; 

        return {
          ...prop,
          'image': imageUrl, // Map for UI (Primary)
          'images': images, // List for Gallery (Carousel support)
          'amenities_list': amenities,
          'rating': rating,
          'reviews_count': reviewCount,
          'price': (prop['price_per_night'] as num).toDouble(),
          'review-images': reviewCount,
        };
      }).toList();

      _properties = fetchedProperties;
      
      // Auto-fetch favorites if user is logged in
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        await fetchFavorites(currentUser.id);
      } else {
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to fetch properties: $e');
      if (kDebugMode) {
        print('Error fetching properties: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch pricing rules for a property
  Future<List<Map<String, dynamic>>> getPricingRules(String propertyId) async {
    try {
      final response = await _supabase
          .from('property_pricing_rules')
          .select()
          .eq('property_id', propertyId)
          .order('date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error fetching pricing rules: $e');
      return [];
    }
  }

  /// Add pricing rules
  Future<void> addPricingRules(String propertyId, List<DateTime> dates, int percentageIncrease) async {
    try {
      final data = dates.map((date) => {
        'property_id': propertyId,
        'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
        'percentage_increase': percentageIncrease,
      }).toList();

      await _supabase.from('property_pricing_rules').upsert(
        data, 
        onConflict: 'property_id, date'
      );
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error adding pricing rules: $e');
      rethrow;
    }
  }

  /// Delete pricing rule
  Future<void> deletePricingRule(String ruleId) async {
    try {
      await _supabase.from('property_pricing_rules').delete().eq('id', ruleId);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error deleting pricing rule: $e');
      rethrow;
    }
  }

  /// Fetch user favorites
  Future<void> fetchFavorites(String userId) async {
    try {
      final response = await _supabase
          .from('favorites')
          .select('property_id')
          .eq('user_id', userId);
      
      final List<dynamic> data = response as List<dynamic>;
      _favoriteIds = data.map((f) => f['property_id'] as String).toSet();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error fetching favorites: $e');
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String userId, String propertyId) async {
    final isFav = _favoriteIds.contains(propertyId);
    try {
      if (isFav) {
        await _supabase
            .from('favorites')
            .delete()
            .match({'user_id': userId, 'property_id': propertyId});
        _favoriteIds.remove(propertyId);
      } else {
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'property_id': propertyId,
        });
        _favoriteIds.add(propertyId);
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error toggling favorite: $e');
      rethrow;
    }
  }

  bool isPropertyFavorite(String propertyId) {
    return _favoriteIds.contains(propertyId);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
