# Reader Chapter Navigation Rework Step 1 Review Findings

Date: 2026-03-22

## 文档定位

- 本文记录对当前章节导航重构 Step 0 / Step 1 代码改动的审查结论，聚焦“已宣称完成的边界”中仍存在的实现偏差、事务风险和验证缺口
- 本文属于 `docs/problem/` 下的问题文档；当前 4 项 Step 1 finding 已在本轮修复并回写，本文保留为 closure record，后续若再出现新的 Step 1 级问题，应新开问题文档而不是继续沿用旧结论
- 若与 [`./chapter_navigation_rework.md`](./chapter_navigation_rework.md) 冲突，以 Phase 1 约束文档为准；本文只回写当前实现与约束之间的差距及修复状态

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

- 当前 UI 主链路仍停留在 legacy 阅读链路，旧书继续读取 `chaptersProvider`；这条结论未变
- repository 读取侧仍使用 `navigation_data_version == 2 && navigation_rebuild_state == ready` 作为 V2 可读前提；这条读取边界未变
- 本次回合已修复此前 4 项 Step 1 finding：
  - 真实 EPUB TOC 输入已对齐 `epubBook.Chapters`
  - `tocSourcePath` 缺失时不再按包根生成伪正确映射
  - `saveNavigationDataV2Ready` 已补最小完整性校验
  - Step 1 已补最小 database / repository 自动化回归
- 因此本文原本列出的 Step 1 边界问题当前可视为关闭；当前剩余主要风险已转移到 Step 3 的旧书状态机 / 阅读会话切换边界，以及 Step 4 的阅读器 V2 接线

## 修复回写

### 1. [已修复] 真实 EPUB TOC 输入已切回 `epubBook.Chapters`

当前状态：

- [`../../lib/services/navigation/navigation_source_adapter.dart`](../../lib/services/navigation/navigation_source_adapter.dart) 现已使用 `epubBook.Chapters` 生成 `tocRoots`
- adapter 不再直接以 `schema.Navigation.NavMap.Points` 作为应用层 TOC 入口
- 已新增 [`../../test/services/navigation/navigation_source_adapter_test.dart`](../../test/services/navigation/navigation_source_adapter_test.dart) 锁定该生产接入边界

说明：

- 本次修复的结论仍保持审慎口径：它解决的是“实现偏离绑定约束且缺少 adapter 级回归测试”的问题
- 这不额外宣称当前 `epubx 4.0.0` 内部解析语义已出现新的结构性分叉；只是把生产接入方式重新收敛到约束要求的唯一来源

### 2. [已修复] `tocSourcePath` 不可解析时改为 unresolved

当前状态：

- [`../../lib/services/navigation/navigation_builder.dart`](../../lib/services/navigation/navigation_builder.dart) 在 `tocSourcePath` 缺失时，若 `href` 仍需要相对路径基准，现会把该节点收敛为 unresolved
- 这类节点不会再静默生成伪正确的 `fileName` / `targetDocumentIndex`
- 已在 [`../../test/services/navigation/navigation_builder_test.dart`](../../test/services/navigation/navigation_builder_test.dart) 新增 focused case 覆盖该边界

当前口径：

- unresolved 的最小保证是：`fileName == null`、`targetDocumentIndex == null`
- 现实现仍保留可直接从 `href` 本身拆出的 `anchor` 元数据；这不影响 Phase 1 对“不可直接跳转”的判定

### 3. [已修复] `saveNavigationDataV2Ready` 已补最小完整性校验

当前状态：

- [`../../lib/data/repositories/book_repository_impl.dart`](../../lib/data/repositories/book_repository_impl.dart) 在写入前现已显式校验：
  - `ReaderDocument.documentIndex` 连续性
  - `ReaderDocument.id` / `documentIndex` / `fileName` 单书唯一性
  - `TocItem.order` 连续性
  - `TocItem.parentId`、`targetDocumentIndex`、`ReadingProgressV2.tocItemId` 引用合法性
- 因此 `ready` 现在更接近“完整可读的最小 V2 数据”，而不再只是“数据库可写”

仍保留的边界：

- 本次并未把全部约束下推到 SQL schema；当前最小防线主要在 repository 层
- 这符合本轮目标，但后续若 Step 2 / Step 3 进一步放大写入入口，仍可再评估是否需要增加更强的数据库级约束

### 4. [已修复] Step 1 已新增最小 database / repository 自动化回归

当前状态：

- 已新增 [`../../test/data/repositories/book_repository_impl_navigation_test.dart`](../../test/data/repositories/book_repository_impl_navigation_test.dart)
- 当前 focused tests 已覆盖：
  - migration 后旧书默认值
  - 非 `ready` 状态不暴露 V2
  - `ready` 成功写入与 `resetNavigationDataToLegacy` 回退
  - `saveNavigationDataV2Ready` 对不完整 payload 的拒绝
  - 数据库写入失败时的事务回滚不留半成品
- 本轮本地已运行：
  - `flutter test test/services/navigation/navigation_builder_test.dart test/services/navigation/navigation_source_adapter_test.dart test/data/repositories/book_repository_impl_navigation_test.dart`

## 当前可保留结论

- 当前阅读页仍只消费 legacy `chapters`，因此旧书不会因为本次 Step 1 修补被提前切到 V2
- repository 侧继续把 V2 读取前提收敛为 `ready + version 2`，后续 Step 3 / Step 4 不应绕过该边界
- “新导入书籍仍先写 legacy 状态”仅是 Step 1 收口时点的历史未完成项；当前状态已在文末的 Step 2 跟进补记中更新

## 剩余风险与后续约束

- 本文原 finding 已关闭，但 Step 3 / Step 4 仍未实现，因此不能把当前状态误判为“章节导航重构已完成”
- 旧书重建状态机、`rebuilding` 期间读取边界、同会话切换策略和阅读器 V2 UI 仍缺少定向验证
- 后续推进时，若再修改 V2 写入语义、读取选择器或旧书重建时序，应新增对应问题文档或测试，而不是沿用本文已关闭的 Step 1 finding 作为兜底

## 2026-03-22 暂存区严格复核补记

- 本节记录对当前 git 暂存区的追加严格检查结果
- 以下补记更新了上文“当前 4 项 Step 1 finding 已关闭”的口径：原 4 项问题仍可视为已修复；本节补记中新增暴露出的 2 项 Step 1 级别问题现也已修复，因此本节保留为 closure record，而不是继续作为未关闭问题列表
- 本节属于对本文的增补记录；后续若继续扩展同类问题，仍建议新开独立问题文档，避免把 closure record 和新问题长期混写

### 5. [已修复] adapter 现已锁定 `epubx 4.0.0` 的真实输入形态

当前状态：

- [`../../lib/services/navigation/navigation_source_adapter.dart`](../../lib/services/navigation/navigation_source_adapter.dart) 现会把 `epubx 4.0.0` 提供的 manifest 相对 `Content.Html` key 与 `EpubChapter.ContentFileName` 按 `ContentDirectoryPath` 统一解析为包内规范路径
- 因此当 `content.opf` 不在包根、真实输入仍保持 `Text/...` 形态时，builder 侧看到的 candidate html files、TOC target 与 manifest / spine 解析结果现已回到同一基准
- 已在 [`../../test/services/navigation/navigation_source_adapter_test.dart`](../../test/services/navigation/navigation_source_adapter_test.dart) 新增更接近真实 `epubx 4.0.0` 输出形态的 adapter + builder 回归测试，覆盖：
  - `opfBaseDir == 'OPS'`
  - `Content.Html` key 为 manifest 相对路径
  - `EpubChapter.ContentFileName` 为 manifest 相对路径
  - `ReaderDocument` 最终仍按 spine 顺序构建

当前口径：

- 本次修复收敛的是 `EpubNavigationSourceAdapter.fromEpubBook -> NavigationBuilder.build` 这条真实生产输入链路
- `NavigationBuilder` 直接消费手工构造 `NavigationSourceBook` 时，调用方仍应自行保证传入路径基准一致；本次没有把 builder 改造成同时猜测多套路径语义

### 6. [已修复] 当前“事务回滚”测试现已覆盖真正的部分写入后回滚

当前状态：

- [`../../test/data/repositories/book_repository_impl_navigation_test.dart`](../../test/data/repositories/book_repository_impl_navigation_test.dart) 的回滚用例现会先插入合法 `book`
- 用例随后通过数据库 trigger 人为制造“事务后半段失败”：
  - `reader_documents`、`toc_items`、`reading_progress_v2` 可先成功写入事务上下文
  - 最终 `books` 状态更新阶段被强制 abort
- 用例现已断言：
  - 事务异常抛出
  - 三张 V2 子表最终不留半成品
  - `books.navigation_data_version` 与 `navigation_rebuild_state` 保持 legacy 默认值

当前口径：

- 当前回归已能证明“前半段已成功写入事务上下文，后半段失败后整体回滚不留半成品”
- 本次仍未分别构造 `toc_items` 插入失败、`reading_progress_v2` 插入失败等更细粒度 SQL 失败点；若后续 repository 写入顺序调整，可再补更窄的定向测试

## 2026-03-22 Step 2 跟进补记

- 本文主体仍是 Step 1 closure record，原文中“新导入书籍仍先写 legacy 状态”这一描述仅代表 Step 1 收口时点的未完成项
- 截至同日后续 Step 2 落地：
  - 新导入书籍主链路已改为单书事务内直接写入 V2 `ready`
  - 导入失败时不会留下新书记录或 V2 半成品
  - 为维持当前阅读器 UI，导入链路仍会同时写入 legacy `chapters` 作为兼容数据
- 当前 Step 1 相关 closure 结论不变；后续剩余主要风险已进一步收敛到 Step 3 的旧书重建状态机与读取切换边界，以及 Step 4 的阅读器 V2 渲染接入
