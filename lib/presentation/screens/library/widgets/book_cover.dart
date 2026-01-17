import 'dart:io';

import 'package:flutter/material.dart';

class BookCover extends StatelessWidget {
  final String? coverPath;

  const BookCover({
    super.key,
    this.coverPath,
  });

  @override
  Widget build(BuildContext context) {
    if (coverPath != null) {
      final file = File(coverPath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _PlaceholderCover(),
      );
    }
    return _PlaceholderCover();
  }
}

class _PlaceholderCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.book,
          size: 48,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
