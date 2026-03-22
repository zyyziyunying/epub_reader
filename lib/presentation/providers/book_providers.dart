import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/book_repository_impl.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_reading_data_source.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/navigation_rebuild_state.dart';
import '../../domain/entities/reading_settings.dart';
import '../../domain/repositories/book_repository.dart';
import '../../services/epub_parser_service.dart';
import '../../services/file_service.dart';

// Services
final fileServiceProvider = Provider<FileService>((ref) => FileService());
final epubParserServiceProvider = Provider<EpubParserService>(
  (ref) => EpubParserService(),
);

// Repository
final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepositoryImpl(),
);

// 书库列表
final libraryBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getAllBooks();
});

final bookReadingDataSourceProvider =
    FutureProvider.family<BookReadingDataSource, String>((ref, bookId) async {
      final repository = ref.watch(bookRepositoryProvider);
      return repository.getBookReadingDataSource(bookId);
    });

// 导入状态
final importingProvider = StateProvider<bool>((ref) => false);

// 导入书籍
final importBookProvider = Provider<Future<Book?> Function()>((ref) {
  return () async {
    final fileService = ref.read(fileServiceProvider);
    final parserService = ref.read(epubParserServiceProvider);
    final repository = ref.read(bookRepositoryProvider);

    // 选择文件
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final filePath = result.files.first.path;
    if (filePath == null) return null;

    ref.read(importingProvider.notifier).state = true;
    String? savedPath;
    String? coverPath;

    try {
      // 生成书籍 ID
      final bookId = const Uuid().v4();

      // 解析 EPUB
      final parsedEpub = await parserService.parseFromFile(filePath);
      final navigationData = await parserService.buildNavigationFromFile(
        filePath,
        bookId: bookId,
      );

      // 复制文件到应用目录
      savedPath = await fileService.copyEpubToAppDirectory(filePath);

      // 保存封面
      if (parsedEpub.coverImage != null) {
        coverPath = await fileService.saveCoverImage(
          parsedEpub.coverImage!,
          bookId,
        );
      }

      // 创建书籍实体
      final book = Book(
        id: bookId,
        title: parsedEpub.title,
        author: parsedEpub.author,
        filePath: savedPath,
        coverPath: coverPath,
        totalChapters: parsedEpub.chapters.length,
        addedAt: DateTime.now(),
        navigationDataVersion: Book.v2NavigationDataVersion,
        navigationRebuildState: NavigationRebuildState.ready,
      );

      // 保留 legacy chapters 仅用于当前阅读器 UI 的最小兼容。
      final legacyChapters = parsedEpub.chapters
          .map(
            (parsed) => Chapter(
              id: const Uuid().v4(),
              bookId: bookId,
              index: parsed.index,
              title: parsed.title,
              content: parsed.htmlContent,
            ),
          )
          .toList();

      await repository.importBookWithNavigationDataV2Ready(
        book: book,
        legacyChapters: legacyChapters,
        documents: navigationData.documents,
        tocItems: navigationData.tocItems,
      );

      // 刷新书库列表
      ref.invalidate(libraryBooksProvider);

      return book;
    } catch (_) {
      await fileService.deleteBookFiles(savedPath, coverPath);
      rethrow;
    } finally {
      ref.read(importingProvider.notifier).state = false;
    }
  };
});

// 删除书籍
final deleteBookProvider = Provider<Future<void> Function(Book)>((ref) {
  return (book) async {
    final fileService = ref.read(fileServiceProvider);
    final repository = ref.read(bookRepositoryProvider);

    // 先删除数据库记录（这样即使文件删除失败，也会成为孤儿文件在下次启动时清理）
    await repository.deleteBook(book.id);

    // 再删除文件（如果失败不影响用户体验，会在下次启动时清理）
    await fileService.deleteBookFiles(book.filePath, book.coverPath);

    // 刷新书库列表
    ref.invalidate(libraryBooksProvider);
  };
});

// 阅读设置
final readingSettingsProvider =
    StateNotifierProvider<ReadingSettingsNotifier, ReadingSettings>((ref) {
      return ReadingSettingsNotifier();
    });

class ReadingSettingsNotifier extends StateNotifier<ReadingSettings> {
  ReadingSettingsNotifier() : super(const ReadingSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = ReadingSettings(
      fontSize: prefs.getDouble('fontSize') ?? 18.0,
      lineHeight: prefs.getDouble('lineHeight') ?? 1.8,
      fontFamily: prefs.getString('fontFamily') ?? 'System',
      theme: ReaderTheme.values[prefs.getInt('theme') ?? 0],
      horizontalPadding: prefs.getDouble('horizontalPadding') ?? 20.0,
      verticalPadding: prefs.getDouble('verticalPadding') ?? 16.0,
      paragraphSpacing: prefs.getDouble('paragraphSpacing') ?? 12.0,
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', state.fontSize);
    await prefs.setDouble('lineHeight', state.lineHeight);
    await prefs.setString('fontFamily', state.fontFamily);
    await prefs.setInt('theme', state.theme.index);
    await prefs.setDouble('horizontalPadding', state.horizontalPadding);
    await prefs.setDouble('verticalPadding', state.verticalPadding);
    await prefs.setDouble('paragraphSpacing', state.paragraphSpacing);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _saveSettings();
  }

  void setLineHeight(double height) {
    state = state.copyWith(lineHeight: height);
    _saveSettings();
  }

  void setTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
    _saveSettings();
  }

  void setHorizontalPadding(double padding) {
    state = state.copyWith(horizontalPadding: padding);
    _saveSettings();
  }
}

// ============ 阅读器相关 Providers ============

// 当前书籍的章节列表
final chaptersProvider = FutureProvider.family<List<Chapter>, String>((
  ref,
  bookId,
) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getChaptersByBookId(bookId);
});
