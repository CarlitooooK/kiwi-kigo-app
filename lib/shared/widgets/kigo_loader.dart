import 'package:flutter/material.dart';
import '../../core/theme/kigo_theme.dart';

/// Kigo loading indicator.
/// Spinner only inside buttons during async actions.
/// For content areas use skeleton (future).
class KigoLoader extends StatelessWidget {
  final String? message;

  const KigoLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: KigoTheme.kigo500,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: KigoTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
