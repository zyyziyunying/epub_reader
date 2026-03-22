import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/book_reading_data_source.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/navigation_rebuild_state.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reading_progress_v2.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/toc_item.dart';
import '../../../domain/repositories/book_repository.dart';
import '../datasources/local/database.dart';

class BookRepositoryImpl implements BookRepository {
  @override
  Future<List<Book>> getAllBooks() async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'books',
      orderBy: 'last_read_at DESC, added_at DESC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  @override
  Future<Book?> getBookById(String id) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  @override
  Future<void> insertBook(Book book) async {
    final db = await AppDatabase.database;
    await db.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateBook(Book book) async {
    final db = await AppDatabase.database;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  @override
  Future<void> deleteBook(String id) async {
    final db = await AppDatabase.database;
    await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Chapter>> getChaptersByBookId(String bookId) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_index ASC',
    );
    return maps.map((map) => Chapter.fromMap(map)).toList();
  }

  @override
  Future<Chapter?> getChapter(String bookId, int index) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'chapters',
      where: 'book_id = ? AND chapter_index = ?',
      whereArgs: [bookId, index],
    );
    if (maps.isEmpty) return null;
    return Chapter.fromMap(maps.first);
  }

  @override
  Future<void> insertChapter(Chapter chapter) async {
    final db = await AppDatabase.database;
    await db.insert(
      'chapters',
      chapter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertChapters(List<Chapter> chapters) async {
    final db = await AppDatabase.database;
    final batch = db.batch();
    for (final chapter in chapters) {
      batch.insert(
        'chapters',
        chapter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<ReadingProgress?> getReadingProgress(String bookId) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (maps.isEmpty) return null;
    return ReadingProgress.fromMap(maps.first);
  }

  @override
  Future<void> saveReadingProgress(ReadingProgress progress) async {
    final db = await AppDatabase.database;
    await db.insert(
      'reading_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<BookReadingDataSource> getBookReadingDataSource(String bookId) async {
    final book = await getBookById(bookId);
    if (book == null) {
      return BookReadingDataSource.legacy;
    }
    return book.usesV2Navigation
        ? BookReadingDataSource.v2
        : BookReadingDataSource.legacy;
  }

  @override
  Future<List<ReaderDocument>> getReaderDocumentsByBookId(String bookId) async {
    if (!await _canReadV2(bookId)) {
      return const [];
    }
    final db = await AppDatabase.database;
    final maps = await db.query(
      'reader_documents',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'document_index ASC',
    );
    return maps.map((map) => ReaderDocument.fromMap(map)).toList();
  }

  @override
  Future<List<TocItem>> getTocItemsByBookId(String bookId) async {
    if (!await _canReadV2(bookId)) {
      return const [];
    }
    final db = await AppDatabase.database;
    final maps = await db.query(
      'toc_items',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'toc_order ASC',
    );
    return maps.map((map) => TocItem.fromMap(map)).toList();
  }

  @override
  Future<ReadingProgressV2?> getReadingProgressV2(String bookId) async {
    if (!await _canReadV2(bookId)) {
      return null;
    }
    final db = await AppDatabase.database;
    final maps = await db.query(
      'reading_progress_v2',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (maps.isEmpty) {
      return null;
    }
    return ReadingProgressV2.fromMap(maps.first);
  }

  @override
  Future<void> saveNavigationDataV2Ready({
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) async {
    if (documents.isEmpty) {
      throw ArgumentError(
        'saveNavigationDataV2Ready requires at least one reader document.',
      );
    }
    if (documents.any((document) => document.bookId != bookId)) {
      throw ArgumentError('All reader documents must belong to book $bookId.');
    }
    if (tocItems.any((tocItem) => tocItem.bookId != bookId)) {
      throw ArgumentError('All TOC items must belong to book $bookId.');
    }

    final progress = _normalizeInitialProgress(
      bookId: bookId,
      documentCount: documents.length,
      initialProgress: initialProgress,
    );
    final db = await AppDatabase.database;

    await db.transaction((txn) async {
      await _deleteNavigationDataV2(txn, bookId);

      for (final document in documents) {
        await txn.insert(
          'reader_documents',
          document.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final tocItem in tocItems) {
        await txn.insert(
          'toc_items',
          tocItem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.insert(
        'reading_progress_v2',
        progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final updatedRows = await txn.update(
        'books',
        {
          'navigation_data_version': Book.v2NavigationDataVersion,
          'navigation_rebuild_state': NavigationRebuildState.ready.dbValue,
          'navigation_rebuild_failed_at': null,
        },
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (updatedRows != 1) {
        throw StateError('Book not found while saving V2 navigation: $bookId');
      }
    });
  }

  @override
  Future<void> resetNavigationDataToLegacy(
    String bookId, {
    required NavigationRebuildState rebuildState,
    DateTime? failedAt,
  }) async {
    if (rebuildState != NavigationRebuildState.legacyPending &&
        rebuildState != NavigationRebuildState.failed) {
      throw ArgumentError(
        'resetNavigationDataToLegacy only supports legacyPending or failed.',
      );
    }

    final effectiveFailedAt = rebuildState == NavigationRebuildState.failed
        ? (failedAt ?? DateTime.now())
        : null;
    final db = await AppDatabase.database;

    await db.transaction((txn) async {
      await _deleteNavigationDataV2(txn, bookId);
      final updatedRows = await txn.update(
        'books',
        {
          'navigation_data_version': Book.legacyNavigationDataVersion,
          'navigation_rebuild_state': rebuildState.dbValue,
          'navigation_rebuild_failed_at':
              effectiveFailedAt?.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [bookId],
      );
      if (updatedRows != 1) {
        throw StateError('Book not found while resetting V2 navigation: $bookId');
      }
    });
  }

  @override
  Future<void> updateLastReadAt(String bookId, DateTime time) async {
    final db = await AppDatabase.database;
    await db.update(
      'books',
      {'last_read_at': time.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<bool> _canReadV2(String bookId) async {
    return (await getBookReadingDataSource(bookId)).usesV2;
  }

  ReadingProgressV2 _normalizeInitialProgress({
    required String bookId,
    required int documentCount,
    required ReadingProgressV2? initialProgress,
  }) {
    final progress = initialProgress ?? ReadingProgressV2.initial(bookId);
    if (progress.bookId != bookId) {
      throw ArgumentError('ReadingProgressV2.bookId must match $bookId.');
    }
    if (progress.documentIndex < 0 || progress.documentIndex >= documentCount) {
      throw RangeError.range(
        progress.documentIndex,
        0,
        documentCount - 1,
        'documentIndex',
      );
    }

    return ReadingProgressV2(
      bookId: progress.bookId,
      documentIndex: progress.documentIndex,
      documentProgress: progress.documentProgress.clamp(0.0, 1.0).toDouble(),
      tocItemId: progress.tocItemId,
      anchor: progress.anchor,
      updatedAt: progress.updatedAt,
    );
  }

  Future<void> _deleteNavigationDataV2(
    DatabaseExecutor executor,
    String bookId,
  ) async {
    await executor.delete(
      'reading_progress_v2',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    await executor.delete(
      'toc_items',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    await executor.delete(
      'reader_documents',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }
}
