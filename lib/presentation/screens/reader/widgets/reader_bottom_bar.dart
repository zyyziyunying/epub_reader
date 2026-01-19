import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/chapter.dart';

class ReaderBottomBar extends ConsumerWidget {
  final int currentChapterIndex;
  final AsyncValue<List<Chapter>> chaptersAsync;
  final Function(int index, List<Chapter> chapters) onChapterChanged;
  final VoidCallback onSettingsPressed;

  const ReaderBottomBar({
    super.key,
    required this.currentChapterIndex,
    required this.chaptersAsync,
    required this.onChapterChanged,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              _buildPreviousButton(),
              Expanded(child: _buildProgressSlider()),
              _buildNextButton(),
              _buildSettingsButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviousButton() {
    return IconButton(
      icon: const Icon(Icons.skip_previous, color: Colors.white),
      onPressed: currentChapterIndex > 0
          ? () => chaptersAsync.whenData((chapters) {
                onChapterChanged(currentChapterIndex - 1, chapters);
              })
          : null,
    );
  }

  Widget _buildProgressSlider() {
    return chaptersAsync.when(
      data: (chapters) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: currentChapterIndex.toDouble(),
            min: 0,
            max: (chapters.length - 1).toDouble(),
            divisions: chapters.length > 1 ? chapters.length - 1 : 1,
            onChanged: (value) {
              onChapterChanged(value.toInt(), chapters);
            },
          ),
          Text(
            '${currentChapterIndex + 1} / ${chapters.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
      loading: () => const SizedBox(),
      error: (_, _) => const SizedBox(),
    );
  }

  Widget _buildNextButton() {
    return IconButton(
      icon: const Icon(Icons.skip_next, color: Colors.white),
      onPressed: chaptersAsync.when(
        data: (chapters) => currentChapterIndex < chapters.length - 1
            ? () => onChapterChanged(currentChapterIndex + 1, chapters)
            : null,
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
      icon: const Icon(Icons.settings, color: Colors.white),
      onPressed: onSettingsPressed,
    );
  }
}
