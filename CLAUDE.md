# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Get dependencies
flutter pub get

# Run a single test file
flutter test test/path/to/test_file.dart
```

## Architecture Overview

This is a cross-platform Flutter EPUB reader using **Clean Architecture** with three layers:

### Layer Structure

```
lib/
├── domain/          # Business logic - pure Dart entities and repository interfaces
├── data/            # Data layer - repository implementations and SQLite database
├── presentation/    # UI layer - screens, widgets, and Riverpod providers
├── services/        # Business services (EPUB parsing, file operations)
└── core/            # Shared utilities (themes, platform helpers)
```

### State Management: Riverpod

All state is managed through Riverpod providers in [book_providers.dart](lib/presentation/providers/book_providers.dart):

- `bookRepositoryProvider` - Singleton repository instance
- `libraryBooksProvider` - FutureProvider for book list
- `importBookProvider` - EPUB import workflow
- `readingSettingsProvider` - StateNotifierProvider for reader preferences (font size, theme, etc.)
- `chaptersProvider` / `currentProgressProvider` - Reading state per book

### Data Flow

1. **EPUB Import**: `FilePicker` → `EpubParserService` → `FileService` (copy to app dir) → `BookRepository` (SQLite)
2. **Reading**: `BookRepository` → Riverpod providers → UI widgets
3. **Settings**: `SharedPreferences` ↔ `ReadingSettingsNotifier`

### Database Schema

SQLite database ([database.dart](lib/data/datasources/local/database.dart)) with three tables:

- `books` - Book metadata (id, title, author, file_path, cover_path)
- `chapters` - Chapter content (book_id, index, title, HTML content)
- `reading_progress` - Reading position (book_id, chapter_index, scroll_position)

### Platform Considerations

Desktop platforms (Windows, macOS, Linux) require FFI for SQLite. Initialization happens in [database_factory.dart](lib/core/platform/database_factory.dart) before app startup.

## Key Dependencies

- `epubx` - EPUB file parsing
- `sqflite` / `sqflite_common_ffi` - SQLite database (mobile/desktop)
- `flutter_riverpod` - State management
- `flutter_html` - HTML content rendering in reader
- `file_picker` - EPUB file selection
