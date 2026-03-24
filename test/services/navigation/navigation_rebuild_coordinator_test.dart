import 'package:epub_reader/domain/entities/book.dart';
import 'package:epub_reader/domain/entities/book_reading_data_source.dart';
import 'package:epub_reader/domain/entities/chapter.dart';
import 'package:epub_reader/domain/entities/navigation_rebuild_state.dart';
import 'package:epub_reader/domain/entities/reading_progress.dart';
import 'package:epub_reader/domain/entities/reading_progress_v2.dart';
import 'package:epub_reader/domain/entities/reader_document.dart';
import 'package:epub_reader/domain/entities/toc_item.dart';
import 'package:epub_reader/domain/repositories/book_repository.dart';
import 'package:epub_reader/presentation/providers/book_providers.dart';
import 'package:epub_reader/services/epub_parser_service.dart';
import 'package:epub_reader/services/navigation/navigation_models.dart';
import 'package:epub_reader/services/navigation/navigation_rebuild_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

//TODO 拆分
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationRebuildCoordinator', () {
    test(
      'keeps current session on legacy while rebuilding legacy_pending books',
      () async {
        final repository = _FakeBookRepository(
          book: _book(
            'book-legacy',
            navigationRebuildState: NavigationRebuildState.legacyPending,
          ),
        );
        final parserService = _FakeEpubParserService();
        final coordinator = NavigationRebuildCoordinator(
          repository: repository,
          parserService: parserService,
        );

        final dataSource = await coordinator.resolveDataSourceForSession(
          'book-legacy',
        );
        await coordinator.waitForActiveRebuild('book-legacy');

        expect(dataSource, BookReadingDataSource.legacy);
        expect(parserService.calledBookIds, orderedEquals(['book-legacy']));
        expect(
          repository.events,
          orderedEquals(['mark:rebuilding', 'save:ready']),
        );
        expect(repository.book!.usesV2Navigation, isTrue);
      },
    );

    test(
      'treats rebuilding without an active task as interrupted rebuild',
      () async {
        final repository = _FakeBookRepository(
          book: _book(
            'book-interrupted',
            navigationRebuildState: NavigationRebuildState.rebuilding,
          ),
        );
        final coordinator = NavigationRebuildCoordinator(
          repository: repository,
          parserService: _FakeEpubParserService(),
        );

        final dataSource = await coordinator.resolveDataSourceForSession(
          'book-interrupted',
        );
        await coordinator.waitForActiveRebuild('book-interrupted');

        expect(dataSource, BookReadingDataSource.legacy);
        expect(
          repository.events,
          orderedEquals([
            'reset:legacy_pending',
            'mark:rebuilding',
            'save:ready',
          ]),
        );
        expect(repository.book!.usesV2Navigation, isTrue);
      },
    );

    test('marks rebuild as failed when parsing throws', () async {
      final repository = _FakeBookRepository(
        book: _book(
          'book-failed',
          navigationRebuildState: NavigationRebuildState.failed,
        ),
      );
      final coordinator = NavigationRebuildCoordinator(
        repository: repository,
        parserService: _FakeEpubParserService(shouldThrow: true),
      );

      final dataSource = await coordinator.resolveDataSourceForSession(
        'book-failed',
      );
      await coordinator.waitForActiveRebuild('book-failed');

      expect(dataSource, BookReadingDataSource.legacy);
      expect(
        repository.events,
        orderedEquals(['mark:rebuilding', 'reset:failed']),
      );
      expect(
        repository.book!.navigationRebuildState,
        NavigationRebuildState.failed,
      );
      expect(repository.book!.usesV2Navigation, isFalse);
      expect(repository.book!.navigationRebuildFailedAt, isNotNull);
    });

    test('returns v2 immediately for ready books', () async {
      final repository = _FakeBookRepository(
        book: _book(
          'book-ready',
          navigationDataVersion: Book.v2NavigationDataVersion,
          navigationRebuildState: NavigationRebuildState.ready,
        ),
      );
      final parserService = _FakeEpubParserService();
      final coordinator = NavigationRebuildCoordinator(
        repository: repository,
        parserService: parserService,
      );

      final dataSource = await coordinator.resolveDataSourceForSession(
        'book-ready',
      );

      expect(dataSource, BookReadingDataSource.v2);
      expect(repository.events, isEmpty);
      expect(parserService.calledBookIds, isEmpty);
    });

    test(
      'refreshes ready books through the dedicated ready entrypoint',
      () async {
        const bookId = 'book-ready-refresh';
        final repository = _FakeBookRepository(
          book: _book(
            bookId,
            navigationDataVersion: Book.v2NavigationDataVersion,
            navigationRebuildState: NavigationRebuildState.ready,
          ),
          readyProgress: ReadingProgressV2(
            bookId: bookId,
            documentIndex: 1,
            documentProgress: 0.55,
            tocItemId: '$bookId:toc:1',
            anchor: 'old-anchor',
            updatedAt: DateTime.utc(2026, 3, 22, 11),
          ),
        );
        final parserService = _FakeEpubParserService(
          navigationResult: NavigationBuildResult(
            documents: [
              ReaderDocument(
                id: '$bookId:doc:new:0',
                bookId: bookId,
                documentIndex: 0,
                fileName: 'OPS/Refresh/ch1.xhtml',
                title: 'Refreshed 1',
                htmlContent: '<html><body>Refreshed 1</body></html>',
              ),
              ReaderDocument(
                id: '$bookId:doc:new:1',
                bookId: bookId,
                documentIndex: 1,
                fileName: 'OPS/Refresh/ch2.xhtml',
                title: 'Refreshed 2',
                htmlContent: '<html><body>Refreshed 2</body></html>',
              ),
            ],
            tocItems: [
              TocItem(
                id: '$bookId:toc:new:0',
                bookId: bookId,
                title: 'Refreshed 1',
                order: 0,
                depth: 0,
                parentId: null,
                fileName: 'OPS/Refresh/ch1.xhtml',
                anchor: null,
                targetDocumentIndex: 0,
              ),
              TocItem(
                id: '$bookId:toc:new:1',
                bookId: bookId,
                title: 'Refreshed 2',
                order: 1,
                depth: 0,
                parentId: null,
                fileName: 'OPS/Refresh/ch2.xhtml',
                anchor: null,
                targetDocumentIndex: 1,
              ),
            ],
            navItems: const [],
            hasPhase2OnlyToc: false,
            usedSpineOrder: true,
          ),
        );
        final coordinator = NavigationRebuildCoordinator(
          repository: repository,
          parserService: parserService,
        );

        await coordinator.refreshReadyNavigationData(bookId);

        expect(parserService.calledBookIds, orderedEquals([bookId]));
        expect(repository.events, orderedEquals(['refresh:ready']));
        expect(repository.book!.usesV2Navigation, isTrue);
        expect(
          repository.documents.map((document) => document.title),
          orderedEquals(['Refreshed 1', 'Refreshed 2']),
        );
        expect(repository.progress, isNotNull);
        expect(repository.progress!.documentIndex, 1);
        expect(repository.progress!.documentProgress, 0.55);
        expect(repository.progress!.tocItemId, isNull);
        expect(repository.progress!.anchor, isNull);
      },
    );

    test(
      'rejects ready refresh for ready books that still have persisted legacy fallback content',
      () async {
        const bookId = 'book-ready-refresh-legacy-fallback';
        final repository = _FakeBookRepository(
          book: _book(
            bookId,
            navigationDataVersion: Book.v2NavigationDataVersion,
            navigationRebuildState: NavigationRebuildState.ready,
          ),
          chapters: [
            Chapter(
              id: '$bookId:chapter:0',
              bookId: bookId,
              index: 0,
              title: 'Legacy Chapter',
              content: '<html><body>Legacy Chapter</body></html>',
            ),
          ],
        );
        final parserService = _FakeEpubParserService();
        final coordinator = NavigationRebuildCoordinator(
          repository: repository,
          parserService: parserService,
        );

        await expectLater(
          coordinator.refreshReadyNavigationData(bookId),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('ready V2-only books without persisted legacy fallback'),
            ),
          ),
        );

        expect(parserService.calledBookIds, isEmpty);
        expect(repository.events, isEmpty);
      },
    );

    test('keeps existing V2 data when ready refresh fails', () async {
      const bookId = 'book-ready-refresh-failed';
      final repository = _FakeBookRepository(
        book: _book(
          bookId,
          navigationDataVersion: Book.v2NavigationDataVersion,
          navigationRebuildState: NavigationRebuildState.ready,
        ),
        documents: [
          ReaderDocument(
            id: '$bookId:doc:0',
            bookId: bookId,
            documentIndex: 0,
            fileName: 'OPS/Text/ch1.xhtml',
            title: 'Existing document',
            htmlContent: '<html><body>Existing document</body></html>',
          ),
        ],
        tocItems: [
          TocItem(
            id: '$bookId:toc:0',
            bookId: bookId,
            title: 'Existing document',
            order: 0,
            depth: 0,
            parentId: null,
            fileName: 'OPS/Text/ch1.xhtml',
            anchor: null,
            targetDocumentIndex: 0,
          ),
        ],
        readyProgress: ReadingProgressV2(
          bookId: bookId,
          documentIndex: 0,
          documentProgress: 0.4,
          tocItemId: '$bookId:toc:0',
          anchor: 'old-anchor',
          updatedAt: DateTime.utc(2026, 3, 22, 12),
        ),
        refreshShouldThrow: true,
      );
      final parserService = _FakeEpubParserService();
      final coordinator = NavigationRebuildCoordinator(
        repository: repository,
        parserService: parserService,
      );

      await expectLater(
        coordinator.refreshReadyNavigationData(bookId),
        throwsA(isA<Exception>()),
      );

      expect(parserService.calledBookIds, orderedEquals([bookId]));
      expect(repository.events, orderedEquals(['refresh:ready']));
      expect(repository.book!.usesV2Navigation, isTrue);
      expect(
        repository.book!.navigationRebuildState,
        NavigationRebuildState.ready,
      );
      expect(
        repository.documents.map((document) => document.title),
        orderedEquals(['Existing document']),
      );
      expect(repository.progress, isNotNull);
      expect(repository.progress!.documentIndex, 0);
      expect(repository.progress!.documentProgress, 0.4);
      expect(repository.progress!.tocItemId, '$bookId:toc:0');
      expect(repository.progress!.anchor, 'old-anchor');
    });

    test(
      'best-effort maps legacy reading progress into V2 ready progress',
      () async {
        const bookId = 'book-progress-map';
        final repository = _FakeBookRepository(
          book: _book(
            bookId,
            navigationRebuildState: NavigationRebuildState.legacyPending,
          ),
          chapters: [
            Chapter(
              id: '$bookId:chapter:0',
              bookId: bookId,
              index: 0,
              title: 'Legacy Chapter',
              content: '<html><body>Matched document</body></html>',
            ),
          ],
          legacyProgress: ReadingProgress(
            bookId: bookId,
            chapterIndex: 0,
            scrollPosition: 0.65,
            updatedAt: DateTime.utc(2026, 3, 22, 8),
          ),
        );
        final parserService = _FakeEpubParserService(
          navigationResult: NavigationBuildResult(
            documents: [
              ReaderDocument(
                id: '$bookId:doc:0',
                bookId: bookId,
                documentIndex: 0,
                fileName: 'OPS/Text/ch1.xhtml',
                title: 'Chapter 1',
                htmlContent: '<html><body>Other document</body></html>',
              ),
              ReaderDocument(
                id: '$bookId:doc:1',
                bookId: bookId,
                documentIndex: 1,
                fileName: 'OPS/Text/ch2.xhtml',
                title: 'Chapter 2',
                htmlContent: '<html><body>Matched document</body></html>',
              ),
            ],
            tocItems: [
              TocItem(
                id: '$bookId:toc:0',
                bookId: bookId,
                title: 'Chapter 1',
                order: 0,
                depth: 0,
                parentId: null,
                fileName: 'OPS/Text/ch1.xhtml',
                anchor: null,
                targetDocumentIndex: 0,
              ),
              TocItem(
                id: '$bookId:toc:1',
                bookId: bookId,
                title: 'Chapter 2',
                order: 1,
                depth: 0,
                parentId: null,
                fileName: 'OPS/Text/ch2.xhtml',
                anchor: null,
                targetDocumentIndex: 1,
              ),
            ],
            navItems: const [],
            hasPhase2OnlyToc: false,
            usedSpineOrder: true,
          ),
        );
        final coordinator = NavigationRebuildCoordinator(
          repository: repository,
          parserService: parserService,
        );

        final dataSource = await coordinator.resolveDataSourceForSession(
          bookId,
        );
        await coordinator.waitForActiveRebuild(bookId);

        expect(dataSource, BookReadingDataSource.legacy);
        expect(repository.savedInitialProgress, isNotNull);
        expect(repository.savedInitialProgress!.documentIndex, 1);
        expect(repository.savedInitialProgress!.documentProgress, 0.65);
        expect(
          repository.savedInitialProgress!.updatedAt,
          DateTime.utc(2026, 3, 22, 8),
        );
      },
    );

    for (final scenario in [
      (
        description: 'still reaches ready when legacy progress is missing',
        repository: _FakeBookRepository(
          book: _book(
            'book-progress-missing',
            navigationRebuildState: NavigationRebuildState.legacyPending,
          ),
        ),
        parserService: _FakeEpubParserService(),
      ),
      (
        description: 'still reaches ready when legacy progress mapping misses',
        repository: _FakeBookRepository(
          book: _book(
            'book-progress-miss',
            navigationRebuildState: NavigationRebuildState.legacyPending,
          ),
          chapters: [
            Chapter(
              id: 'book-progress-miss:chapter:0',
              bookId: 'book-progress-miss',
              index: 0,
              title: 'Legacy Chapter',
              content: '<html><body>Unmatched document</body></html>',
            ),
          ],
          legacyProgress: ReadingProgress(
            bookId: 'book-progress-miss',
            chapterIndex: 0,
            scrollPosition: 0.45,
            updatedAt: DateTime.utc(2026, 3, 22, 9),
          ),
        ),
        parserService: _FakeEpubParserService(),
      ),
      (
        description:
            'still reaches ready when legacy progress mapping is ambiguous',
        repository: _FakeBookRepository(
          book: _book(
            'book-progress-ambiguous',
            navigationRebuildState: NavigationRebuildState.legacyPending,
          ),
          chapters: [
            Chapter(
              id: 'book-progress-ambiguous:chapter:0',
              bookId: 'book-progress-ambiguous',
              index: 0,
              title: 'Legacy Chapter',
              content: '<html><body>Duplicate document</body></html>',
            ),
          ],
          legacyProgress: ReadingProgress(
            bookId: 'book-progress-ambiguous',
            chapterIndex: 0,
            scrollPosition: 0.45,
            updatedAt: DateTime.utc(2026, 3, 22, 10),
          ),
        ),
        parserService: _FakeEpubParserService(
          navigationResult: NavigationBuildResult(
            documents: [
              ReaderDocument(
                id: 'book-progress-ambiguous:doc:0',
                bookId: 'book-progress-ambiguous',
                documentIndex: 0,
                fileName: 'OPS/Text/ch1.xhtml',
                title: 'Chapter 1',
                htmlContent: '<html><body>Duplicate document</body></html>',
              ),
              ReaderDocument(
                id: 'book-progress-ambiguous:doc:1',
                bookId: 'book-progress-ambiguous',
                documentIndex: 1,
                fileName: 'OPS/Text/ch2.xhtml',
                title: 'Chapter 2',
                htmlContent: '<html><body>Duplicate document</body></html>',
              ),
            ],
            tocItems: [
              TocItem(
                id: 'book-progress-ambiguous:toc:0',
                bookId: 'book-progress-ambiguous',
                title: 'Chapter 1',
                order: 0,
                depth: 0,
                parentId: null,
                fileName: 'OPS/Text/ch1.xhtml',
                anchor: null,
                targetDocumentIndex: 0,
              ),
              TocItem(
                id: 'book-progress-ambiguous:toc:1',
                bookId: 'book-progress-ambiguous',
                title: 'Chapter 2',
                order: 1,
                depth: 0,
                parentId: null,
                fileName: 'OPS/Text/ch2.xhtml',
                anchor: null,
                targetDocumentIndex: 1,
              ),
            ],
            navItems: const [],
            hasPhase2OnlyToc: false,
            usedSpineOrder: true,
          ),
        ),
      ),
    ]) {
      test(scenario.description, () async {
        final coordinator = NavigationRebuildCoordinator(
          repository: scenario.repository,
          parserService: scenario.parserService,
        );
        final bookId = scenario.repository.book!.id;

        final dataSource = await coordinator.resolveDataSourceForSession(
          bookId,
        );
        await coordinator.waitForActiveRebuild(bookId);

        expect(dataSource, BookReadingDataSource.legacy);
        expect(
          scenario.repository.events,
          orderedEquals(['mark:rebuilding', 'save:ready']),
        );
        expect(scenario.repository.savedInitialProgress, isNull);
        expect(scenario.repository.book!.usesV2Navigation, isTrue);
      });
    }
  });

  group('bookReadingDataSourceProvider', () {
    test(
      're-evaluates the next reader session after a successful background rebuild',
      () async {
        final repository = _FakeBookRepository(
          book: _book(
            'book-session-success',
            navigationRebuildState: NavigationRebuildState.legacyPending,
          ),
        );
        final parserService = _FakeEpubParserService();
        final container = ProviderContainer(
          overrides: [
            bookRepositoryProvider.overrideWith((ref) => repository),
            epubParserServiceProvider.overrideWith((ref) => parserService),
          ],
        );
        addTearDown(container.dispose);

        final firstSession = (
          bookId: 'book-session-success',
          sessionToken: Object(),
        );
        final firstSubscription = container.listen(
          bookReadingDataSourceProvider(firstSession),
          (_, _) {},
          fireImmediately: true,
        );

        expect(
          await container.read(
            bookReadingDataSourceProvider(firstSession).future,
          ),
          BookReadingDataSource.legacy,
        );
        await container
            .read(navigationRebuildCoordinatorProvider)
            .waitForActiveRebuild('book-session-success');
        expect(
          firstSubscription.read().requireValue,
          BookReadingDataSource.legacy,
        );

        firstSubscription.close();

        final secondSession = (
          bookId: 'book-session-success',
          sessionToken: Object(),
        );
        expect(
          await container.read(
            bookReadingDataSourceProvider(secondSession).future,
          ),
          BookReadingDataSource.v2,
        );
        expect(
          parserService.calledBookIds,
          orderedEquals(['book-session-success']),
        );
      },
    );

    test(
      'retries failed rebuilds when the next reader session starts',
      () async {
        final repository = _FakeBookRepository(
          book: _book(
            'book-session-retry',
            navigationRebuildState: NavigationRebuildState.legacyPending,
          ),
        );
        final parserService = _FakeEpubParserService(throwOnCalls: {1});
        final container = ProviderContainer(
          overrides: [
            bookRepositoryProvider.overrideWith((ref) => repository),
            epubParserServiceProvider.overrideWith((ref) => parserService),
          ],
        );
        addTearDown(container.dispose);

        final firstSession = (
          bookId: 'book-session-retry',
          sessionToken: Object(),
        );
        final firstSubscription = container.listen(
          bookReadingDataSourceProvider(firstSession),
          (_, _) {},
          fireImmediately: true,
        );

        expect(
          await container.read(
            bookReadingDataSourceProvider(firstSession).future,
          ),
          BookReadingDataSource.legacy,
        );
        await container
            .read(navigationRebuildCoordinatorProvider)
            .waitForActiveRebuild('book-session-retry');
        expect(
          repository.book!.navigationRebuildState,
          NavigationRebuildState.failed,
        );
        expect(
          firstSubscription.read().requireValue,
          BookReadingDataSource.legacy,
        );

        firstSubscription.close();

        final secondSession = (
          bookId: 'book-session-retry',
          sessionToken: Object(),
        );
        final secondSubscription = container.listen(
          bookReadingDataSourceProvider(secondSession),
          (_, _) {},
          fireImmediately: true,
        );

        expect(
          await container.read(
            bookReadingDataSourceProvider(secondSession).future,
          ),
          BookReadingDataSource.legacy,
        );
        await container
            .read(navigationRebuildCoordinatorProvider)
            .waitForActiveRebuild('book-session-retry');
        expect(
          secondSubscription.read().requireValue,
          BookReadingDataSource.legacy,
        );
        expect(repository.book!.usesV2Navigation, isTrue);

        secondSubscription.close();

        final thirdSession = (
          bookId: 'book-session-retry',
          sessionToken: Object(),
        );
        expect(
          await container.read(
            bookReadingDataSourceProvider(thirdSession).future,
          ),
          BookReadingDataSource.v2,
        );
        expect(
          parserService.calledBookIds,
          orderedEquals(['book-session-retry', 'book-session-retry']),
        );
        expect(
          repository.events,
          orderedEquals([
            'mark:rebuilding',
            'reset:failed',
            'mark:rebuilding',
            'save:ready',
          ]),
        );
      },
    );
  });
}

class _FakeBookRepository implements BookRepository {
  _FakeBookRepository({
    required this.book,
    this.chapters = const [],
    this.legacyProgress,
    this.documents = const [],
    this.tocItems = const [],
    this.readyProgress,
    this.refreshShouldThrow = false,
  }) : progress = readyProgress;

  Book? book;
  final List<Chapter> chapters;
  final ReadingProgress? legacyProgress;
  final ReadingProgressV2? readyProgress;
  final bool refreshShouldThrow;
  List<ReaderDocument> documents;
  List<TocItem> tocItems;
  ReadingProgressV2? progress;
  ReadingProgressV2? savedInitialProgress;
  final List<String> events = [];

  @override
  Future<Book?> getBookById(String id) async {
    if (book?.id != id) {
      return null;
    }
    return book;
  }

  @override
  Future<void> markNavigationRebuildInProgress(String bookId) async {
    events.add('mark:rebuilding');
    book = book!.copyWith(
      navigationDataVersion: Book.legacyNavigationDataVersion,
      navigationRebuildState: NavigationRebuildState.rebuilding,
      navigationRebuildFailedAt: null,
    );
  }

  @override
  Future<void> saveNavigationDataV2Ready({
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) async {
    events.add('save:ready');
    this.documents = documents;
    this.tocItems = tocItems;
    savedInitialProgress = initialProgress;
    progress = initialProgress ?? ReadingProgressV2.initial(bookId);
    book = book!.copyWith(
      navigationDataVersion: Book.v2NavigationDataVersion,
      navigationRebuildState: NavigationRebuildState.ready,
      navigationRebuildFailedAt: null,
    );
  }

  @override
  Future<bool> supportsReadyPreservingRefresh(String bookId) async {
    return book?.id == bookId && book!.usesV2Navigation && chapters.isEmpty;
  }

  @override
  Future<void> refreshNavigationDataV2Ready({
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
  }) async {
    events.add('refresh:ready');
    if (book == null || !book!.usesV2Navigation) {
      throw StateError(
        'refreshNavigationDataV2Ready requires an existing ready V2 book: $bookId',
      );
    }
    if (chapters.isNotEmpty) {
      throw StateError(
        'refreshNavigationDataV2Ready only supports ready V2-only books without persisted legacy fallback content: $bookId',
      );
    }
    if (refreshShouldThrow) {
      throw Exception('forced ready refresh failure');
    }

    this.documents = documents;
    this.tocItems = tocItems;

    final currentProgress = progress;
    if (currentProgress == null ||
        currentProgress.documentIndex < 0 ||
        currentProgress.documentIndex >= documents.length) {
      progress = ReadingProgressV2.initial(bookId);
    } else {
      progress = ReadingProgressV2(
        bookId: bookId,
        documentIndex: currentProgress.documentIndex,
        documentProgress: currentProgress.documentProgress
            .clamp(0.0, 1.0)
            .toDouble(),
        tocItemId: null,
        anchor: null,
        updatedAt: currentProgress.updatedAt,
      );
    }

    book = book!.copyWith(
      navigationDataVersion: Book.v2NavigationDataVersion,
      navigationRebuildState: NavigationRebuildState.ready,
      navigationRebuildFailedAt: null,
    );
  }

  @override
  Future<void> resetNavigationDataToLegacy(
    String bookId, {
    required NavigationRebuildState rebuildState,
    DateTime? failedAt,
  }) async {
    events.add('reset:${rebuildState.dbValue}');
    documents = const [];
    tocItems = const [];
    progress = null;
    book = book!.copyWith(
      navigationDataVersion: Book.legacyNavigationDataVersion,
      navigationRebuildState: rebuildState,
      navigationRebuildFailedAt: rebuildState == NavigationRebuildState.failed
          ? (failedAt ?? DateTime.now())
          : null,
    );
  }

  @override
  Future<BookReadingDataSource> getBookReadingDataSource(String bookId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Book>> getAllBooks() {
    throw UnimplementedError();
  }

  @override
  Future<List<Chapter>> getChaptersByBookId(String bookId) {
    throw UnimplementedError();
  }

  @override
  Future<ReadingProgressV2?> deriveLegacyRebuildInitialProgressV2({
    required String bookId,
    required List<ReaderDocument> documents,
  }) async {
    if (legacyProgress?.bookId != bookId) {
      return null;
    }

    Chapter? legacyChapter;
    for (final chapter in chapters) {
      if (chapter.bookId == bookId &&
          chapter.index == legacyProgress!.chapterIndex) {
        legacyChapter = chapter;
        break;
      }
    }
    if (legacyChapter == null) {
      return null;
    }

    final matches = documents
        .where((document) => document.htmlContent == legacyChapter!.content)
        .toList();
    if (matches.length != 1) {
      return null;
    }

    return ReadingProgressV2(
      bookId: bookId,
      documentIndex: matches.single.documentIndex,
      documentProgress: legacyProgress!.scrollPosition
          .clamp(0.0, 1.0)
          .toDouble(),
      tocItemId: null,
      anchor: null,
      updatedAt: legacyProgress!.updatedAt,
    );
  }

  @override
  Future<ReadingProgressV2?> getReadingProgressV2(String bookId) {
    throw UnimplementedError();
  }

  @override
  Future<List<ReaderDocument>> getReaderDocumentsByBookId(String bookId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TocItem>> getTocItemsByBookId(String bookId) {
    throw UnimplementedError();
  }

  @override
  Future<void> importBookWithNavigationDataV2Ready({
    required Book book,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> insertBook(Book book) {
    throw UnimplementedError();
  }

  @override
  Future<void> insertChapter(Chapter chapter) {
    throw UnimplementedError();
  }

  @override
  Future<void> insertChapters(List<Chapter> chapters) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveReadingProgressV2(ReadingProgressV2 progress) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateBook(Book book) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateLastReadAt(String bookId, DateTime time) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBook(String id) {
    throw UnimplementedError();
  }
}

class _FakeEpubParserService extends EpubParserService {
  _FakeEpubParserService({
    this.shouldThrow = false,
    this.throwOnCalls = const <int>{},
    this.navigationResult,
  });

  final bool shouldThrow;
  final Set<int> throwOnCalls;
  final NavigationBuildResult? navigationResult;
  final List<String> calledBookIds = [];
  int _callCount = 0;

  @override
  Future<NavigationBuildResult> buildNavigationFromFile(
    String filePath, {
    required String bookId,
  }) async {
    calledBookIds.add(bookId);
    _callCount += 1;
    if (shouldThrow || throwOnCalls.contains(_callCount)) {
      throw Exception('forced parse failure');
    }
    return navigationResult ??
        NavigationBuildResult(
          documents: [
            ReaderDocument(
              id: '$bookId:doc:0',
              bookId: bookId,
              documentIndex: 0,
              fileName: 'OPS/Text/ch1.xhtml',
              title: 'Chapter 1',
              htmlContent: '<html><body>Chapter 1</body></html>',
            ),
          ],
          tocItems: [
            TocItem(
              id: '$bookId:toc:0',
              bookId: bookId,
              title: 'Chapter 1',
              order: 0,
              depth: 0,
              parentId: null,
              fileName: 'OPS/Text/ch1.xhtml',
              anchor: null,
              targetDocumentIndex: 0,
            ),
          ],
          navItems: const [],
          hasPhase2OnlyToc: false,
          usedSpineOrder: true,
        );
  }
}

Book _book(
  String id, {
  int navigationDataVersion = Book.legacyNavigationDataVersion,
  required NavigationRebuildState navigationRebuildState,
}) {
  return Book(
    id: id,
    title: 'Book $id',
    author: 'Author',
    filePath: 'D:/books/$id.epub',
    totalChapters: 1,
    addedAt: DateTime.utc(2026, 3, 22),
    navigationDataVersion: navigationDataVersion,
    navigationRebuildState: navigationRebuildState,
  );
}
