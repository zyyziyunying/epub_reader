import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/router_core.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../providers/book_providers.dart';
import 'widgets/chapter_content.dart';
import 'widgets/reader_drawer.dart';
import 'widgets/reader_settings_sheet.dart';

// 当前书籍的章节列表
final chaptersProvider = FutureProvider.family<List<Chapter>, String>((
  ref,
  bookId,
) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getChaptersByBookId(bookId);
});

// 当前阅读进度
final currentProgressProvider = StateProvider.family<ReadingProgress, String>((
  ref,
  bookId,
) {
  return ReadingProgress.initial(bookId);
});

// 加载阅读进度
final loadProgressProvider = FutureProvider.family<ReadingProgress?, String>((
  ref,
  bookId,
) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getReadingProgress(bookId);
});

class ReaderScreen extends ConsumerStatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late ScrollController _scrollController;
  bool _showControls = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentChapterIndex = 0;
  bool _isLoadingProgress = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final savedProgress = await ref.read(
      loadProgressProvider(widget.book.id).future,
    );
    if (savedProgress != null) {
      _currentChapterIndex = savedProgress.chapterIndex;
      ref.read(currentProgressProvider(widget.book.id).notifier).state =
          savedProgress;
    }
    setState(() => _isLoadingProgress = false);

    // 等待章节加载完成后恢复滚动位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (savedProgress != null && _scrollController.hasClients) {
        _scrollToSavedPosition(savedProgress);
      }
    });
  }

  void _scrollToSavedPosition(ReadingProgress progress) {
    // 等待布局完成后再滚动
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetScroll = maxScroll * progress.scrollPosition;

      _scrollController.jumpTo(targetScroll.clamp(0.0, maxScroll));
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final scrollProgress = position.pixels / position.maxScrollExtent;

    // 保存滚动进度
    _saveProgress(_currentChapterIndex, scrollProgress.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.book.id));
    final settings = ref.watch(readingSettingsProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: settings.backgroundColor,
      drawer: chaptersAsync.when(
        data: (chapters) => ReaderDrawer(
          book: widget.book,
          chapters: chapters,
          currentIndex: _currentChapterIndex,
          onChapterSelected: (index) {
            _jumpToChapter(index, chapters);
            NavigatorManager.pop();
          },
        ),
        loading: () =>
            const Drawer(child: Center(child: CircularProgressIndicator())),
        error: (_, _) =>
            const Drawer(child: Center(child: Text('Error loading chapters'))),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // 内容区域 - 连续滚动所有章节
            chaptersAsync.when(
              data: (chapters) {
                if (chapters.isEmpty) {
                  return const Center(child: Text('No chapters found'));
                }
                if (_isLoadingProgress) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      for (int i = 0; i < chapters.length; i++)
                        ChapterContent(
                          key: ValueKey('chapter_$i'),
                          chapter: chapters[i],
                          settings: settings,
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),

            // 顶部控制栏
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(context),
              ),

            // 底部控制栏
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(context, chaptersAsync),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => NavigatorManager.pop(),
          ),
          title: Text(
            widget.book.title,
            style: const TextStyle(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    AsyncValue<List<Chapter>> chaptersAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 上一章
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: _currentChapterIndex > 0
                    ? () => chaptersAsync.whenData((chapters) {
                        _jumpToChapter(_currentChapterIndex - 1, chapters);
                      })
                    : null,
              ),

              // 进度条和章节信息
              Expanded(
                child: chaptersAsync.when(
                  data: (chapters) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Slider(
                        value: _currentChapterIndex.toDouble(),
                        min: 0,
                        max: (chapters.length - 1).toDouble(),
                        divisions: chapters.length > 1
                            ? chapters.length - 1
                            : 1,
                        onChanged: (value) {
                          _jumpToChapter(value.toInt(), chapters);
                        },
                      ),
                      Text(
                        '${_currentChapterIndex + 1} / ${chapters.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),
              ),

              // 下一章
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: chaptersAsync.when(
                  data: (chapters) =>
                      _currentChapterIndex < chapters.length - 1
                      ? () => _jumpToChapter(_currentChapterIndex + 1, chapters)
                      : null,
                  loading: () => null,
                  error: (_, _) => null,
                ),
              ),

              // 设置
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => _showSettings(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _jumpToChapter(int index, List<Chapter> chapters) {
    if (index < 0 || index >= chapters.length) return;

    setState(() => _currentChapterIndex = index);

    // 计算目标章节的位置
    // 需要等待下一帧以确保布局完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // 简单估算：假设每个章节高度相似，滚动到对应位置
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetPosition = (maxScroll / chapters.length) * index;

      _scrollController.animateTo(
        targetPosition.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });

    _saveProgress(index, 0.0);
  }

  Future<void> _saveProgress(int chapterIndex, double scrollPosition) async {
    final progress = ReadingProgress(
      bookId: widget.book.id,
      chapterIndex: chapterIndex,
      scrollPosition: scrollPosition,
      updatedAt: DateTime.now(),
    );

    ref.read(currentProgressProvider(widget.book.id).notifier).state = progress;

    final repository = ref.read(bookRepositoryProvider);
    await repository.saveReadingProgress(progress);
    await repository.updateLastReadAt(widget.book.id, DateTime.now());
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReaderSettingsSheet(),
    );
  }
}
