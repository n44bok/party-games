import 'package:flutter/material.dart';

import 'glass.dart';

/// Shown when content could not be loaded: a message, optional details (debug
/// builds) and a retry button.
class LoadError extends StatelessWidget {
  const LoadError({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.details,
  });

  final String message;
  final String retryLabel;
  final String? details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(details!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            GlassButton(
              label: retryLabel,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
