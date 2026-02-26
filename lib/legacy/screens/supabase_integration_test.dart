import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hostify/legacy/services/auth_service.dart';
import 'package:hostify/legacy/services/property_service.dart';

/// Comprehensive Supabase Integration Test
class SupabaseIntegrationTest extends StatefulWidget {
  const SupabaseIntegrationTest({super.key});

  @override
  State<SupabaseIntegrationTest> createState() => _SupabaseIntegrationTestState();
}

class _SupabaseIntegrationTestState extends State<SupabaseIntegrationTest> {
  final List<TestResult> _testResults = [];
  bool _isRunning = false;
  int _passedTests = 0;
  int _failedTests = 0;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
      _passedTests = 0;
      _failedTests = 0;
    });

    await _test1CheckClientInitialization();
    await _test2CheckDatabaseConnection();
    await _test3CheckTablesExist();
    await _test4TestAuthService();
    await _test5TestPropertyService();

    setState(() => _isRunning = false);
  }

  Future<void> _test1CheckClientInitialization() async {
    await _runTest(
      'Supabase Client Initialization',
      () async {
        final client = Supabase.instance.client;
        if (client.auth.currentUser == null) {
          return TestResult(
            name: 'Supabase Client',
            passed: true,
            message: 'Client initialized, no user logged in',
          );
        }
        return TestResult(
          name: 'Supabase Client',
          passed: true,
          message: 'Client initialized, user: ${client.auth.currentUser?.email}',
        );
      },
    );
  }

  Future<void> _test2CheckDatabaseConnection() async {
    await _runTest(
      'Database Connection',
      () async {
        try {
          await Supabase.instance.client
              .from('user_profiles')
              .select('id')
              .limit(1);
          
          return TestResult(
            name: 'Database Connection',
            passed: true,
            message: 'Successfully queried database',
          );
        } catch (e) {
          return TestResult(
            name: 'Database Connection',
            passed: false,
            message: 'Failed to query database: $e',
          );
        }
      },
    );
  }

  Future<void> _test3CheckTablesExist() async {
    await _runTest(
      'Check Required Tables',
      () async {
        try {
          final tables = [
            'user_profiles',
            'user_roles',
            'property-images',
            'bookings',
            'review-images',
          ];

          for (final table in tables) {
            await Supabase.instance.client.from(table).select('id').limit(1);
          }

          return TestResult(
            name: 'Required Tables',
            passed: true,
            message: 'All ${tables.length} core tables accessible',
          );
        } catch (e) {
          return TestResult(
            name: 'Required Tables',
            passed: false,
            message: 'Table access error: $e',
          );
        }
      },
    );
  }

  Future<void> _test4TestAuthService() async {
    await _runTest(
      'Auth Service',
      () async {
        try {
          final authService = AuthService();
          final isLoggedIn = authService.isLoggedIn;
          
          return TestResult(
            name: 'Auth Service',
            passed: true,
            message: 'Auth service functional, logged in: $isLoggedIn',
          );
        } catch (e) {
          return TestResult(
            name: 'Auth Service',
            passed: false,
            message: 'Auth service error: $e',
          );
        }
      },
    );
  }

  Future<void> _test5TestPropertyService() async {
    await _runTest(
      'Property Service',
      () async {
        try {
          final propertyService = PropertyService();
          final properties = await propertyService.getActiveProperties();
          
          return TestResult(
            name: 'Property Service',
            passed: true,
            message: 'Fetched ${properties.length} properties',
          );
        } catch (e) {
          return TestResult(
            name: 'Property Service',
            passed: false,
            message: 'Property service error: $e',
          );
        }
      },
    );
  }

  Future<void> _runTest(String name, Future<TestResult> Function() test) async {
    try {
      final result = await test();
      setState(() {
        _testResults.add(result);
        if (result.passed) {
          _passedTests++;
        } else {
          _failedTests++;
        }
      });
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      setState(() {
        _testResults.add(TestResult(
          name: name,
          passed: false,
          message: 'Test crashed: $e',
        ));
        _failedTests++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Supabase Integration Test'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runTests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _failedTests == 0 && !_isRunning
                    ? [Colors.green[400]!, Colors.green[600]!]
                    : [const Color(0xFFFFD700), const Color(0xFF3A4836)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                if (_isRunning)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Icon(
                    _failedTests == 0 ? Icons.check_circle : Icons.warning,
                    color: Colors.white,
                    size: 48,
                  ),
                const SizedBox(height: 16),
                Text(
                  _isRunning
                      ? 'Running Tests...'
                      : _failedTests == 0
                          ? '✓ All Tests Passed! 🎉'
                          : '⚠️ Some Tests Failed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Passed: $_passedTests | Failed: $_failedTests',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Test Results List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: result.passed ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      result.passed ? Icons.check_circle : Icons.error,
                      color: result.passed ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    title: Text(
                      result.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        result.message,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TestResult {
  final String name;
  final bool passed;
  final String message;

  TestResult({
    required this.name,
    required this.passed,
    required this.message,
  });
}
