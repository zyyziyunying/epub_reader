import 'navigation_rebuild_state.dart';

class Book {
  static const int legacyNavigationDataVersion = 0;
  static const int v2NavigationDataVersion = 2;

  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverPath;
  final int totalChapters;
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final int navigationDataVersion;
  final NavigationRebuildState navigationRebuildState;
  final DateTime? navigationRebuildFailedAt;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverPath,
    required this.totalChapters,
    required this.addedAt,
    this.lastReadAt,
    this.navigationDataVersion = legacyNavigationDataVersion,
    this.navigationRebuildState = NavigationRebuildState.legacyPending,
    this.navigationRebuildFailedAt,
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? coverPath,
    int? totalChapters,
    DateTime? addedAt,
    DateTime? lastReadAt,
    int? navigationDataVersion,
    NavigationRebuildState? navigationRebuildState,
    DateTime? navigationRebuildFailedAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      totalChapters: totalChapters ?? this.totalChapters,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      navigationDataVersion: navigationDataVersion ?? this.navigationDataVersion,
      navigationRebuildState:
          navigationRebuildState ?? this.navigationRebuildState,
      navigationRebuildFailedAt:
          navigationRebuildFailedAt ?? this.navigationRebuildFailedAt,
    );
  }

  bool get usesV2Navigation =>
      navigationDataVersion == v2NavigationDataVersion &&
      navigationRebuildState == NavigationRebuildState.ready;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'file_path': filePath,
      'cover_path': coverPath,
      'total_chapters': totalChapters,
      'added_at': addedAt.millisecondsSinceEpoch,
      'last_read_at': lastReadAt?.millisecondsSinceEpoch,
      'navigation_data_version': navigationDataVersion,
      'navigation_rebuild_state': navigationRebuildState.dbValue,
      'navigation_rebuild_failed_at':
          navigationRebuildFailedAt?.millisecondsSinceEpoch,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      filePath: map['file_path'] as String,
      coverPath: map['cover_path'] as String?,
      totalChapters: map['total_chapters'] as int,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
      lastReadAt: map['last_read_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_read_at'] as int)
          : null,
      navigationDataVersion:
          (map['navigation_data_version'] as int?) ?? legacyNavigationDataVersion,
      navigationRebuildState: NavigationRebuildState.fromDbValue(
        map['navigation_rebuild_state'] as String?,
      ),
      navigationRebuildFailedAt: map['navigation_rebuild_failed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['navigation_rebuild_failed_at'] as int,
            )
          : null,
    );
  }
}
