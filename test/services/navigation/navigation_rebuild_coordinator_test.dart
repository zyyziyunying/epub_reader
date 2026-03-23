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
  _FakeBookRepository({required this.book});

  Book? book;
  List<ReaderDocument> documents = const [];
  List<TocItem> tocItems = const [];
  ReadingProgressV2? progress;
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
    progress = initialProgress ?? ReadingProgressV2.initial(bookId);
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
  Future<Chapter?> getChapter(String bookId, int index) {
    throw UnimplementedError();
  }

  @override
  Future<ReadingProgress?> getReadingProgress(String bookId) {
    throw UnimplementedError();
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
    required List<Chapter> legacyChapters,
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
  Future<void> saveReadingProgress(ReadingProgress progress) {
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
  });

  final bool shouldThrow;
  final Set<int> throwOnCalls;
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
    return NavigationBuildResult(
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
