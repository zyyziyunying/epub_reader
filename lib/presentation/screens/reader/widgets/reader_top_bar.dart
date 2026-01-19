import 'package:flutter/material.dart';

import '../../../../core/router/router_core.dart';
import '../../../../domain/entities/book.dart';

class ReaderTopBar extends StatelessWidget {
  final Book book;
  final VoidCallback onMenuPressed;

  const ReaderTopBar({
    super.key,
    required this.book,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => NavigatorManager.pop(),
          ),
          title: Text(
            book.title,
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: onMenuPressed,
            ),
          ],
        ),
      ),
    );
  }
}
