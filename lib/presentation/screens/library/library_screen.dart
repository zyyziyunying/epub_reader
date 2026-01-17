import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/router_core.dart';
import '../../../domain/entities/book.dart';
import '../../../routes/app_routes.dart';
import '../../providers/book_providers.dart';
import 'widgets/book_card.dart';
import 'widgets/delete_book_dialog.dart';
import 'widgets/empty_library_view.dart';
import 'widgets/error_view.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(libraryBooksProvider);
    final isImporting = ref.watch(importingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          if (isImporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: booksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return const EmptyLibraryView();
          }
          return _buildBookGrid(context, ref, books);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(libraryBooksProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isImporting ? null : () => _importBook(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Import'),
      ),
    );
  }

  Widget _buildBookGrid(BuildContext context, WidgetRef ref, List<Book> books) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 5
            : constraints.maxWidth > 600
                ? 4
                : constraints.maxWidth > 400
                    ? 3
                    : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.65,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            return BookCard(
              book: books[index],
              onTap: () => _openBook(context, books[index]),
              onDelete: () => _deleteBook(context, ref, books[index]),
            );
          },
        );
      },
    );
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    final importBook = ref.read(importBookProvider);
    final book = await importBook();

    if (book != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported: ${book.title}')),
      );
    }
  }

  void _openBook(BuildContext context, Book book) {
    NavigatorManager.pushNamed(
      AppRoutes.readerName,
      extra: book,
    );
  }

  Future<void> _deleteBook(BuildContext context, WidgetRef ref, Book book) async {
    final confirmed = await DeleteBookDialog.show(context, book);

    if (confirmed == true) {
      final deleteBook = ref.read(deleteBookProvider);
      await deleteBook(book);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted: ${book.title}')),
        );
      }
    }
  }
}
