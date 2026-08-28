import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router.dart';
import 'core/theme/kigo_theme.dart';

/// Root application widget.
class KigoWelcomeApp extends ConsumerWidget {
  const KigoWelcomeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kigo Welcome',
      debugShowCheckedModeBanner: false,
      theme: KigoTheme.light,
      routerConfig: router,
    );
  }
}
