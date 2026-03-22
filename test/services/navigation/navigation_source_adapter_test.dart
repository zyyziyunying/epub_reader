import 'package:epub_reader/services/navigation/navigation_builder.dart';
import 'package:epub_reader/services/navigation/navigation_source_adapter.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EpubNavigationSourceAdapter', () {
    test('resolves chapter and html paths against content.opf base dir', () {
      final book = _epubBookWithRelativePaths();

      final source = EpubNavigationSourceAdapter.fromEpubBook(book);

      expect(source.opfBaseDir, 'OPS');
      expect(
        source.htmlFiles.map((file) => file.rawPath),
        orderedEquals(['OPS/Text/ch1.xhtml', 'OPS/Text/ch2.xhtml']),
      );
      expect(
        source.tocRoots.map((node) => node.title),
        orderedEquals(['Chapter 1', 'Chapter 2']),
      );
      expect(source.tocRoots.first.resolvedFileName, 'OPS/Text/ch1.xhtml');
      expect(source.tocRoots.first.tocSourcePath, isNull);
      expect(source.tocRoots.first.children.single.title, 'Section 1');
      expect(
        source.tocRoots.first.children.single.resolvedFileName,
        'OPS/Text/ch1.xhtml',
      );
      expect(source.tocRoots.first.children.single.resolvedAnchor, 'frag');
    });

    test(
      'keeps usable spine order when epubx html keys stay manifest relative',
      () {
        final source = EpubNavigationSourceAdapter.fromEpubBook(
          _epubBookWithRelativePaths(),
        );

        final result = const NavigationBuilder().build(
          bookId: 'book-1',
          source: source,
        );

        expect(result.usedSpineOrder, isTrue);
        expect(
          result.documents.map((document) => document.fileName),
          orderedEquals(['OPS/Text/ch2.xhtml', 'OPS/Text/ch1.xhtml']),
        );
        expect(
          result.navItems.map((item) => item.title),
          orderedEquals(['Chapter 2', 'Chapter 1']),
        );
      },
    );
  });
}

EpubBook _epubBookWithRelativePaths() {
  final book = EpubBook()
    ..Schema = (EpubSchema()
      ..ContentDirectoryPath = 'OPS'
      ..Package = (EpubPackage()
        ..Manifest = (EpubManifest()
          ..Items = [
            _manifestItem('ch1', 'Text/ch1.xhtml'),
            _manifestItem('ch2', 'Text/ch2.xhtml'),
          ])
        ..Spine = (EpubSpine()
          ..Items = [_spineItem('ch2'), _spineItem('ch1')])))
    ..Content = EpubContent()
    ..Chapters = [
      EpubChapter()
        ..Title = 'Chapter 1'
        ..ContentFileName = 'Text/ch1.xhtml'
        ..SubChapters = [
          EpubChapter()
            ..Title = 'Section 1'
            ..ContentFileName = 'Text/ch1.xhtml'
            ..Anchor = 'frag'
            ..SubChapters = <EpubChapter>[],
        ],
      EpubChapter()
        ..Title = 'Chapter 2'
        ..ContentFileName = 'Text/ch2.xhtml'
        ..SubChapters = <EpubChapter>[],
    ];
  book.Content!.Html!['Text/ch1.xhtml'] = EpubTextContentFile()
    ..Content =
        '<html><head><title>Document 1</title></head><body></body></html>';
  book.Content!.Html!['Text/ch2.xhtml'] = EpubTextContentFile()
    ..Content =
        '<html><head><title>Document 2</title></head><body></body></html>';
  return book;
}

EpubManifestItem _manifestItem(String id, String href) {
  return EpubManifestItem()
    ..Id = id
    ..Href = href
    ..MediaType = 'application/xhtml+xml';
}

EpubSpineItemRef _spineItem(String idRef) {
  return EpubSpineItemRef()
    ..IdRef = idRef
    ..IsLinear = true;
}
