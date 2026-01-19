# 日志工具使用指南

## 概述

本项目使用自定义的日志工具 `AppLogger`，基于 `dart:developer` 的 log 方法实现，支持：
- 日志级别过滤（debug, info, warning, error）
- ANSI 颜色输出（在支持的终端中显示彩色日志）
- 模块分组（如 [FileService], [NavigatorManager]）
- 可配置的最小日志级别

## 快速开始

### 1. 导入日志库

```dart
import 'package:epub_reader/common/log/log.dart';
```

### 2. 创建日志器

```dart
class MyService {
  final _log = AppLogger('MyService');

  void doSomething() {
    _log.info('开始执行操作');
    // ... 业务逻辑
  }
}
```

### 3. 输出日志

```dart
// Debug 级别 - 开发时的详细调试信息
_log.debug('调试信息: 变量值 = $value');

// Info 级别 - 正常的业务流程信息
_log.info('用户登录成功');

// Warning 级别 - 潜在问题但不影响运行
_log.warning('配置文件不存在，使用默认配置');

// Error 级别 - 严重错误
try {
  // ... 可能出错的代码
} catch (e, st) {
  _log.error('操作失败', error: e, stackTrace: st);
}
```

## 日志级别

| 级别 | 值 | 颜色 | 使用场景 |
|------|-----|------|----------|
| debug | 0 | 灰色 | 开发时的详细调试信息，生产环境可能不输出 |
| info | 800 | 蓝色 | 正常的业务流程信息，如"已清理孤儿文件" |
| warning | 900 | 黄色 | 潜在问题但不影响运行，如"无法删除文件，将在下次启动时清理" |
| error | 1000 | 红色 | 严重错误，如异常捕获、操作失败 |

## 配置日志级别

### 在 main.dart 中配置

```dart
import 'package:flutter/foundation.dart';
import 'package:epub_reader/common/log/log.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 根据环境配置日志级别
  if (kReleaseMode) {
    LogConfig.setProductionMode(); // 只输出 warning 和 error
  } else {
    LogConfig.setDevelopmentMode(); // 输出所有日志
  }

  runApp(MyApp());
}
```

### 手动设置日志级别

```dart
// 只输出 info 及以上级别的日志
LogConfig.minLevel = LogLevel.info;

// 只输出 warning 及以上级别的日志
LogConfig.minLevel = LogLevel.warning;

// 输出所有日志
LogConfig.minLevel = LogLevel.debug;
```

## 使用示例

### 示例 1：文件服务

```dart
import 'package:epub_reader/common/log/log.dart';

class FileService {
  final _log = AppLogger('FileService');

  Future<void> deleteFile(String filePath) async {
    _log.info('开始删除文件: $filePath');

    try {
      final file = File(filePath);
      await file.delete();
      _log.info('文件删除成功: $filePath');
    } catch (e, st) {
      _log.error('文件删除失败: $filePath', error: e, stackTrace: st);
      rethrow;
    }
  }
}
```

### 示例 2：网络请求

```dart
import 'package:epub_reader/common/log/log.dart';

class ApiService {
  final _log = AppLogger('ApiService');

  Future<Response> fetchData(String url) async {
    _log.debug('发起请求: $url');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        _log.info('请求成功: $url');
        return response;
      } else {
        _log.warning('请求返回非 200 状态码: ${response.statusCode}');
        throw Exception('Request failed');
      }
    } catch (e, st) {
      _log.error('请求失败: $url', error: e, stackTrace: st);
      rethrow;
    }
  }
}
```

### 示例 3：启动任务

```dart
import 'package:epub_reader/common/log/log.dart';

void initializeApp() {
  final log = AppLogger('Startup');

  log.info('应用启动中...');

  try {
    // 初始化数据库
    log.debug('初始化数据库');
    DatabaseHelper.initialize();

    // 加载配置
    log.debug('加载配置文件');
    ConfigManager.load();

    log.info('应用启动完成');
  } catch (e, st) {
    log.error('应用启动失败', error: e, stackTrace: st);
  }
}
```

## ANSI 颜色支持

日志工具使用 ANSI 转义序列为不同级别的日志添加颜色：

- **Debug**: `\x1B[90m` (灰色)
- **Info**: `\x1B[34m` (蓝色)
- **Warning**: `\x1B[33m` (黄色)
- **Error**: `\x1B[31m` (红色)

### 颜色显示效果

在支持 ANSI 的终端（如 VS Code 调试控制台）中，日志会显示为：
- 🔵 **INFO** [FileService] 已清理孤儿书籍文件
- 🟡 **WARNING** [FileService] 无法删除文件，将在下次启动时清理
- 🔴 **ERROR** [Startup] 后台清理孤儿文件失败

### 禁用颜色

如果终端不支持 ANSI 颜色，可以在创建日志器时禁用：

```dart
final log = AppLogger('MyModule', enableColors: false);
```

## 最佳实践

### 1. 模块命名

使用类名作为模块名，保持一致性：

```dart
class UserService {
  final _log = AppLogger('UserService');  // ✅ 推荐
}
```

### 2. 日志级别选择

- **debug**: 变量值、函数调用、详细流程
- **info**: 业务操作成功、状态变更
- **warning**: 可恢复的错误、降级处理
- **error**: 异常捕获、操作失败

### 3. 错误日志

重要的错误日志应包含 `error` 和 `stackTrace` 参数：

```dart
try {
  // ... 可能出错的代码
} catch (e, st) {
  _log.error('操作失败', error: e, stackTrace: st);  // ✅ 推荐
  // _log.error('操作失败: $e');  // ❌ 不推荐
}
```

### 4. 生产环境配置

在生产环境中，建议只输出 warning 和 error 级别的日志：

```dart
if (kReleaseMode) {
  LogConfig.setProductionMode();
}
```

### 5. 日志消息格式

- 使用简洁明了的消息
- 包含关键信息（如文件路径、用户 ID）
- 避免敏感信息（如密码、token）

```dart
// ✅ 推荐
_log.info('用户登录成功: userId=$userId');

// ❌ 不推荐
_log.info('用户登录成功: password=$password');
```

## 与 dart:developer 的集成

`AppLogger` 底层使用 `dart:developer` 的 log 方法：

```dart
developer.log(
  formattedMessage,        // 日志消息
  time: DateTime.now(),    // 时间戳
  level: level.value,      // 日志级别（数值）
  name: coloredLevel,      // 日志名称（带颜色）
  error: error,            // 错误对象
  stackTrace: stackTrace,  // 堆栈跟踪
);
```

这意味着：
- 日志可以在 Flutter DevTools 中查看
- Release 模式下性能优良
- 支持结构化日志输出

## 测试

运行日志工具的单元测试：

```bash
flutter test test/common/log/app_logger_test.dart
```

## 常见问题

### Q: 为什么在终端中看不到颜色？

A: 某些终端不支持 ANSI 颜色码。在 VS Code 的调试控制台中可以正常显示颜色。

### Q: 如何在生产环境中完全禁用日志？

A: 设置最小日志级别为一个很高的值，或者使用条件编译：

```dart
if (kReleaseMode) {
  // 不创建日志器，或使用空实现
}
```

### Q: 日志会影响性能吗？

A: `dart:developer` 的 log 方法在 Release 模式下经过优化，性能影响很小。如果担心性能，可以设置 `LogConfig.minLevel = LogLevel.warning`。

### Q: 如何查看日志输出？

A:
- **开发模式**: 在 IDE 的调试控制台中查看
- **Flutter DevTools**: 在 Logging 标签页中查看
- **命令行**: 使用 `flutter run` 时在终端中查看

## 参考资料

- [dart:developer 文档](https://api.dart.dev/stable/dart-developer/dart-developer-library.html)
- [ANSI 转义序列](https://en.wikipedia.org/wiki/ANSI_escape_code)
- [Flutter 日志最佳实践](https://docs.flutter.dev/testing/debugging)
