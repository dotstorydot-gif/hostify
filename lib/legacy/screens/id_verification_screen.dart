import "package:flutter/material.dart";
import 'package:hostify/legacy/screens/booking_screen.dart';

class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  String? _selectedDocType = 'passport'; // 'passport' or 'id_card'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Verification'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Document Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Passport'),
                    value: 'passport',
                    groupValue: _selectedDocType,
                    onChanged: (String? value) => setState(() => _selectedDocType = value),
                    activeColor: const Color(0xFFFFD700),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('ID Card'),
                    value: 'id_card',
                    groupValue: _selectedDocType,
                    onChanged: (String? value) => setState(() => _selectedDocType = value),
                    activeColor: const Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_selectedDocType == 'passport') ...[
              _buildUploadButton("Upload Passport Photo"),
            ] else ...[
              _buildUploadButton("Upload ID Front"),
              const SizedBox(height: 16),
              _buildUploadButton("Upload ID Back"),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                // Simulate verification success
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const BookingScreen()),
                );
              },
              child: const Text('Verify & Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton(String label) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: InkWell(
        onTap: () {
          // Placeholder for image picker
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image picker placeholder logic')),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
