import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class AdminContentCreator extends StatefulWidget {
  const AdminContentCreator({super.key});

  @override
  State<AdminContentCreator> createState() => _AdminContentCreatorState();
}

class _AdminContentCreatorState extends State<AdminContentCreator> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetAudience = 'all';
  File? _selectedImage;
  bool _isLoading = false;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final response = await Supabase.instance.client
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      
      setState(() {
        _announcements = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading announcements: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final fileName = 'announcement_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'public/$fileName';

      await Supabase.instance.client.storage
          .from('announcements')
          .upload(path, image);

      final url = Supabase.instance.client.storage
          .from('announcements')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _publishAnnouncement() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and message')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }

      await Supabase.instance.client.from('announcements').insert({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'image_url': imageUrl,
        'target_audience': _targetAudience,
        'is_active': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement published successfully!')),
        );
        
        // Clear form
        _titleController.clear();
        _messageController.clear();
        setState(() {
          _selectedImage = null;
          _targetAudience = 'all';
        });
        
        // Refresh list
        _fetchAnnouncements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error publishing: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAnnouncementStatus(String id, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('announcements')
          .update({'is_active': !currentStatus})
          .eq('id', id);
      
      _fetchAnnouncements();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!currentStatus ? 'Announcement activated' : 'Announcement deactivated')),
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

  Future<void> _deleteAnnouncement(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('announcements')
            .delete()
            .eq('id', id);
        
        _fetchAnnouncements();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement deleted')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('News & Announcements'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Create New Announcement Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Announcement',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title Field
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Message Field
                  TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.message),
                      helperText: 'Write your announcement message here',
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  
                  // Target Audience Selector
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.people, size: 20, color: Color(0xFFFFD700)),
                            SizedBox(width: 8),
                            Text(
                              'Send To:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All Users'),
                              selected: _targetAudience == 'all',
                              onSelected: (_) => setState(() => _targetAudience = 'all'),
                              selectedColor: const Color(0xFFFFD700),
                              labelStyle: TextStyle(
                                color: _targetAudience == 'all' ? Colors.white : Colors.black,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Landlords Only'),
                              selected: _targetAudience == 'landlord',
                              onSelected: (_) => setState(() => _targetAudience = 'landlord'),
                              selectedColor: const Color(0xFFFFD700),
                              labelStyle: TextStyle(
                                color: _targetAudience == 'landlord' ? Colors.white : Colors.black,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Travelers Only'),
                              selected: _targetAudience == 'traveler',
                              onSelected: (_) => setState(() => _targetAudience = 'traveler'),
                              selectedColor: const Color(0xFFFFD700),
                              labelStyle: TextStyle(
                                color: _targetAudience == 'traveler' ? Colors.white : Colors.black,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Guests Only'),
                              selected: _targetAudience == 'guest',
                              onSelected: (_) => setState(() => _targetAudience = 'guest'),
                              selectedColor: const Color(0xFFFFD700),
                              labelStyle: TextStyle(
                                color: _targetAudience == 'guest' ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Image Upload
                  InkWell(
                    onTap: _pickImage,
                    child: Container(
                      height: _selectedImage != null ? 200 : 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    "Upload Banner Image (Optional)",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.red,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                      onPressed: () => setState(() => _selectedImage = null),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Publish Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _publishAnnouncement,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isLoading ? 'Publishing...' : 'Publish Announcement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Existing Announcements List
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Published Announcements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  _announcements.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No announcements yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _announcements.length,
                          itemBuilder: (context, index) {
                            final announcement = _announcements[index];
                            final isActive = announcement['is_active'] ?? true;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (announcement['image_url'] != null)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      child: Image.network(
                                        announcement['image_url'],
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                announcement['title'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Chip(
                                              label: Text(
                                                _getAudienceName(announcement['target_audience']),
                                                style: const TextStyle(fontSize: 10),
                                              ),
                                              backgroundColor: Colors.black.withOpacity(0.1),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          announcement['message'],
                                          style: TextStyle(color: Colors.grey[700]),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Switch(
                                              value: isActive,
                                              onChanged: (_) => _toggleAnnouncementStatus(
                                                announcement['id'],
                                                isActive,
                                              ),
                                              activeThumbColor: const Color(0xFFFFD700),
                                            ),
                                            Text(isActive ? 'Active' : 'Inactive'),
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteAnnouncement(announcement['id']),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAudienceName(String audience) {
    switch (audience) {
      case 'all':
        return 'All Users';
      case 'landlord':
        return 'Landlords';
      case 'traveler':
        return 'Travelers';
      case 'guest':
        return 'Guests';
      default:
        return audience;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
