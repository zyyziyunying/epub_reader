import '../../domain/entities/document_nav_item.dart';
import '../../domain/entities/reader_document.dart';
import '../../domain/entities/toc_item.dart';

List<DocumentNavItem> buildDocumentNavItems({
  required List<ReaderDocument> documents,
  required List<TocItem> tocItems,
}) {
  final tocItemsByDocumentIndex = <int, List<TocItem>>{};

  for (final tocItem in tocItems) {
    final documentIndex = tocItem.targetDocumentIndex;
    if (documentIndex == null || tocItem.anchor != null) {
      continue;
    }

    tocItemsByDocumentIndex
        .putIfAbsent(documentIndex, () => <TocItem>[])
        .add(tocItem);
  }

  return [
    for (final document in documents)
      DocumentNavItem(
        documentId: document.id,
        documentIndex: document.documentIndex,
        fileName: document.fileName,
        title: _pickNavTitle(
          documentTitle: document.title,
          tocItems:
              tocItemsByDocumentIndex[document.documentIndex] ??
              const <TocItem>[],
        ),
      ),
  ];
}

bool hasPhase2OnlyToc(List<TocItem> tocItems) {
  final countsByTarget = <int, int>{};

  for (final tocItem in tocItems) {
    final target = tocItem.targetDocumentIndex;
    if (target == null) {
      continue;
    }

    countsByTarget[target] = (countsByTarget[target] ?? 0) + 1;
  }

  for (final tocItem in tocItems) {
    if (tocItem.targetDocumentIndex == null || tocItem.anchor != null) {
      return true;
    }

    final target = tocItem.targetDocumentIndex!;
    if ((countsByTarget[target] ?? 0) > 1) {
      return true;
    }
  }

  return false;
}

String _pickNavTitle({
  required String documentTitle,
  required List<TocItem> tocItems,
}) {
  final sortedItems = [...tocItems]
    ..sort((left, right) => left.order.compareTo(right.order));

  for (final tocItem in sortedItems) {
    final cleaned = _cleanText(tocItem.title);
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }

  return documentTitle;
}

String _cleanText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
