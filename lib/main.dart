import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import 'app.dart';
import 'common/log/log.dart';
import 'core/platform/database_factory.dart';
import 'core/router/factory/router_factory.dart' as router_factory;
import 'data/repositories/book_repository_impl.dart';
import 'routes/app_routes.dart';
import 'services/file_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 配置日志级别
  if (kReleaseMode) {
    LogConfig.setProductionMode(); // 生产环境只输出 warning 和 error
  }

  // 初始化数据库工厂（桌面平台需要 FFI）
  DatabaseFactoryHelper.initialize();

  // 后台清理孤儿文件（不阻塞应用启动）
  _cleanOrphanFilesInBackground();

  // 创建路由
  final router = router_factory.RouterFactory.create(
    router_factory.RouterConfig(
      initialLocation: AppRoutes.library,
      showRouteErrorPage: true,
      routes: appRoutes(),
    ),
  );

  runApp(ProviderScope(child: EpubReaderApp(router: router)));
}

/// 后台清理孤儿文件（之前因系统占用而未能删除的文件）
void _cleanOrphanFilesInBackground() {
  final log = AppLogger('Startup');

  Future(() async {
    try {
      final repository = BookRepositoryImpl();
      final books = await repository.getAllBooks();
      final validBookFileNames = books
          .map((book) => path.basenameWithoutExtension(book.filePath))
          .where((fileName) => fileName.isNotEmpty)
          .toSet();
      final validCoverFileNames = books
          .map((book) => book.coverPath)
          .whereType<String>()
          .map(path.basenameWithoutExtension)
          .where((fileName) => fileName.isNotEmpty)
          .toSet();

      final fileService = FileService();
      await fileService.cleanOrphanFiles(
        validBookFileNames: validBookFileNames,
        validCoverFileNames: validCoverFileNames,
      );
    } catch (e, st) {
      log.error('后台清理孤儿文件失败', error: e, stackTrace: st);
    }
  });
}
