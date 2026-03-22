class ReaderDocument {
  const ReaderDocument({
    required this.id,
    required this.bookId,
    required this.documentIndex,
    required this.fileName,
    required this.title,
    required this.htmlContent,
  });

  final String id;
  final String bookId;
  final int documentIndex;
  final String fileName;
  final String title;
  final String htmlContent;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'document_index': documentIndex,
      'file_name': fileName,
      'title': title,
      'html_content': htmlContent,
    };
  }

  factory ReaderDocument.fromMap(Map<String, dynamic> map) {
    return ReaderDocument(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      documentIndex: map['document_index'] as int,
      fileName: map['file_name'] as String,
      title: map['title'] as String,
      htmlContent: map['html_content'] as String,
    );
  }
}
