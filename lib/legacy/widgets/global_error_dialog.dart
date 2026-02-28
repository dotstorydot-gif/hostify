import "package:flutter/material.dart";

class GlobalDialogs {
  static Future<void> showError(BuildContext context, String message, [String? details]) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Error', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          if (details != null) ...[
            const SizedBox(height: 8),
            Text(
              details,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static Future<void> showSuccess(BuildContext context, String message, {String title = 'Success'}) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFFFFD700)),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Color(0xFFFFD700))),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFD700)),
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
