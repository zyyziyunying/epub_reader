import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../providers/book_providers.dart';

class ReaderController {
  final WidgetRef ref;
  final String bookId;
  final ScrollController scrollController;
  final List<GlobalKey> chapterKeys = [];

  int get currentChapterIndex =>
      ref.read(currentChapterIndexProvider(bookId));

  ReaderController({
    required this.ref,
    required this.bookId,
    required this.scrollController,
  }) {
    scrollController.addListener(_onScroll);
  }

  void initializeChapterKeys(int chapterCount) {
    chapterKeys.clear();
    for (int i = 0; i < chapterCount; i++) {
      chapterKeys.add(GlobalKey());
    }
  }

  Future<void> loadProgress() async {
    final savedProgress = await ref.read(
      loadProgressProvider(bookId).future,
    );

    if (savedProgress != null) {
      ref.read(currentChapterIndexProvider(bookId).notifier).state =
          savedProgress.chapterIndex;
      ref.read(currentProgressProvider(bookId).notifier).state = savedProgress;

      // 等待布局完成后恢复滚动位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSavedPosition(savedProgress);
      });
    }
  }

  void _scrollToSavedPosition(ReadingProgress progress) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!scrollController.hasClients) return;

      final maxScroll = scrollController.position.maxScrollExtent;
      final targetScroll = maxScroll * progress.scrollPosition;

      scrollController.jumpTo(targetScroll.clamp(0.0, maxScroll));
    });
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;

    final position = scrollController.position;
    final scrollProgress = position.pixels / position.maxScrollExtent;

    // 根据滚动位置更新当前章节索引
    final newChapterIndex = _calculateCurrentChapterIndex();
    final currentIndex = ref.read(currentChapterIndexProvider(bookId));

    if (newChapterIndex != currentIndex) {
      ref.read(currentChapterIndexProvider(bookId).notifier).state = newChapterIndex;
    }

    saveProgress(newChapterIndex, scrollProgress.clamp(0.0, 1.0));
  }

  int _calculateCurrentChapterIndex() {
    if (!scrollController.hasClients || chapterKeys.isEmpty) {
      return ref.read(currentChapterIndexProvider(bookId));
    }

    final scrollOffset = scrollController.offset;
    final viewportHeight = scrollController.position.viewportDimension;
    final centerOffset = scrollOffset + (viewportHeight / 2);

    // 找到视口中心位置对应的章节
    for (int i = 0; i < chapterKeys.length; i++) {
      final context = chapterKeys[i].currentContext;
      if (context == null) continue;

      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final position = renderBox.localToGlobal(Offset.zero);
      final chapterTop = scrollOffset + position.dy;
      final chapterBottom = chapterTop + renderBox.size.height;

      // 如果视口中心在这个章节内，返回该章节索引
      if (centerOffset >= chapterTop && centerOffset < chapterBottom) {
        return i;
      }
    }

    return ref.read(currentChapterIndexProvider(bookId));
  }

  void jumpToChapter(int index, List<Chapter> chapters) {
    if (index < 0 || index >= chapters.length) return;

    ref.read(currentChapterIndexProvider(bookId).notifier).state = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      // 获取目标章节的实际位置
      double targetPosition = 0.0;

      if (index < chapterKeys.length && chapterKeys[index].currentContext != null) {
        final RenderBox? renderBox = chapterKeys[index].currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          // 获取章节相对于 ScrollView 的位置
          final position = renderBox.localToGlobal(Offset.zero);
          targetPosition = scrollController.offset + position.dy;
        }
      } else {
        // 如果无法获取实际位置，使用估算（作为后备方案）
        final maxScroll = scrollController.position.maxScrollExtent;
        targetPosition = (maxScroll / chapters.length) * index;
      }

      final maxScroll = scrollController.position.maxScrollExtent;
      scrollController.animateTo(
        targetPosition.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });

    saveProgress(index, 0.0);
  }

  Future<void> saveProgress(int chapterIndex, double scrollPosition) async {
    final progress = ReadingProgress(
      bookId: bookId,
      chapterIndex: chapterIndex,
      scrollPosition: scrollPosition,
      updatedAt: DateTime.now(),
    );

    ref.read(currentProgressProvider(bookId).notifier).state = progress;

    final repository = ref.read(bookRepositoryProvider);
    await repository.saveReadingProgress(progress);
    await repository.updateLastReadAt(bookId, DateTime.now());
  }

  void dispose() {
    scrollController.removeListener(_onScroll);
  }
}
