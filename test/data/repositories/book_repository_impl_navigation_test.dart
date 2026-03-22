import 'dart:io';

import 'package:epub_reader/core/platform/database_factory.dart';
import 'package:epub_reader/data/datasources/local/database.dart';
import 'package:epub_reader/data/repositories/book_repository_impl.dart';
import 'package:epub_reader/domain/entities/book.dart';
import 'package:epub_reader/domain/entities/book_reading_data_source.dart';
import 'package:epub_reader/domain/entities/navigation_rebuild_state.dart';
import 'package:epub_reader/domain/entities/reading_progress_v2.dart';
import 'package:epub_reader/domain/entities/reader_document.dart';
import 'package:epub_reader/domain/entities/toc_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookRepositoryImpl navigation V2', () {
    const existingBookId = 'book-1';
    final repository = BookRepositoryImpl();
    late Directory tempDir;
    late String databasePath;

    setUpAll(() {
      DatabaseFactoryHelper.initialize();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'epub_reader_navigation_test_',
      );
      databasePath = p.join(tempDir.path, 'epub_reader.db');
      await AppDatabase.resetForTest();
      AppDatabase.overrideDatabasePathForTest(databasePath);
    });

    tearDown(() async {
      await AppDatabase.resetForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'upgrades legacy books to navigation defaults and creates V2 tables',
      () async {
        await _createLegacyVersion1Database(databasePath);

        final book = await repository.getBookById(existingBookId);
        expect(book, isNotNull);
        expect(book!.navigationDataVersion, Book.legacyNavigationDataVersion);
        expect(
          book.navigationRebuildState,
          NavigationRebuildState.legacyPending,
        );
        expect(book.navigationRebuildFailedAt, isNull);

        final db = await AppDatabase.database;
        expect(await _tableExists(db, 'reader_documents'), isTrue);
        expect(await _tableExists(db, 'toc_items'), isTrue);
        expect(await _tableExists(db, 'reading_progress_v2'), isTrue);
      },
    );

    test('keeps V2 rows unreadable until navigation state is ready', () async {
      await repository.insertBook(
        _book(existingBookId).copyWith(
          navigationDataVersion: Book.v2NavigationDataVersion,
          navigationRebuildState: NavigationRebuildState.failed,
        ),
      );

      final db = await AppDatabase.database;
      await db.insert(
        'reader_documents',
        _documents(existingBookId).first.toMap(),
      );
      await db.insert('toc_items', _tocItems(existingBookId).first.toMap());
      await db.insert(
        'reading_progress_v2',
        _progress(
          existingBookId,
          tocItemId: '$existingBookId:toc_item:0',
        ).toMap(),
      );

      expect(
        await repository.getBookReadingDataSource(existingBookId),
        BookReadingDataSource.legacy,
      );
      expect(
        await repository.getReaderDocumentsByBookId(existingBookId),
        isEmpty,
      );
      expect(await repository.getTocItemsByBookId(existingBookId), isEmpty);
      expect(await repository.getReadingProgressV2(existingBookId), isNull);
    });

    test(
      'writes ready V2 data and resetNavigationDataToLegacy removes it',
      () async {
        await repository.insertBook(_book(existingBookId));

        await repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: _tocItems(existingBookId),
          initialProgress: _progress(
            existingBookId,
            documentIndex: 1,
            documentProgress: 1.2,
            tocItemId: '$existingBookId:toc_item:1',
          ),
        );

        expect(
          await repository.getBookReadingDataSource(existingBookId),
          BookReadingDataSource.v2,
        );
        expect(
          (await repository.getReaderDocumentsByBookId(
            existingBookId,
          )).map((document) => document.documentIndex),
          orderedEquals([0, 1]),
        );
        expect(
          (await repository.getTocItemsByBookId(
            existingBookId,
          )).map((tocItem) => tocItem.order),
          orderedEquals([0, 1]),
        );

        final progress = await repository.getReadingProgressV2(existingBookId);
        expect(progress, isNotNull);
        expect(progress!.documentIndex, 1);
        expect(progress.documentProgress, 1.0);
        expect(progress.tocItemId, '$existingBookId:toc_item:1');

        final failedAt = DateTime.fromMillisecondsSinceEpoch(1234);
        await repository.resetNavigationDataToLegacy(
          existingBookId,
          rebuildState: NavigationRebuildState.failed,
          failedAt: failedAt,
        );

        expect(
          await repository.getBookReadingDataSource(existingBookId),
          BookReadingDataSource.legacy,
        );
        expect(
          await repository.getReaderDocumentsByBookId(existingBookId),
          isEmpty,
        );
        expect(await repository.getTocItemsByBookId(existingBookId), isEmpty);
        expect(await repository.getReadingProgressV2(existingBookId), isNull);

        final book = await repository.getBookById(existingBookId);
        expect(book, isNotNull);
        expect(book!.navigationDataVersion, Book.legacyNavigationDataVersion);
        expect(book.navigationRebuildState, NavigationRebuildState.failed);
        expect(book.navigationRebuildFailedAt, failedAt);
      },
    );

    test('rejects incomplete ready payloads before any write', () async {
      await repository.insertBook(_book(existingBookId));

      await expectLater(
        repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: [
            _document(existingBookId, 0, 'OPS/Text/ch1.xhtml'),
            _document(existingBookId, 2, 'OPS/Text/ch2.xhtml'),
          ],
          tocItems: const <TocItem>[],
        ),
        throwsArgumentError,
      );

      await expectLater(
        repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: [
            _tocItem(
              existingBookId,
              0,
              parentId: '$existingBookId:toc_item:missing',
              targetDocumentIndex: 0,
            ),
          ],
        ),
        throwsArgumentError,
      );

      await expectLater(
        repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: [_tocItem(existingBookId, 0, targetDocumentIndex: 3)],
        ),
        throwsRangeError,
      );

      await expectLater(
        repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: _tocItems(existingBookId),
          initialProgress: _progress(
            existingBookId,
            tocItemId: '$existingBookId:toc_item:missing',
          ),
        ),
        throwsArgumentError,
      );

      await _expectNoV2Rows(existingBookId);
      expect(
        await repository.getBookReadingDataSource(existingBookId),
        BookReadingDataSource.legacy,
      );
    });

    test('rolls back partial V2 writes when final book update fails', () async {
      await repository.insertBook(_book(existingBookId));
      final db = await AppDatabase.database;
      await db.execute('''
        CREATE TRIGGER fail_navigation_ready_update
        BEFORE UPDATE OF navigation_data_version, navigation_rebuild_state, navigation_rebuild_failed_at ON books
        WHEN OLD.id = '$existingBookId'
        BEGIN
          SELECT RAISE(ABORT, 'forced books update failure');
        END;
      ''');

      await expectLater(
        repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: _tocItems(existingBookId),
        ),
        throwsA(isA<DatabaseException>()),
      );

      await _expectNoV2Rows(existingBookId);

      final book = await repository.getBookById(existingBookId);
      expect(book, isNotNull);
      expect(book!.navigationDataVersion, Book.legacyNavigationDataVersion);
      expect(book.navigationRebuildState, NavigationRebuildState.legacyPending);
    });
  });
}

Future<void> _createLegacyVersion1Database(String databasePath) async {
  final db = await databaseFactory.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            file_path TEXT NOT NULL,
            cover_path TEXT,
            total_chapters INTEGER NOT NULL,
            added_at INTEGER NOT NULL,
            last_read_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE chapters (
            id TEXT PRIMARY KEY,
            book_id TEXT NOT NULL,
            chapter_index INTEGER NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE reading_progress (
            book_id TEXT PRIMARY KEY,
            chapter_index INTEGER NOT NULL,
            scroll_position REAL NOT NULL,
            updated_at INTEGER NOT NULL,
            FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
          )
        ''');
      },
    ),
  );

  await db.insert('books', {
    'id': 'book-1',
    'title': 'Legacy Book',
    'author': 'Author',
    'file_path': 'D:/books/legacy.epub',
    'cover_path': null,
    'total_chapters': 2,
    'added_at': DateTime.utc(2026, 3, 22).millisecondsSinceEpoch,
    'last_read_at': null,
  });
  await db.close();
}

Future<bool> _tableExists(Database db, String tableName) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['table', tableName],
    limit: 1,
  );
  return rows.isNotEmpty;
}

Future<void> _expectNoV2Rows(String bookId) async {
  final db = await AppDatabase.database;
  for (final tableName in const [
    'reader_documents',
    'toc_items',
    'reading_progress_v2',
  ]) {
    final rows = await db.query(
      tableName,
      columns: ['book_id'],
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    expect(rows, isEmpty, reason: 'Expected no rows in $tableName for $bookId');
  }
}

Book _book(String id) {
  return Book(
    id: id,
    title: 'Book $id',
    author: 'Author',
    filePath: 'D:/books/$id.epub',
    totalChapters: 2,
    addedAt: DateTime.utc(2026, 3, 22),
  );
}

List<ReaderDocument> _documents(String bookId) {
  return [
    _document(bookId, 0, 'OPS/Text/ch1.xhtml'),
    _document(bookId, 1, 'OPS/Text/ch2.xhtml'),
  ];
}

ReaderDocument _document(String bookId, int index, String fileName) {
  return ReaderDocument(
    id: '$bookId:reader_document:$index',
    bookId: bookId,
    documentIndex: index,
    fileName: fileName,
    title: 'Document $index',
    htmlContent:
        '<html><head><title>Document $index</title></head><body></body></html>',
  );
}

List<TocItem> _tocItems(String bookId) {
  return [
    _tocItem(bookId, 0, targetDocumentIndex: 0),
    _tocItem(bookId, 1, targetDocumentIndex: 1),
  ];
}

TocItem _tocItem(
  String bookId,
  int order, {
  String? parentId,
  int? targetDocumentIndex,
}) {
  return TocItem(
    id: '$bookId:toc_item:$order',
    bookId: bookId,
    title: 'TOC $order',
    order: order,
    depth: 0,
    parentId: parentId,
    fileName: targetDocumentIndex == null
        ? null
        : 'OPS/Text/ch${targetDocumentIndex + 1}.xhtml',
    anchor: null,
    targetDocumentIndex: targetDocumentIndex,
  );
}

ReadingProgressV2 _progress(
  String bookId, {
  int documentIndex = 0,
  double documentProgress = 0.5,
  String? tocItemId,
}) {
  return ReadingProgressV2(
    bookId: bookId,
    documentIndex: documentIndex,
    documentProgress: documentProgress,
    tocItemId: tocItemId,
    anchor: null,
    updatedAt: DateTime.utc(2026, 3, 22),
  );
}
