import "package:flutter/material.dart";
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConnectionTest extends StatefulWidget {
  const SupabaseConnectionTest({super.key});

  @override
  State<SupabaseConnectionTest> createState() => _SupabaseConnectionTestState();
}

class _SupabaseConnectionTestState extends State<SupabaseConnectionTest> {
  bool _isLoading = true;
  String _status = 'Testing connection...';
  Color _statusColor = Colors.orange;
  Map<String, dynamic> _results = {};

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _results = {};
    });

    try {
      // Test 1: Check if Supabase is initialized
      final supabase = Supabase.instance.client;
      _results['initialized'] = '✅ Supabase client initialized';

      // Test 2: Get Supabase URL
      // Test 2: Get Supabase Session
      final session = supabase.auth.currentSession;
      _results['session'] = session != null ? '✅ Session Active' : 'ℹ️ No Active Session';

      // Test 3: Test simple query (count properties)
      try {
        final response = await supabase
            .from('properties')
            .select()
            .count(CountOption.exact);
        
        _results['database'] = '✅ Database connected (${response.count} properties)';
      } catch (e) {
        _results['database'] = '❌ Database error: $e';
      }

      // Test 4: Check authentication state
      if (session != null) {
        _results['auth'] = '✅ User authenticated: ${session.user.email}';
      } else {
        _results['auth'] = '⚠️ No user logged in (OK for testing)';
      }

      // Test 5: Test storage buckets
      try {
        final buckets = await supabase.storage.listBuckets();
        _results['storage'] = '✅ Storage accessible (${buckets.length} buckets)';
      } catch (e) {
        _results['storage'] = '❌ Storage error: $e';
      }

      setState(() {
        _status = 'All tests completed!';
        _statusColor = Colors.green;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Connection failed!';
        _statusColor = Colors.red;
        _results['error'] = '❌ Fatal error: $e';
        _isLoading = false;
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor, width: 2),
              ),
              child: Row(
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(_statusColor == Colors.green ? Icons.check_circle : Icons.error,
                        color: _statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Results
            if (_results.isNotEmpty) ...[
              const Text(
                'Test Results',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final key = _results.keys.elementAt(index);
                    final value = _results[key];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          key.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Retry Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: const Icon(Icons.refresh),
                label: const Text('Re-test Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
