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

  // 章节位置缓存：存储已渲染章节的滚动位置

  int get currentChapterIndex => ref.read(currentChapterIndexProvider(bookId));

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
    final savedProgress = await ref.read(loadProgressProvider(bookId).future);

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
      ref.read(currentChapterIndexProvider(bookId).notifier).state =
          newChapterIndex;
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
    // 注意：ListView.builder 只渲染可见的 item，所以需要检查 context 是否存在
    for (int i = 0; i < chapterKeys.length; i++) {
      final context = chapterKeys[i].currentContext;
      if (context == null) continue;

      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) continue;

      try {
        final position = renderBox.localToGlobal(Offset.zero);
        final chapterTop = position.dy + scrollOffset;
        final chapterBottom = chapterTop + renderBox.size.height;

        // 如果视口中心在这个章节内，返回该章节索引
        if (centerOffset >= chapterTop && centerOffset < chapterBottom) {
          return i;
        }
      } catch (_) {
        // 如果章节不在可见区域，跳过
        continue;
      }
    }

    return ref.read(currentChapterIndexProvider(bookId));
  }

  void jumpToChapter(int index, List<Chapter> chapters) {
    if (index < 0 || index >= chapters.length) return;

    ref.read(currentChapterIndexProvider(bookId).notifier).state = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performJumpToChapter(index, chapters);
    });

    saveProgress(index, 0.0);
  }

  Future<void> _performJumpToChapter(int index, List<Chapter> chapters) async {
    if (!scrollController.hasClients) return;

    // 步骤1：检查目标章节是否已经渲染
    if (index < chapterKeys.length &&
        chapterKeys[index].currentContext != null) {
      final RenderBox? renderBox =
          chapterKeys[index].currentContext!.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        // 章节已渲染，直接跳转到精确位置
        try {
          final position = renderBox.localToGlobal(Offset.zero);
          final targetPosition = scrollController.offset + position.dy;
          final maxScroll = scrollController.position.maxScrollExtent;

          await scrollController.animateTo(
            targetPosition.clamp(0.0, maxScroll),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        } catch (_) {}
      }
    }

    // 步骤2：章节未渲染，使用估算位置进行初始跳转
    final maxScroll = scrollController.position.maxScrollExtent;
    final estimatedPosition = (maxScroll / chapters.length) * index;

    await scrollController.animateTo(
      estimatedPosition.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // 步骤3：等待章节渲染后进行精确调整
    await Future.delayed(const Duration(milliseconds: 100));

    if (!scrollController.hasClients) return;

    // 尝试多次查找目标章节（最多3次）
    for (int attempt = 0; attempt < 3; attempt++) {
      if (index < chapterKeys.length &&
          chapterKeys[index].currentContext != null) {
        final RenderBox? renderBox =
            chapterKeys[index].currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          try {
            final position = renderBox.localToGlobal(Offset.zero);
            final targetPosition = scrollController.offset + position.dy;
            final currentMaxScroll = scrollController.position.maxScrollExtent;

            // 如果目标章节已经在视口附近，进行精确调整
            if ((position.dy).abs() > 10) {
              await scrollController.animateTo(
                targetPosition.clamp(0.0, currentMaxScroll),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            }
            return;
          } catch (_) {}
        }
      }

      // 如果还没找到，等待更长时间再试
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }
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
