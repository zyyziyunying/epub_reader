import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'log_config.dart';

/// 应用日志工具
///
/// 基于 dart:developer 的 log 方法，支持：
/// - 日志级别过滤（debug, info, warning, error）
/// - ANSI 颜色输出（仅在支持的终端中显示）
/// - 模块分组（如 [FileService], [NavigatorManager]）
/// - 可配置的最小日志级别
///
/// ## 使用示例
///
/// ```dart
/// // 创建模块日志器
/// final log = AppLogger('FileService');
///
/// // 输出不同级别的日志
/// log.debug('调试信息');
/// log.info('普通信息');
/// log.warning('警告信息');
/// log.error('错误信息', error: e, stackTrace: st);
/// ```
class AppLogger {
  /// 模块名称（用于日志分组）
  final String module;

  /// 是否启用 ANSI 颜色
  final bool enableColors;

  /// 构造函数
  ///
  /// [module] 模块名称，将显示为 [ModuleName] 前缀
  /// [enableColors] 是否启用 ANSI 颜色，默认在 Debug 模式下启用
  AppLogger(
    this.module, {
    this.enableColors = kDebugMode,
  });

  /// 输出 Debug 级别日志
  void debug(String message) {
    _log(LogLevel.debug, message);
  }

  /// 输出 Info 级别日志
  void info(String message) {
    _log(LogLevel.info, message);
  }

  /// 输出 Warning 级别日志
  void warning(String message, {Object? error}) {
    _log(LogLevel.warning, message, error: error);
  }

  /// 输出 Error 级别日志
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  /// 内部日志输出方法
  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    // 检查日志级别过滤
    if (level.value < LogConfig.minLevel.value) {
      return;
    }

    // 构建日志消息
    final coloredLevel = enableColors ? level.coloredName : level.name;
    final formattedMessage = '[$module] $message';

    // 使用 dart:developer 的 log 方法
    developer.log(
      formattedMessage,
      time: DateTime.now(),
      level: level.value,
      name: coloredLevel,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// 日志级别枚举
enum LogLevel {
  /// Debug 级别 - 开发时的详细调试信息
  debug(0, 'DEBUG', AnsiColor.gray),

  /// Info 级别 - 正常的业务流程信息
  info(800, 'INFO', AnsiColor.blue),

  /// Warning 级别 - 潜在问题但不影响运行
  warning(900, 'WARNING', AnsiColor.yellow),

  /// Error 级别 - 严重错误
  error(1000, 'ERROR', AnsiColor.red);

  /// 级别值（对应 dart:developer 的 level 参数）
  final int value;

  /// 级别名称
  final String name;

  /// ANSI 颜色
  final AnsiColor color;

  const LogLevel(this.value, this.name, this.color);

  /// 带颜色的级别名称
  String get coloredName => '${color.code}$name${AnsiColor.reset.code}';
}

/// ANSI 颜色码
///
/// 用于在支持 ANSI 转义序列的终端中显示彩色文本。
class AnsiColor {
  /// ANSI 转义序列代码
  final String code;

  const AnsiColor(this.code);

  // 颜色定义
  /// 重置所有样式
  static const reset = AnsiColor('\x1B[0m');

  /// 灰色（用于 Debug）
  static const gray = AnsiColor('\x1B[90m');

  /// 蓝色（用于 Info）
  static const blue = AnsiColor('\x1B[34m');

  /// 黄色（用于 Warning）
  static const yellow = AnsiColor('\x1B[33m');

  /// 红色（用于 Error）
  static const red = AnsiColor('\x1B[31m');

  /// 绿色
  static const green = AnsiColor('\x1B[32m');

  /// 青色
  static const cyan = AnsiColor('\x1B[36m');

  /// 品红色
  static const magenta = AnsiColor('\x1B[35m');

  /// 包装文本
  String wrap(String text) => '$code$text${reset.code}';
}
