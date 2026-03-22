# Reader Chapter Navigation Rewrite Progress

Date: 2026-03-22

## 文档定位

- 本文用于同步章节导航重写的当前进度、已完成切片、剩余 blocker 和测试入口
- 本文属于 `docs/progress/`，只汇报现状，不单独定义实现约束
- 绑定约束见 [`../problem/chapter_navigation_rework.md`](../problem/chapter_navigation_rework.md)
- 推进顺序见 [`../plan/chapter_navigation_rewrite_plan.md`](../plan/chapter_navigation_rewrite_plan.md)

## 当前阶段结论

- 当前代码已完成 Step 0、Step 1，以及本轮 Step 1 数据边界修补
- 用户可见阅读体验仍停留在 Phase 0 / legacy 链路；V2 数据链路的 adapter、builder、repository 与数据库回归边界已收紧，但尚未接入导入主链路和阅读器主链路
- 当前已确认：
  - 阅读器 UI 仍继续读取 legacy `chaptersProvider`
  - repository 读取侧仍以 `navigation_data_version == 2 && navigation_rebuild_state == ready` 作为 V2 可读前提
  - `saveNavigationDataV2Ready` 现在才可近似视为“最小完整 V2 ready 数据”的入口，而不是仅仅“能写进 SQL 的 payload”

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
  - `test/services/navigation/navigation_source_adapter_test.dart`

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
- repository / builder 边界本轮已补齐：
  - 真实 EPUB TOC 输入已切回 `epubBook.Chapters`；adapter 现会把 `epubx 4.0.0` 的 manifest 相对 `Content.Html` key / `EpubChapter.ContentFileName` 统一解析到包内规范路径，并新增覆盖 `opfBaseDir != ''` 的 adapter + builder 回归测试
  - `tocSourcePath` 缺失时，builder 会把相对 `href` 收敛为 unresolved，不再按包根生成伪正确 `fileName` / `targetDocumentIndex`
  - `saveNavigationDataV2Ready` 现已显式校验：
    - `ReaderDocument.documentIndex` 连续性
    - `ReaderDocument.id` / `documentIndex` / `fileName` 单书唯一性
    - `TocItem.order` 连续性
    - `TocItem.parentId`、`targetDocumentIndex`、`ReadingProgressV2.tocItemId` 引用合法性
  - `AppDatabase` 已提供测试数据库路径 override，便于做 migration / transaction focused tests
- 已新增 focused database / repository tests：
  - `test/data/repositories/book_repository_impl_navigation_test.dart`

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
- adapter 到 builder 的真实 EPUB TOC 输入边界
- Step 1 的数据库升级默认值、旧书 legacy 回退、非 `ready` 状态读取隔离、`ready` 事务写入 / 回退，以及“前半段已写入、后半段失败”场景下的整体回滚
- `Book` 新状态字段、V2 表结构、repository 新接口的静态闭合情况

## 当前不可通过 UI 直接测试的范围

- 新导入书籍直接生成 V2 `ready` 数据
- 旧书首次打开触发重建并在后续会话切换到 V2
- 目录点击跳转、上一章 / 下一章、当前文档高亮
- V2 进度保存 / 恢复

## 建议测试入口

1. 先跑 focused tests：
   `flutter test test/services/navigation/navigation_builder_test.dart test/services/navigation/navigation_source_adapter_test.dart test/data/repositories/book_repository_impl_navigation_test.dart`
2. 再做一次手工验证 legacy 回退：
   - 用现有书库数据启动应用
   - 确认旧书仍可打开阅读页
   - 确认未接 V2 的阅读页没有因为新表、新字段或 Step 1 边界修补而崩溃
3. 若后续继续推进 Step 2 / Step 3，应新增定向测试，而不是复用本轮 Step 1 回归去间接覆盖状态机
