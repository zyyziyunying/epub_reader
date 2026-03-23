import 'package:html/parser.dart' as html_parser;

import '../../domain/entities/reader_document.dart';
import '../../domain/entities/toc_item.dart';
import 'document_navigation.dart';
import 'navigation_models.dart';
import 'navigation_path_utils.dart';

class NavigationBuilder {
  const NavigationBuilder();

  NavigationBuildResult build({
    required String bookId,
    required NavigationSourceBook source,
  }) {
    final htmlSources = _selectHtmlSources(source.htmlFiles);
    final flattenedTocNodes = _flattenToc(source.tocRoots);
    final manifestFileNames = _buildManifestFileNames(
      opfBaseDir: source.opfBaseDir,
      manifestItems: source.manifestItems,
    );
    final documentFileNames = _buildDocumentFileNames(
      candidateFileNames: htmlSources.keys.toSet(),
      manifestFileNames: manifestFileNames,
      spineItems: source.spineItems,
      flattenedTocNodes: flattenedTocNodes,
    );
    final documents = _buildDocuments(
      bookId: bookId,
      documentFileNames: documentFileNames,
      htmlSources: htmlSources,
    );
    final documentIndexByFileName = {
      for (final document in documents)
        document.fileName: document.documentIndex,
    };
    final tocItems = _buildTocItems(
      bookId: bookId,
      flattenedTocNodes: flattenedTocNodes,
      documentIndexByFileName: documentIndexByFileName,
    );
    final navItems = buildDocumentNavItems(
      documents: documents,
      tocItems: tocItems,
    );

    return NavigationBuildResult(
      documents: documents,
      tocItems: tocItems,
      navItems: navItems,
      hasPhase2OnlyToc: hasPhase2OnlyToc(tocItems),
      usedSpineOrder: _hasUsableSpine(
        candidateFileNames: htmlSources.keys.toSet(),
        manifestFileNames: manifestFileNames,
        spineItems: source.spineItems,
      ),
    );
  }

  Map<String, _ResolvedHtmlSource> _selectHtmlSources(
    List<NavigationSourceHtmlFile> htmlFiles,
  ) {
    final resolved = <String, _ResolvedHtmlSource>{};

    for (final htmlFile in htmlFiles) {
      final fileName = NavigationPathUtils.normalizePackagePath(
        htmlFile.rawPath,
      );
      if (fileName == null) {
        continue;
      }

      final existing = resolved[fileName];
      if (existing == null ||
          htmlFile.rawPath.compareTo(existing.rawPath) < 0) {
        resolved[fileName] = _ResolvedHtmlSource(
          rawPath: htmlFile.rawPath,
          fileName: fileName,
          htmlContent: htmlFile.htmlContent,
        );
      }
    }

    return resolved;
  }

  Map<String, String> _buildManifestFileNames({
    required String opfBaseDir,
    required List<NavigationSourceManifestItem> manifestItems,
  }) {
    final fileNameById = <String, String>{};

    for (final manifestItem in manifestItems) {
      if (manifestItem.id.isEmpty) {
        continue;
      }

      final fileName = NavigationPathUtils.resolvePackagePath(
        rawPath: manifestItem.href,
        baseDir: opfBaseDir,
      );
      if (fileName == null) {
        continue;
      }

      fileNameById.putIfAbsent(manifestItem.id, () => fileName);
    }

    return fileNameById;
  }

  List<_FlattenedTocNode> _flattenToc(List<NavigationSourceTocNode> roots) {
    final flattened = <_FlattenedTocNode>[];

    void visit(
      NavigationSourceTocNode node, {
      required int depth,
      required int? parentOrder,
    }) {
      final order = flattened.length;
      final resolvedTarget = _resolveTocTarget(node);
      flattened.add(
        _FlattenedTocNode(
          order: order,
          depth: depth,
          parentOrder: parentOrder,
          title: node.title,
          fileName: resolvedTarget.fileName,
          anchor: resolvedTarget.anchor,
        ),
      );

      for (final child in node.children) {
        visit(child, depth: depth + 1, parentOrder: order);
      }
    }

    for (final root in roots) {
      visit(root, depth: 0, parentOrder: null);
    }

    return flattened;
  }

  _ResolvedTarget _resolveTocTarget(NavigationSourceTocNode node) {
    final normalizedResolvedFileName = node.resolvedFileName == null
        ? null
        : NavigationPathUtils.normalizePackagePath(node.resolvedFileName!);
    final normalizedResolvedAnchor = _normalizeAnchor(node.resolvedAnchor);
    if (normalizedResolvedFileName != null ||
        normalizedResolvedAnchor != null) {
      return _ResolvedTarget(
        fileName: normalizedResolvedFileName,
        anchor: normalizedResolvedAnchor,
      );
    }

    final href = node.href;
    if (href == null) {
      return const _ResolvedTarget(fileName: null, anchor: null);
    }

    final target = _splitHref(href);
    final normalizedTocSourcePath = node.tocSourcePath == null
        ? null
        : NavigationPathUtils.normalizePackagePath(node.tocSourcePath!);
    if (target.path.isEmpty) {
      return _ResolvedTarget(
        fileName: normalizedTocSourcePath,
        anchor: target.anchor,
      );
    }

    if (normalizedTocSourcePath == null) {
      return _ResolvedTarget(fileName: null, anchor: target.anchor);
    }

    final baseDir = NavigationPathUtils.dirname(normalizedTocSourcePath);
    final fileName = NavigationPathUtils.resolvePackagePath(
      rawPath: target.path,
      baseDir: baseDir,
    );

    return _ResolvedTarget(fileName: fileName, anchor: target.anchor);
  }

  List<String> _buildDocumentFileNames({
    required Set<String> candidateFileNames,
    required Map<String, String> manifestFileNames,
    required List<NavigationSourceSpineItem> spineItems,
    required List<_FlattenedTocNode> flattenedTocNodes,
  }) {
    final orderedFromSpine = <String>[];
    final spineSeen = <String>{};

    for (final spineItem in spineItems) {
      final fileName = manifestFileNames[spineItem.idRef];
      if (fileName == null || !candidateFileNames.contains(fileName)) {
        continue;
      }

      if (spineSeen.add(fileName)) {
        orderedFromSpine.add(fileName);
      }
    }

    if (orderedFromSpine.isNotEmpty) {
      return orderedFromSpine;
    }

    final orderedFromToc = <String>[];
    final tocSeen = <String>{};
    for (final tocNode in flattenedTocNodes) {
      final fileName = tocNode.fileName;
      if (fileName == null || !candidateFileNames.contains(fileName)) {
        continue;
      }

      if (tocSeen.add(fileName)) {
        orderedFromToc.add(fileName);
      }
    }

    final remaining =
        candidateFileNames
            .where((fileName) => !tocSeen.contains(fileName))
            .toList()
          ..sort();

    return <String>[...orderedFromToc, ...remaining];
  }

  List<ReaderDocument> _buildDocuments({
    required String bookId,
    required List<String> documentFileNames,
    required Map<String, _ResolvedHtmlSource> htmlSources,
  }) {
    final documents = <ReaderDocument>[];

    for (var index = 0; index < documentFileNames.length; index++) {
      final fileName = documentFileNames[index];
      final htmlSource = htmlSources[fileName]!;
      documents.add(
        ReaderDocument(
          id: '$bookId:reader_document:$index',
          bookId: bookId,
          documentIndex: index,
          fileName: fileName,
          title: _deriveDocumentTitle(
            fileName: fileName,
            htmlContent: htmlSource.htmlContent,
          ),
          htmlContent: htmlSource.htmlContent,
        ),
      );
    }

    return documents;
  }

  List<TocItem> _buildTocItems({
    required String bookId,
    required List<_FlattenedTocNode> flattenedTocNodes,
    required Map<String, int> documentIndexByFileName,
  }) {
    return [
      for (final tocNode in flattenedTocNodes)
        TocItem(
          id: '$bookId:toc_item:${tocNode.order}',
          bookId: bookId,
          title: tocNode.title,
          order: tocNode.order,
          depth: tocNode.depth,
          parentId: tocNode.parentOrder == null
              ? null
              : '$bookId:toc_item:${tocNode.parentOrder}',
          fileName: tocNode.fileName,
          anchor: tocNode.anchor,
          targetDocumentIndex: tocNode.fileName == null
              ? null
              : documentIndexByFileName[tocNode.fileName!],
        ),
    ];
  }

  bool _hasUsableSpine({
    required Set<String> candidateFileNames,
    required Map<String, String> manifestFileNames,
    required List<NavigationSourceSpineItem> spineItems,
  }) {
    for (final spineItem in spineItems) {
      final fileName = manifestFileNames[spineItem.idRef];
      if (fileName != null && candidateFileNames.contains(fileName)) {
        return true;
      }
    }

    return false;
  }

  String _deriveDocumentTitle({
    required String fileName,
    required String htmlContent,
  }) {
    try {
      final document = html_parser.parse(htmlContent);
      final selectors = <String>['title', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'];

      for (final selector in selectors) {
        final element = document.querySelector(selector);
        final cleaned = _cleanText(element?.text ?? '');
        if (cleaned.isNotEmpty) {
          return cleaned;
        }
      }
    } catch (_) {}

    final fileStem = _cleanText(
      NavigationPathUtils.basenameWithoutExtension(fileName),
    );
    if (fileStem.isNotEmpty) {
      return fileStem;
    }

    return fileName;
  }

  String _cleanText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _normalizeAnchor(String? anchor) {
    if (anchor == null || anchor.isEmpty) {
      return null;
    }
    return anchor;
  }

  _SplitHref _splitHref(String href) {
    final anchorIndex = href.indexOf('#');
    if (anchorIndex < 0) {
      return _SplitHref(path: href, anchor: null);
    }

    final anchor = href.substring(anchorIndex + 1);
    return _SplitHref(
      path: href.substring(0, anchorIndex),
      anchor: anchor.isEmpty ? null : anchor,
    );
  }
}

class _ResolvedHtmlSource {
  const _ResolvedHtmlSource({
    required this.rawPath,
    required this.fileName,
    required this.htmlContent,
  });

  final String rawPath;
  final String fileName;
  final String htmlContent;
}

class _FlattenedTocNode {
  const _FlattenedTocNode({
    required this.order,
    required this.depth,
    required this.parentOrder,
    required this.title,
    required this.fileName,
    required this.anchor,
  });

  final int order;
  final int depth;
  final int? parentOrder;
  final String title;
  final String? fileName;
  final String? anchor;
}

class _ResolvedTarget {
  const _ResolvedTarget({required this.fileName, required this.anchor});

  final String? fileName;
  final String? anchor;
}

class _SplitHref {
  const _SplitHref({required this.path, required this.anchor});

  final String path;
  final String? anchor;
}
