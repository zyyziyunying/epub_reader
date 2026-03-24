import '../../domain/entities/book_reading_data_source.dart';
import '../../domain/entities/navigation_rebuild_state.dart';
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
  final Map<String, Future<void>> _activeTasks = {};

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
        !_activeTasks.containsKey(bookId)) {
      await _repository.resetNavigationDataToLegacy(
        bookId,
        rebuildState: NavigationRebuildState.legacyPending,
      );
    }

    _runExclusive(bookId, () => _rebuild(bookId));

    // Phase 1 keeps the current reader session on legacy and only switches
    // future sessions after a successful rebuild commits ready V2 data.
    return BookReadingDataSource.legacy;
  }

  Future<void> refreshReadyNavigationData(String bookId) {
    return _runExclusive(bookId, () => _refreshReadyNavigationData(bookId));
  }

  Future<void> waitForActiveRebuild(String bookId) async {
    await _activeTasks[bookId];
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
      final initialProgress = await _repository
          .deriveLegacyRebuildInitialProgressV2(
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

  Future<void> _refreshReadyNavigationData(String bookId) async {
    final book = await _repository.getBookById(bookId);
    if (book == null) {
      throw StateError(
        'Book not found while refreshing ready V2 navigation: $bookId',
      );
    }
    if (!book.usesV2Navigation) {
      throw StateError(
        'refreshReadyNavigationData requires an existing ready V2 book: $bookId',
      );
    }
    final supportsReadyRefresh = await _repository
        .supportsReadyPreservingRefresh(bookId);
    if (!supportsReadyRefresh) {
      throw StateError(
        'refreshReadyNavigationData only supports ready V2-only books without persisted legacy fallback content: $bookId',
      );
    }

    final navigationData = await _parserService.buildNavigationFromFile(
      book.filePath,
      bookId: bookId,
    );
    await _repository.refreshNavigationDataV2Ready(
      bookId: bookId,
      documents: navigationData.documents,
      tocItems: navigationData.tocItems,
    );
  }

  Future<void> _runExclusive(String bookId, Future<void> Function() task) {
    final activeTask = _activeTasks[bookId];
    if (activeTask != null) {
      return activeTask;
    }

    late final Future<void> trackedTask;
    trackedTask = task().whenComplete(() {
      if (identical(_activeTasks[bookId], trackedTask)) {
        _activeTasks.remove(bookId);
      }
    });
    _activeTasks[bookId] = trackedTask;
    return trackedTask;
  }
}
