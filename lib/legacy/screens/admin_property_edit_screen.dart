import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Add this import
import 'dart:io';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/providers/property_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminPropertyEditScreen extends StatefulWidget {
  final String? propertyId;
  final String propertyName;

  const AdminPropertyEditScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<AdminPropertyEditScreen> createState() => _AdminPropertyEditScreenState();
}

class _AdminPropertyEditScreenState extends State<AdminPropertyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _icalController = TextEditingController(); // New
  // New controllers for details
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _guestsController = TextEditingController();
  final _weeklyDiscountController = TextEditingController();
  final _monthlyDiscountController = TextEditingController();
  
  final List<File> _propertyImages = [];
  bool _isLoading = false;
  
  // Amenities
  final Map<String, bool> _amenities = {
    'WiFi': false,
    'Air Conditioning': false,
    'Heating': false,
    'Kitchen': false,
    'Washing Machine': false,
    'TV': false,
    'Parking': false,
    'Pool': false,
    'Gym': false,
    'Elevator': false,
  };

  // Landlord Multi-Assign
  List<Map<String, dynamic>> _availableLandlords = [];
  final Set<String> _selectedLandlordIds = {};

  @override
  void initState() {
    super.initState();
    _fetchLandlordsData();
    if (widget.propertyId != null) {
      _loadPropertyData();
    }
  }

  Future<void> _fetchLandlordsData() async {
     try {
       // 1. Fetch available landlords (users with role 'landlord' or 'admin')
       final supabase = Supabase.instance.client; // Fix: Use global instance
       
       // Query user_profiles (assuming we want all users for now OR filtered)
       // Better: Fetch user_roles joined with profiles.
       final profilesResponse = await supabase
           .from('user_profiles')
           .select('id, email, full_name');
       
       // Filter roles client-side or use a view if complex. 
       // For admin simplicity, listing all profiles might be okay, or filter by role table.
       // Let's list all profiles for now to ensure we catch 'info@dot-story.com'
       
       final profiles = List<Map<String, dynamic>>.from(profilesResponse);
       setState(() {
         _availableLandlords = profiles;
       });

       // 2. If editing, fetch current assignments
       if (widget.propertyId != null) {
         final assignmentsResponse = await supabase
             .from('property_landlords')
             .select('user_id')
             .eq('property_id', widget.propertyId!);
         
         final assignedIds = List<Map<String, dynamic>>.from(assignmentsResponse)
             .map((e) => e['user_id'] as String)
             .toSet();

         setState(() {
           _selectedLandlordIds.addAll(assignedIds);
         });
       }
     } catch (e) {
       debugPrint('Error fetching landlords: $e');
     }
  }

  void _loadPropertyData() {
    // Find property from provider
    final properties = context.read<PropertyProvider>().properties;
    try {
      final property = properties.firstWhere((p) => p['id'] == widget.propertyId);
      
      _nameController.text = property['name'] ?? '';
      _descriptionController.text = property['description'] ?? '';
      _priceController.text = (property['price_per_night']?.toString() ?? '0');
      
      // Basic location parsing - assuming format "Address, City, Country"
      final locationParts = (property['location'] as String? ?? '').split(', ');
      if (locationParts.isNotEmpty) _locationController.text = locationParts[0];
      if (locationParts.length > 1) _cityController.text = locationParts[1];
      if (locationParts.length > 2) _countryController.text = locationParts[2];
      
      _icalController.text = property['ical_url'] ?? ''; // New
      
      _bedroomsController.text = property['bedrooms']?.toString() ?? '1';
      _bathroomsController.text = property['bathrooms']?.toString() ?? '1';
      _guestsController.text = property['max_guests']?.toString() ?? '1';
      _weeklyDiscountController.text = property['weekly_discount_percent']?.toString() ?? '15';
      _monthlyDiscountController.text = property['monthly_discount_percent']?.toString() ?? '60';

      // Load amenities
      final amenitiesList = (property['amenities_list'] as List<dynamic>?) ?? [];
      for (var amenity in amenitiesList) {
        if (_amenities.containsKey(amenity)) {
          _amenities[amenity] = true;
        }
      }
    } catch (e) {
      debugPrint('Property not found in local state: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _icalController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _guestsController.dispose();
    _weeklyDiscountController.dispose();
    _monthlyDiscountController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    setState(() {
      _propertyImages.addAll(images.map((img) => File(img.path)));
    });
  }

  Future<void> _syncCalendar() async {
    if (widget.propertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please save the property first.')));
      return;
    }
    if (_icalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an iCal URL.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<PropertyProvider>().syncCalendar(widget.propertyId!, _icalController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendar synced successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showHolidayPricingDialog() async {
    if (widget.propertyId == null) return;
    
    // Local state for the dialog
    List<DateTime> selectedDates = [];
    int percentageIncrease = 20; // Default
    final percentageController = TextEditingController(text: '20');
    bool isLoadingRules = true;
    List<Map<String, dynamic>> existingRules = [];
    DateTime focusedDay = DateTime.now();

    // Fetch rules
    final provider = context.read<PropertyProvider>();
    
    void fetchRules(StateSetter setState) {
      provider.getPricingRules(widget.propertyId!).then((rules) {
        if (mounted) {
          setState(() {
            existingRules = rules;
            isLoadingRules = false;
          });
        }
      });
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Initial fetch
          if (isLoadingRules && existingRules.isEmpty) {
             fetchRules(setState);
          }

          return AlertDialog(
            title: const Text('Manage Holiday Rates'),
            content: SizedBox(
              width: 500,
              height: 600,
              child: Column(
                children: [
                   // Calendar
                   TableCalendar(
                     firstDay: DateTime.now(),
                     lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
                     focusedDay: focusedDay,
                     selectedDayPredicate: (day) {
                       return selectedDates.any((d) => isSameDay(d, day));
                     },
                     onDaySelected: (selectedDay, focused) {
                       setState(() {
                         focusedDay = focused;
                         if (selectedDates.any((d) => isSameDay(d, selectedDay))) {
                           selectedDates.removeWhere((d) => isSameDay(d, selectedDay));
                         } else {
                           selectedDates.add(selectedDay);
                         }
                       });
                     },
                     onPageChanged: (focused) {
                        focusedDay = focused;
                     },
                     calendarStyle: const CalendarStyle(
                       selectedDecoration: BoxDecoration(
                         color: Color(0xFFFFD700),
                         shape: BoxShape.circle,
                       ),
                       todayDecoration: BoxDecoration(
                         color: Color(0xFFE8F5E9),
                         shape: BoxShape.circle,
                       ),
                       todayTextStyle: TextStyle(color: Color(0xFFFFD700)),
                     ),
                   ),
                   const SizedBox(height: 16),
                   
                   // Percentage Input
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           const Text('Increase Price by: '),
                           const SizedBox(width: 8),
                           SizedBox(
                             width: 100,
                             child: TextField(
                               controller: percentageController,
                               keyboardType: TextInputType.number,
                               decoration: const InputDecoration(
                                 suffixText: '%',
                                 isDense: true,
                                 border: OutlineInputBorder(),
                               ),
                               onChanged: (val) {
                                 percentageIncrease = int.tryParse(val) ?? 0;
                               },
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       SizedBox(
                         width: double.infinity,
                         child: ElevatedButton(
                           onPressed: selectedDates.isEmpty ? null : () async {
                             // Add Rule
                             setState(() => isLoadingRules = true);
                             try {
                               await provider.addPricingRules(
                                 widget.propertyId!, 
                                 selectedDates, 
                                 percentageIncrease
                               );
                               // Clear selection and refresh
                               selectedDates.clear();
                               selectedDates = []; // Re-init
                               fetchRules(setState);
                             } catch (e) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Error: $e')),
                               );
                               setState(() => isLoadingRules = false);
                             }
                           },
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.black,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 12),
                           ),
                           child: const Text('Add Rule'),
                         ),
                       ),
                     ],
                   ),
                   const Divider(height: 32),
                   
                   // Existing Rules List
                   const Align(
                     alignment: Alignment.centerLeft,
                     child: Text('Active Rules:', style: TextStyle(fontWeight: FontWeight.bold)),
                   ),
                   const SizedBox(height: 8),
                   Expanded(
                     child: isLoadingRules 
                       ? const Center(child: CircularProgressIndicator())
                       : existingRules.isEmpty 
                         ? const Center(child: Text('No custom rates applied.', style: TextStyle(color: Colors.grey)))
                         : ListView.builder(
                             itemCount: existingRules.length,
                             itemBuilder: (context, index) {
                               final rule = existingRules[index];
                               final date = DateTime.parse(rule['date']);
                               final pct = rule['percentage_increase'];
                               return ListTile(
                                 dense: true,
                                 title: Text(date.toString().split(' ')[0]),
                                 trailing: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Text('+$pct%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                     IconButton(
                                       icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                       onPressed: () async {
                                          await provider.deletePricingRule(rule['id']);
                                          fetchRules(setState);
                                       },
                                     ),
                                   ],
                                 ),
                               );
                             },
                           ),
                   ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = context.read<AppStateProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Collect selected amenities
      final selectedAmenities = _amenities.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (widget.propertyId == null) {
        // Create
        await context.read<PropertyProvider>().addProperty(
          name: _nameController.text,
          description: _descriptionController.text,
          price: double.tryParse(_priceController.text) ?? 0.0,
          location: _locationController.text,
          city: _cityController.text,
          country: _countryController.text,
          bedrooms: int.tryParse(_bedroomsController.text) ?? 1,
          bathrooms: int.tryParse(_bathroomsController.text) ?? 1,
          guests: int.tryParse(_guestsController.text) ?? 1,
          landlordId: user.id,
          amenities: selectedAmenities,
          icalUrl: _icalController.text.isNotEmpty ? _icalController.text : null,
          primaryImage: _propertyImages.isNotEmpty ? _propertyImages.first : null,
          otherImages: _propertyImages.length > 1 ? _propertyImages.sublist(1) : null,
        );
      } else {
        // Update
        await context.read<PropertyProvider>().updateProperty(
          id: widget.propertyId!,
          updates: {
            'name': _nameController.text,
            'description': _descriptionController.text,
            'price_per_night': double.tryParse(_priceController.text) ?? 0.0,
            'location': '${_locationController.text}, ${_cityController.text}, ${_countryController.text}',
            'bedrooms': int.tryParse(_bedroomsController.text) ?? 1,
            'bathrooms': int.tryParse(_bathroomsController.text) ?? 1,
            'max_guests': int.tryParse(_guestsController.text) ?? 1,
            'weekly_discount_percent': double.tryParse(_weeklyDiscountController.text) ?? 0.0,
            'monthly_discount_percent': double.tryParse(_monthlyDiscountController.text) ?? 0.0,
          },
          amenities: selectedAmenities,
          icalUrl: _icalController.text.isNotEmpty ? _icalController.text : null,
          newImages: _propertyImages.isNotEmpty ? _propertyImages : null,
        );
      }

      // Save Landlord Assignments
      if (widget.propertyId != null) {
         final supabase = Supabase.instance.client; // Fix: Use global instance
         
         // Clear existing (Simple Replace Approach)
         await supabase.from('property_landlords').delete().eq('property_id', widget.propertyId!);
         
         // Insert new
         if (_selectedLandlordIds.isNotEmpty) {
           final inserts = _selectedLandlordIds.map((uid) => {
             'property_id': widget.propertyId,
             'user_id': uid,
           }).toList();
           await supabase.from('property_landlords').insert(inserts);
         }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.propertyId == null 
              ? 'Property created successfully!' 
              : 'Property updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
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
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.propertyId == null ? 'Add New Property' : 'Edit Property',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photos Section
                    const Text(
                      'Property Photos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          if (_propertyImages.isEmpty)
                            GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[50],
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Tap to add photos', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _propertyImages.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        width: 120,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          image: DecorationImage(
                                            image: FileImage(_propertyImages[index]),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _pickImages,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add More Photos'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Basic Information
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _nameController,
                      label: 'Property Name',
                      icon: Icons.home,
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      icon: Icons.description,
                      maxLines: 3,
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _priceController,
                      label: 'Price per Night (USD)',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    // Holiday Pricing logic
                    // Holiday Pricing logic
                    const Text(
                        'Holiday & Seasonal Pricing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Set custom price increases for specific dates (e.g., Holidays, Weekends).',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showHolidayPricingDialog,
                                icon: const Icon(Icons.calendar_month, color: Color(0xFFFFD700)),
                                label: const Text('Manage Holiday Rates', style: TextStyle(color: Color(0xFFFFD700))),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: Color(0xFFFFD700)),
                                ),
                              ),
                            ),
                          ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Pricing Discounts Section
                    const Text(
                      'Pricing Discounts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _weeklyDiscountController,
                            label: 'Weekly Discount (7+ nights) %',
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _monthlyDiscountController,
                            label: 'Monthly Discount (28+ nights) %',
                            icon: Icons.calendar_month,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _bedroomsController,
                            label: 'Bedrooms',
                            icon: Icons.bed,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _bathroomsController,
                            label: 'Bathrooms',
                            icon: Icons.bathtub,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _guestsController,
                            label: 'Max Guests',
                            icon: Icons.people,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // Location
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _locationController,
                      label: 'Address',
                      icon: Icons.location_on,
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City',
                            icon: Icons.location_city,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _countryController,
                            label: 'Country',
                            icon: Icons.flag,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // Amenities
                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _amenities.keys.map((amenity) {
                          return FilterChip(
                            label: Text(amenity),
                            selected: _amenities[amenity]!,
                            onSelected: (selected) {
                              setState(() => _amenities[amenity] = selected);
                            },
                            selectedColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
                            checkmarkColor: const Color(0xFFFFD700),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // iCalendar Sync
                    const Text(
                      'Calendar Sync',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sync availability with Airbnb, Booking.com, etc.'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _icalController,
                            label: 'iCal URL (e.g. Airbnb Export Link)',
                            icon: Icons.link,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _syncCalendar,
                              icon: const Icon(Icons.sync),
                              label: const Text('Sync Calendar Now'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFFD700),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Assign Landlords
                    const Text(
                      'Assign Landlords',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select users who can manage this property.'),
                          const SizedBox(height: 12),
                          if (_availableLandlords.isEmpty)
                             const Padding(
                               padding: EdgeInsets.all(8.0),
                               child: Text("Loading landlords..."),
                             )
                          else
                            Wrap(
                              spacing: 8,
                              children: _availableLandlords.map((user) {
                                final isSelected = _selectedLandlordIds.contains(user['id']);
                                return FilterChip(
                                  label: Text(user['email'] ?? 'Unknown'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedLandlordIds.add(user['id']);
                                      } else {
                                        _selectedLandlordIds.remove(user['id']);
                                      }
                                    });
                                  },
                                  selectedColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                  checkmarkColor: const Color(0xFFFFD700),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProperty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Property',
                                style: TextStyle(
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
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
      ),
    );
  }
}
