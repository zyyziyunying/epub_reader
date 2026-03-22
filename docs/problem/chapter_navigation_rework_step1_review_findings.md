# Reader Chapter Navigation Rework Step 1 Review Findings

Date: 2026-03-22

## 文档定位

- 本文记录对当前章节导航重构 Step 0 / Step 1 代码改动的审查结论，聚焦“已宣称完成的边界”中仍存在的实现偏差、事务风险和验证缺口
- 本文属于 `docs/problem/` 下的问题文档；若相关问题被后续提交修复，应更新、关闭或归档本文
- 若与 [`./chapter_navigation_rework.md`](./chapter_navigation_rework.md) 冲突，以 Phase 1 约束文档为准；本文只回写当前实现与约束之间的差距

## 审核范围

- 绑定约束：[`./chapter_navigation_rework.md`](./chapter_navigation_rework.md)
- 当前进度：[`../progress/chapter_navigation_rewrite_progress.md`](../progress/chapter_navigation_rewrite_progress.md)
- 推进计划：[`../plan/chapter_navigation_rewrite_plan.md`](../plan/chapter_navigation_rewrite_plan.md)
- 当前已审文件集中在：
  - `lib/data/datasources/local/database.dart`
  - `lib/data/repositories/book_repository_impl.dart`
  - `lib/domain/entities/`
  - `lib/domain/repositories/book_repository.dart`
  - `lib/services/navigation/`
  - `lib/services/epub_parser_service.dart`
  - `lib/presentation/providers/book_providers.dart`

## 当前结论

- 当前代码已经把 Step 1 所需的主要表结构、实体和 repository 边界显式落地
- 当前 UI 主链路仍停留在 legacy 阅读链路，旧书继续读取 `chaptersProvider`，因此“旧书仍走 legacy”这一点当前成立
- repository 读取侧已经用 `navigation_data_version == 2 && navigation_rebuild_state == ready` 作为 V2 可读前提，因此“非 ready 状态不暴露 V2 数据”在当前 repository 边界上基本成立
- 但截至本次审查，仍不能判定“Step 1 边界完整且无明显迁移 / 事务 / 读取风险”
- 主要问题收敛为：真实 TOC 接入仍偏离绑定约束且缺少 adapter 级回归验证、`tocSourcePath` 缺失时解析基准错误、`ready` 写入边界尚未真正收紧到完整 V2 数据、以及 Step 1 缺少自动化回归验证

## 审核问题

### 1. 实际 EPUB TOC 接入偏离绑定约束

问题：

- 当前 [`../services/navigation/navigation_source_adapter.dart`](../../lib/services/navigation/navigation_source_adapter.dart) 直接使用 `schema.Navigation.NavMap.Points` 作为 `tocRoots` 来源
- 但 Phase 1 约束明确要求：`TocItem` 的唯一结构来源必须是 `epubBook.Chapters` 返回的根节点列表，而不是应用层自行改用其他 TOC 入口
- 截至本次审查，能够直接确认的是“当前实现偏离了绑定约束”；还不能仅凭当前仓库代码证明“现依赖版本下 `schema.Navigation.NavMap.Points` 与 `epubBook.Chapters` 已产生结构性分叉”

风险：

- Step 0 builder 测到的是抽象输入模型，但真实 EPUB 接入仍未对齐到约束指定的唯一入口
- 当前 `epubx 4.0.0` 内部的 `EpubBook.Chapters` 也是基于 `Navigation.NavMap.Points` 生成，因此本次更合理的风险判断是：实现契约与生产接入方式未统一，且缺少 adapter 级回归测试来锁定这一前提
- 若后续升级解析库、调整 adapter，或项目需要依赖 `epubBook.Chapters` 的稳定契约补充 `tocSourcePath` 上下文，现有实现与测试基线仍可能发生静默分叉

相关约束与代码：

- 约束：[`./chapter_navigation_rework.md`](./chapter_navigation_rework.md) 中 `TocItem` 唯一生成与线性化契约
- 代码：[`../../lib/services/navigation/navigation_source_adapter.dart`](../../lib/services/navigation/navigation_source_adapter.dart)

建议调整：

- 要么把真实 EPUB TOC 输入切回 `epubBook.Chapters` 对应的唯一来源，并补足 `tocSourcePath` 所需上下文；要么先显式修订绑定约束，避免实现与文档长期分叉
- 至少补一层 adapter 级测试，保证 builder 测试使用的输入结构与真实生产入口保持一致

### 2. `tocSourcePath` 缺失时当前实现会错误按包根解析相对 `href`

问题：

- 当前 adapter 在无法解析 nav/NCX 源路径时，会把 `tocSourcePath` 置为空字符串
- builder 随后仍继续把相对 `href` 按该空基准解析，等价于隐式假设 TOC 来源文档位于包根目录

风险：

- 约束要求 `TocItem.href` 必须基于真实 `tocSourcePath` 解析；若来源路径不可得，不应静默引入新的相对路径基准
- 对 nav/NCX 文件不在包根目录的 EPUB，这会把 `fileName`、`anchor` 和 `targetDocumentIndex` 静默解析错
- 错误结果仍可能被持久化为 `ready` 数据，后续阅读链路会把错误当作稳定映射

相关约束与代码：

- 约束：[`./chapter_navigation_rework.md`](./chapter_navigation_rework.md) 中“路径来源与规范化基准”
- 代码：[`../../lib/services/navigation/navigation_source_adapter.dart`](../../lib/services/navigation/navigation_source_adapter.dart)、[`../../lib/services/navigation/navigation_builder.dart`](../../lib/services/navigation/navigation_builder.dart)

建议调整：

- 当 `tocSourcePath` 不可解析时，不要把相对 `href` 默认相对包根解析
- 这类节点应收敛为 unresolved，令 `fileName` / `targetDocumentIndex` 为空，而不是生成伪正确映射

### 3. `saveNavigationDataV2Ready` 还没有把 `ready` 写入边界收紧到“完整 V2 数据”

问题：

- 当前 repository 在 [`../../lib/data/repositories/book_repository_impl.dart`](../../lib/data/repositories/book_repository_impl.dart) 中提供了单书事务写入入口 `saveNavigationDataV2Ready`
- 但该方法目前只校验：
  - `documents` 非空
  - `documents` 与 `tocItems` 的 `bookId` 必须一致
  - `initialProgress.documentIndex` 在文档范围内
- 数据库 schema 也未约束以下关键不变量：
  - `document_index` 必须连续且无洞
  - `target_document_index` 必须落在有效范围
  - `parent_id` 必须引用同书已存在的父 TOC 节点
  - `reading_progress_v2.toc_item_id` 若非空，必须引用同书合法 TOC 项

风险：

- 只要调用方传入“SQL 可写但结构不完整”的 V2 数据，repository 仍会把书状态切到 `ready`
- 一旦后续 Step 2 / Step 3 开始真正消费这些接口，`ready` 将不再等价于“完整且可读的 V2 数据”
- 这与 Step 1 原本要把事务和读取边界收紧在 repository 的目标不符

相关约束与代码：

- 计划要求：[`../plan/chapter_navigation_rewrite_plan.md`](../plan/chapter_navigation_rewrite_plan.md) 中 Step 1 的 repository 边界定义
- 当前进度宣称：[`../progress/chapter_navigation_rewrite_progress.md`](../progress/chapter_navigation_rewrite_progress.md) 中 `ready` 事务写入与读取边界说明
- 代码：[`../../lib/data/repositories/book_repository_impl.dart`](../../lib/data/repositories/book_repository_impl.dart)、[`../../lib/data/datasources/local/database.dart`](../../lib/data/datasources/local/database.dart)

建议调整：

- 在 repository 写入前补齐结构校验，不要把完整性假设全部留给调用方
- 至少显式校验：
  - `documentIndex` 从 `0..n-1` 连续分配
  - `ReaderDocument.fileName`、`documentIndex` 在单书内唯一
  - `TocItem.order` 连续稳定
  - `parentId`、`targetDocumentIndex`、`tocItemId` 的引用目标合法
- 若短期内不想把全部约束下推到 SQL，也应先在 repository 层补最小防线

### 4. Step 1 的迁移 / 事务 / 读取边界仍缺少自动化回归

问题：

- 当前仓库与本次导航重构直接相关的自动化测试只有 [`../../test/services/navigation/navigation_builder_test.dart`](../../test/services/navigation/navigation_builder_test.dart)
- 数据库升级、旧书默认落 `legacy_pending`、非 `ready` 状态读不到 V2、`saveNavigationDataV2Ready` 的事务回滚与 `resetNavigationDataToLegacy` 清理边界，目前没有对应测试
- 当前进度文档也明确写到：UI 还没有命中 `saveNavigationDataV2Ready`，若要验证 Step 1 事务接口，需要额外 harness 或调试入口

风险：

- 当前 Step 1 的“不会误读半成品 V2 数据”更多是代码静态推断，而不是执行验证
- 一旦后续继续接 Step 2 / Step 3，没有数据库层回归测试，迁移默认值、事务顺序和失败清理很容易静默退化
- 尤其是旧库升级场景，若没有 migration test，很难证明旧书一定稳定初始化为 `legacy_pending`

审查补充：

- 本次复核期间再次尝试执行 `flutter test test/services/navigation/navigation_builder_test.dart`
- 该命令在当前环境下仍然超时，未能得到可靠执行结果；因此现有 focused tests 也未在本次 review 中完成运行确认

建议调整：

- 至少补一组 repository / database 层定向测试，覆盖：
  - migration 后旧书默认字段值
  - `ready` 写入成功时的单书事务完整提交
  - 中途失败时不会残留 `reader_documents` / `toc_items` / `reading_progress_v2`
  - `legacy_pending` / `failed` 状态下 V2 查询返回空结果
  - `resetNavigationDataToLegacy` 后状态与 V2 数据同步回退

## 当前可保留结论

- 当前阅读页仍只消费 legacy `chapters`，因此旧书不会因为本次 Step 1 改动被提前切到 V2
- 当前 repository 侧已经把 V2 读取前提收敛为 `ready + version 2`，这一点应继续保持，后续 Step 2 / Step 3 不应绕过该边界
- 新导入书籍仍先写 legacy 状态这件事属于 Step 2 未完成项，不应混入本次 Step 1 审核结论

## 对后续推进的约束建议

- 在修复本文问题前，不建议把当前 Step 1 实现直接视为“V2 数据边界已完全收口”
- Step 2 接新书直达 `ready` 前，应先修正真实 TOC 来源和 `tocSourcePath` 解析基准问题
- Step 2 / Step 3 开始复用 `saveNavigationDataV2Ready` 前，应先把 `ready` 的最小完整性校验补齐
- 在继续推进旧书重建状态机前，应先补最小数据库回归测试，否则事务边界只能靠人工推断
