import 'package:epub_reader/domain/entities/chapter.dart';
import 'package:epub_reader/domain/entities/reading_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/book.dart';
import '../../providers/book_providers.dart';
import 'reader_controller.dart';
import 'widgets/chapter_content.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_drawer.dart';
import 'widgets/reader_settings_sheet.dart';
import 'widgets/reader_top_bar.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late ScrollController _scrollController;
  late ReaderController _controller;
  bool _showControls = false;
  bool _isLoadingProgress = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = ReaderController(
      ref: ref,
      bookId: widget.book.id,
      scrollController: _scrollController,
    );
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    await _controller.loadProgress();
    setState(() => _isLoadingProgress = false);
  }

  @override
  void dispose() {
    _controller.dispose();
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
      drawer: _buildDrawer(chaptersAsync),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            _buildContent(chaptersAsync, settings),
            if (_showControls) _buildTopBar(),
            if (_showControls) _buildBottomBar(chaptersAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(AsyncValue<List<Chapter>> chaptersAsync) {
    final currentIndex = ref.watch(currentChapterIndexProvider(widget.book.id));

    return chaptersAsync.when(
      data: (chapters) => ReaderDrawer(
        book: widget.book,
        chapters: chapters,
        currentIndex: currentIndex,
        onChapterSelected: (index) {
          _controller.jumpToChapter(index, chapters);
          Navigator.pop(context);
        },
      ),
      loading: () =>
          const Drawer(child: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Drawer(child: Center(child: Text('Error loading chapters'))),
    );
  }

  Widget _buildContent(
    AsyncValue<List<Chapter>> chaptersAsync,
    ReadingSettings settings,
  ) {
    return chaptersAsync.when(
      data: (chapters) {
        if (chapters.isEmpty) {
          return const Center(child: Text('No chapters found'));
        }
        if (_isLoadingProgress) {
          return const Center(child: CircularProgressIndicator());
        }

        // 初始化章节 keys
        if (_controller.chapterKeys.isEmpty || _controller.chapterKeys.length != chapters.length) {
          _controller.initializeChapterKeys(chapters.length);
        }

        return SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              for (int i = 0; i < chapters.length; i++)
                ChapterContent(
                  key: _controller.chapterKeys[i],
                  chapter: chapters[i],
                  settings: settings,
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
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

  Widget _buildBottomBar(AsyncValue<List<Chapter>> chaptersAsync) {
    final currentIndex = ref.watch(currentChapterIndexProvider(widget.book.id));

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ReaderBottomBar(
        currentChapterIndex: currentIndex,
        chaptersAsync: chaptersAsync,
        onChapterChanged: _controller.jumpToChapter,
        onSettingsPressed: _showSettings,
      ),
    );
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
