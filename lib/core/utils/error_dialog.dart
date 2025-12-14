import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A universal error dialog utility that provides a consistent
/// way to display errors throughout the application.
class ErrorDialog {
  /// Shows an error dialog with the given message.
  /// 
  /// [context] - The build context to show the dialog
  /// [message] - The error message to display (can be String, Exception, or dynamic)
  /// [title] - Optional custom title (defaults to "Error")
  /// [onDismiss] - Optional callback when dialog is dismissed
  static Future<void> show(
    BuildContext context, {
    required dynamic message,
    String? title,
    VoidCallback? onDismiss,
  }) async {
    // Extract error message from different types
    String errorMessage = _extractErrorMessage(message);
    
    // Use custom title or default
    final dialogTitle = title ?? 'Error';

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dialogTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Extracts a readable error message from various error types
  static String _extractErrorMessage(dynamic error) {
    if (error == null) {
      return 'An unknown error occurred. Please try again.';
    }

    if (error is String) {
      return error;
    }

    if (error is Exception) {
      final message = error.toString();
      // Remove "Exception: " prefix if present
      if (message.startsWith('Exception: ')) {
        return message.substring(11);
      }
      return message;
    }

    // For other types, convert to string
    final errorString = error.toString();
    
    // Clean up common error prefixes
    if (errorString.startsWith('Exception: ')) {
      return errorString.substring(11);
    }
    if (errorString.startsWith('Error: ')) {
      return errorString.substring(7);
    }

    return errorString;
  }

  /// Shows an error dialog with a retry option
  /// 
  /// [context] - The build context to show the dialog
  /// [message] - The error message to display
  /// [title] - Optional custom title (defaults to "Error")
  /// [onRetry] - Callback when retry is pressed
  /// [onDismiss] - Optional callback when dialog is dismissed
  static Future<void> showWithRetry(
    BuildContext context, {
    required dynamic message,
    String? title,
    required VoidCallback onRetry,
    VoidCallback? onDismiss,
  }) async {
    String errorMessage = _extractErrorMessage(message);
    final dialogTitle = title ?? 'Error';

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dialogTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
