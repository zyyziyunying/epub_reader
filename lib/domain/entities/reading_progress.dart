class ReadingProgress {
  final String bookId;
  final int chapterIndex;
  final double scrollPosition;
  final DateTime updatedAt;

  const ReadingProgress({
    required this.bookId,
    required this.chapterIndex,
    required this.scrollPosition,
    required this.updatedAt,
  });

  ReadingProgress copyWith({
    String? bookId,
    int? chapterIndex,
    double? scrollPosition,
    DateTime? updatedAt,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'scroll_position': scrollPosition,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      bookId: map['book_id'] as String,
      chapterIndex: map['chapter_index'] as int,
      scrollPosition: (map['scroll_position'] as num).toDouble(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  factory ReadingProgress.initial(String bookId) {
    return ReadingProgress(
      bookId: bookId,
      chapterIndex: 0,
      scrollPosition: 0.0,
      updatedAt: DateTime.now(),
    );
  }
}
