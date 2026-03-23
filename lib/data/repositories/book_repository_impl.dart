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
  BookRepositoryImpl({
    Future<void> Function(String bookId)? beforeNavigationV2ReadQuery,
  }) : _beforeNavigationV2ReadQuery = beforeNavigationV2ReadQuery;

  final Future<void> Function(String bookId)? _beforeNavigationV2ReadQuery;

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
    return _getBookByIdFromExecutor(db, id);
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
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
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
  Future<void> importBookWithNavigationDataV2Ready({
    required Book book,
    required List<Chapter> legacyChapters,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) async {
    final progress = _prepareNavigationDataV2Ready(
      bookId: book.id,
      documents: documents,
      tocItems: tocItems,
      initialProgress: initialProgress,
    );
    _validateLegacyChapters(book.id, legacyChapters);

    final db = await AppDatabase.database;
    final pendingBook = book.copyWith(
      navigationDataVersion: Book.legacyNavigationDataVersion,
      navigationRebuildState: NavigationRebuildState.legacyPending,
      navigationRebuildFailedAt: null,
    );

    await db.transaction((txn) async {
      await txn.insert(
        'books',
        pendingBook.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final chapter in legacyChapters) {
        await txn.insert(
          'chapters',
          chapter.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await _writeNavigationDataV2Ready(
        txn,
        bookId: book.id,
        documents: documents,
        tocItems: tocItems,
        progress: progress,
      );
    });
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
    await _beforeNavigationV2ReadQuery?.call(bookId);
    final db = await AppDatabase.database;
    final maps = await db.query(
      'reader_documents',
      where: '''
        book_id = ?
        AND EXISTS (
          SELECT 1
          FROM books
          WHERE id = ?
            AND navigation_data_version = ?
            AND navigation_rebuild_state = ?
        )
      ''',
      whereArgs: [
        bookId,
        bookId,
        Book.v2NavigationDataVersion,
        NavigationRebuildState.ready.dbValue,
      ],
      orderBy: 'document_index ASC',
    );
    return maps.map((map) => ReaderDocument.fromMap(map)).toList();
  }

  @override
  Future<List<TocItem>> getTocItemsByBookId(String bookId) async {
    await _beforeNavigationV2ReadQuery?.call(bookId);
    final db = await AppDatabase.database;
    final maps = await db.query(
      'toc_items',
      where: '''
        book_id = ?
        AND EXISTS (
          SELECT 1
          FROM books
          WHERE id = ?
            AND navigation_data_version = ?
            AND navigation_rebuild_state = ?
        )
      ''',
      whereArgs: [
        bookId,
        bookId,
        Book.v2NavigationDataVersion,
        NavigationRebuildState.ready.dbValue,
      ],
      orderBy: 'toc_order ASC',
    );
    return maps.map((map) => TocItem.fromMap(map)).toList();
  }

  @override
  Future<ReadingProgressV2?> getReadingProgressV2(String bookId) async {
    await _beforeNavigationV2ReadQuery?.call(bookId);
    final db = await AppDatabase.database;
    final maps = await db.query(
      'reading_progress_v2',
      where: '''
        book_id = ?
        AND EXISTS (
          SELECT 1
          FROM books
          WHERE id = ?
            AND navigation_data_version = ?
            AND navigation_rebuild_state = ?
        )
      ''',
      whereArgs: [
        bookId,
        bookId,
        Book.v2NavigationDataVersion,
        NavigationRebuildState.ready.dbValue,
      ],
    );
    if (maps.isEmpty) {
      return null;
    }
    return ReadingProgressV2.fromMap(maps.first);
  }

  @override
  Future<void> saveReadingProgressV2(ReadingProgressV2 progress) async {
    final db = await AppDatabase.database;
    final normalizedProgress = ReadingProgressV2(
      bookId: progress.bookId,
      documentIndex: progress.documentIndex,
      documentProgress: progress.documentProgress.clamp(0.0, 1.0).toDouble(),
      tocItemId: progress.tocItemId,
      anchor: progress.anchor,
      updatedAt: progress.updatedAt,
    );

    await db.transaction((txn) async {
      final book = await _getBookByIdFromExecutor(txn, progress.bookId);
      if (book == null || !book.usesV2Navigation) {
        return;
      }

      await _validatePersistedProgressV2(
        txn,
        bookId: progress.bookId,
        progress: normalizedProgress,
      );

      final updatedRows = await txn.update(
        'reading_progress_v2',
        normalizedProgress.toMap(),
        where: 'book_id = ?',
        whereArgs: [progress.bookId],
      );
      if (updatedRows == 1) {
        return;
      }

      throw StateError(
        'Missing V2 reading progress row while saving progress for ${progress.bookId}.',
      );
    });
  }

  @override
  Future<void> saveNavigationDataV2Ready({
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) async {
    final progress = _prepareNavigationDataV2Ready(
      bookId: bookId,
      documents: documents,
      tocItems: tocItems,
      initialProgress: initialProgress,
    );
    final db = await AppDatabase.database;

    await db.transaction((txn) async {
      await _writeNavigationDataV2Ready(
        txn,
        bookId: bookId,
        documents: documents,
        tocItems: tocItems,
        progress: progress,
      );
    });
  }

  @override
  Future<void> markNavigationRebuildInProgress(String bookId) async {
    final db = await AppDatabase.database;
    final updatedRows = await db.update(
      'books',
      {
        'navigation_data_version': Book.legacyNavigationDataVersion,
        'navigation_rebuild_state': NavigationRebuildState.rebuilding.dbValue,
        'navigation_rebuild_failed_at': null,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
    if (updatedRows != 1) {
      throw StateError(
        'Book not found while marking rebuild in progress: $bookId',
      );
    }
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
        throw StateError(
          'Book not found while resetting V2 navigation: $bookId',
        );
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

  ReadingProgressV2 _prepareNavigationDataV2Ready({
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    required ReadingProgressV2? initialProgress,
  }) {
    if (documents.isEmpty) {
      throw ArgumentError(
        'saveNavigationDataV2Ready requires at least one reader document.',
      );
    }
    final documentsByIndex = _validateReaderDocuments(bookId, documents);
    final tocItemsById = _validateTocItems(bookId, tocItems, documentsByIndex);
    final progress = _normalizeInitialProgress(
      bookId: bookId,
      documentCount: documents.length,
      initialProgress: initialProgress,
    );
    _validateProgressReference(bookId, progress, tocItemsById);
    return progress;
  }

  Future<void> _writeNavigationDataV2Ready(
    DatabaseExecutor executor, {
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    required ReadingProgressV2 progress,
  }) async {
    await _deleteNavigationDataV2(executor, bookId);

    for (final document in documents) {
      await executor.insert(
        'reader_documents',
        document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final tocItem in tocItems) {
      await executor.insert(
        'toc_items',
        tocItem.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await executor.insert(
      'reading_progress_v2',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final updatedRows = await executor.update(
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

  Future<Book?> _getBookByIdFromExecutor(
    DatabaseExecutor executor,
    String id,
  ) async {
    final maps = await executor.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) {
      return null;
    }
    return Book.fromMap(maps.first);
  }

  Future<void> _validatePersistedProgressV2(
    DatabaseExecutor executor, {
    required String bookId,
    required ReadingProgressV2 progress,
  }) async {
    final documentCount =
        Sqflite.firstIntValue(
          await executor.rawQuery(
            'SELECT COUNT(*) FROM reader_documents WHERE book_id = ?',
            [bookId],
          ),
        ) ??
        0;
    if (documentCount <= 0) {
      throw StateError(
        'Missing reader documents while saving V2 progress for $bookId.',
      );
    }
    if (progress.documentIndex < 0 || progress.documentIndex >= documentCount) {
      throw RangeError.range(
        progress.documentIndex,
        0,
        documentCount - 1,
        'documentIndex',
      );
    }

    final documentRows = await executor.query(
      'reader_documents',
      columns: const ['document_index'],
      where: 'book_id = ? AND document_index = ?',
      whereArgs: [bookId, progress.documentIndex],
      limit: 1,
    );
    if (documentRows.isEmpty) {
      throw StateError(
        'Missing reader document at index ${progress.documentIndex} while saving V2 progress for $bookId.',
      );
    }

    final tocItemId = progress.tocItemId;
    if (tocItemId == null) {
      return;
    }

    final tocRows = await executor.query(
      'toc_items',
      columns: const ['target_document_index'],
      where: 'book_id = ? AND id = ?',
      whereArgs: [bookId, tocItemId],
      limit: 1,
    );
    if (tocRows.isEmpty) {
      throw ArgumentError(
        'ReadingProgressV2.tocItemId must reference an existing TOC item for book $bookId.',
      );
    }

    final targetDocumentIndex = tocRows.first['target_document_index'] as int?;
    if (targetDocumentIndex != null &&
        targetDocumentIndex != progress.documentIndex) {
      throw ArgumentError(
        'ReadingProgressV2.tocItemId must point to the same documentIndex when the TOC item is directly mappable.',
      );
    }
  }

  Map<int, ReaderDocument> _validateReaderDocuments(
    String bookId,
    List<ReaderDocument> documents,
  ) {
    final documentsByIndex = <int, ReaderDocument>{};
    final documentIds = <String>{};
    final fileNames = <String>{};

    for (final document in documents) {
      if (document.bookId != bookId) {
        throw ArgumentError(
          'All reader documents must belong to book $bookId.',
        );
      }
      if (!documentIds.add(document.id)) {
        throw ArgumentError(
          'ReaderDocument.id must be unique within book $bookId.',
        );
      }
      if (!fileNames.add(document.fileName)) {
        throw ArgumentError(
          'ReaderDocument.fileName must be unique within book $bookId.',
        );
      }
      if (documentsByIndex.containsKey(document.documentIndex)) {
        throw ArgumentError(
          'ReaderDocument.documentIndex must be unique within book $bookId.',
        );
      }
      documentsByIndex[document.documentIndex] = document;
    }

    for (var index = 0; index < documents.length; index++) {
      if (!documentsByIndex.containsKey(index)) {
        throw ArgumentError(
          'ReaderDocument.documentIndex must be contiguous 0..${documents.length - 1} for book $bookId.',
        );
      }
    }

    return documentsByIndex;
  }

  Map<String, TocItem> _validateTocItems(
    String bookId,
    List<TocItem> tocItems,
    Map<int, ReaderDocument> documentsByIndex,
  ) {
    final tocItemsById = <String, TocItem>{};
    final tocOrders = <int, TocItem>{};

    for (final tocItem in tocItems) {
      if (tocItem.bookId != bookId) {
        throw ArgumentError('All TOC items must belong to book $bookId.');
      }
      if (tocItemsById.containsKey(tocItem.id)) {
        throw ArgumentError('TocItem.id must be unique within book $bookId.');
      }
      if (tocOrders.containsKey(tocItem.order)) {
        throw ArgumentError(
          'TocItem.order must be unique within book $bookId.',
        );
      }
      tocItemsById[tocItem.id] = tocItem;
      tocOrders[tocItem.order] = tocItem;
    }

    for (var order = 0; order < tocItems.length; order++) {
      if (!tocOrders.containsKey(order)) {
        throw ArgumentError(
          'TocItem.order must be contiguous 0..${tocItems.length - 1} for book $bookId.',
        );
      }
    }

    for (final tocItem in tocItems) {
      final parentId = tocItem.parentId;
      if (parentId != null && !tocItemsById.containsKey(parentId)) {
        throw ArgumentError(
          'TocItem.parentId must reference an existing TOC item.',
        );
      }

      final targetDocumentIndex = tocItem.targetDocumentIndex;
      if (targetDocumentIndex != null &&
          !documentsByIndex.containsKey(targetDocumentIndex)) {
        throw RangeError.range(
          targetDocumentIndex,
          0,
          documentsByIndex.length - 1,
          'targetDocumentIndex',
        );
      }
    }

    return tocItemsById;
  }

  void _validateProgressReference(
    String bookId,
    ReadingProgressV2 progress,
    Map<String, TocItem> tocItemsById,
  ) {
    final tocItemId = progress.tocItemId;
    if (tocItemId == null) {
      return;
    }

    final tocItem = tocItemsById[tocItemId];
    if (tocItem == null) {
      throw ArgumentError(
        'ReadingProgressV2.tocItemId must reference an existing TOC item for book $bookId.',
      );
    }
    if (tocItem.targetDocumentIndex != null &&
        tocItem.targetDocumentIndex != progress.documentIndex) {
      throw ArgumentError(
        'ReadingProgressV2.tocItemId must point to the same documentIndex when the TOC item is directly mappable.',
      );
    }
  }

  void _validateLegacyChapters(String bookId, List<Chapter> legacyChapters) {
    final chapterIds = <String>{};
    final chapterIndexes = <int>{};

    for (final chapter in legacyChapters) {
      if (chapter.bookId != bookId) {
        throw ArgumentError('All legacy chapters must belong to book $bookId.');
      }
      if (!chapterIds.add(chapter.id)) {
        throw ArgumentError(
          'Chapter.id must be unique within imported book $bookId.',
        );
      }
      if (!chapterIndexes.add(chapter.index)) {
        throw ArgumentError(
          'Chapter.index must be unique within imported book $bookId.',
        );
      }
    }
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
