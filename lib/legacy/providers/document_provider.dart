import "package:flutter/material.dart";
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

/// Provider for managing guest identity documents
class DocumentProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _userDocuments = [];
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get userDocuments => _userDocuments;

  /// Upload a document to storage and database
  Future<void> uploadDocument({
    required String userId,
    required String documentType,
    required io.File file,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final fileName = path.basename(file.path);
      final fileExt = path.extension(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = '${userId}_${documentType}_$timestamp$fileExt';
      final storagePath = '$userId/$uniqueName';

      // 1. Upload to Supabase Storage
      await _supabase.storage.from('documents').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // 2. Insert into user_documents table (using 20260121_create_user_documents.sql schema)
      await _supabase.from('user_documents').insert({
        'user_id': userId,
        'document_type': documentType,
        'file_path': storagePath,
        'file_name': fileName,
        'file_size': await file.length(),
      });

      notifyListeners();
    } catch (e) {
      _setError('Failed to upload document: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Web-compatible upload using XFile and uploadBinary
  Future<void> uploadDocumentCompat({
    required String userId,
    required String documentType,
    required XFile imageFile,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final fileExt = imageFile.path.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = '${userId}_${documentType}_$timestamp.$fileExt';
      final storagePath = '$userId/$uniqueName';

      final bytes = await imageFile.readAsBytes();

      // 1. Upload to Supabase Storage using uploadBinary
      await _supabase.storage.from('documents').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$fileExt',
          cacheControl: '3600', 
          upsert: false
        ),
      );

      // 2. Insert into user_documents table
      await _supabase.from('user_documents').insert({
        'user_id': userId,
        'document_type': documentType,
        'file_path': storagePath,
        'file_name': uniqueName,
        'file_size': bytes.length,
      });

      notifyListeners();
    } catch (e) {
      _setError('Failed to upload document: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch documents for a specific user
  Future<void> fetchUserDocuments(String userId) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await _supabase
          .from('user_documents')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
          
      _userDocuments = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch documents: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId, String filePath) async {
    try {
      // 1. Delete from Storage
      await _supabase.storage.from('documents').remove([filePath]);
      
      // 2. Delete from Database
      await _supabase.from('user_documents').delete().eq('id', documentId);
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete document: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
