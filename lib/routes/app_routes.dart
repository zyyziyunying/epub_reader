import 'package:flutter/cupertino.dart';

import '../core/router/router_core.dart';
import '../domain/entities/book.dart';
import '../presentation/screens/library/library_screen.dart';
import '../presentation/screens/reader/reader_screen.dart';

/// 应用路由配置
///
/// 定义所有路由路径和名称
class AppRoutes {
  AppRoutes._();

  // 路由路径
  static const String library = '/';
  static const String reader = '/reader';

  // 路由名称
  static const String libraryName = 'library';
  static const String readerName = 'reader';
}

/// 创建应用路由列表
List<RouteBase> appRoutes() => [
      // 图书馆页面（首页）
      GoRoute(
        path: AppRoutes.library,
        name: AppRoutes.libraryName,
        pageBuilder: (context, state) => CupertinoPage<void>(
          key: state.pageKey,
          child: const LibraryScreen(),
        ),
      ),

      // 阅读器页面
      GoRoute(
        path: AppRoutes.reader,
        name: AppRoutes.readerName,
        pageBuilder: (context, state) {
          // 从 extra 参数获取 Book 对象
          final book = state.extra as Book?;

          if (book == null) {
            // 如果没有传递 Book 对象，返回错误页面
            throw Exception('Book parameter is required for reader screen');
          }

          return CupertinoPage<void>(
            key: state.pageKey,
            child: ReaderScreen(book: book),
          );
        },
      ),
    ];
