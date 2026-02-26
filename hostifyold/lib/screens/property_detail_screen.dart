import 'package:flutter/material.dart';
import 'package:hostify/l10n/app_localizations.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'package:provider/provider.dart';
import 'package:hostify/providers/booking_provider.dart';
import 'package:hostify/providers/app_state_provider.dart';
import 'package:hostify/providers/review_provider.dart';
import 'package:hostify/providers/property_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hostify/screens/auth_screen.dart';
import 'package:hostify/screens/guest_document_upload_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int adults;
  final int children;

  const PropertyDetailScreen({
    super.key,
    required this.property,
    this.checkIn,
    this.checkOut,
    this.adults = 2,
    this.children = 0,
  });

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _currentImageIndex = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.property['id'] != null) {
        context.read<ReviewProvider>().fetchPropertyReviews(widget.property['id']);
      }
    });
  }
  


// ... (rest of build method unchanged until submit)




  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo Gallery
                _buildPhotoGallery(),
                
                // Property Info
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.property['name'] ?? 'Property Name',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.property['rating']?.toString() ?? '4.8',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Location
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.property['location'] ?? 'El Gouna, Egypt',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Quick Stats
                      Row(
                        children: [
                          _buildStatChip(
                            Icons.bed,
                            '${widget.property['bedrooms'] ?? 3} ${l10n.bedrooms}',
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            Icons.bathtub,
                            '${widget.property['bathrooms'] ?? 2} ${l10n.bathrooms}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatChip(
                            Icons.people,
                            '${widget.property['guests'] ?? 6} ${l10n.guestsCount}',
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      
                      // Property Highlights
                      Text(
                        l10n.propertyHighlights,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAmenityGrid(),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      
                      // Description
                      Text(
                        l10n.aboutProperty,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.property['description'] ??
                            'Experience luxury living in this beautiful property located in the heart of El Gouna. '
                            'Featuring modern amenities, stunning views, and easy access to local attractions. '
                            'Perfect for families and groups looking for a memorable stay.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.grey[700],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Reviews Section
                      Text(
                        l10n.guestReviews,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReviewsList(),
                      
                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Top AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        Consumer<PropertyProvider>(
                          builder: (context, propertyProvider, _) {
                            final userId = context.read<AppStateProvider>().currentUser?.id;
                            final isFav = propertyProvider.isPropertyFavorite(widget.property['id']);
                            
                            return IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isFav ? Icons.favorite : Icons.favorite_border,
                                  color: isFav ? Colors.red : const Color(0xFF2D3748),
                                ),
                              ),
                              onPressed: () async {
                                if (userId != null) {
                                  try {
                                    await propertyProvider.toggleFavorite(userId, widget.property['id']);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
                                      );
                                    }
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.loginToFavorite)),
                                  );
                                }
                              },
                            );
                          },
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.share,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          onPressed: () {
                            final propertyName = widget.property['name'] ?? 'Property';
                            final propertyLocation = widget.property['location'] ?? '';
                            Share.share(l10n.shareProperty(propertyName, propertyLocation));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom Booking Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${widget.property['price']?.toStringAsFixed(0) ?? '200'}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        Text(
                          l10n.perNight,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _showBookingRequestDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.requestBooking,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery() {
    // Priority: 'images' list from RPC, then 'property_images' from provider, then 'image' primary
    List<String> images = [];
    
    if (widget.property['images'] != null && widget.property['images'] is List) {
      images = (widget.property['images'] as List).cast<String>();
    } else if (widget.property['property_images'] != null) {
      images = (widget.property['property_images'] as List)
          .map((img) => img['image_url'] as String)
          .toList();
    }
    
    // Fallback to primary image if list is empty, or placeholder
    if (images.isEmpty) {
      final primary = widget.property['image'] as String?;
      if (primary != null && primary.isNotEmpty) {
        images = [primary];
      }
    }
    
    final displayImages = images.isNotEmpty ? images : [''];

    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 350,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() => _currentImageIndex = index);
            },
          ),
          items: displayImages.map((imageUrl) {
            return Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.villa, size: 100, color: Colors.white),
                );
              },
            );
          }).toList(),
        ),
        
        // Image Counter
        if (displayImages.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${displayImages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFFD700)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityGrid() {
    final amenities = [
      {'icon': Icons.wifi, 'label': 'Free WiFi'},
      {'icon': Icons.pool, 'label': 'Swimming Pool'},
      {'icon': Icons.local_parking, 'label': 'Free Parking'},
      {'icon': Icons.restaurant, 'label': 'Breakfast'},
      {'icon': Icons.ac_unit, 'label': 'Air Conditioning'},
      {'icon': Icons.kitchen, 'label': 'Kitchen'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: amenities.map((amenity) {
        return Container(
          width: (MediaQuery.of(context).size.width - 64) / 2,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                amenity['icon'] as IconData,
                color: const Color(0xFFFFD700),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  amenity['label'] as String,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }



  Widget _buildReviewsList() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<ReviewProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = provider.reviews;
        if (reviews.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noReviews,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final review = reviews[index];
            final guestName = review['guest_name'] ?? 'Guest';
            final rating = (review['overall_rating'] ?? 5.0).toDouble();
            final comment = review['review_text'] ?? '';
            final date = review['created_at'] != null 
                ? DateFormat.yMMMd().format(DateTime.parse(review['created_at'])) 
                : '';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black,
                        radius: 20,
                        child: Text(
                          guestName.isNotEmpty ? guestName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guestName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              date,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFFFB800), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB800)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      comment,
                      style: TextStyle(color: Colors.grey[800], height: 1.5),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBookingRequestDialog() {
    final l10n = AppLocalizations.of(context)!;
    if (widget.checkIn == null || widget.checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectDatesFirst)),
      );
      return;
    }

    final user = context.read<AppStateProvider>().currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text('Please sign in to book this property.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('Sign In'),
            ),
          ],
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
          content: const Text('To ensure safety, please upload your identity documents before booking.'),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmBooking),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Property: ${widget.property['name']}'),
            const SizedBox(height: 8),
            Text('Dates: ${widget.checkIn!.day}/${widget.checkIn!.month} - ${widget.checkOut!.day}/${widget.checkOut!.month}'),
            const SizedBox(height: 8),
            Text('${l10n.guestsCount}: ${widget.adults} ${l10n.adults}, ${widget.children} ${l10n.children}'),
            const SizedBox(height: 16),
            Text(
              l10n.totalPriceNote,
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : () {
              Navigator.pop(context);
              _submitBookingRequest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l10n.sendRequest),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBookingRequest() async {
    setState(() => _isSubmitting = true);

    try {
      final propertyId = widget.property['id'] ?? 'unknown';
      final basePrice = (widget.property['price'] as num?)?.toDouble() ?? 0.0;
      final checkIn = widget.checkIn!;
      final checkOut = widget.checkOut!;
      final nights = checkOut.difference(checkIn).inDays;
      
      // Calculate Total Price with Holiday Rules
      double calculatedTotal = 0.0;
      
      // Fetch pricing rules using context before loop (safe)
      final propertyProvider = context.read<PropertyProvider>();
      final rules = await propertyProvider.getPricingRules(propertyId);
      
      for (int i = 0; i < nights; i++) {
        final date = checkIn.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        // Find matching rule
        final rule = rules.firstWhere(
          (r) => r['date'] == dateStr,
          orElse: () => {},
        );
        
        double dailyPrice = basePrice;
        if (rule.isNotEmpty) {
          final pct = (rule['percentage_increase'] as num).toDouble();
          dailyPrice = basePrice * (1 + (pct / 100));
        }
        
        calculatedTotal += dailyPrice;
      }
      
      // Fallback if 0 (shouldn't happen)
      if (calculatedTotal == 0) calculatedTotal = nights * basePrice;


      if (!mounted) return;

      // Use BookingProvider
      final currentUser = context.read<AppStateProvider>().currentUser;
      if (currentUser == null) throw Exception('User must be logged in to book');

      await context.read<BookingProvider>().createBooking(
        propertyId: propertyId,
        userId: currentUser.id,
        checkIn: checkIn,
        checkOut: checkOut,
        guests: widget.adults + widget.children,
        totalPrice: calculatedTotal,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing booking: $e')),
        );
      }
    } finally {

      if (mounted) {
        setState(() => _isSubmitting = false);
      }
  }
}
}
