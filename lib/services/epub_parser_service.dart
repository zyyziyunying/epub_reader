import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;

class EpubParserService {
  /// 从文件路径解析 EPUB
  Future<ParsedEpub> parseFromFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return parseFromBytes(bytes);
  }

  /// 从字节数据解析 EPUB
  Future<ParsedEpub> parseFromBytes(Uint8List bytes) async {
    final epubBook = await EpubReader.readBook(bytes);

    return ParsedEpub(
      title: epubBook.Title ?? 'Unknown',
      author: epubBook.Author ?? 'Unknown',
      coverImage: _extractCoverImage(epubBook),
      chapters: _extractChapters(epubBook),
    );
  }

  /// 提取封面图片
  Uint8List? _extractCoverImage(EpubBook book) {
    final img.Image? coverImage = book.CoverImage;
    if (coverImage != null) {
      return Uint8List.fromList(img.encodeJpg(coverImage));
    }
    return null;
  }

  /// 提取章节列表
  List<ParsedChapter> _extractChapters(EpubBook book) {
    final chapters = <ParsedChapter>[];
    final content = book.Content;

    if (content?.Html != null) {
      int index = 0;
      for (final entry in content!.Html!.entries) {
        final htmlContent = entry.value.Content ?? '';
        chapters.add(
          ParsedChapter(
            index: index++,
            title: _extractChapterTitle(htmlContent, entry.key),
            htmlContent: htmlContent,
            fileName: entry.key,
          ),
        );
      }
    }

    return chapters;
  }

  /// 从 HTML 提取章节标题
  String _extractChapterTitle(String html, String fileName) {
    try {
      final document = html_parser.parse(html);

      // 尝试从 <title> 标签提取
      final titleElement = document.querySelector('title');
      if (titleElement != null && titleElement.text.isNotEmpty) {
        return titleElement.text.trim();
      }

      // 尝试从 <h1> 标签提取
      final h1Element = document.querySelector('h1');
      if (h1Element != null && h1Element.text.isNotEmpty) {
        return h1Element.text.trim();
      }

      // 尝试从 <h2> 标签提取
      final h2Element = document.querySelector('h2');
      if (h2Element != null && h2Element.text.isNotEmpty) {
        return h2Element.text.trim();
      }
    } catch (_) {}

    // 使用文件名作为后备
    return fileName.replaceAll(
      RegExp(r'\.(x?html?|xml)$', caseSensitive: false),
      '',
    );
  }
}

/// 解析后的 EPUB 数据
class ParsedEpub {
  final String title;
  final String author;
  final Uint8List? coverImage;
  final List<ParsedChapter> chapters;

  ParsedEpub({
    required this.title,
    required this.author,
    this.coverImage,
    required this.chapters,
  });
}

/// 解析后的章节数据
class ParsedChapter {
  final int index;
  final String title;
  final String htmlContent;
  final String fileName;

  ParsedChapter({
    required this.index,
    required this.title,
    required this.htmlContent,
    required this.fileName,
  });
}
