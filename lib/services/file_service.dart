import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileService {
  static const _uuid = Uuid();

  /// 获取应用文档目录
  Future<String> getAppDocumentsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// 获取书籍存储目录
  Future<String> getBooksDirectory() async {
    final documentsPath = await getAppDocumentsPath();
    final booksDir = Directory(path.join(documentsPath, 'epub_reader', 'books'));
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir.path;
  }

  /// 获取封面存储目录
  Future<String> getCoversDirectory() async {
    final documentsPath = await getAppDocumentsPath();
    final coversDir = Directory(path.join(documentsPath, 'epub_reader', 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir.path;
  }

  /// 复制 EPUB 文件到应用目录
  Future<String> copyEpubToAppDirectory(String sourcePath) async {
    final booksDir = await getBooksDirectory();
    final fileName = '${_uuid.v4()}.epub';
    final destPath = path.join(booksDir, fileName);

    final sourceFile = File(sourcePath);
    await sourceFile.copy(destPath);

    return destPath;
  }

  /// 保存封面图片
  Future<String?> saveCoverImage(Uint8List imageBytes, String bookId) async {
    try {
      final coversDir = await getCoversDirectory();
      final coverPath = path.join(coversDir, '$bookId.jpg');

      final file = File(coverPath);
      await file.writeAsBytes(imageBytes);

      return coverPath;
    } catch (e) {
      return null;
    }
  }

  /// 删除书籍相关文件
  Future<void> deleteBookFiles(String? filePath, String? coverPath) async {
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (coverPath != null) {
      final file = File(coverPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}