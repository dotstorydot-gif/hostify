import 'package:flutter/material.dart';
import 'package:hostify/legacy/screens/guest_document_upload_screen.dart';

class GuestTermsScreen extends StatefulWidget {
  const GuestTermsScreen({super.key});

  @override
  State<GuestTermsScreen> createState() => _GuestTermsScreenState();
}

class _GuestTermsScreenState extends State<GuestTermsScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFF000000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.description, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Welcome to .Hostify',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please read and accept our terms before continuing',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
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
                        _buildSection(
                          '1. Acceptance of Terms',
                          'By accessing and using .Hostify services, you accept and agree to be bound by the terms and provision of this agreement.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          '2. Booking & Reservations',
                          'All bookings are subject to availability. A valid ID or passport is required for verification. Check-in time is 3:00 PM and check-out time is 11:00 AM unless otherwise arranged.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          '3. Payment Terms',
                          'Full payment is required at the time of booking. Cancellations made 48 hours before check-in are eligible for a full refund. Late cancellations may incur charges.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          '4. Guest Responsibilities',
                          'Guests must respect property rules, maintain cleanliness, and report any damages immediately. Smoking is prohibited in all indoor areas. Maximum occupancy must not be exceeded.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          '5. Privacy & Data Protection',
                          'We collect and store your personal information solely for booking and service purposes. Your data is protected and will not be shared with third parties without consent.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          '6. Liability',
                          '.Hostify is not liable for any loss, damage, or injury during your stay except where caused by our negligence. Guests are responsible for their personal belongings.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          '7. Service Requests',
                          'Additional services (housekeeping, transportation, etc.) may be requested and are subject to availability and additional charges. Service requests should be made at least 24 hours in advance.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          '8. Modifications',
                          'We reserve the right to modify these terms at any time. Continued use of our services constitutes acceptance of any changes.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Bottom acceptance section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _accepted,
                      onChanged: (value) => setState(() => _accepted = value ?? false),
                      activeColor: const Color(0xFFFFD700),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _accepted = !_accepted),
                        child: const Text(
                          'I have read and accept the Terms & Conditions',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _accepted
                        ? () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GuestDocumentUploadScreen(),
                              ),
                            );
                          }
                        : null,
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
                      'Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
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
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
