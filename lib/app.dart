import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/library/library_screen.dart';

class EpubReaderApp extends StatelessWidget {
  const EpubReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPUB Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const LibraryScreen(),
    );
  }
}