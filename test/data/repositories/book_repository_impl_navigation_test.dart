import 'dart:io';

import 'package:epub_reader/core/platform/database_factory.dart';
import 'package:epub_reader/data/datasources/local/database.dart';
import 'package:epub_reader/data/repositories/book_repository_impl.dart';
import 'package:epub_reader/domain/entities/book.dart';
import 'package:epub_reader/domain/entities/book_reading_data_source.dart';
import 'package:epub_reader/domain/entities/chapter.dart';
import 'package:epub_reader/domain/entities/navigation_rebuild_state.dart';
import 'package:epub_reader/domain/entities/reading_progress_v2.dart';
import 'package:epub_reader/domain/entities/reader_document.dart';
import 'package:epub_reader/domain/entities/toc_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

//TODO 拆分
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
        await repository.insertBook(
          _book(existingBookId).copyWith(totalChapters: 99),
        );
        await repository.insertChapter(_legacyChapter(existingBookId, 0));

        await repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documentsWithCount(existingBookId, 3),
          tocItems: _tocItemsWithCount(existingBookId, 3),
          initialProgress: _progress(
            existingBookId,
            documentIndex: 2,
            documentProgress: 1.2,
            tocItemId: '$existingBookId:toc_item:2',
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
          orderedEquals([0, 1, 2]),
        );
        expect(
          (await repository.getTocItemsByBookId(
            existingBookId,
          )).map((tocItem) => tocItem.order),
          orderedEquals([0, 1, 2]),
        );

        final progress = await repository.getReadingProgressV2(existingBookId);
        expect(progress, isNotNull);
        expect(progress!.documentIndex, 2);
        expect(progress.documentProgress, 1.0);
        expect(progress.tocItemId, '$existingBookId:toc_item:2');

        final readyBook = await repository.getBookById(existingBookId);
        expect(readyBook, isNotNull);
        expect(readyBook!.totalChapters, 3);

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

    test(
      'rejects legacy downgrade entrypoints for ready V2-only books without fallback content',
      () async {
        await repository.insertBook(_book(existingBookId));
        await repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: _tocItems(existingBookId),
        );

        await expectLater(
          repository.markNavigationRebuildInProgress(existingBookId),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('Cannot downgrade ready V2-only book'),
            ),
          ),
        );

        await expectLater(
          repository.resetNavigationDataToLegacy(
            existingBookId,
            rebuildState: NavigationRebuildState.failed,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('Cannot downgrade ready V2-only book'),
            ),
          ),
        );

        expect(
          await repository.getBookReadingDataSource(existingBookId),
          BookReadingDataSource.v2,
        );
        expect(await _countRows('reader_documents', existingBookId), 2);
        expect(await _countRows('toc_items', existingBookId), 2);
        expect(await _countRows('reading_progress_v2', existingBookId), 1);

        final book = await repository.getBookById(existingBookId);
        expect(book, isNotNull);
        expect(book!.usesV2Navigation, isTrue);
        expect(book.navigationRebuildFailedAt, isNull);
      },
    );

    test(
      'refreshNavigationDataV2Ready keeps ready books readable and applies refreshed payload',
      () async {
        await _seedReadyNavigationData(
          repository,
          existingBookId,
          initialProgress: _progress(
            existingBookId,
            documentIndex: 1,
            documentProgress: 0.6,
            tocItemId: '$existingBookId:toc_item:1',
            anchor: 'old-anchor',
          ),
        );

        await repository.refreshNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _refreshedDocuments(existingBookId),
          tocItems: _refreshedTocItems(existingBookId),
        );

        final book = await repository.getBookById(existingBookId);
        expect(book, isNotNull);
        expect(book!.usesV2Navigation, isTrue);
        expect(book.navigationRebuildState, NavigationRebuildState.ready);
        expect(book.navigationRebuildFailedAt, isNull);
        expect(book.totalChapters, 3);

        final documents = await repository.getReaderDocumentsByBookId(
          existingBookId,
        );
        expect(
          documents.map((document) => document.title),
          orderedEquals([
            'Refreshed Document 0',
            'Refreshed Document 1',
            'Refreshed Document 2',
          ]),
        );
        expect(
          (await repository.getTocItemsByBookId(
            existingBookId,
          )).map((tocItem) => tocItem.order),
          orderedEquals([0, 1, 2]),
        );

        final progress = await repository.getReadingProgressV2(existingBookId);
        expect(progress, isNotNull);
        expect(progress!.documentIndex, 1);
        expect(progress.documentProgress, 0.6);
        expect(progress.tocItemId, isNull);
        expect(progress.anchor, isNull);
      },
    );

    test(
      'refreshNavigationDataV2Ready rejects ready books that still have persisted legacy fallback content',
      () async {
        await repository.insertBook(_book(existingBookId));
        await repository.insertChapter(_legacyChapter(existingBookId, 0));
        await repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: _tocItems(existingBookId),
          initialProgress: _progress(
            existingBookId,
            documentIndex: 1,
            documentProgress: 0.35,
            tocItemId: '$existingBookId:toc_item:1',
            anchor: 'old-anchor',
          ),
        );

        expect(
          await repository.supportsReadyPreservingRefresh(existingBookId),
          isFalse,
        );

        await expectLater(
          repository.refreshNavigationDataV2Ready(
            bookId: existingBookId,
            documents: _refreshedDocuments(existingBookId),
            tocItems: _refreshedTocItems(existingBookId),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('ready V2-only books without persisted legacy fallback'),
            ),
          ),
        );

        final book = await repository.getBookById(existingBookId);
        expect(book, isNotNull);
        expect(book!.usesV2Navigation, isTrue);
        expect(book.navigationRebuildState, NavigationRebuildState.ready);

        final documents = await repository.getReaderDocumentsByBookId(
          existingBookId,
        );
        expect(
          documents.map((document) => document.title),
          orderedEquals(['Document 0', 'Document 1']),
        );

        final progress = await repository.getReadingProgressV2(existingBookId);
        expect(progress, isNotNull);
        expect(progress!.documentIndex, 1);
        expect(progress.documentProgress, 0.35);
        expect(progress.tocItemId, '$existingBookId:toc_item:1');
        expect(progress.anchor, 'old-anchor');
      },
    );

    test(
      'refreshNavigationDataV2Ready rolls back to the previous ready payload when the refresh write fails',
      () async {
        await _seedReadyNavigationData(
          repository,
          existingBookId,
          initialProgress: _progress(
            existingBookId,
            documentIndex: 1,
            documentProgress: 0.3,
            tocItemId: '$existingBookId:toc_item:1',
            anchor: 'old-anchor',
          ),
        );

        final db = await AppDatabase.database;
        await db.execute('''
          CREATE TRIGGER fail_ready_refresh_update
          BEFORE UPDATE OF navigation_data_version, navigation_rebuild_state, navigation_rebuild_failed_at ON books
          WHEN OLD.id = '$existingBookId'
          BEGIN
            SELECT RAISE(ABORT, 'forced ready refresh failure');
          END;
        ''');

        await expectLater(
          repository.refreshNavigationDataV2Ready(
            bookId: existingBookId,
            documents: _refreshedDocuments(existingBookId),
            tocItems: _refreshedTocItems(existingBookId),
          ),
          throwsA(isA<DatabaseException>()),
        );

        final book = await repository.getBookById(existingBookId);
        expect(book, isNotNull);
        expect(book!.usesV2Navigation, isTrue);
        expect(book.navigationRebuildState, NavigationRebuildState.ready);
        expect(book.navigationRebuildFailedAt, isNull);
        expect(book.totalChapters, 2);

        final documents = await repository.getReaderDocumentsByBookId(
          existingBookId,
        );
        expect(
          documents.map((document) => document.title),
          orderedEquals(['Document 0', 'Document 1']),
        );

        final progress = await repository.getReadingProgressV2(existingBookId);
        expect(progress, isNotNull);
        expect(progress!.documentIndex, 1);
        expect(progress.documentProgress, 0.3);
        expect(progress.tocItemId, '$existingBookId:toc_item:1');
        expect(progress.anchor, 'old-anchor');
      },
    );

    test(
      'refreshNavigationDataV2Ready falls back to initial progress when the old documentIndex is out of range',
      () async {
        await _seedReadyNavigationData(
          repository,
          existingBookId,
          initialProgress: _progress(
            existingBookId,
            documentIndex: 1,
            documentProgress: 0.9,
            tocItemId: '$existingBookId:toc_item:1',
            anchor: 'old-anchor',
          ),
        );

        await repository.refreshNavigationDataV2Ready(
          bookId: existingBookId,
          documents: [_refreshedDocument(existingBookId, 0)],
          tocItems: [_refreshedTocItem(existingBookId, 0, 0)],
        );

        final progress = await repository.getReadingProgressV2(existingBookId);
        expect(progress, isNotNull);
        expect(progress!.documentIndex, 0);
        expect(progress.documentProgress, 0);
        expect(progress.tocItemId, isNull);
        expect(progress.anchor, isNull);
      },
    );

    test(
      'deriveLegacyRebuildInitialProgressV2 maps legacy progress from persisted fallback content',
      () async {
        await repository.insertBook(_book(existingBookId));
        await repository.insertChapter(
          _legacyChapter(
            existingBookId,
            0,
          ).copyWith(content: '<html><body>Matched document</body></html>'),
        );
        await _seedLegacyReadingProgress(
          existingBookId,
          chapterIndex: 0,
          scrollPosition: 1.4,
          updatedAt: DateTime.utc(2026, 3, 22, 8),
        );

        final progress = await repository.deriveLegacyRebuildInitialProgressV2(
          bookId: existingBookId,
          documents: [
            ReaderDocument(
              id: '$existingBookId:reader_document:0',
              bookId: existingBookId,
              documentIndex: 0,
              fileName: 'OPS/Text/ch1.xhtml',
              title: 'Document 0',
              htmlContent: '<html><body>Other document</body></html>',
            ),
            ReaderDocument(
              id: '$existingBookId:reader_document:1',
              bookId: existingBookId,
              documentIndex: 1,
              fileName: 'OPS/Text/ch2.xhtml',
              title: 'Document 1',
              htmlContent: '<html><body>Matched document</body></html>',
            ),
          ],
        );

        expect(progress, isNotNull);
        expect(progress!.documentIndex, 1);
        expect(progress.documentProgress, 1.0);
        expect(progress.tocItemId, isNull);
        expect(progress.anchor, isNull);
        expect(
          progress.updatedAt.millisecondsSinceEpoch,
          DateTime.utc(2026, 3, 22, 8).millisecondsSinceEpoch,
        );
      },
    );

    for (final scenario in [
      (
        description:
            'deriveLegacyRebuildInitialProgressV2 returns null when legacy progress is missing',
        seed: () async {
          await repository.insertBook(_book(existingBookId));
        },
        documents: [
          ReaderDocument(
            id: '$existingBookId:reader_document:0',
            bookId: existingBookId,
            documentIndex: 0,
            fileName: 'OPS/Text/ch1.xhtml',
            title: 'Document 0',
            htmlContent: '<html><body>Matched document</body></html>',
          ),
        ],
      ),
      (
        description:
            'deriveLegacyRebuildInitialProgressV2 returns null when the legacy chapter row is missing',
        seed: () async {
          await repository.insertBook(_book(existingBookId));
          await _seedLegacyReadingProgress(
            existingBookId,
            chapterIndex: 3,
            scrollPosition: 0.4,
            updatedAt: DateTime.utc(2026, 3, 22, 9),
          );
        },
        documents: [
          ReaderDocument(
            id: '$existingBookId:reader_document:0',
            bookId: existingBookId,
            documentIndex: 0,
            fileName: 'OPS/Text/ch1.xhtml',
            title: 'Document 0',
            htmlContent: '<html><body>Matched document</body></html>',
          ),
        ],
      ),
      (
        description:
            'deriveLegacyRebuildInitialProgressV2 returns null when fallback content does not match any document',
        seed: () async {
          await repository.insertBook(_book(existingBookId));
          await repository.insertChapter(
            _legacyChapter(
              existingBookId,
              0,
            ).copyWith(content: '<html><body>Unmatched document</body></html>'),
          );
          await _seedLegacyReadingProgress(
            existingBookId,
            chapterIndex: 0,
            scrollPosition: 0.4,
            updatedAt: DateTime.utc(2026, 3, 22, 10),
          );
        },
        documents: [
          ReaderDocument(
            id: '$existingBookId:reader_document:0',
            bookId: existingBookId,
            documentIndex: 0,
            fileName: 'OPS/Text/ch1.xhtml',
            title: 'Document 0',
            htmlContent: '<html><body>Other document</body></html>',
          ),
        ],
      ),
      (
        description:
            'deriveLegacyRebuildInitialProgressV2 returns null when fallback content matches multiple documents',
        seed: () async {
          await repository.insertBook(_book(existingBookId));
          await repository.insertChapter(
            _legacyChapter(
              existingBookId,
              0,
            ).copyWith(content: '<html><body>Duplicate document</body></html>'),
          );
          await _seedLegacyReadingProgress(
            existingBookId,
            chapterIndex: 0,
            scrollPosition: 0.4,
            updatedAt: DateTime.utc(2026, 3, 22, 11),
          );
        },
        documents: [
          ReaderDocument(
            id: '$existingBookId:reader_document:0',
            bookId: existingBookId,
            documentIndex: 0,
            fileName: 'OPS/Text/ch1.xhtml',
            title: 'Document 0',
            htmlContent: '<html><body>Duplicate document</body></html>',
          ),
          ReaderDocument(
            id: '$existingBookId:reader_document:1',
            bookId: existingBookId,
            documentIndex: 1,
            fileName: 'OPS/Text/ch2.xhtml',
            title: 'Document 1',
            htmlContent: '<html><body>Duplicate document</body></html>',
          ),
        ],
      ),
    ]) {
      test(scenario.description, () async {
        await scenario.seed();

        final progress = await repository.deriveLegacyRebuildInitialProgressV2(
          bookId: existingBookId,
          documents: scenario.documents,
        );

        expect(progress, isNull);
      });
    }

    test(
      'updates V2 reading progress only while the book remains ready',
      () async {
        await repository.insertBook(_book(existingBookId));
        await repository.insertChapter(_legacyChapter(existingBookId, 0));
        await repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: _tocItems(existingBookId),
        );

        await repository.saveReadingProgressV2(
          _progress(existingBookId, documentIndex: 1, documentProgress: 1.4),
        );

        var progress = await repository.getReadingProgressV2(existingBookId);
        expect(progress, isNotNull);
        expect(progress!.documentIndex, 1);
        expect(progress.documentProgress, 1.0);

        await repository.markNavigationRebuildInProgress(existingBookId);
        await repository.saveReadingProgressV2(
          _progress(existingBookId, documentIndex: 0, documentProgress: 0.2),
        );

        final db = await AppDatabase.database;
        final rows = await db.query(
          'reading_progress_v2',
          where: 'book_id = ?',
          whereArgs: [existingBookId],
        );
        expect(rows, hasLength(1));

        progress = ReadingProgressV2.fromMap(rows.single);
        expect(progress.documentIndex, 1);
        expect(progress.documentProgress, 1.0);
      },
    );

    test(
      'rejects V2 progress saves with an out-of-range documentIndex',
      () async {
        await _seedReadyNavigationData(
          repository,
          existingBookId,
          initialProgress: _progress(
            existingBookId,
            documentIndex: 1,
            documentProgress: 0.3,
            tocItemId: '$existingBookId:toc_item:1',
          ),
        );

        await expectLater(
          repository.saveReadingProgressV2(
            _progress(
              existingBookId,
              documentIndex: 2,
              documentProgress: 0.8,
              tocItemId: '$existingBookId:toc_item:1',
            ),
          ),
          throwsRangeError,
        );

        final progress = await _loadStoredProgress(repository, existingBookId);
        expect(progress.documentIndex, 1);
        expect(progress.documentProgress, 0.3);
        expect(progress.tocItemId, '$existingBookId:toc_item:1');
      },
    );

    test('rejects V2 progress saves with an unknown tocItemId', () async {
      await _seedReadyNavigationData(
        repository,
        existingBookId,
        initialProgress: _progress(
          existingBookId,
          documentIndex: 0,
          documentProgress: 0.25,
          tocItemId: '$existingBookId:toc_item:0',
        ),
      );

      await expectLater(
        repository.saveReadingProgressV2(
          _progress(
            existingBookId,
            documentIndex: 0,
            documentProgress: 0.8,
            tocItemId: '$existingBookId:toc_item:missing',
          ),
        ),
        throwsArgumentError,
      );

      final progress = await _loadStoredProgress(repository, existingBookId);
      expect(progress.documentIndex, 0);
      expect(progress.documentProgress, 0.25);
      expect(progress.tocItemId, '$existingBookId:toc_item:0');
    });

    test(
      'rejects V2 progress saves when tocItem targetDocumentIndex does not match',
      () async {
        await _seedReadyNavigationData(
          repository,
          existingBookId,
          initialProgress: _progress(
            existingBookId,
            documentIndex: 0,
            documentProgress: 0.2,
            tocItemId: '$existingBookId:toc_item:0',
          ),
        );

        await expectLater(
          repository.saveReadingProgressV2(
            _progress(
              existingBookId,
              documentIndex: 0,
              documentProgress: 0.8,
              tocItemId: '$existingBookId:toc_item:1',
            ),
          ),
          throwsArgumentError,
        );

        final progress = await _loadStoredProgress(repository, existingBookId);
        expect(progress.documentIndex, 0);
        expect(progress.documentProgress, 0.2);
        expect(progress.tocItemId, '$existingBookId:toc_item:0');
      },
    );

    test(
      'skips invalid V2 progress writes after the book leaves ready',
      () async {
        await _seedReadyNavigationData(
          repository,
          existingBookId,
          seedLegacyFallbackChapter: true,
          initialProgress: _progress(
            existingBookId,
            documentIndex: 1,
            documentProgress: 0.4,
            tocItemId: '$existingBookId:toc_item:1',
          ),
        );
        await repository.markNavigationRebuildInProgress(existingBookId);

        await repository.saveReadingProgressV2(
          _progress(
            existingBookId,
            documentIndex: 99,
            documentProgress: 0.8,
            tocItemId: '$existingBookId:toc_item:missing',
          ),
        );

        final db = await AppDatabase.database;
        final rows = await db.query(
          'reading_progress_v2',
          where: 'book_id = ?',
          whereArgs: [existingBookId],
        );
        expect(rows, hasLength(1));

        final progress = ReadingProgressV2.fromMap(rows.single);
        expect(progress.documentIndex, 1);
        expect(progress.documentProgress, 0.4);
        expect(progress.tocItemId, '$existingBookId:toc_item:1');
      },
    );

    test('markNavigationRebuildInProgress keeps V2 unreadable', () async {
      await repository.insertBook(_book(existingBookId));
      await repository.insertChapter(_legacyChapter(existingBookId, 0));
      await repository.saveNavigationDataV2Ready(
        bookId: existingBookId,
        documents: _documents(existingBookId),
        tocItems: _tocItems(existingBookId),
      );

      await repository.markNavigationRebuildInProgress(existingBookId);

      final book = await repository.getBookById(existingBookId);
      expect(book, isNotNull);
      expect(book!.navigationDataVersion, Book.legacyNavigationDataVersion);
      expect(book.navigationRebuildState, NavigationRebuildState.rebuilding);
      expect(book.navigationRebuildFailedAt, isNull);
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
      'blocks stale V2 row reads when rebuild starts right before the row query',
      () async {
        await repository.insertBook(_book(existingBookId));
        await repository.insertChapter(_legacyChapter(existingBookId, 0));
        await repository.saveNavigationDataV2Ready(
          bookId: existingBookId,
          documents: _documents(existingBookId),
          tocItems: _tocItems(existingBookId),
        );

        Future<void> expectReadBlockedDuringInterleaving<T>(
          Future<T> Function(BookRepositoryImpl repository) read,
          Matcher matcher,
        ) async {
          var triggered = false;
          late final BookRepositoryImpl raceRepository;
          raceRepository = BookRepositoryImpl(
            beforeNavigationV2ReadQuery: (bookId) async {
              if (triggered) {
                return;
              }
              triggered = true;
              await raceRepository.markNavigationRebuildInProgress(bookId);
            },
          );

          final result = await read(raceRepository);
          expect(result, matcher);

          final book = await repository.getBookById(existingBookId);
          expect(book, isNotNull);
          expect(book!.navigationDataVersion, Book.legacyNavigationDataVersion);
          expect(
            book.navigationRebuildState,
            NavigationRebuildState.rebuilding,
          );
        }

        await expectReadBlockedDuringInterleaving<List<ReaderDocument>>(
          (raceRepository) =>
              raceRepository.getReaderDocumentsByBookId(existingBookId),
          isEmpty,
        );
        expect(await _countRows('reader_documents', existingBookId), 2);

        await _forceBookReadyWithoutTouchingV2(existingBookId);
        await expectReadBlockedDuringInterleaving<List<TocItem>>(
          (raceRepository) =>
              raceRepository.getTocItemsByBookId(existingBookId),
          isEmpty,
        );
        expect(await _countRows('toc_items', existingBookId), 2);

        await _forceBookReadyWithoutTouchingV2(existingBookId);
        await expectReadBlockedDuringInterleaving<ReadingProgressV2?>(
          (raceRepository) =>
              raceRepository.getReadingProgressV2(existingBookId),
          isNull,
        );
        expect(await _countRows('reading_progress_v2', existingBookId), 1);
      },
    );

    test(
      'imports new books directly as ready without persisting legacy chapters',
      () async {
        const importedBookId = 'book-import';
        await repository.importBookWithNavigationDataV2Ready(
          book: _book(importedBookId).copyWith(
            totalChapters: 99,
            navigationDataVersion: Book.v2NavigationDataVersion,
            navigationRebuildState: NavigationRebuildState.ready,
          ),
          documents: _documentsWithCount(importedBookId, 3),
          tocItems: _tocItemsWithCount(importedBookId, 3),
        );

        final book = await repository.getBookById(importedBookId);
        expect(book, isNotNull);
        expect(book!.navigationDataVersion, Book.v2NavigationDataVersion);
        expect(book.navigationRebuildState, NavigationRebuildState.ready);
        expect(book.navigationRebuildFailedAt, isNull);
        expect(book.totalChapters, 3);
        expect(
          await repository.getBookReadingDataSource(importedBookId),
          BookReadingDataSource.v2,
        );

        expect(await repository.getChaptersByBookId(importedBookId), isEmpty);
        expect(
          (await repository.getReaderDocumentsByBookId(
            importedBookId,
          )).map((document) => document.documentIndex),
          orderedEquals([0, 1, 2]),
        );
        expect(
          (await repository.getTocItemsByBookId(
            importedBookId,
          )).map((tocItem) => tocItem.order),
          orderedEquals([0, 1, 2]),
        );

        final progress = await repository.getReadingProgressV2(importedBookId);
        expect(progress, isNotNull);
        expect(progress!.documentIndex, 0);
        expect(progress.documentProgress, 0);
        expect(progress.tocItemId, isNull);
        expect(progress.anchor, isNull);
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

    test('rolls back new-book import when final ready update fails', () async {
      const importedBookId = 'book-import-fail';
      final db = await AppDatabase.database;
      await db.execute('''
        CREATE TRIGGER fail_new_book_import_ready_update
        BEFORE UPDATE OF navigation_data_version, navigation_rebuild_state, navigation_rebuild_failed_at ON books
        WHEN OLD.id = '$importedBookId'
        BEGIN
          SELECT RAISE(ABORT, 'forced new book import failure');
        END;
      ''');

      await expectLater(
        repository.importBookWithNavigationDataV2Ready(
          book: _book(importedBookId).copyWith(
            navigationDataVersion: Book.v2NavigationDataVersion,
            navigationRebuildState: NavigationRebuildState.ready,
          ),
          documents: _documents(importedBookId),
          tocItems: _tocItems(importedBookId),
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await repository.getBookById(importedBookId), isNull);
      expect(await repository.getChaptersByBookId(importedBookId), isEmpty);
      await _expectNoV2Rows(importedBookId);
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

Future<void> _forceBookReadyWithoutTouchingV2(String bookId) async {
  final db = await AppDatabase.database;
  final updatedRows = await db.update(
    'books',
    {
      'navigation_data_version': Book.v2NavigationDataVersion,
      'navigation_rebuild_state': NavigationRebuildState.ready.dbValue,
      'navigation_rebuild_failed_at': null,
    },
    where: 'id = ?',
    whereArgs: [bookId],
  );
  expect(updatedRows, 1);
}

Future<int> _countRows(String tableName, String bookId) async {
  final db = await AppDatabase.database;
  final rows = await db.query(
    tableName,
    columns: ['book_id'],
    where: 'book_id = ?',
    whereArgs: [bookId],
  );
  return rows.length;
}

Future<void> _seedReadyNavigationData(
  BookRepositoryImpl repository,
  String bookId, {
  bool seedLegacyFallbackChapter = false,
  ReadingProgressV2? initialProgress,
}) async {
  await repository.insertBook(_book(bookId));
  if (seedLegacyFallbackChapter) {
    await repository.insertChapter(_legacyChapter(bookId, 0));
  }
  await repository.saveNavigationDataV2Ready(
    bookId: bookId,
    documents: _documents(bookId),
    tocItems: _tocItems(bookId),
    initialProgress: initialProgress,
  );
}

Future<void> _seedLegacyReadingProgress(
  String bookId, {
  required int chapterIndex,
  required double scrollPosition,
  required DateTime updatedAt,
}) async {
  final db = await AppDatabase.database;
  await db.insert('reading_progress', {
    'book_id': bookId,
    'chapter_index': chapterIndex,
    'scroll_position': scrollPosition,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  });
}

Future<ReadingProgressV2> _loadStoredProgress(
  BookRepositoryImpl repository,
  String bookId,
) async {
  final progress = await repository.getReadingProgressV2(bookId);
  expect(progress, isNotNull);
  return progress!;
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

Chapter _legacyChapter(String bookId, int index) {
  return Chapter(
    id: '$bookId:chapter:$index',
    bookId: bookId,
    index: index,
    title: 'Legacy Chapter $index',
    content: '<html><body><p>Legacy fallback $index</p></body></html>',
  );
}

List<ReaderDocument> _documents(String bookId) {
  return _documentsWithCount(bookId, 2);
}

List<ReaderDocument> _documentsWithCount(String bookId, int count) {
  return List.generate(
    count,
    (index) => _document(bookId, index, 'OPS/Text/ch${index + 1}.xhtml'),
  );
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
  return _tocItemsWithCount(bookId, 2);
}

List<TocItem> _tocItemsWithCount(String bookId, int count) {
  return List.generate(
    count,
    (index) => _tocItem(bookId, index, targetDocumentIndex: index),
  );
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
  String? anchor,
}) {
  return ReadingProgressV2(
    bookId: bookId,
    documentIndex: documentIndex,
    documentProgress: documentProgress,
    tocItemId: tocItemId,
    anchor: anchor,
    updatedAt: DateTime.utc(2026, 3, 22),
  );
}

List<ReaderDocument> _refreshedDocuments(String bookId) {
  return [
    _refreshedDocument(bookId, 0),
    _refreshedDocument(bookId, 1),
    _refreshedDocument(bookId, 2),
  ];
}

ReaderDocument _refreshedDocument(String bookId, int index) {
  return ReaderDocument(
    id: '$bookId:refreshed_reader_document:$index',
    bookId: bookId,
    documentIndex: index,
    fileName: 'OPS/Refresh/part${index + 1}.xhtml',
    title: 'Refreshed Document $index',
    htmlContent:
        '<html><head><title>Refreshed Document $index</title></head><body></body></html>',
  );
}

List<TocItem> _refreshedTocItems(String bookId) {
  return [
    _refreshedTocItem(bookId, 0, 0),
    _refreshedTocItem(bookId, 1, 1),
    _refreshedTocItem(bookId, 2, 2),
  ];
}

TocItem _refreshedTocItem(String bookId, int order, int targetDocumentIndex) {
  return TocItem(
    id: '$bookId:refreshed_toc_item:$order',
    bookId: bookId,
    title: 'Refreshed TOC $order',
    order: order,
    depth: 0,
    parentId: null,
    fileName: 'OPS/Refresh/part${targetDocumentIndex + 1}.xhtml',
    anchor: null,
    targetDocumentIndex: targetDocumentIndex,
  );
}
