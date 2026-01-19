/// 日志工具库
///
/// 提供统一的日志输出接口，支持日志级别过滤、ANSI 颜色和模块分组。
///
/// ## 使用方式
///
/// ```dart
/// import 'package:epub_reader/common/log/log.dart';
///
/// final log = AppLogger('MyModule');
/// log.info('这是一条信息');
/// log.error('发生错误', error: e, stackTrace: st);
/// ```
library;

export 'app_logger.dart';
export 'log_config.dart';
