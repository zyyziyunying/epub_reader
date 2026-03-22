import '../../domain/entities/document_nav_item.dart';
import '../../domain/entities/reader_document.dart';
import '../../domain/entities/toc_item.dart';

class NavigationSourceBook {
  const NavigationSourceBook({
    required this.opfBaseDir,
    required this.htmlFiles,
    required this.manifestItems,
    required this.spineItems,
    required this.tocRoots,
  });

  final String opfBaseDir;
  final List<NavigationSourceHtmlFile> htmlFiles;
  final List<NavigationSourceManifestItem> manifestItems;
  final List<NavigationSourceSpineItem> spineItems;
  final List<NavigationSourceTocNode> tocRoots;
}

class NavigationSourceHtmlFile {
  const NavigationSourceHtmlFile({
    required this.rawPath,
    required this.htmlContent,
  });

  final String rawPath;
  final String htmlContent;
}

class NavigationSourceManifestItem {
  const NavigationSourceManifestItem({required this.id, required this.href});

  final String id;
  final String href;
}

class NavigationSourceSpineItem {
  const NavigationSourceSpineItem({
    required this.idRef,
    required this.isLinear,
  });

  final String idRef;
  final bool isLinear;
}

class NavigationSourceTocNode {
  const NavigationSourceTocNode({
    required this.title,
    this.href,
    this.tocSourcePath,
    this.resolvedFileName,
    this.resolvedAnchor,
    this.children = const [],
  });

  final String title;
  final String? href;
  final String? tocSourcePath;
  final String? resolvedFileName;
  final String? resolvedAnchor;
  final List<NavigationSourceTocNode> children;
}

class NavigationBuildResult {
  const NavigationBuildResult({
    required this.documents,
    required this.tocItems,
    required this.navItems,
    required this.hasPhase2OnlyToc,
    required this.usedSpineOrder,
  });

  final List<ReaderDocument> documents;
  final List<TocItem> tocItems;
  final List<DocumentNavItem> navItems;
  final bool hasPhase2OnlyToc;
  final bool usedSpineOrder;
}
