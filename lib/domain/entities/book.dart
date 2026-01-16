class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String? coverPath;
  final int totalChapters;
  final DateTime addedAt;
  final DateTime? lastReadAt;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    this.coverPath,
    required this.totalChapters,
    required this.addedAt,
    this.lastReadAt,
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
    );
  }

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
    );
  }
}
