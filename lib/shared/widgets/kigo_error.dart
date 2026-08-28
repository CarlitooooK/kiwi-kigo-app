import 'package:flutter/material.dart';
import '../../core/theme/kigo_theme.dart';

/// Kigo error state.
/// Pattern: Icon 48px + Title + Message (cause+action) + CTA
class KigoError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const KigoError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: KigoTheme.red500,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: KigoTheme.slate900,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
