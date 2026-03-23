import 'package:flutter/material.dart';

import 'core/router/router_core.dart';
import 'core/theme/app_theme.dart';

class EpubReaderApp extends StatelessWidget {
  final GoRouter router;

  const EpubReaderApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EPUB Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
