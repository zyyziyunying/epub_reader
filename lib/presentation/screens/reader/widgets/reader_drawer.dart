import 'package:flutter/material.dart';

import '../../../../domain/entities/book.dart';
import '../../../../domain/entities/document_nav_item.dart';
import '../legacy_fallback_status.dart';

class ReaderDrawer extends StatelessWidget {
  const ReaderDrawer.legacy({
    super.key,
    required this.book,
    required LegacyFallbackStatus legacyFallbackStatus,
  }) : _navItems = null,
       _currentDocumentIndex = null,
       _hasPhase2OnlyToc = false,
       _onDocumentSelected = null,
       _legacyFallbackStatus = legacyFallbackStatus;

  const ReaderDrawer.v2({
    super.key,
    required this.book,
    required List<DocumentNavItem> navItems,
    required int currentDocumentIndex,
    required bool hasPhase2OnlyToc,
    required ValueChanged<int> onDocumentSelected,
  }) : _navItems = navItems,
       _currentDocumentIndex = currentDocumentIndex,
       _hasPhase2OnlyToc = hasPhase2OnlyToc,
       _onDocumentSelected = onDocumentSelected,
       _legacyFallbackStatus = null;

  final Book book;
  final List<DocumentNavItem>? _navItems;
  final int? _currentDocumentIndex;
  final bool _hasPhase2OnlyToc;
  final ValueChanged<int>? _onDocumentSelected;
  final LegacyFallbackStatus? _legacyFallbackStatus;

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;

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
                        ? _legacyFallbackStatus!.drawerHeaderMessage
                        : 'Phase 1 navigation works at the document level.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    navItems == null
                        ? _legacyFallbackStatus!.drawerContentSummary
                        : '${navItems.length} documents',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            if (navItems != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Table of Contents',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                  ? _buildLegacyFallbackMessage(context)
                  : _buildDocumentNavList(context, navItems),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyFallbackMessage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _legacyFallbackStatus!.panelTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _legacyFallbackStatus.panelMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_legacyFallbackStatus.diagnosticDetails case final details?) ...[
            const SizedBox(height: 8),
            Text(details, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
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
