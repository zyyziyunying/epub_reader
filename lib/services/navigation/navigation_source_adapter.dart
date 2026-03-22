import 'package:epubx/epubx.dart';

import 'navigation_models.dart';
import 'navigation_path_utils.dart';

class EpubNavigationSourceAdapter {
  const EpubNavigationSourceAdapter._();

  static NavigationSourceBook fromEpubBook(EpubBook book) {
    final schema = book.Schema;
    final package = schema?.Package;
    final opfBaseDir =
        NavigationPathUtils.normalizePackagePath(
          schema?.ContentDirectoryPath ?? '',
        ) ??
        '';
    final htmlEntries =
        book.Content?.Html?.entries.toList() ??
        const <MapEntry<String, EpubTextContentFile>>[];
    final manifestItems =
        package?.Manifest?.Items ?? const <EpubManifestItem>[];
    final spineItems = package?.Spine?.Items ?? const <EpubSpineItemRef>[];
    final chapters = book.Chapters ?? const <EpubChapter>[];

    return NavigationSourceBook(
      opfBaseDir: opfBaseDir,
      htmlFiles: [
        for (final entry in htmlEntries)
          if (_resolveContentPath(entry.key, opfBaseDir)
              case final resolvedPath?)
            NavigationSourceHtmlFile(
              rawPath: resolvedPath,
              htmlContent: entry.value.Content ?? '',
            ),
      ],
      manifestItems: [
        for (final item in manifestItems)
          if ((item.Id ?? '').isNotEmpty && (item.Href ?? '').isNotEmpty)
            NavigationSourceManifestItem(id: item.Id!, href: item.Href!),
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
        for (final chapter in chapters)
          _mapChapter(chapter, opfBaseDir: opfBaseDir),
      ],
    );
  }

  static NavigationSourceTocNode _mapChapter(
    EpubChapter chapter, {
    String opfBaseDir = '',
  }) {
    final children = chapter.SubChapters ?? const <EpubChapter>[];

    return NavigationSourceTocNode(
      title: chapter.Title ?? '',
      resolvedFileName: chapter.ContentFileName == null
          ? null
          : _resolveContentPath(chapter.ContentFileName!, opfBaseDir),
      resolvedAnchor: chapter.Anchor,
      children: [
        for (final child in children)
          _mapChapter(child, opfBaseDir: opfBaseDir),
      ],
    );
  }

  static String? _resolveContentPath(String rawPath, String opfBaseDir) {
    final normalized = NavigationPathUtils.normalizePackagePath(rawPath);
    if (normalized == null) {
      return null;
    }
    if (opfBaseDir.isEmpty ||
        normalized == opfBaseDir ||
        normalized.startsWith('$opfBaseDir/')) {
      return normalized;
    }

    return NavigationPathUtils.resolvePackagePath(
          rawPath: rawPath,
          baseDir: opfBaseDir,
        ) ??
        normalized;
  }
}
