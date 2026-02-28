import "package:flutter/material.dart";
import 'package:hostify/legacy/screens/id_verification_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  "Please read and agree to our terms and conditions to proceed with your booking.\n\n"
                  "1. Respect the property.\n"
                  "2. No loud noise after 10 PM.\n"
                  "3. Check-out time is 11 AM.\n"
                  // ... more text
                  ,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const IdVerificationScreen()),
                  );
                },
                child: const Text('I Agree'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
