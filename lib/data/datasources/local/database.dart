import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _databaseName = 'epub_reader.db';
  static const _databaseVersion = 2;

  static Database? _database;
  static String? _databasePathOverrideForTest;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path =
        _databasePathOverrideForTest ?? await _resolveDefaultDatabasePath();

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<String> _resolveDefaultDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _databaseName);
  }

  static void overrideDatabasePathForTest(String path) {
    _databasePathOverrideForTest = path;
  }

  static Future<void> resetForTest() async {
    await close();
    _databasePathOverrideForTest = null;
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createBooksTable(db);
    await _createChaptersTable(db);
    await _createReadingProgressTable(db);
    await _createReaderDocumentsTable(db);
    await _createTocItemsTable(db);
    await _createReadingProgressV2Table(db);
    await _createIndexes(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN navigation_data_version INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE books ADD COLUMN navigation_rebuild_state TEXT NOT NULL DEFAULT 'legacy_pending'",
      );
      await db.execute(
        'ALTER TABLE books ADD COLUMN navigation_rebuild_failed_at INTEGER',
      );
      await _createReaderDocumentsTable(db);
      await _createTocItemsTable(db);
      await _createReadingProgressV2Table(db);
      await _createIndexes(db);
    }
  }

  static Future<void> _createBooksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        file_path TEXT NOT NULL,
        cover_path TEXT,
        total_chapters INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        last_read_at INTEGER,
        navigation_data_version INTEGER NOT NULL DEFAULT 0,
        navigation_rebuild_state TEXT NOT NULL DEFAULT 'legacy_pending',
        navigation_rebuild_failed_at INTEGER
      )
    ''');
  }

  static Future<void> _createChaptersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createReadingProgressTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reading_progress (
        book_id TEXT PRIMARY KEY,
        chapter_index INTEGER NOT NULL,
        scroll_position REAL NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createReaderDocumentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reader_documents (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        document_index INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        title TEXT NOT NULL,
        html_content TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createTocItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS toc_items (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        title TEXT NOT NULL,
        toc_order INTEGER NOT NULL,
        depth INTEGER NOT NULL,
        parent_id TEXT,
        file_name TEXT,
        anchor TEXT,
        target_document_index INTEGER,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createReadingProgressV2Table(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reading_progress_v2 (
        book_id TEXT PRIMARY KEY,
        document_index INTEGER NOT NULL,
        document_progress REAL NOT NULL CHECK (document_progress >= 0 AND document_progress <= 1),
        toc_item_id TEXT,
        anchor TEXT,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chapters_book_id ON chapters (book_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_reader_documents_book_id_document_index ON reader_documents (book_id, document_index)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_reader_documents_book_id_file_name ON reader_documents (book_id, file_name)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_toc_items_book_id_order ON toc_items (book_id, toc_order)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_toc_items_book_id_parent_id ON toc_items (book_id, parent_id)',
    );
  }

  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
