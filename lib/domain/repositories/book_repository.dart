import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';

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
  Future<ReadingProgress?> getReadingProgress(String bookId);
  Future<void> saveReadingProgress(ReadingProgress progress);
  Future<void> updateLastReadAt(String bookId, DateTime time);
}
