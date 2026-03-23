import 'package:epub_reader/domain/entities/chapter.dart';
import 'package:epub_reader/domain/entities/reading_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/book.dart';
import '../../providers/book_providers.dart';
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
  bool _showControls = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Object _readingSessionToken = Object();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsReading();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      bookReadingDataSourceProvider((
        bookId: widget.book.id,
        sessionToken: _readingSessionToken,
      )),
    );
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
            if (_showControls) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(AsyncValue<List<Chapter>> chaptersAsync) {
    return chaptersAsync.when(
      data: (chapters) => ReaderDrawer(book: widget.book, chapters: chapters),
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

        return ListView.builder(
          controller: _scrollController,
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            return ChapterContent(chapter: chapters[index], settings: settings);
          },
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

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ReaderBottomBar(onSettingsPressed: _showSettings),
    );
  }

  Future<void> _markAsReading() async {
    final repository = ref.read(bookRepositoryProvider);
    await repository.updateLastReadAt(widget.book.id, DateTime.now());
    if (!mounted) return;
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
