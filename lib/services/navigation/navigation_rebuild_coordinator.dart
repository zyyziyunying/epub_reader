import '../../domain/entities/book_reading_data_source.dart';
import '../../domain/entities/navigation_rebuild_state.dart';
import '../../domain/entities/reader_document.dart';
import '../../domain/entities/reading_progress_v2.dart';
import '../../domain/repositories/book_repository.dart';
import '../epub_parser_service.dart';

class NavigationRebuildCoordinator {
  NavigationRebuildCoordinator({
    required BookRepository repository,
    required EpubParserService parserService,
  }) : _repository = repository,
       _parserService = parserService;

  final BookRepository _repository;
  final EpubParserService _parserService;
  final Map<String, Future<void>> _activeRebuilds = {};

  Future<BookReadingDataSource> resolveDataSourceForSession(
    String bookId,
  ) async {
    final book = await _repository.getBookById(bookId);
    if (book == null) {
      return BookReadingDataSource.legacy;
    }
    if (book.usesV2Navigation) {
      return BookReadingDataSource.v2;
    }

    if (book.navigationRebuildState == NavigationRebuildState.rebuilding &&
        !_activeRebuilds.containsKey(bookId)) {
      await _repository.resetNavigationDataToLegacy(
        bookId,
        rebuildState: NavigationRebuildState.legacyPending,
      );
    }

    _activeRebuilds.putIfAbsent(bookId, () {
      final future = _rebuild(bookId);
      future.whenComplete(() => _activeRebuilds.remove(bookId));
      return future;
    });

    // Phase 1 keeps the current reader session on legacy and only switches
    // future sessions after a successful rebuild commits ready V2 data.
    return BookReadingDataSource.legacy;
  }

  Future<void> waitForActiveRebuild(String bookId) async {
    await _activeRebuilds[bookId];
  }

  Future<void> _rebuild(String bookId) async {
    final book = await _repository.getBookById(bookId);
    if (book == null || book.usesV2Navigation) {
      return;
    }

    try {
      await _repository.markNavigationRebuildInProgress(bookId);
      final navigationData = await _parserService.buildNavigationFromFile(
        book.filePath,
        bookId: bookId,
      );
      final initialProgress = await _mapLegacyProgressToV2(
        bookId: bookId,
        documents: navigationData.documents,
      );
      await _repository.saveNavigationDataV2Ready(
        bookId: bookId,
        documents: navigationData.documents,
        tocItems: navigationData.tocItems,
        initialProgress: initialProgress,
      );
    } catch (_) {
      try {
        await _repository.resetNavigationDataToLegacy(
          bookId,
          rebuildState: NavigationRebuildState.failed,
        );
      } catch (_) {}
    }
  }

  Future<ReadingProgressV2?> _mapLegacyProgressToV2({
    required String bookId,
    required List<ReaderDocument> documents,
  }) async {
    final legacyProgress = await _repository.getReadingProgress(bookId);
    if (legacyProgress == null) {
      return null;
    }

    final legacyChapter = await _repository.getChapter(
      bookId,
      legacyProgress.chapterIndex,
    );
    if (legacyChapter == null) {
      return null;
    }

    final matches = documents
        .where((document) => document.htmlContent == legacyChapter.content)
        .toList();
    if (matches.length != 1) {
      return null;
    }

    return ReadingProgressV2(
      bookId: bookId,
      documentIndex: matches.single.documentIndex,
      documentProgress: legacyProgress.scrollPosition
          .clamp(0.0, 1.0)
          .toDouble(),
      tocItemId: null,
      anchor: null,
      updatedAt: legacyProgress.updatedAt,
    );
  }
}
