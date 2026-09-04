import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kigo_theme.dart';

/// Small, unobtrusive "Contactar soporte" chip pinned at the bottom of every
/// flow (added as a global overlay in app.dart). Tapping it opens the support
/// screen — a QR the visitor scans with the Kigo app to call support.
class SupportButton extends StatelessWidget {
  const SupportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        // context.push is available app-wide via the root GoRouter.
        onPressed: () => context.push('/support'),
        icon: const Icon(Icons.support_agent_rounded,
            size: 18, color: KigoTheme.slate500),
        label: const Text(
          'Contactar soporte',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: KigoTheme.slate500,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
