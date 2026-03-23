import 'package:flutter/material.dart';

import '../../../../domain/entities/book.dart';

class DeleteBookDialog extends StatelessWidget {
  final Book book;

  const DeleteBookDialog({super.key, required this.book});

  static Future<bool?> show(BuildContext context, Book book) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DeleteBookDialog(book: book),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Book'),
      content: Text('Are you sure you want to delete "${book.title}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
