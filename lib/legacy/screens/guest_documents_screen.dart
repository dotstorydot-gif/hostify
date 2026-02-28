import "package:flutter/material.dart";
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;

class GuestDocumentsScreen extends StatefulWidget {
  const GuestDocumentsScreen({super.key});

  @override
  State<GuestDocumentsScreen> createState() => _GuestDocumentsScreenState();
}

class _GuestDocumentsScreenState extends State<GuestDocumentsScreen> {
  // Mock data - should come from Supabase
  bool _hasIdDocument = false;
  bool _hasPassport = false;
  String _idVerificationStatus = 'Not Verified';
  String _passportVerificationStatus = 'Not Verified';
  
  XFile? _selectedIdDocument;
  XFile? _selectedPassport;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    // TODO: Load from Supabase Storage
    // Check if user has uploaded documents before
    setState(() {
      _hasIdDocument = false;
      _idVerificationStatus = 'Not Verified';
    });
  }

  Future<void> _pickDocument(String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        if (type == 'id') {
          _selectedIdDocument = image;
        } else {
          _selectedPassport = image;
        }
      });
    }
  }

  Future<void> _uploadDocument(String type) async {
    setState(() => _isLoading = true);

    // TODO: Upload to Supabase Storage
    // 1. Upload file to storage bucket
    // 2. Save URL to user profile in database
    // 3. Update verification status
    
    await Future.delayed(const Duration(seconds: 2)); // Simulate upload

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (type == 'id') {
          _hasIdDocument = true;
          _idVerificationStatus = 'Pending Review';
          _selectedIdDocument = null;
        } else {
          _hasPassport = true;
          _passportVerificationStatus = 'Pending Review';
          _selectedPassport = null;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type == 'id' ? 'ID' : 'Passport'} uploaded successfully!')),
      );
    }
  }

  Future<void> _deleteDocument(String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete this ${type == 'id' ? 'ID' : 'passport'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        if (type == 'id') {
          _hasIdDocument = false;
          _idVerificationStatus = 'Not Verified';
        } else {
          _hasPassport = false;
          _passportVerificationStatus = 'Not Verified';
        }
      });
      
      // TODO: Delete from Supabase Storage
    }
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
                        'My Documents',
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
                // Info Card
                Container(
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
                          Icons.verified_user,
                          color: Color(0xFFFFD700),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verification Documents',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Upload once, use for all bookings',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Documents List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ID Document Card
                _buildDocumentCard(
                  type: 'id',
                  title: 'National ID / Driver\'s License',
                  hasDocument: _hasIdDocument,
                  verificationStatus: _idVerificationStatus,
                  selectedFile: _selectedIdDocument,
                ),
                const SizedBox(height: 16),
                
                // Passport Card
                _buildDocumentCard(
                  type: 'passport',
                  title: 'Passport',
                  hasDocument: _hasPassport,
                  verificationStatus: _passportVerificationStatus,
                  selectedFile: _selectedPassport,
                ),
                
                const SizedBox(height: 24),
                
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your documents are securely stored and only used for verification purposes.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String type,
    required String title,
    required bool hasDocument,
    required String verificationStatus,
    XFile? selectedFile,
  }) {
    final statusColor = verificationStatus == 'Verified'
        ? Colors.green
        : verificationStatus == 'Pending Review'
            ? Colors.orange
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    type == 'id' ? Icons.badge : Icons.flight_takeoff,
                    color: const Color(0xFFFFD700),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      verificationStatus == 'Verified'
                          ? Icons.check_circle
                          : verificationStatus == 'Pending Review'
                              ? Icons.pending
                              : Icons.cancel,
                      size: 14,
                      color: statusColor[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      verificationStatus,
                      style: TextStyle(
                        color: statusColor[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (hasDocument && selectedFile == null)
            // Document already uploaded
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Document uploaded',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDocument(type),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Replace'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFD700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteDocument(type),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else if (selectedFile != null)
            // File selected, ready to upload
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb 
                      ? Image.network(selectedFile.path, fit: BoxFit.cover, width: double.infinity)
                      : Image.file(io.File(selectedFile.path), fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _uploadDocument(type),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(_isLoading ? 'Uploading...' : 'Upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          if (type == 'id') {
                            _selectedIdDocument = null;
                          } else {
                            _selectedPassport = null;
                          }
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            )
          else
            // No document uploaded
            GestureDetector(
              onTap: () => _pickDocument(type),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'Tap to upload document',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'JPG, PNG up to 10MB',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
