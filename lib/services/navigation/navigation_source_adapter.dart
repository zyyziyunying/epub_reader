import 'package:epubx/epubx.dart';

import 'navigation_models.dart';
import 'navigation_path_utils.dart';

class EpubNavigationSourceAdapter {
  const EpubNavigationSourceAdapter._();

  static NavigationSourceBook fromEpubBook(EpubBook book) {
    final schema = book.Schema;
    final package = schema?.Package;
    final opfBaseDir =
        NavigationPathUtils.normalizePackagePath(schema?.ContentDirectoryPath ?? '') ?? '';
    final tocSourcePath = _resolveTocSourcePath(
      package: package,
      opfBaseDir: opfBaseDir,
    );
    final htmlEntries = book.Content?.Html?.entries.toList() ??
        const <MapEntry<String, EpubTextContentFile>>[];
    final manifestItems = package?.Manifest?.Items ?? const <EpubManifestItem>[];
    final spineItems = package?.Spine?.Items ?? const <EpubSpineItemRef>[];
    final navPoints = schema?.Navigation?.NavMap?.Points ?? const <EpubNavigationPoint>[];

    return NavigationSourceBook(
      opfBaseDir: opfBaseDir,
      htmlFiles: [
        for (final entry in htmlEntries)
          NavigationSourceHtmlFile(
            rawPath: entry.key,
            htmlContent: entry.value.Content ?? '',
          ),
      ],
      manifestItems: [
        for (final item in manifestItems)
          if ((item.Id ?? '').isNotEmpty && (item.Href ?? '').isNotEmpty)
            NavigationSourceManifestItem(
              id: item.Id!,
              href: item.Href!,
            ),
      ],
      spineItems: [
        for (final item in spineItems)
          if ((item.IdRef ?? '').isNotEmpty)
            NavigationSourceSpineItem(
              idRef: item.IdRef!,
              isLinear: item.IsLinear ?? true,
            ),
      ],
      tocRoots: [
        for (final point in navPoints)
          _mapTocNode(
            point,
            tocSourcePath: tocSourcePath ?? '',
          ),
      ],
    );
  }

  static NavigationSourceTocNode _mapTocNode(
    EpubNavigationPoint point, {
    required String tocSourcePath,
  }) {
    final labels = point.NavigationLabels ?? const <EpubNavigationLabel>[];
    final children =
        point.ChildNavigationPoints ?? const <EpubNavigationPoint>[];

    return NavigationSourceTocNode(
      title: labels.isNotEmpty ? (labels.first.Text ?? '') : '',
      href: point.Content?.Source,
      tocSourcePath: tocSourcePath,
      children: [
        for (final child in children)
          _mapTocNode(child, tocSourcePath: tocSourcePath),
      ],
    );
  }

  static String? _resolveTocSourcePath({
    required EpubPackage? package,
    required String opfBaseDir,
  }) {
    if (package == null) {
      return null;
    }

    final manifestItems = package.Manifest?.Items ?? const <EpubManifestItem>[];
    EpubManifestItem? tocManifestItem;

    if (package.Version == EpubVersion.Epub2) {
      final tocId = package.Spine?.TableOfContents;
      if (tocId != null) {
        for (final item in manifestItems) {
          if (item.Id?.toLowerCase() == tocId.toLowerCase()) {
            tocManifestItem = item;
            break;
          }
        }
      }
    } else {
      for (final item in manifestItems) {
        final properties = item.Properties
                ?.split(RegExp(r'\s+'))
                .where((token) => token.isNotEmpty)
                .toList() ??
            const <String>[];
        if (properties.contains('nav')) {
          tocManifestItem = item;
          break;
        }
      }
    }

    final href = tocManifestItem?.Href;
    if (href == null || href.isEmpty) {
      return null;
    }

    return NavigationPathUtils.resolvePackagePath(
      rawPath: href,
      baseDir: opfBaseDir,
    );
  }
}
