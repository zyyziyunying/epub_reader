# Reader Chapter Navigation Rewrite Progress

Date: 2026-03-22

## 文档定位

- 本文用于同步章节导航重写的当前进度、已完成切片、剩余 blocker 和测试入口
- 本文属于 `docs/progress/`，只汇报现状，不单独定义实现约束
- 绑定约束见 [`../problem/chapter_navigation_rework.md`](../problem/chapter_navigation_rework.md)
- 推进顺序见 [`../plan/chapter_navigation_rewrite_plan.md`](../plan/chapter_navigation_rewrite_plan.md)

## 当前阶段结论

- 当前代码已完成 Step 0、Step 1、Step 2，并补上了 Step 3 的最小会话切换边界
- 用户可见阅读体验仍停留在 Phase 0 / legacy 链路；V2 数据链路的 adapter、builder、repository、旧书重建状态机与会话读取选择边界已收紧，但阅读器主链路尚未切到 V2 渲染
- 当前已确认：
  - 阅读器 UI 仍继续读取 legacy `chaptersProvider`
  - repository 读取侧仍以 `navigation_data_version == 2 && navigation_rebuild_state == ready` 作为 V2 可读前提
  - `saveNavigationDataV2Ready` 现在才可近似视为“最小完整 V2 ready 数据”的入口，而不是仅仅“能写进 SQL 的 payload”
  - 新导入书籍会在单书事务内写入 `reader_documents`、`toc_items`、最小 `reading_progress_v2`，并直接落库为 `ready`
  - 为维持当前阅读器 UI，导入链路仍会同时写入 legacy `chapters` 作为兼容数据；这不改变新书的导航状态口径，也不等于 Step 4 已落地
  - `bookReadingDataSourceProvider` 现已承担“阅读会话读取选择器”职责，并按阅读页实例建立真实会话边界：旧书首次打开会触发后台重建，`rebuilding` 中断会先回退到 `legacy_pending` 再重试，当前会话保持 legacy，不做热切换；同一进程内关闭再打开同一本书时会重新判定，而不是复用首次 `bookId` 缓存

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

### Step 2: 新导入书籍直达 `ready`

- `lib/presentation/providers/book_providers.dart` 的新书导入主链路现已接入：
  - 解析 EPUB legacy 内容
  - 构建 V2 navigation payload
  - 通过 repository 单事务写入新书与 V2 `ready` 数据
- `lib/data/repositories/book_repository_impl.dart` 已新增新书导入事务入口：
  - 同一事务内插入 `books`
  - 写入当前 UI 兼容所需的 legacy `chapters`
  - 复用 `saveNavigationDataV2Ready` 的校验 / ready 写入语义，写入 `reader_documents`、`toc_items`、最小 `reading_progress_v2`
  - 事务末尾将 `books.navigation_data_version = 2`、`navigation_rebuild_state = ready`
- 导入失败时：
  - 数据库事务整体回滚，不留下新书行或 V2 半成品
  - provider 会 best-effort 清理已复制的 EPUB / cover 文件
- 已新增 focused tests：
  - 新书导入成功后直接为 V2 `ready`
  - 新书导入在最终 `ready` 切换失败时整体回滚

### Step 3: 旧书重建状态机与阅读会话切换边界

- `lib/data/repositories/book_repository_impl.dart` 已新增：
  - `markNavigationRebuildInProgress`
  - `rebuilding` 状态下的只读隔离回归测试
- 已新增后台重建协调器：
  - `lib/services/navigation/navigation_rebuild_coordinator.dart`
- `lib/presentation/providers/book_providers.dart` 中：
  - `bookReadingDataSourceProvider` 不再直接读取 repository 当前状态，而是改为按 `bookId` 建立会话边界
  - 对 `legacy_pending` / `failed` 书籍会在打开阅读页时触发后台重建
  - 对“无活跃任务但状态残留为 `rebuilding`”的书籍，会先回退到 `legacy_pending` 再重试
  - Phase 1 默认策略已落地：当前会话保持 legacy，不在同一次阅读会话内热切换到 V2
- `lib/presentation/screens/reader/reader_screen.dart` 现已在进入阅读页时订阅会话读取选择器，从而触发旧书重建
- 已新增 focused tests：
  - `test/services/navigation/navigation_rebuild_coordinator_test.dart`
  - repository 对 `markNavigationRebuildInProgress` 的只读隔离断言

## 当前未完成切片

- Step 4：阅读器 V2 渲染、`DocumentNavItem[]` 目录点击、上一章 / 下一章还未实现
- Step 4：统一 `current document` 判定还未实现
- Step 5：V2 进度保存 / 恢复和 legacy 进度 best-effort 映射还未实现
- Step 6：legacy 导航职责清理还未开始

## 剩余 Blocker

- blocker 2 仍未关闭：`current document` 判定尚未前移为阅读器交互基础能力

## 当前可测试范围

- Step 0 的纯数据导航构建与断言
- adapter 到 builder 的真实 EPUB TOC 输入边界
- Step 1 的数据库升级默认值、旧书 legacy 回退、非 `ready` 状态读取隔离、`ready` 事务写入 / 回退，以及“前半段已写入、后半段失败”场景下的整体回滚
- Step 3 的旧书首次打开触发后台重建、中断恢复回退、失败清理和“当前会话保持 legacy”边界
- `Book` 新状态字段、V2 表结构、repository 新接口的静态闭合情况

## 当前不可通过 UI 直接测试的范围

- 旧书首次打开触发后台重建后的数据库状态切换与后续会话读取选择
- 目录点击跳转、上一章 / 下一章、当前文档高亮
- V2 进度保存 / 恢复

## 建议测试入口

1. 先跑 focused tests：
   `flutter test test/services/navigation/navigation_builder_test.dart test/services/navigation/navigation_source_adapter_test.dart test/data/repositories/book_repository_impl_navigation_test.dart test/services/navigation/navigation_rebuild_coordinator_test.dart`
2. 再做一次手工验证 legacy 回退：
   - 用现有书库数据启动应用
   - 确认旧书仍可打开阅读页
   - 确认旧书首次打开后不会阻塞进入阅读页
   - 若检查数据库状态，应可观察到旧书从 `legacy_pending / failed` 进入后台重建，并在成功后落为 `ready`
   - 确认未接 V2 的阅读页没有因为新表、新字段或 Step 1 / Step 3 边界修补而崩溃
3. 手工验证新导入书籍：
   - 导入一本新 EPUB
   - 确认书籍记录已直接落为 `navigation_data_version = 2`、`navigation_rebuild_state = ready`
   - 确认当前阅读页仍可通过 legacy `chapters` 打开，不会因为新书已 `ready` 而立刻切到未实现的 V2 UI
4. 若后续继续推进 Step 4，应在此基础上新增阅读页渲染和交互测试，而不是复用 Step 3 的状态机测试去间接覆盖 UI 切换
