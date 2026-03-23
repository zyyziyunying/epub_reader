import 'dart:typed_data';

import 'package:epub_reader/domain/entities/book.dart';
import 'package:epub_reader/domain/entities/book_reading_data_source.dart';
import 'package:epub_reader/domain/entities/chapter.dart';
import 'package:epub_reader/domain/entities/document_nav_item.dart';
import 'package:epub_reader/domain/entities/navigation_rebuild_state.dart';
import 'package:epub_reader/domain/entities/reading_progress.dart';
import 'package:epub_reader/domain/entities/reading_progress_v2.dart';
import 'package:epub_reader/domain/entities/reader_document.dart';
import 'package:epub_reader/domain/entities/toc_item.dart';
import 'package:epub_reader/domain/repositories/book_repository.dart';
import 'package:epub_reader/presentation/providers/book_providers.dart';
import 'package:epub_reader/services/epub_parser_service.dart';
import 'package:epub_reader/services/file_service.dart';
import 'package:epub_reader/services/navigation/navigation_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'importBookProvider stores totalChapters from V2 documents for ready imports',
    () async {
      FilePicker.platform = _FakeFilePicker();
      final parserService = _FakeEpubParserService();
      final fileService = _FakeFileService();
      final repository = _CapturingBookRepository();
      final container = ProviderContainer(
        overrides: [
          epubParserServiceProvider.overrideWith((ref) => parserService),
          fileServiceProvider.overrideWith((ref) => fileService),
          bookRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final importBook = container.read(importBookProvider);
      final importedBook = await importBook();

      expect(importedBook, isNotNull);
      expect(importedBook!.navigationDataVersion, Book.v2NavigationDataVersion);
      expect(importedBook.navigationRebuildState, NavigationRebuildState.ready);
      expect(importedBook.totalChapters, 1);

      final persistedBook = repository.importedBook;
      expect(persistedBook, isNotNull);
      expect(persistedBook!.totalChapters, 1);
      expect(repository.importedDocuments, hasLength(1));
      expect(repository.importedTocItems, hasLength(2));
    },
  );
}

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult([
      PlatformFile(
        name: 'sample.epub',
        size: 0,
        path: 'D:/fixtures/sample.epub',
      ),
    ]);
  }
}

class _FakeEpubParserService extends EpubParserService {
  @override
  Future<ParsedEpub> parseFromFile(String filePath) async {
    return ParsedEpub(
      title: 'Sample Book',
      author: 'Sample Author',
      coverImage: Uint8List(0),
      chapters: [
        ParsedChapter(
          index: 0,
          title: 'Legacy 1',
          htmlContent: '<p>legacy 1</p>',
          fileName: 'OPS/Text/legacy-1.xhtml',
        ),
        ParsedChapter(
          index: 1,
          title: 'Legacy 2',
          htmlContent: '<p>legacy 2</p>',
          fileName: 'OPS/Text/legacy-2.xhtml',
        ),
      ],
    );
  }

  @override
  Future<NavigationBuildResult> buildNavigationFromFile(
    String filePath, {
    required String bookId,
  }) async {
    final documents = [
      ReaderDocument(
        id: '$bookId:document:0',
        bookId: bookId,
        documentIndex: 0,
        fileName: 'OPS/Text/doc-1.xhtml',
        title: 'Document 1',
        htmlContent: '<html><body><p>doc 1</p></body></html>',
      ),
    ];
    final tocItems = [
      TocItem(
        id: '$bookId:toc:0',
        bookId: bookId,
        title: 'Start',
        order: 0,
        depth: 0,
        parentId: null,
        fileName: 'OPS/Text/doc-1.xhtml',
        anchor: null,
        targetDocumentIndex: 0,
      ),
      TocItem(
        id: '$bookId:toc:1',
        bookId: bookId,
        title: 'Anchor',
        order: 1,
        depth: 1,
        parentId: '$bookId:toc:0',
        fileName: 'OPS/Text/doc-1.xhtml',
        anchor: 'part-1',
        targetDocumentIndex: 0,
      ),
    ];

    return NavigationBuildResult(
      documents: documents,
      tocItems: tocItems,
      navItems: [
        DocumentNavItem(
          documentId: '$bookId:document:0',
          documentIndex: 0,
          fileName: 'OPS/Text/doc-1.xhtml',
          title: 'Start',
        ),
      ],
      hasPhase2OnlyToc: true,
      usedSpineOrder: true,
    );
  }
}

class _FakeFileService extends FileService {
  @override
  Future<String> copyEpubToAppDirectory(String sourcePath) async {
    return 'D:/app/books/imported.epub';
  }

  @override
  Future<String?> saveCoverImage(Uint8List imageBytes, String bookId) async {
    return 'D:/app/covers/$bookId.jpg';
  }

  @override
  Future<void> deleteBookFiles(String? filePath, String? coverPath) async {}
}

class _CapturingBookRepository implements BookRepository {
  Book? importedBook;
  List<ReaderDocument> importedDocuments = const [];
  List<TocItem> importedTocItems = const [];

  @override
  Future<void> importBookWithNavigationDataV2Ready({
    required Book book,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) async {
    importedBook = book;
    importedDocuments = documents;
    importedTocItems = tocItems;
  }

  @override
  Future<List<Book>> getAllBooks() async => const [];

  @override
  Future<Book?> getBookById(String id) async => null;

  @override
  Future<void> insertBook(Book book) async => throw UnimplementedError();

  @override
  Future<void> updateBook(Book book) async => throw UnimplementedError();

  @override
  Future<void> deleteBook(String id) async => throw UnimplementedError();

  @override
  Future<List<Chapter>> getChaptersByBookId(String bookId) async =>
      throw UnimplementedError();

  @override
  Future<Chapter?> getChapter(String bookId, int index) async =>
      throw UnimplementedError();

  @override
  Future<void> insertChapter(Chapter chapter) async =>
      throw UnimplementedError();

  @override
  Future<void> insertChapters(List<Chapter> chapters) async =>
      throw UnimplementedError();

  @override
  Future<ReadingProgress?> getReadingProgress(String bookId) async =>
      throw UnimplementedError();

  @override
  Future<void> saveReadingProgress(ReadingProgress progress) async =>
      throw UnimplementedError();

  @override
  Future<BookReadingDataSource> getBookReadingDataSource(String bookId) async =>
      throw UnimplementedError();

  @override
  Future<List<ReaderDocument>> getReaderDocumentsByBookId(
    String bookId,
  ) async => throw UnimplementedError();

  @override
  Future<List<TocItem>> getTocItemsByBookId(String bookId) async =>
      throw UnimplementedError();

  @override
  Future<ReadingProgressV2?> getReadingProgressV2(String bookId) async =>
      throw UnimplementedError();

  @override
  Future<void> saveReadingProgressV2(ReadingProgressV2 progress) async =>
      throw UnimplementedError();

  @override
  Future<void> saveNavigationDataV2Ready({
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  }) async => throw UnimplementedError();

  @override
  Future<void> markNavigationRebuildInProgress(String bookId) async =>
      throw UnimplementedError();

  @override
  Future<void> resetNavigationDataToLegacy(
    String bookId, {
    required NavigationRebuildState rebuildState,
    DateTime? failedAt,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateLastReadAt(String bookId, DateTime time) async =>
      throw UnimplementedError();
}
