class Chapter {
  final String id;
  final String bookId;
  final int index;
  final String title;
  final String content;

  const Chapter({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    required this.content,
  });

  Chapter copyWith({
    String? id,
    String? bookId,
    int? index,
    String? title,
    String? content,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      index: index ?? this.index,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': index,
      'title': title,
      'content': content,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      index: map['chapter_index'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
    );
  }
}
