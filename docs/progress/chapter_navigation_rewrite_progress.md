# Reader Chapter Navigation Rewrite Progress

Date: 2026-03-22

## 文档定位

- 本文用于同步章节导航重写的当前进度、已完成切片、剩余 blocker 和测试入口
- 本文属于 `docs/progress/`，只汇报现状，不单独定义实现约束
- 绑定约束见 [`../problem/chapter_navigation_rework.md`](../problem/chapter_navigation_rework.md)
- 推进顺序见 [`../plan/chapter_navigation_rewrite_plan.md`](../plan/chapter_navigation_rewrite_plan.md)

## 当前阶段结论

- 当前代码已完成 Step 0 和 Step 1
- 用户可见阅读体验仍停留在 Phase 0 / legacy 链路；V2 数据链路已具备基础落库和读取边界，但尚未接入导入主链路和阅读器主链路
- 因此下一步可以开始测试 Step 0 的纯数据输出和 Step 1 的数据库迁移稳定性，但还不能从 UI 验证 V2 阅读跳转、上一章 / 下一章或 V2 进度恢复

## 已完成切片

### Step 0: 导航 builder 与纯数据断言

- 已新增纯数据导航 builder：
  - `lib/services/navigation/navigation_builder.dart`
  - `lib/services/navigation/navigation_models.dart`
  - `lib/services/navigation/navigation_path_utils.dart`
  - `lib/services/navigation/navigation_source_adapter.dart`
- 已新增 V2 基础实体：
  - `lib/domain/entities/reader_document.dart`
  - `lib/domain/entities/toc_item.dart`
  - `lib/domain/entities/document_nav_item.dart`
- `lib/services/epub_parser_service.dart` 已暴露：
  - `buildNavigationFromFile`
  - `buildNavigationFromBytes`
- 已补 focused tests：
  - `test/services/navigation/navigation_builder_test.dart`

### Step 1: 数据库迁移 + repository 边界

- `books` 已新增导航状态字段：
  - `navigation_data_version`
  - `navigation_rebuild_state`
  - `navigation_rebuild_failed_at`
- 已新增 V2 表：
  - `reader_documents`
  - `toc_items`
  - `reading_progress_v2`
- 已新增最小 V2 实体与状态模型：
  - `NavigationRebuildState`
  - `BookReadingDataSource`
  - `ReadingProgressV2`
- repository 已明确以下边界：
  - 单书 `ready` 事务写入入口：`saveNavigationDataV2Ready`
  - 单书 V2 清理 / 重置入口：`resetNavigationDataToLegacy`
  - legacy / V2 读取选择入口：`getBookReadingDataSource`
  - V2 查询入口：`getReaderDocumentsByBookId`、`getTocItemsByBookId`、`getReadingProgressV2`
- `ready` 事务的最小 `ReadingProgressV2` 默认写入策略已固定：
  - 默认 `documentIndex = 0`
  - 默认 `documentProgress = 0`
  - 默认 `tocItemId = null`
  - 默认 `anchor = null`
- repository 层当前保证：
  - 只有 `books.navigation_rebuild_state == ready` 且 `navigation_data_version == 2` 时，V2 数据才可读
  - `rebuilding` 或其他非 `ready` 状态下，不暴露半成品 V2 数据

## 当前未完成切片

- Step 2：新导入书籍直达 `ready` 还未接入当前导入链路
- Step 3：旧书 `legacy_pending -> rebuilding -> ready / failed` 状态机还未接入打开书籍流程
- Step 3：按 `bookId` 驱动的阅读会话 provider / 读取选择器还未建立
- Step 4：阅读器 V2 渲染、`DocumentNavItem[]` 目录点击、上一章 / 下一章还未实现
- Step 4：统一 `current document` 判定还未实现
- Step 5：V2 进度保存 / 恢复和 legacy 进度 best-effort 映射还未实现
- Step 6：legacy 导航职责清理还未开始

## 剩余 Blocker

- blocker 2 仍未关闭：`current document` 判定尚未前移为阅读器交互基础能力
- blocker 3 仍未关闭：旧书重建触发者、`rebuilding` 期间读取边界、同会话切换策略尚未落地

## 当前可测试范围

- Step 0 的纯数据导航构建与断言
- Step 1 的数据库升级是否成功、旧书是否仍可走 legacy 阅读链路、非 `ready` 状态下是否不会误读 V2 数据
- `Book` 新状态字段、V2 表结构、repository 新接口的静态闭合情况

## 当前不可通过 UI 直接测试的范围

- 新导入书籍直接生成 V2 `ready` 数据
- 旧书首次打开触发重建并在后续会话切换到 V2
- 目录点击跳转、上一章 / 下一章、当前文档高亮
- V2 进度保存 / 恢复

## 建议测试入口

1. 先跑 focused test：
   `flutter test test/services/navigation/navigation_builder_test.dart`
2. 再做一次定向静态检查：
   `dart analyze lib/services/navigation lib/services/epub_parser_service.dart lib/domain/entities lib/domain/repositories/book_repository.dart lib/data/datasources/local/database.dart lib/data/repositories/book_repository_impl.dart lib/presentation/providers/book_providers.dart test/services/navigation/navigation_builder_test.dart`
3. 然后手工验证数据库升级与 legacy 回退：
   - 用现有书库数据启动应用
   - 确认旧书仍可打开阅读页
   - 确认未接 V2 的阅读页没有因为新表或新字段而崩溃
4. 若要直接验证 Step 1 的事务接口，需要额外加一个临时 harness 或调试入口；当前 UI 还没有命中 `saveNavigationDataV2Ready`
