import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hostify/core/config/supabase_config.dart';

void main() {
  group('Supabase Connectivity Tests', () {
    late SupabaseClient client;

    setUp(() {
      client = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseAnonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
    });

    test('Initial Connection - Configuration Check', () {
      expect(SupabaseConfig.supabaseUrl, isNotEmpty);
      expect(SupabaseConfig.supabaseAnonKey, isNotEmpty);
      // print('✅ URL Configured: ${SupabaseConfig.supabaseUrl}');
    });

    test('Database Connection - Public Table Access', () async {
      try {
        // Try to select just one column from a public table to minimize data
        // Using 'properties' which should exist
        final response = await client
            .from('properties')
            .select('id')
            .limit(1);
            
        // print('✅ Database accessible. Rows returned: ${response.length}');
        expect(response, isA<List>());
      } catch (e) {
        fail('❌ Database connection failed: $e');
      }
    });
    
    test('Storage Buckets - Public Bucket Check', () async {
      try {
        final buckets = await client.storage.listBuckets();
        // print('✅ Storage accessible. Buckets found: ${buckets.length}');
        
        // final bucketNames = buckets.map((b) => b.name).toList();
        // print('   Buckets: $bucketNames');
        
        expect(buckets, isA<List>());
        // Note: Empty list is expected if RLS prevents listing buckets for Anon users
      } catch (e) {
        fail('❌ Storage check failed: $e');
      }
    });
  });
}
