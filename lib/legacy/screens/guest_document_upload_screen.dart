import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hostify/legacy/screens/guest_verification_pending_screen.dart';
import 'package:provider/provider.dart';
import 'package:hostify/legacy/providers/app_state_provider.dart';
import 'package:hostify/legacy/providers/document_provider.dart';

class GuestDocumentUploadScreen extends StatefulWidget {
  const GuestDocumentUploadScreen({super.key});

  @override
  State<GuestDocumentUploadScreen> createState() => _GuestDocumentUploadScreenState();
}

class _GuestDocumentUploadScreenState extends State<GuestDocumentUploadScreen> {
  String _documentType = 'passport'; // 'passport' or 'id'
  XFile? _passportImage;
  XFile? _idFrontImage;
  XFile? _idBackImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String imageType) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
        if (imageType == 'passport') {
            _passportImage = pickedFile;
          } else if (imageType == 'id_front') {
            _idFrontImage = pickedFile;
          } else if (imageType == 'id_back') {
            _idBackImage = pickedFile;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  bool _isSubmitting = false;

  bool _canSubmit() {
    if (_documentType == 'passport') {
      return _passportImage != null;
    } else {
      return _idFrontImage != null && _idBackImage != null;
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit()) return;

    final user = context.read<AppStateProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload Front Image
      await context.read<DocumentProvider>().uploadDocumentCompat(
        userId: user.id,
        documentType: '${_documentType}_front',
        imageFile: _documentType == 'passport' ? _passportImage! : _idFrontImage!,
      );

      // Upload Back Image if needed
      if (_documentType != 'passport' && _idBackImage != null) {
        await context.read<DocumentProvider>().uploadDocumentCompat(
          userId: user.id,
          documentType: '${_documentType}_back',
          imageFile: _idBackImage!,
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const GuestVerificationPendingScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Document Verification'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FC3F7), Color(0xFF5E92F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Identity Verification',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please upload a clear photo of your ID document',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Document Type Selector
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  const Text(
                    'Select Document Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDocumentTypeCard(
                          'Passport',
                          'passport',
                          Icons.book,
                          'Upload 1 page',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDocumentTypeCard(
                          'National ID',
                          'id',
                          Icons.credit_card,
                          'Front & Back',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Upload Section
            if (_documentType == 'passport') ...[
              _buildUploadCard(
                'Passport Photo',
                'Upload a clear photo of your passport main page',
                _passportImage,
                () => _pickImage('passport'),
              ),
            ] else ...[
              _buildUploadCard(
                'ID Front Side',
                'Upload the front side of your ID card',
                _idFrontImage,
                () => _pickImage('id_front'),
              ),
              const SizedBox(height: 16),
              _buildUploadCard(
                'ID Back Side',
                'Upload the back side of your ID card',
                _idBackImage,
                () => _pickImage('id_back'),
              ),
            ],
            const SizedBox(height: 24),

            // Guidelines
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Photo Guidelines',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuideline('✓ Ensure all text is clearly readable'),
                  _buildGuideline('✓ Photo should be well-lit'),
                  _buildGuideline('✓ No glare or shadows'),
                  _buildGuideline('✓ All corners visible'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit() ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Submit for Verification',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTypeCard(String title, String type, IconData icon, String subtitle) {
    final isSelected = _documentType == type;
    
    return GestureDetector(
      onTap: () => setState(() {
        _documentType = type;
        // Clear images when switching types
        _passportImage = null;
        _idFrontImage = null;
        _idBackImage = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(String title, String description, XFile? image, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
              ),
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb 
                        ? Image.network(image.path, fit: BoxFit.cover, width: double.infinity)
                        : Image.file(io.File(image.path), fit: BoxFit.cover, width: double.infinity),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to upload photo',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (image != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Photo uploaded',
                      style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onTap,
                  child: const Text('Change'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideline(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
      ),
    );
  }
}
