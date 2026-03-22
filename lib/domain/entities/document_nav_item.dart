class DocumentNavItem {
  const DocumentNavItem({
    required this.documentId,
    required this.documentIndex,
    required this.fileName,
    required this.title,
  });

  final String documentId;
  final int documentIndex;
  final String fileName;
  final String title;
}
