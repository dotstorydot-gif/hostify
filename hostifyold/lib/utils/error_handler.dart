import 'package:flutter/material.dart';

/// Centralized error handling utility
class ErrorHandler {
  /// Show error snackbar with consistent styling
  static void showError(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Show success snackbar
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
  
  /// Show warning snackbar
  static void showWarning(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF9800),
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
  
  /// Show info snackbar
  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
  
  /// Show error dialog
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
  }) async {
    if (!context.mounted) return;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  details,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Parse Supabase error and return user-friendly message
  static String parseError(dynamic error) {
    if (error == null) return 'An unknown error occurred';
    
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }
    
    // Authentication errors
    if (errorString.contains('invalid_grant') ||
        errorString.contains('invalid credentials')) {
      return 'Invalid email or password.';
    }
    
    if (errorString.contains('user already exists') ||
        errorString.contains('already registered')) {
      return 'This email is already registered.';
    }
    
    if (errorString.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    
    // Database errors
    if (errorString.contains('foreign key')) {
      return 'Cannot complete operation due to related data.';
    }
    
    if (errorString.contains('unique constraint')) {
      return 'This record already exists.';
    }
    
    if (errorString.contains('not found')) {
      return 'The requested resource was not found.';
    }
    
    // Permission errors
    if (errorString.contains('permission denied') ||
        errorString.contains('insufficient_privileges')) {
      return 'You don\'t have permission to perform this action.';
    }
    
    // File upload errors
    if (errorString.contains('file size')) {
      return 'File size exceeds the maximum limit.';
    }
    
    if (errorString.contains('file type')) {
      return 'This file type is not allowed.';
    }
    
    // Default: Return cleaned error message
    return _cleanErrorMessage(errorString);
  }
  
  /// Clean up technical error messages for users
  static String _cleanErrorMessage(String error) {
    // Remove technical prefixes
    error = error.replaceAll(RegExp(r'exception: |error: |postgresql '), '');
    
    // Capitalize first letter
    if (error.isNotEmpty) {
      error = error[0].toUpperCase() + error.substring(1);
    }
    
    // Ensure it ends with a period
    if (!error.endsWith('.')) {
      error += '.';
    }
    
    return error;
  }
  
  /// Handle async errors with loading state
  static Future<T?> handleAsync<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    String? successMessage,
    String? errorMessage,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      final result = await operation();
      
      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }
      
      onSuccess?.call();
      return result;
    } catch (e) {
      if (context.mounted) {
        final message = errorMessage ?? parseError(e);
        showError(context, message);
      }
      
      onError?.call();
      return null;
    }
  }
}
