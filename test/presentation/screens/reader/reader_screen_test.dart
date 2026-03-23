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
import 'package:epub_reader/presentation/screens/reader/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'renders V2 reader navigation, updates current document, and only shows document nav items in the drawer',
    (tester) async {
      final repository = _FakeReaderRepository(
        book: _book(
          'book-v2',
          navigationDataVersion: Book.v2NavigationDataVersion,
          navigationRebuildState: NavigationRebuildState.ready,
        ),
        chapters: [_chapter('book-v2', 0, 'Legacy Chapter')],
        documents: [
          _document('book-v2', 0, 'Document 1', paragraphCount: 18),
          _document('book-v2', 1, 'Document 2', paragraphCount: 18),
        ],
        tocItems: [
          _tocItem('book-v2', 0, title: 'Intro', targetDocumentIndex: 0),
          _tocItem(
            'book-v2',
            1,
            title: 'Ignored Anchor',
            targetDocumentIndex: 0,
            anchor: 'part-1',
          ),
          _tocItem(
            'book-v2',
            2,
            title: 'Duplicate Entry',
            targetDocumentIndex: 0,
          ),
          _tocItem('book-v2', 3, title: '   ', targetDocumentIndex: 1),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWith((ref) => repository),
            bookReadingDataSourceProvider.overrideWith(
              (ref, session) async => BookReadingDataSource.v2,
            ),
          ],
          child: MaterialApp(home: ReaderScreen(book: repository.book)),
        ),
      );

      await tester.pumpAndSettle();

      expect(repository.chapterReadCount, 0);
      expect(repository.documentReadCount, greaterThan(0));
      expect(find.text('Document 1'), findsOneWidget);

      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();

      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('1 / 2 documents'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('2 / 2 documents'), findsOneWidget);
      expect(find.text('Document 2'), findsWidgets);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Some TOC entries in this EPUB use anchors or multiple entries per document. Phase 1 only supports document-level navigation.',
        ),
        findsOneWidget,
      );
      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('Ignored Anchor'), findsNothing);
      expect(find.text('Duplicate Entry'), findsNothing);

      await tester.tap(find.text('Intro'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 2 documents'), findsOneWidget);
    },
  );

  testWidgets('restores and saves V2 reading progress inside a ready session', (
    tester,
  ) async {
    final repository = _FakeReaderRepository(
      book: _book(
        'book-v2-progress',
        navigationDataVersion: Book.v2NavigationDataVersion,
        navigationRebuildState: NavigationRebuildState.ready,
      ),
      chapters: [_chapter('book-v2-progress', 0, 'Legacy Chapter')],
      documents: [
        _document('book-v2-progress', 0, 'Document 1', paragraphCount: 20),
        _document('book-v2-progress', 1, 'Document 2', paragraphCount: 20),
      ],
      tocItems: [
        _tocItem('book-v2-progress', 0, title: 'Intro', targetDocumentIndex: 0),
        _tocItem(
          'book-v2-progress',
          1,
          title: 'Second',
          targetDocumentIndex: 1,
        ),
      ],
      initialProgress: ReadingProgressV2(
        bookId: 'book-v2-progress',
        documentIndex: 1,
        documentProgress: 0.4,
        tocItemId: null,
        anchor: null,
        updatedAt: DateTime.utc(2026, 3, 22),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWith((ref) => repository),
          bookReadingDataSourceProvider.overrideWith(
            (ref, session) async => BookReadingDataSource.v2,
          ),
        ],
        child: MaterialApp(home: ReaderScreen(book: repository.book)),
      ),
    );

    await tester.pumpAndSettle();

    expect(repository.v2ProgressReadCount, 1);

    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2 documents'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);

    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(repository.savedV2Progress, isNotEmpty);
    expect(repository.v2ProgressSaveCount, greaterThan(0));
    expect(repository.savedV2Progress.last.documentIndex, 1);
    expect(repository.savedV2Progress.last.documentProgress, greaterThan(0.4));
  });

  testWidgets(
    'flushes V2 reading progress when app lifecycle changes to paused',
    (tester) async {
      final repository = _FakeReaderRepository(
        book: _book(
          'book-v2-paused',
          navigationDataVersion: Book.v2NavigationDataVersion,
          navigationRebuildState: NavigationRebuildState.ready,
        ),
        chapters: [_chapter('book-v2-paused', 0, 'Legacy Chapter')],
        documents: [
          _document('book-v2-paused', 0, 'Document 1', paragraphCount: 28),
        ],
        tocItems: [
          _tocItem('book-v2-paused', 0, title: 'Intro', targetDocumentIndex: 0),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWith((ref) => repository),
            bookReadingDataSourceProvider.overrideWith(
              (ref, session) async => BookReadingDataSource.v2,
            ),
          ],
          child: MaterialApp(home: ReaderScreen(book: repository.book)),
        ),
      );

      await tester.pumpAndSettle();
      expect(repository.v2ProgressSaveCount, 0);

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -300),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(repository.savedV2Progress, isNotEmpty);
      expect(repository.v2ProgressSaveCount, 1);
      expect(repository.savedV2Progress.last.documentIndex, 0);
      expect(repository.savedV2Progress.last.documentProgress, greaterThan(0));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    },
  );

  testWidgets(
    'flushes V2 reading progress when app lifecycle changes to hidden',
    (tester) async {
      final repository = _FakeReaderRepository(
        book: _book(
          'book-v2-hidden',
          navigationDataVersion: Book.v2NavigationDataVersion,
          navigationRebuildState: NavigationRebuildState.ready,
        ),
        chapters: [_chapter('book-v2-hidden', 0, 'Legacy Chapter')],
        documents: [
          _document('book-v2-hidden', 0, 'Document 1', paragraphCount: 28),
        ],
        tocItems: [
          _tocItem('book-v2-hidden', 0, title: 'Intro', targetDocumentIndex: 0),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookRepositoryProvider.overrideWith((ref) => repository),
            bookReadingDataSourceProvider.overrideWith(
              (ref, session) async => BookReadingDataSource.v2,
            ),
          ],
          child: MaterialApp(home: ReaderScreen(book: repository.book)),
        ),
      );

      await tester.pumpAndSettle();
      expect(repository.v2ProgressSaveCount, 0);

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -300),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();

      expect(repository.savedV2Progress, isNotEmpty);
      expect(repository.v2ProgressSaveCount, 1);
      expect(repository.savedV2Progress.last.documentIndex, 0);
      expect(repository.savedV2Progress.last.documentProgress, greaterThan(0));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    },
  );

  testWidgets('keeps legacy reading UI for legacy reader sessions', (
    tester,
  ) async {
    final repository = _FakeReaderRepository(
      book: _book(
        'book-legacy',
        navigationRebuildState: NavigationRebuildState.legacyPending,
      ).copyWith(totalChapters: 99),
      chapters: [
        _chapter('book-legacy', 0, 'Legacy Chapter 1'),
        _chapter('book-legacy', 1, 'Legacy Chapter 2'),
      ],
      documents: [_document('book-legacy', 0, 'Document 1', paragraphCount: 6)],
      tocItems: [
        _tocItem('book-legacy', 0, title: 'Intro', targetDocumentIndex: 0),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWith((ref) => repository),
          bookReadingDataSourceProvider.overrideWith(
            (ref, session) async => BookReadingDataSource.legacy,
          ),
        ],
        child: MaterialApp(home: ReaderScreen(book: repository.book)),
      ),
    );

    await tester.pumpAndSettle();

    expect(repository.chapterReadCount, greaterThan(0));
    expect(repository.documentReadCount, 0);
    expect(repository.v2ProgressReadCount, 0);
    expect(repository.v2ProgressSaveCount, 0);
    expect(find.text('Legacy Chapter 1'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();

    expect(repository.v2ProgressReadCount, 0);
    expect(repository.v2ProgressSaveCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();

    expect(find.text('Legacy fallback mode'), findsOneWidget);
    expect(
      find.text(
        'Continuous reading stays available in this session while document navigation is unavailable.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Navigation unavailable'), findsOneWidget);
    expect(
      find.text(
        'This session is using legacy fallback content. Reopen the book after a successful rebuild to use document navigation.',
      ),
      findsOneWidget,
    );
    expect(find.text('2 legacy content items'), findsOneWidget);
    expect(find.text('Table of Contents'), findsNothing);
  });
}

class _FakeReaderRepository implements BookRepository {
  _FakeReaderRepository({
    required this.book,
    required this.chapters,
    required this.documents,
    required this.tocItems,
    this.initialProgress,
  }) : v2Progress = initialProgress;

  final Book book;
  final List<Chapter> chapters;
  final List<ReaderDocument> documents;
  final List<TocItem> tocItems;
  final ReadingProgressV2? initialProgress;
  ReadingProgressV2? v2Progress;

  int chapterReadCount = 0;
  int documentReadCount = 0;
  int tocReadCount = 0;
  int updateLastReadCount = 0;
  int v2ProgressReadCount = 0;
  int v2ProgressSaveCount = 0;
  final List<ReadingProgressV2> savedV2Progress = [];

  @override
  Future<List<Chapter>> getChaptersByBookId(String bookId) async {
    chapterReadCount += 1;
    return chapters;
  }

  @override
  Future<List<ReaderDocument>> getReaderDocumentsByBookId(String bookId) async {
    documentReadCount += 1;
    return documents;
  }

  @override
  Future<List<TocItem>> getTocItemsByBookId(String bookId) async {
    tocReadCount += 1;
    return tocItems;
  }

  @override
  Future<void> updateLastReadAt(String bookId, DateTime time) async {
    updateLastReadCount += 1;
  }

  @override
  Future<Book?> getBookById(String id) async => book.id == id ? book : null;

  @override
  Future<BookReadingDataSource> getBookReadingDataSource(String bookId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Book>> getAllBooks() async {
    throw UnimplementedError();
  }

  @override
  Future<Chapter?> getChapter(String bookId, int index) async {
    throw UnimplementedError();
  }

  @override
  Future<ReadingProgress?> getReadingProgress(String bookId) async {
    throw UnimplementedError();
  }

  @override
  Future<ReadingProgressV2?> getReadingProgressV2(String bookId) async {
    v2ProgressReadCount += 1;
    return v2Progress;
  }

  @override
  Future<void> importBookWithNavigationDataV2Ready({
    required Book book,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> insertBook(Book book) async {
    throw UnimplementedError();
  }

  @override
  Future<void> insertChapter(Chapter chapter) async {
    throw UnimplementedError();
  }

  @override
  Future<void> insertChapters(List<Chapter> chapters) async {
    throw UnimplementedError();
  }

  @override
  Future<void> markNavigationRebuildInProgress(String bookId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> resetNavigationDataToLegacy(
    String bookId, {
    required NavigationRebuildState rebuildState,
    DateTime? failedAt,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> saveNavigationDataV2Ready({
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> saveReadingProgress(ReadingProgress progress) async {
    throw UnimplementedError();
  }

  @override
  Future<void> saveReadingProgressV2(ReadingProgressV2 progress) async {
    v2ProgressSaveCount += 1;
    savedV2Progress.add(progress);
    v2Progress = progress;
  }

  @override
  Future<void> updateBook(Book book) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBook(String id) async {
    throw UnimplementedError();
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
    totalChapters: 2,
    addedAt: DateTime.utc(2026, 3, 22),
    navigationDataVersion: navigationDataVersion,
    navigationRebuildState: navigationRebuildState,
  );
}

Chapter _chapter(String bookId, int index, String title) {
  return Chapter(
    id: '$bookId:chapter:$index',
    bookId: bookId,
    index: index,
    title: title,
    content: '<html><body><p>$title body</p></body></html>',
  );
}

ReaderDocument _document(
  String bookId,
  int index,
  String title, {
  required int paragraphCount,
}) {
  final paragraphs = List.generate(
    paragraphCount,
    (paragraphIndex) =>
        '<p>$title paragraph ${paragraphIndex + 1} ${'content ' * 12}</p>',
  ).join();

  return ReaderDocument(
    id: '$bookId:document:$index',
    bookId: bookId,
    documentIndex: index,
    fileName: 'OPS/Text/ch${index + 1}.xhtml',
    title: title,
    htmlContent: '<html><body>$paragraphs</body></html>',
  );
}

TocItem _tocItem(
  String bookId,
  int order, {
  required String title,
  required int targetDocumentIndex,
  String? anchor,
}) {
  return TocItem(
    id: '$bookId:toc:$order',
    bookId: bookId,
    title: title,
    order: order,
    depth: 0,
    parentId: null,
    fileName: 'OPS/Text/ch${targetDocumentIndex + 1}.xhtml',
    anchor: anchor,
    targetDocumentIndex: targetDocumentIndex,
  );
}
