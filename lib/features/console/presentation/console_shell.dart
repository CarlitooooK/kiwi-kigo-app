import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/router.dart';
import '../../../core/theme/kigo_theme.dart';

/// Console Shell — Navigation wrapper for the management console.
///
/// Provides a sidebar/rail navigation for the admin experience.
class ConsoleShell extends StatelessWidget {
  final Widget child;

  const ConsoleShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail for console
          NavigationRail(
            selectedIndex: _getSelectedIndex(currentLocation),
            onDestinationSelected: (index) => _onItemTapped(context, index),
            labelType: NavigationRailLabelType.all,
            backgroundColor: KigoTheme.gray200,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: KigoTheme.kigo500,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kigo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: KigoTheme.kigo500,
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Visitas'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: KigoTheme.umbral200),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith(RoutePaths.consoleVisits)) return 1;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.consoleDashboard);
        break;
      case 1:
        context.go(RoutePaths.consoleVisits);
        break;
    }
  }
}
