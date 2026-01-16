import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../providers/book_providers.dart';
import 'widgets/chapter_content.dart';
import 'widgets/reader_drawer.dart';
import 'widgets/reader_settings_sheet.dart';

// 当前书籍的章节列表
final chaptersProvider = FutureProvider.family<List<Chapter>, String>((ref, bookId) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getChaptersByBookId(bookId);
});

// 当前阅读进度
final currentProgressProvider = StateProvider.family<ReadingProgress, String>((ref, bookId) {
  return ReadingProgress.initial(bookId);
});

// 加载阅读进度
final loadProgressProvider = FutureProvider.family<ReadingProgress?, String>((ref, bookId) async {
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
  late PageController _pageController;
  bool _showControls = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final savedProgress = await ref.read(loadProgressProvider(widget.book.id).future);
    if (savedProgress != null) {
      ref.read(currentProgressProvider(widget.book.id).notifier).state = savedProgress;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(savedProgress.chapterIndex);
      } else {
        _pageController = PageController(initialPage: savedProgress.chapterIndex);
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.book.id));
    final settings = ref.watch(readingSettingsProvider);
    final progress = ref.watch(currentProgressProvider(widget.book.id));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: settings.backgroundColor,
      drawer: chaptersAsync.when(
        data: (chapters) => ReaderDrawer(
          book: widget.book,
          chapters: chapters,
          currentIndex: progress.chapterIndex,
          onChapterSelected: (index) {
            _pageController.jumpToPage(index);
            Navigator.of(context).pop();
          },
        ),
        loading: () => const Drawer(child: Center(child: CircularProgressIndicator())),
        error: (_, __) => const Drawer(child: Center(child: Text('Error loading chapters'))),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // 内容区域
            chaptersAsync.when(
              data: (chapters) {
                if (chapters.isEmpty) {
                  return const Center(child: Text('No chapters found'));
                }
                return PageView.builder(
                  controller: _pageController,
                  itemCount: chapters.length,
                  onPageChanged: (index) => _onPageChanged(index),
                  itemBuilder: (context, index) {
                    return ChapterContent(
                      chapter: chapters[index],
                      settings: settings,
                      onScrollPositionChanged: (position) {
                        _saveProgress(index, position);
                      },
                    );
                  },
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
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildBottomBar(BuildContext context, AsyncValue<List<Chapter>> chaptersAsync) {
    final progress = ref.watch(currentProgressProvider(widget.book.id));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
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
                onPressed: progress.chapterIndex > 0
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                    : null,
              ),

              // 进度条
              Expanded(
                child: chaptersAsync.when(
                  data: (chapters) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Slider(
                        value: progress.chapterIndex.toDouble(),
                        min: 0,
                        max: (chapters.length - 1).toDouble(),
                        divisions: chapters.length > 1 ? chapters.length - 1 : 1,
                        onChanged: (value) {
                          _pageController.jumpToPage(value.toInt());
                        },
                      ),
                      Text(
                        '${progress.chapterIndex + 1} / ${chapters.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ),

              // 下一章
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: chaptersAsync.when(
                  data: (chapters) => progress.chapterIndex < chapters.length - 1
                      ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                      : null,
                  loading: () => null,
                  error: (_, __) => null,
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

  void _onPageChanged(int index) {
    ref.read(currentProgressProvider(widget.book.id).notifier).state =
        ref.read(currentProgressProvider(widget.book.id)).copyWith(
          chapterIndex: index,
          scrollPosition: 0.0,
        );
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
