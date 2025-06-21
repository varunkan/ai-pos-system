import 'package:flutter/material.dart';

/// A reusable error dialog widget for consistent error handling.
/// 
/// This widget provides a standardized way to display errors to users.
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final bool showRetry;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.showRetry = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (showRetry)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true); // Return true to indicate retry
            },
            child: const Text('Retry'),
          ),
        if (actionText != null && onAction != null)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction!();
            },
            child: Text(actionText!),
          ),
      ],
    );
  }
}

/// A specialized error dialog for network errors.
class NetworkErrorDialog extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const NetworkErrorDialog({
    super.key,
    this.message = 'Network connection error. Please check your internet connection and try again.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDialog(
      title: 'Network Error',
      message: message,
      showRetry: onRetry != null,
    );
  }
}

/// A specialized error dialog for validation errors.
class ValidationErrorDialog extends StatelessWidget {
  final String message;

  const ValidationErrorDialog({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDialog(
      title: 'Validation Error',
      message: message,
    );
  }
}

/// A utility class for showing error dialogs.
class ErrorDialogHelper {
  /// Shows a general error dialog.
  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
    bool showRetry = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        actionText: actionText,
        onAction: onAction,
        showRetry: showRetry,
      ),
    );
  }

  /// Shows a network error dialog.
  static Future<void> showNetworkError(
    BuildContext context, {
    String message = 'Network connection error. Please check your internet connection and try again.',
    VoidCallback? onRetry,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => NetworkErrorDialog(
        message: message,
        onRetry: onRetry,
      ),
    );
  }

  /// Shows a validation error dialog.
  static Future<void> showValidationError(
    BuildContext context, {
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ValidationErrorDialog(
        message: message,
      ),
    );
  }
} 