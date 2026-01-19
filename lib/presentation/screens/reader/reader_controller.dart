import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../providers/book_providers.dart';

class ReaderController {
  final WidgetRef ref;
  final String bookId;
  final ScrollController scrollController;

  int get currentChapterIndex =>
      ref.read(currentChapterIndexProvider(bookId));

  ReaderController({
    required this.ref,
    required this.bookId,
    required this.scrollController,
  }) {
    scrollController.addListener(_onScroll);
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

    final currentIndex = ref.read(currentChapterIndexProvider(bookId));
    saveProgress(currentIndex, scrollProgress.clamp(0.0, 1.0));
  }

  void jumpToChapter(int index, List<Chapter> chapters) {
    if (index < 0 || index >= chapters.length) return;

    ref.read(currentChapterIndexProvider(bookId).notifier).state = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      final maxScroll = scrollController.position.maxScrollExtent;
      final targetPosition = (maxScroll / chapters.length) * index;

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
