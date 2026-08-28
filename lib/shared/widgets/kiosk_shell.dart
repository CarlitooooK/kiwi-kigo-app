import 'package:flutter/material.dart';
import 'journey_rail.dart';

/// KioskShell — Layout wrapper for the kiosk visitor experience.
///
/// Structure: JourneyRail (left) + Content (right)
///
/// The rail is always visible during the flow, giving the visitor
/// permanent context of where they are in the process.
///
/// On narrow screens (< 600px), the rail collapses to dot-only mode.
class KioskShell extends StatelessWidget {
  final List<JourneyStep> steps;
  final Widget child;

  const KioskShell({
    super.key,
    required this.steps,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showFullRail = screenWidth >= 600;

    if (!showFullRail) {
      // On mobile/narrow: no rail, just content
      return Scaffold(body: child);
    }

    return Scaffold(
      body: Row(
        children: [
          // Journey Rail — always visible
          JourneyRail(steps: steps),

          // Content area
          Expanded(child: child),
        ],
      ),
    );
  }
}
