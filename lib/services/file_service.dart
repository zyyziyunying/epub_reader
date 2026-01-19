import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../common/log/log.dart';

class FileService {
  static const _uuid = Uuid();
  final _log = AppLogger('FileService');

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

    // 确保目标文件可写（Windows 上复制只读文件会保留只读属性）
    if (Platform.isWindows) {
      try {
        // 移除只读属性
        await Process.run('attrib', ['-R', destPath]);
      } catch (e) {
        _log.warning('无法移除文件只读属性: $destPath', error: e);
      }
    }

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
      await _deleteFileWithRetry(filePath);
    }

    if (coverPath != null) {
      await _deleteFileWithRetry(coverPath);
    }
  }

  /// 带重试机制的文件删除（处理 Windows 文件占用问题）
  ///
  /// 采用静默失败策略：如果文件被占用无法删除，不抛出异常，
  /// 而是记录日志并返回。孤儿文件会在应用启动时被清理。
  Future<void> _deleteFileWithRetry(String filePath, {int maxRetries = 5}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }

    for (int i = 0; i < maxRetries; i++) {
      try {
        await file.delete();
        return; // 删除成功
      } on PathAccessException catch (e) {
        if (i == maxRetries - 1) {
          // 静默失败：Windows 系统可能延迟释放文件句柄（杀毒软件、索引服务等）
          // 不阻塞用户操作，孤儿文件会在下次启动时清理
          _log.warning('无法删除文件 $filePath (${e.message})，将在下次启动时清理');
          return;
        }
        // 增加等待时间：500ms, 1s, 1.5s, 2s, 2.5s
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      } catch (e) {
        // 其他类型的错误直接抛出
        rethrow;
      }
    }
  }

  /// 清理孤儿文件（数据库中不存在但文件夹中存在的文件）
  ///
  /// 应在应用启动时调用，清理之前因系统占用而未能删除的文件。
  /// [validBookIds] 数据库中所有有效的书籍 ID 列表
  Future<void> cleanOrphanFiles(Set<String> validBookIds) async {
    try {
      // 清理书籍文件
      final booksDir = Directory(await getBooksDirectory());
      if (await booksDir.exists()) {
        await for (final entity in booksDir.list()) {
          if (entity is File && entity.path.endsWith('.epub')) {
            final fileName = path.basenameWithoutExtension(entity.path);
            if (!validBookIds.contains(fileName)) {
              try {
                await entity.delete();
                _log.info('已清理孤儿书籍文件: ${entity.path}');
              } catch (e) {
                _log.error('清理孤儿书籍文件失败: ${entity.path}', error: e);
              }
            }
          }
        }
      }

      // 清理封面文件
      final coversDir = Directory(await getCoversDirectory());
      if (await coversDir.exists()) {
        await for (final entity in coversDir.list()) {
          if (entity is File && entity.path.endsWith('.jpg')) {
            final fileName = path.basenameWithoutExtension(entity.path);
            if (!validBookIds.contains(fileName)) {
              try {
                await entity.delete();
                _log.info('已清理孤儿封面文件: ${entity.path}');
              } catch (e) {
                _log.error('清理孤儿封面文件失败: ${entity.path}', error: e);
              }
            }
          }
        }
      }
    } catch (e) {
      _log.error('清理孤儿文件时出错', error: e);
    }
  }
}