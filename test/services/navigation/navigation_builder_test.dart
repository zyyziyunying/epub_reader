import 'package:epub_reader/services/navigation/navigation_builder.dart';
import 'package:epub_reader/services/navigation/navigation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigationBuilder', () {
    const builder = NavigationBuilder();

    test(
      'uses usable spine order and keeps linear false items in document order',
      () {
        final result = builder.build(
          bookId: 'book-1',
          source: NavigationSourceBook(
            opfBaseDir: 'OPS',
            htmlFiles: [
              _htmlFile(
                'OPS/Text/ch1.xhtml',
                '<html><head><title>Document 1</title></head><body></body></html>',
              ),
              _htmlFile(
                'OPS/Text/ch2.xhtml',
                '<html><head><title>Document 2</title></head><body></body></html>',
              ),
              _htmlFile(
                'OPS/Text/appendix.xhtml',
                '<html><head><title>Appendix</title></head><body></body></html>',
              ),
            ],
            manifestItems: [
              _manifestItem('ch1', 'Text/ch1.xhtml'),
              _manifestItem('ch2', 'Text/ch2.xhtml'),
              _manifestItem('appendix', 'Text/appendix.xhtml'),
            ],
            spineItems: [_spineItem('ch2', isLinear: false), _spineItem('ch1')],
            tocRoots: [
              _tocNode(title: 'Chapter 1', href: 'Text/ch1.xhtml'),
              _tocNode(title: 'Chapter 2', href: 'Text/ch2.xhtml'),
              _tocNode(title: 'Appendix', href: 'Text/appendix.xhtml'),
            ],
          ),
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

    test(
      'falls back to TOC order and appends remaining html files alphabetically',
      () {
        final result = builder.build(
          bookId: 'book-2',
          source: NavigationSourceBook(
            opfBaseDir: 'OPS',
            htmlFiles: [
              _htmlFile(
                'OPS/Text/b.xhtml',
                '<html><head><title>B</title></head><body></body></html>',
              ),
              _htmlFile(
                'OPS/Text/c.xhtml',
                '<html><head><title>C</title></head><body></body></html>',
              ),
              _htmlFile(
                'OPS/Text/a.xhtml',
                '<html><head><title>A</title></head><body></body></html>',
              ),
            ],
            manifestItems: [_manifestItem('missing', 'Text/missing.xhtml')],
            spineItems: [_spineItem('missing')],
            tocRoots: [
              _tocNode(
                title: 'Part C',
                href: 'Text/c.xhtml',
                children: [
                  _tocNode(title: 'Part A', href: 'Text/a.xhtml#frag'),
                ],
              ),
              _tocNode(title: 'Missing', href: 'Text/missing.xhtml'),
            ],
          ),
        );

        expect(result.usedSpineOrder, isFalse);
        expect(
          result.documents.map((document) => document.fileName),
          orderedEquals([
            'OPS/Text/c.xhtml',
            'OPS/Text/a.xhtml',
            'OPS/Text/b.xhtml',
          ]),
        );
        expect(
          result.tocItems.map((item) => item.order),
          orderedEquals([0, 1, 2]),
        );
        expect(result.tocItems[1].parentId, 'book-2:toc_item:0');
        expect(result.tocItems[1].fileName, 'OPS/Text/a.xhtml');
        expect(result.tocItems[1].anchor, 'frag');
        expect(result.tocItems[2].targetDocumentIndex, isNull);
      },
    );

    test(
      'normalizes paths and keeps the lexicographically smallest html source',
      () {
        final result = builder.build(
          bookId: 'book-3',
          source: NavigationSourceBook(
            opfBaseDir: 'OPS',
            htmlFiles: [
              _htmlFile(
                './OPS/Text/../Text/ch%201.xhtml',
                '<html><head><title>Winner Title</title></head><body></body></html>',
              ),
              _htmlFile(
                'OPS/Text/ch 1.xhtml',
                '<html><head><title>Loser Title</title></head><body></body></html>',
              ),
            ],
            manifestItems: [_manifestItem('chapter', './Text/ch%201.xhtml')],
            spineItems: [_spineItem('chapter')],
            tocRoots: [
              _tocNode(
                title: 'Resolved Chapter',
                href: '../Text/ch%201.xhtml#intro',
                tocSourcePath: 'OPS/nav/nav.xhtml',
              ),
            ],
          ),
        );

        expect(result.documents.single.fileName, 'OPS/Text/ch 1.xhtml');
        expect(result.documents.single.title, 'Winner Title');
        expect(result.tocItems.single.fileName, 'OPS/Text/ch 1.xhtml');
        expect(result.tocItems.single.anchor, 'intro');
        expect(result.tocItems.single.targetDocumentIndex, 0);
      },
    );

    test('treats TOC href as unresolved when tocSourcePath is missing', () {
      final result = builder.build(
        bookId: 'book-3b',
        source: NavigationSourceBook(
          opfBaseDir: 'OPS',
          htmlFiles: [
            _htmlFile(
              'OPS/Text/ch1.xhtml',
              '<html><head><title>Chapter 1</title></head><body></body></html>',
            ),
          ],
          manifestItems: [_manifestItem('chapter', 'Text/ch1.xhtml')],
          spineItems: [_spineItem('chapter')],
          tocRoots: [
            _tocNode(
              title: 'Unknown Base',
              href: 'Text/ch1.xhtml#frag',
              tocSourcePath: null,
            ),
          ],
        ),
      );

      expect(result.tocItems.single.fileName, isNull);
      expect(result.tocItems.single.anchor, 'frag');
      expect(result.tocItems.single.targetDocumentIndex, isNull);
    });
    test(
      'builds nav titles from the first eligible TOC item and flags phase 2 only toc',
      () {
        final result = builder.build(
          bookId: 'book-4',
          source: NavigationSourceBook(
            opfBaseDir: 'OPS',
            htmlFiles: [
              _htmlFile(
                'OPS/Text/ch1.xhtml',
                '<html><head><title>Document Title</title></head><body></body></html>',
              ),
            ],
            manifestItems: [_manifestItem('chapter', 'Text/ch1.xhtml')],
            spineItems: [_spineItem('chapter')],
            tocRoots: [
              _tocNode(title: '   ', href: 'Text/ch1.xhtml'),
              _tocNode(title: 'Section', href: 'Text/ch1.xhtml#section-1'),
              _tocNode(title: 'Readable Title', href: 'Text/ch1.xhtml'),
            ],
          ),
        );

        expect(result.navItems.single.title, 'Readable Title');
        expect(result.hasPhase2OnlyToc, isTrue);
      },
    );

    test('falls back to document title when no TOC title is eligible', () {
      final result = builder.build(
        bookId: 'book-5',
        source: NavigationSourceBook(
          opfBaseDir: 'OPS',
          htmlFiles: [
            _htmlFile(
              'OPS/Text/ch1.xhtml',
              '<html><body><h3>Visible Heading</h3></body></html>',
            ),
          ],
          manifestItems: [_manifestItem('chapter', 'Text/ch1.xhtml')],
          spineItems: [_spineItem('chapter')],
          tocRoots: [
            _tocNode(title: '  ', href: 'Text/ch1.xhtml'),
            _tocNode(title: 'Ignored Anchor', href: 'Text/ch1.xhtml#part'),
          ],
        ),
      );

      expect(result.documents.single.title, 'Visible Heading');
      expect(result.navItems.single.title, 'Visible Heading');
    });
  });
}

NavigationSourceHtmlFile _htmlFile(String rawPath, String htmlContent) {
  return NavigationSourceHtmlFile(rawPath: rawPath, htmlContent: htmlContent);
}

NavigationSourceManifestItem _manifestItem(String id, String href) {
  return NavigationSourceManifestItem(id: id, href: href);
}

NavigationSourceSpineItem _spineItem(String idRef, {bool isLinear = true}) {
  return NavigationSourceSpineItem(idRef: idRef, isLinear: isLinear);
}

NavigationSourceTocNode _tocNode({
  required String title,
  String? href,
  String? tocSourcePath = 'OPS/nav.xhtml',
  List<NavigationSourceTocNode> children = const [],
}) {
  return NavigationSourceTocNode(
    title: title,
    href: href,
    tocSourcePath: tocSourcePath,
    children: children,
  );
}
