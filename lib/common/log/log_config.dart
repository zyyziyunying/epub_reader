import 'app_logger.dart';

/// 全局日志配置
///
/// 用于配置应用的日志行为，包括最小日志级别等。
class LogConfig {
  LogConfig._();

  /// 最小日志级别
  ///
  /// 只有大于等于此级别的日志才会被输出。
  /// 默认为 debug（输出所有日志）。
  ///
  /// ## 使用示例
  ///
  /// ```dart
  /// // 只输出 warning 及以上级别的日志
  /// LogConfig.minLevel = LogLevel.warning;
  /// ```
  static LogLevel minLevel = LogLevel.debug;

  /// 设置生产环境配置
  ///
  /// 在生产环境中，通常只输出 warning 和 error 级别的日志。
  static void setProductionMode() {
    minLevel = LogLevel.warning;
  }

  /// 设置开发环境配置
  ///
  /// 在开发环境中，输出所有级别的日志。
  static void setDevelopmentMode() {
    minLevel = LogLevel.debug;
  }
}
