import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../domain/entities/book.dart';
import '../../../domain/entities/book_reading_data_source.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/document_nav_item.dart';
import '../../../domain/entities/reading_progress_v2.dart';
import '../../../domain/entities/reading_settings.dart';
import '../../../domain/repositories/book_repository.dart';
import '../../providers/book_providers.dart';
import 'legacy_fallback_status.dart';
import 'widgets/legacy_chapter_content.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_document_content.dart';
import 'widgets/reader_drawer.dart';
import 'widgets/reader_settings_sheet.dart';
import 'widgets/reader_top_bar.dart';

//TODO 拆分
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  late final ScrollController _legacyScrollController;
  late final ItemScrollController _documentScrollController;
  late final ScrollOffsetController _documentOffsetController;
  late final ItemPositionsListener _documentPositionsListener;
  late final BookRepository _bookRepository;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Object _readingSessionToken = Object();

  bool _showControls = false;
  int _currentDocumentIndex = 0;
  int _documentCount = 0;
  bool _initialV2ProgressResolved = false;
  bool _initialV2RestoreInFlight = false;
  Timer? _pendingV2ProgressSaveTimer;
  ReadingProgressV2? _pendingV2ProgressSave;
  ReadingProgressV2? _lastSavedV2Progress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bookRepository = ref.read(bookRepositoryProvider);
    _legacyScrollController = ScrollController();
    _documentScrollController = ItemScrollController();
    _documentOffsetController = ScrollOffsetController();
    _documentPositionsListener = ItemPositionsListener.create();
    _documentPositionsListener.itemPositions.addListener(
      _handleDocumentPositionsChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsReading();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingV2ProgressSaveTimer?.cancel();
    unawaited(_flushPendingV2ProgressSave());
    _documentPositionsListener.itemPositions.removeListener(
      _handleDocumentPositionsChanged,
    );
    _legacyScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushPendingV2ProgressSave());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    final dataSourceAsync = ref.watch(
      bookReadingDataSourceProvider((
        bookId: widget.book.id,
        sessionToken: _readingSessionToken,
      )),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: settings.backgroundColor,
      drawer: _buildDrawer(dataSourceAsync),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            _buildContent(dataSourceAsync, settings),
            if (_showControls) _buildTopBar(),
            if (_showControls) _buildBottomBar(dataSourceAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(AsyncValue<BookReadingDataSource> dataSourceAsync) {
    return dataSourceAsync.when(
      data: (dataSource) {
        if (!dataSource.usesV2) {
          final legacyFallbackStatus = _legacyFallbackStatus(
            ref.watch(legacyChaptersProvider(widget.book.id)),
          );
          return ReaderDrawer.legacy(
            book: widget.book,
            legacyFallbackStatus: legacyFallbackStatus,
          );
        }

        final navigationAsync = ref.watch(
          readerNavigationDataProvider(widget.book.id),
        );
        return navigationAsync.when(
          data: (navigationData) => ReaderDrawer.v2(
            book: widget.book,
            navItems: navigationData.navItems,
            currentDocumentIndex: _effectiveDocumentIndex(
              navigationData.documents.length,
            ),
            hasPhase2OnlyToc: navigationData.hasPhase2OnlyToc,
            onDocumentSelected: _handleDocumentSelected,
          ),
          loading: () => _buildLoadingDrawer(),
          error: (_, _) => _buildMessageDrawer('Error loading navigation'),
        );
      },
      loading: _buildLoadingDrawer,
      error: (_, _) => _buildMessageDrawer('Error resolving reader session'),
    );
  }

  Widget _buildContent(
    AsyncValue<BookReadingDataSource> dataSourceAsync,
    ReadingSettings settings,
  ) {
    return dataSourceAsync.when(
      data: (dataSource) => dataSource.usesV2
          ? _buildV2Content(settings)
          : _buildLegacyContent(settings),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildLegacyContent(ReadingSettings settings) {
    _documentCount = 0;

    final legacyContentAsync = ref.watch(
      legacyChaptersProvider(widget.book.id),
    );
    final legacyFallbackStatus = _legacyFallbackStatus(legacyContentAsync);
    return legacyContentAsync.when(
      data: (legacyContent) {
        if (legacyContent.isEmpty) {
          return _buildLegacyFallbackMessageContent(legacyFallbackStatus);
        }

        return ListView.builder(
          controller: _legacyScrollController,
          itemCount: legacyContent.length,
          itemBuilder: (context, index) {
            return LegacyChapterContent(
              legacyChapter: legacyContent[index],
              settings: settings,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _buildLegacyFallbackMessageContent(legacyFallbackStatus),
    );
  }

  Widget _buildV2Content(ReadingSettings settings) {
    final navigationAsync = ref.watch(
      readerNavigationDataProvider(widget.book.id),
    );
    final initialProgressAsync = ref.watch(
      readerInitialProgressV2Provider((
        bookId: widget.book.id,
        sessionToken: _readingSessionToken,
      )),
    );
    return navigationAsync.when(
      data: (navigationData) => initialProgressAsync.when(
        data: (initialProgress) {
          final documents = navigationData.documents;
          _documentCount = documents.length;
          final initialIndex = _initialDocumentIndex(
            initialProgress,
            documents.length,
          );
          _syncCurrentDocumentIndexIfNeeded(
            documentCount: documents.length,
            preferredIndex: initialIndex,
          );
          _restoreInitialV2ProgressIfNeeded(
            initialProgress: initialProgress,
            documentCount: documents.length,
          );

          if (documents.isEmpty) {
            return const Center(child: Text('No documents found'));
          }

          return ScrollablePositionedList.builder(
            initialScrollIndex: initialIndex,
            itemCount: documents.length,
            itemScrollController: _documentScrollController,
            itemPositionsListener: _documentPositionsListener,
            scrollOffsetController: _documentOffsetController,
            itemBuilder: (context, index) {
              return ReaderDocumentContent(
                document: documents[index],
                settings: settings,
                showDivider: index < documents.length - 1,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ReaderTopBar(
        book: widget.book,
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    );
  }

  Widget _buildBottomBar(AsyncValue<BookReadingDataSource> dataSourceAsync) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: dataSourceAsync.when(
        data: (dataSource) {
          if (dataSource.usesV2) {
            return _buildV2BottomBar();
          }

          final legacyFallbackStatus = _legacyFallbackStatus(
            ref.watch(legacyChaptersProvider(widget.book.id)),
          );

          return ReaderBottomBar(
            title: legacyFallbackStatus.bottomBarTitle,
            subtitle: legacyFallbackStatus.bottomBarSubtitle,
            onSettingsPressed: _showSettings,
          );
        },
        loading: () => ReaderBottomBar(
          title: 'Loading reader',
          subtitle: 'Resolving reading data source...',
          onSettingsPressed: _showSettings,
        ),
        error: (_, _) => ReaderBottomBar(
          title: 'Legacy fallback mode',
          subtitle: 'Falling back to legacy content for this session.',
          onSettingsPressed: _showSettings,
        ),
      ),
    );
  }

  Widget _buildV2BottomBar() {
    final navigationAsync = ref.watch(
      readerNavigationDataProvider(widget.book.id),
    );
    return navigationAsync.when(
      data: (navigationData) {
        final currentIndex = _effectiveDocumentIndex(
          navigationData.documents.length,
        );
        final currentNavItem = _currentNavItem(
          navigationData.navItems,
          currentIndex,
        );

        return ReaderBottomBar(
          title: currentNavItem?.title ?? widget.book.title,
          subtitle:
              '${currentIndex + 1} / ${navigationData.documents.length} documents',
          onSettingsPressed: _showSettings,
          onPreviousPressed: currentIndex > 0
              ? () => _scrollToDocument(currentIndex - 1)
              : null,
          onNextPressed: currentIndex < navigationData.documents.length - 1
              ? () => _scrollToDocument(currentIndex + 1)
              : null,
        );
      },
      loading: () => ReaderBottomBar(
        title: 'Loading navigation',
        subtitle: 'Preparing document navigation...',
        onSettingsPressed: _showSettings,
      ),
      error: (_, _) => ReaderBottomBar(
        title: 'Navigation unavailable',
        subtitle: 'Failed to load document navigation.',
        onSettingsPressed: _showSettings,
      ),
    );
  }

  LegacyFallbackStatus _legacyFallbackStatus(
    AsyncValue<List<Chapter>> legacyContentAsync,
  ) {
    return legacyContentAsync.when(
      data: (legacyContent) => legacyContent.isEmpty
          ? const LegacyFallbackStatus.empty()
          : LegacyFallbackStatus.available(legacyContent.length),
      loading: () => const LegacyFallbackStatus.loading(),
      error: (error, _) => LegacyFallbackStatus.error(error),
    );
  }

  Widget _buildLegacyFallbackMessageContent(LegacyFallbackStatus status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status.panelTitle, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(status.panelMessage, textAlign: TextAlign.center),
            if (status.diagnosticDetails case final details?) ...[
              const SizedBox(height: 12),
              Text(details, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Drawer _buildLoadingDrawer() {
    return const Drawer(child: Center(child: CircularProgressIndicator()));
  }

  Drawer _buildMessageDrawer(String message) {
    return Drawer(child: Center(child: Text(message)));
  }

  int _effectiveDocumentIndex(int documentCount) {
    if (documentCount <= 0) {
      return 0;
    }
    return _clampDocumentIndex(_currentDocumentIndex, documentCount);
  }

  int _clampDocumentIndex(int documentIndex, int documentCount) {
    if (documentCount <= 0) {
      return 0;
    }
    if (documentIndex < 0) {
      return 0;
    }
    if (documentIndex >= documentCount) {
      return documentCount - 1;
    }
    return documentIndex;
  }

  int _initialDocumentIndex(
    ReadingProgressV2? initialProgress,
    int documentCount,
  ) {
    if (initialProgress == null) {
      return _effectiveDocumentIndex(documentCount);
    }
    return _clampDocumentIndex(initialProgress.documentIndex, documentCount);
  }

  DocumentNavItem? _currentNavItem(
    List<DocumentNavItem> navItems,
    int currentIndex,
  ) {
    for (final navItem in navItems) {
      if (navItem.documentIndex == currentIndex) {
        return navItem;
      }
    }
    return null;
  }

  void _syncCurrentDocumentIndexIfNeeded({
    required int documentCount,
    int? preferredIndex,
  }) {
    final nextIndex = preferredIndex == null
        ? _effectiveDocumentIndex(documentCount)
        : _clampDocumentIndex(preferredIndex, documentCount);
    if (nextIndex == _currentDocumentIndex) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentDocumentIndex = nextIndex;
      });
    });
  }

  List<ItemPosition> _visibleDocumentPositions() {
    return _documentPositionsListener.itemPositions.value
        .where((position) => position.itemTrailingEdge > 0)
        .toList()
      ..sort(
        (left, right) => left.itemLeadingEdge.compareTo(right.itemLeadingEdge),
      );
  }

  ItemPosition? _visibleDocumentPositionForIndex(int documentIndex) {
    for (final position in _visibleDocumentPositions()) {
      if (position.index == documentIndex) {
        return position;
      }
    }
    return null;
  }

  double _documentProgressFromPosition(ItemPosition position) {
    final extentFraction = position.itemTrailingEdge - position.itemLeadingEdge;
    final scrollableFraction = extentFraction - 1;
    if (scrollableFraction <= 0) {
      return 0;
    }

    final consumedFraction = (-position.itemLeadingEdge).clamp(
      0.0,
      scrollableFraction,
    );
    return (consumedFraction / scrollableFraction).clamp(0.0, 1.0).toDouble();
  }

  double _restoreOffsetForProgress(
    ItemPosition position,
    double documentProgress,
  ) {
    final extentFraction = position.itemTrailingEdge - position.itemLeadingEdge;
    final scrollableFraction = extentFraction - 1;
    if (scrollableFraction <= 0) {
      return 0;
    }

    final viewportExtent = MediaQuery.sizeOf(context).height;
    if (viewportExtent <= 0) {
      return 0;
    }

    return viewportExtent *
        scrollableFraction *
        documentProgress.clamp(0.0, 1.0).toDouble();
  }

  ReadingProgressV2? _currentV2Progress() {
    if (_documentCount <= 0) {
      return null;
    }

    final visiblePositions = _visibleDocumentPositions();
    if (visiblePositions.isEmpty) {
      return null;
    }

    final currentPosition = visiblePositions.first;
    return ReadingProgressV2(
      bookId: widget.book.id,
      documentIndex: currentPosition.index,
      documentProgress: _documentProgressFromPosition(currentPosition),
      tocItemId: null,
      anchor: null,
      updatedAt: DateTime.now(),
    );
  }

  bool _sameV2Progress(ReadingProgressV2 left, ReadingProgressV2 right) {
    return left.bookId == right.bookId &&
        left.documentIndex == right.documentIndex &&
        (left.documentProgress - right.documentProgress).abs() < 0.001 &&
        left.tocItemId == right.tocItemId &&
        left.anchor == right.anchor;
  }

  void _scheduleV2ProgressSave(ReadingProgressV2 progress) {
    if (!_initialV2ProgressResolved || _initialV2RestoreInFlight) {
      return;
    }
    if (_lastSavedV2Progress != null &&
        _sameV2Progress(progress, _lastSavedV2Progress!)) {
      return;
    }

    _pendingV2ProgressSave = progress;
    _pendingV2ProgressSaveTimer?.cancel();
    _pendingV2ProgressSaveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_flushPendingV2ProgressSave());
    });
  }

  Future<void> _flushPendingV2ProgressSave() async {
    _pendingV2ProgressSaveTimer?.cancel();
    _pendingV2ProgressSaveTimer = null;

    if (!_initialV2ProgressResolved || _initialV2RestoreInFlight) {
      return;
    }

    final currentProgress = _currentV2Progress();
    if (currentProgress != null) {
      _pendingV2ProgressSave = currentProgress;
    }

    final progress = _pendingV2ProgressSave;
    if (progress == null) {
      return;
    }
    if (_lastSavedV2Progress != null &&
        _sameV2Progress(progress, _lastSavedV2Progress!)) {
      _pendingV2ProgressSave = null;
      return;
    }

    _pendingV2ProgressSave = null;
    try {
      await _bookRepository.saveReadingProgressV2(progress);
      _lastSavedV2Progress = progress;
    } catch (_) {}
  }

  void _restoreInitialV2ProgressIfNeeded({
    required ReadingProgressV2? initialProgress,
    required int documentCount,
  }) {
    if (_initialV2ProgressResolved || _initialV2RestoreInFlight) {
      return;
    }
    if (documentCount <= 0) {
      _initialV2ProgressResolved = true;
      return;
    }

    final initialIndex = _initialDocumentIndex(initialProgress, documentCount);
    final normalizedProgress = initialProgress == null
        ? null
        : ReadingProgressV2(
            bookId: initialProgress.bookId,
            documentIndex: initialIndex,
            documentProgress: initialProgress.documentProgress
                .clamp(0.0, 1.0)
                .toDouble(),
            tocItemId: initialProgress.tocItemId,
            anchor: initialProgress.anchor,
            updatedAt: initialProgress.updatedAt,
          );

    _initialV2RestoreInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          return;
        }

        if (normalizedProgress == null ||
            normalizedProgress.documentProgress <= 0 ||
            !_documentScrollController.isAttached) {
          return;
        }

        await WidgetsBinding.instance.endOfFrame;
        final position = _visibleDocumentPositionForIndex(initialIndex);
        if (position == null) {
          return;
        }

        final offset = _restoreOffsetForProgress(
          position,
          normalizedProgress.documentProgress,
        );
        if (offset <= 0.5) {
          return;
        }

        await _documentOffsetController.animateScroll(
          offset: offset,
          duration: const Duration(milliseconds: 1),
          curve: Curves.linear,
        );
      } finally {
        _initialV2RestoreInFlight = false;
        _initialV2ProgressResolved = true;
        if (normalizedProgress != null) {
          _lastSavedV2Progress = normalizedProgress;
        }
      }
    });
  }

  void _handleDocumentPositionsChanged() {
    if (!mounted || _documentCount <= 0) {
      return;
    }

    final visiblePositions = _visibleDocumentPositions();
    if (visiblePositions.isEmpty) {
      return;
    }

    final currentPosition = visiblePositions.first;
    final nextIndex = currentPosition.index;
    if (nextIndex != _currentDocumentIndex) {
      setState(() {
        _currentDocumentIndex = nextIndex;
      });
    }

    final progress = _currentV2Progress();
    if (progress != null) {
      _scheduleV2ProgressSave(progress);
    }
  }

  Future<void> _handleDocumentSelected(int documentIndex) async {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDocument(documentIndex);
    });
  }

  Future<void> _scrollToDocument(int documentIndex) async {
    if (documentIndex < 0 || documentIndex >= _documentCount) {
      return;
    }

    if (mounted && _currentDocumentIndex != documentIndex) {
      setState(() {
        _currentDocumentIndex = documentIndex;
      });
    }

    if (!_documentScrollController.isAttached) {
      return;
    }

    await _documentScrollController.scrollTo(
      index: documentIndex,
      alignment: 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _markAsReading() async {
    await _bookRepository.updateLastReadAt(widget.book.id, DateTime.now());
    if (!mounted) {
      return;
    }
    ref.invalidate(libraryBooksProvider);
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReaderSettingsSheet(),
    );
  }
}
