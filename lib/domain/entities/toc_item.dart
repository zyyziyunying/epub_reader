class TocItem {
  const TocItem({
    required this.id,
    required this.bookId,
    required this.title,
    required this.order,
    required this.depth,
    required this.parentId,
    required this.fileName,
    required this.anchor,
    required this.targetDocumentIndex,
  });

  final String id;
  final String bookId;
  final String title;
  final int order;
  final int depth;
  final String? parentId;
  final String? fileName;
  final String? anchor;
  final int? targetDocumentIndex;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'title': title,
      'toc_order': order,
      'depth': depth,
      'parent_id': parentId,
      'file_name': fileName,
      'anchor': anchor,
      'target_document_index': targetDocumentIndex,
    };
  }

  factory TocItem.fromMap(Map<String, dynamic> map) {
    return TocItem(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      title: map['title'] as String,
      order: map['toc_order'] as int,
      depth: map['depth'] as int,
      parentId: map['parent_id'] as String?,
      fileName: map['file_name'] as String?,
      anchor: map['anchor'] as String?,
      targetDocumentIndex: map['target_document_index'] as int?,
    );
  }
}
