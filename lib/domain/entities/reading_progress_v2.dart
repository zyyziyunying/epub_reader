class ReadingProgressV2 {
  const ReadingProgressV2({
    required this.bookId,
    required this.documentIndex,
    required this.documentProgress,
    required this.updatedAt,
    this.tocItemId,
    this.anchor,
  });

  final String bookId;
  final int documentIndex;
  final double documentProgress;
  final String? tocItemId;
  final String? anchor;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'document_index': documentIndex,
      'document_progress': documentProgress,
      'toc_item_id': tocItemId,
      'anchor': anchor,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ReadingProgressV2.fromMap(Map<String, dynamic> map) {
    return ReadingProgressV2(
      bookId: map['book_id'] as String,
      documentIndex: map['document_index'] as int,
      documentProgress: (map['document_progress'] as num).toDouble(),
      tocItemId: map['toc_item_id'] as String?,
      anchor: map['anchor'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  factory ReadingProgressV2.initial(
    String bookId, {
    int documentIndex = 0,
    DateTime? updatedAt,
  }) {
    return ReadingProgressV2(
      bookId: bookId,
      documentIndex: documentIndex,
      documentProgress: 0,
      tocItemId: null,
      anchor: null,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
