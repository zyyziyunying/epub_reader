import '../../../domain/entities/book_reading_data_source.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/navigation_rebuild_state.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reading_progress_v2.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/toc_item.dart';

abstract class BookRepository {
  Future<List<Book>> getAllBooks();
  Future<Book?> getBookById(String id);
  Future<void> insertBook(Book book);
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String id);
  Future<List<Chapter>> getChaptersByBookId(String bookId);
  Future<Chapter?> getChapter(String bookId, int index);
  Future<void> insertChapter(Chapter chapter);
  Future<void> insertChapters(List<Chapter> chapters);
  Future<void> importBookWithNavigationDataV2Ready({
    required Book book,
    required List<Chapter> legacyChapters,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  });
  Future<ReadingProgress?> getReadingProgress(String bookId);
  Future<void> saveReadingProgress(ReadingProgress progress);
  Future<BookReadingDataSource> getBookReadingDataSource(String bookId);
  Future<List<ReaderDocument>> getReaderDocumentsByBookId(String bookId);
  Future<List<TocItem>> getTocItemsByBookId(String bookId);
  Future<ReadingProgressV2?> getReadingProgressV2(String bookId);
  Future<void> saveNavigationDataV2Ready({
    required String bookId,
    required List<ReaderDocument> documents,
    required List<TocItem> tocItems,
    ReadingProgressV2? initialProgress,
  });
  Future<void> markNavigationRebuildInProgress(String bookId);
  Future<void> resetNavigationDataToLegacy(
    String bookId, {
    required NavigationRebuildState rebuildState,
    DateTime? failedAt,
  });
  Future<void> updateLastReadAt(String bookId, DateTime time);
}
