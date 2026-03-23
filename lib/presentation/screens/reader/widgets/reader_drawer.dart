import 'package:flutter/material.dart';

import '../../../../domain/entities/book.dart';
import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/document_nav_item.dart';

class ReaderDrawer extends StatelessWidget {
  const ReaderDrawer.legacy({
    super.key,
    required this.book,
    required List<Chapter> chapters,
  }) : _chapters = chapters,
       _navItems = null,
       _currentDocumentIndex = null,
       _hasPhase2OnlyToc = false,
       _onDocumentSelected = null;

  const ReaderDrawer.v2({
    super.key,
    required this.book,
    required List<DocumentNavItem> navItems,
    required int currentDocumentIndex,
    required bool hasPhase2OnlyToc,
    required ValueChanged<int> onDocumentSelected,
  }) : _chapters = null,
       _navItems = navItems,
       _currentDocumentIndex = currentDocumentIndex,
       _hasPhase2OnlyToc = hasPhase2OnlyToc,
       _onDocumentSelected = onDocumentSelected;

  final Book book;
  final List<Chapter>? _chapters;
  final List<DocumentNavItem>? _navItems;
  final int? _currentDocumentIndex;
  final bool _hasPhase2OnlyToc;
  final ValueChanged<int>? _onDocumentSelected;

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;
    final chapters = _chapters;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 书籍信息头部
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    navItems == null
                        ? 'Chapter navigation is temporarily disabled while the reader navigation is being rebuilt.'
                        : 'Phase 1 navigation works at the document level.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    navItems == null
                        ? '${chapters!.length} chapters'
                        : '${navItems.length} documents',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // 章节列表标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Table of Contents',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (navItems != null && _hasPhase2OnlyToc)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Some TOC entries in this EPUB use anchors or multiple entries per document. Phase 1 only supports document-level navigation.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

            Expanded(
              child: navItems == null
                  ? _buildLegacyChapterList(context, chapters!)
                  : _buildDocumentNavList(context, navItems),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyChapterList(BuildContext context, List<Chapter> chapters) {
    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];

        return ListTile(
          leading: _buildIndexBadge(context, index: index),
          title: Text(
            chapter.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          enabled: false,
        );
      },
    );
  }

  Widget _buildDocumentNavList(
    BuildContext context,
    List<DocumentNavItem> navItems,
  ) {
    return ListView.builder(
      itemCount: navItems.length,
      itemBuilder: (context, index) {
        final navItem = navItems[index];
        final isSelected = navItem.documentIndex == _currentDocumentIndex;

        return ListTile(
          leading: _buildIndexBadge(
            context,
            index: index,
            selected: isSelected,
          ),
          title: Text(
            navItem.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isSelected,
          onTap: () => _onDocumentSelected?.call(navItem.documentIndex),
        );
      },
    );
  }

  Widget _buildIndexBadge(
    BuildContext context, {
    required int index,
    bool selected = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = selected
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return CircleAvatar(
      radius: 14,
      backgroundColor: backgroundColor,
      child: Text(
        '${index + 1}',
        style: TextStyle(fontSize: 12, color: foregroundColor),
      ),
    );
  }
}
