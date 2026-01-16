import 'package:sqflite/sqflite.dart';

import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/repositories/book_repository.dart';
import '../datasources/local/database.dart';

class BookRepositoryImpl implements BookRepository {
  @override
  Future<List<Book>> getAllBooks() async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'books',
      orderBy: 'last_read_at DESC, added_at DESC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  @override
  Future<Book?> getBookById(String id) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  @override
  Future<void> insertBook(Book book) async {
    final db = await AppDatabase.database;
    await db.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateBook(Book book) async {
    final db = await AppDatabase.database;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  @override
  Future<void> deleteBook(String id) async {
    final db = await AppDatabase.database;
    await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Chapter>> getChaptersByBookId(String bookId) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_index ASC',
    );
    return maps.map((map) => Chapter.fromMap(map)).toList();
  }

  @override
  Future<Chapter?> getChapter(String bookId, int index) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'chapters',
      where: 'book_id = ? AND chapter_index = ?',
      whereArgs: [bookId, index],
    );
    if (maps.isEmpty) return null;
    return Chapter.fromMap(maps.first);
  }

  @override
  Future<void> insertChapter(Chapter chapter) async {
    final db = await AppDatabase.database;
    await db.insert(
      'chapters',
      chapter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertChapters(List<Chapter> chapters) async {
    final db = await AppDatabase.database;
    final batch = db.batch();
    for (final chapter in chapters) {
      batch.insert(
        'chapters',
        chapter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<ReadingProgress?> getReadingProgress(String bookId) async {
    final db = await AppDatabase.database;
    final maps = await db.query(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (maps.isEmpty) return null;
    return ReadingProgress.fromMap(maps.first);
  }

  @override
  Future<void> saveReadingProgress(ReadingProgress progress) async {
    final db = await AppDatabase.database;
    await db.insert(
      'reading_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateLastReadAt(String bookId, DateTime time) async {
    final db = await AppDatabase.database;
    await db.update(
      'books',
      {'last_read_at': time.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }
}
