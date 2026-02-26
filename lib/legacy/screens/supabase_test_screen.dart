import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test screen to verify Supabase connection
class SupabaseTestScreen extends StatefulWidget {
  const SupabaseTestScreen({super.key});

  @override
  State<SupabaseTestScreen> createState() => _SupabaseTestScreenState();
}

class _SupabaseTestScreenState extends State<SupabaseTestScreen> {
  String _statusMessage = 'Testing connection...';
  bool _isLoading = true;
  Color _statusColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Test 1: Check if client is initialized
      setState(() {
        _statusMessage = '✓ Supabase client initialized\n\nTesting database connection...';
      });
      
      await Future.delayed(const Duration(seconds: 1));
      
      // Test 2: Simple query to check connection
      final response = await supabase.from('user_profiles').select().limit(1);
      
      setState(() {
        _statusMessage = '''✓ Supabase client initialized
✓ Database connection successful
✓ Query executed successfully

Found ${(response as List).length} user profile(s)

🎉 Integration Complete!
You can now use Supabase services in your app.''';
        _isLoading = false;
        _statusColor = Colors.green;
      });
      
    } catch (e) {
      setState(() {
        _statusMessage = '''❌ Connection Error

Error: $e

Possible issues:
1. Check API key format - should start with "eyJ..."
2. Verify database migrations ran successfully
3. Check RLS policies are configured

Get the correct anon key from:
Supabase Dashboard → Settings → API → anon public''';
        _isLoading = false;
        _statusColor = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Connection Test'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _statusColor, width: 2),
                ),
                child: Column(
                  children: [
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Icon(
                        _statusColor == Colors.green ? Icons.check_circle : Icons.error,
                        color: _statusColor,
                        size: 64,
                      ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _statusMessage = 'Testing connection...';
                        _statusColor = Colors.orange;
                      });
                      _testConnection();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Test Again',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
