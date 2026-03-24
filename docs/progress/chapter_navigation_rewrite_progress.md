# Reader Chapter Navigation Rewrite Progress

Date: 2026-03-24

## 文档定位

- 本文用于同步章节导航重写的当前进度、已完成切片、剩余 blocker 和测试入口
- 本文属于 `docs/progress/`，只汇报现状，不单独定义实现约束
- 绑定约束见 [`../problem/chapter_navigation_rework.md`](../problem/chapter_navigation_rework.md)
- 推进顺序见 [`../plan/chapter_navigation_rewrite_plan.md`](../plan/chapter_navigation_rewrite_plan.md)

## 当前阶段结论

- 当前代码已完成 Step 0、Step 1、Step 2、Step 3、Step 4 和 Step 5；Step 6 仍在推进，但本轮已完成 V2-only `ready` refresh blocker 收口
- 用户可见阅读体验现已按阅读会话数据源分流：`ready` 会话走 V2 `ReaderDocument[]` 渲染与文档级导航；`legacy_pending / rebuilding / failed` 或当前会话保持 legacy 的场景，仍继续走 Phase 0 / legacy 链路
  - 当前已确认：
  - `bookReadingDataSourceProvider` 仍承担“阅读会话读取选择器”职责，并按阅读页实例建立真实会话边界：旧书首次打开会触发后台重建，`rebuilding` 中断会先回退到 `legacy_pending` 再重试，当前会话保持 legacy，不做热切换；同一进程内关闭再打开同一本书时会重新判定，而不是复用首次 `bookId` 缓存
  - repository 读取侧仍以 `navigation_data_version == 2 && navigation_rebuild_state == ready` 作为 V2 可读前提
  - `saveNavigationDataV2Ready` 现在才可近似视为“最小完整 V2 ready 数据”的入口，而不是仅仅“能写进 SQL 的 payload”
  - 新导入书籍会在单书事务内写入 `reader_documents`、`toc_items`、最小 `reading_progress_v2`，并直接落库为 `ready`
  - Step 6 当前已先清掉两处剩余 legacy 导航职责：
    - 新导入且直接 `ready` 的书不再额外持久化 legacy `chapters`
    - legacy 会话的目录抽屉不再把 `Chapter` 渲染成目录列表，而是仅显示 fallback 说明
    - 新导入 `ready` 书的 `Book.totalChapters` 已改为采用 V2 `ReaderDocument[]` 数量，不再沿用 legacy `parsedEpub.chapters.length`
    - legacy drawer 的数量提示已改为使用当前会话实际加载到的 fallback 正文数，而不是 `book.totalChapters`
    - repository 的官方降级入口现已拒绝把“无 legacy fallback 正文的 `ready` 书”切回 `legacy_pending / rebuilding / failed`
    - legacy fallback 正文为空时，阅读页正文区、底栏和抽屉都会显示恢复提示，不再误报“continuous reading available”
  - Step 6 已正式补出专项 blocker：V2-only `ready` 书若未来需要恢复或重建，不再设计为降回 legacy，而应走独立的“保持 `ready` 可读的原位刷新”链路
  - coordinator / repository 已补出独立的 `ready-preserving refresh` 官方入口：刷新期间旧 V2 保持可读，成功后原子替换，失败时保持旧 V2 和 `ready` 状态不变
  - `ready-preserving refresh` 现已补上显式能力判断与事务内断言，只允许“无 persisted legacy fallback 的 V2-only `ready` 书”进入该入口；focused tests 已覆盖拒绝旧 ready 书误用该入口
  - legacy fallback UI 现已按 `loading / error / empty / available` 四态分流；focused widget tests 已覆盖 fallback 读取失败时正文区、底栏和抽屉的失败语义一致性
  - V2 阅读页现已只消费 `ReaderDocument[] + TocItem[]` 派生出的 `DocumentNavItem[]`，不再渲染原始 `TocItem` 行
  - V2 阅读页代码路径现已接入 `documentIndex + documentProgress` 的恢复与保存；focused tests 已覆盖 ready 会话内的恢复/保存、`AppLifecycleState.paused / hidden` flush，以及 legacy 会话不读不写 V2 进度
  - 旧书后台重建代码路径现已接入 legacy `chapterIndex + scrollPosition -> documentIndex + documentProgress` 的 best-effort 映射；focused tests 已覆盖唯一命中成功路径，以及 progress 缺失 / 映射 miss / 多文档歧义都不阻塞 `ready`

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

### Step 4: 阅读器 V2 渲染、统一 `current document` 判定与导航 UI

- `lib/presentation/providers/book_providers.dart` 已新增：
  - `readerNavigationDataProvider`
  - `ReaderDocument[] + TocItem[] -> DocumentNavItem[]` 的阅读页派生入口
- `lib/services/navigation/document_navigation.dart` 已抽出共享规则：
  - `DocumentNavItem.title` 仍唯一按“合格 `TocItem.title` -> `ReaderDocument.title`”派生
  - Phase 2-only TOC 判定不再在 UI 层复制另一套逻辑
- `lib/presentation/screens/reader/reader_screen.dart` 现已：
  - 按阅读会话数据源在 legacy / V2 之间选择渲染链路
  - 在 V2 会话中按 `ReaderDocument[]` 连续渲染正文
  - 基于统一 `current document` 状态驱动底部状态、目录高亮和上一章 / 下一章
- `lib/presentation/screens/reader/widgets/reader_drawer.dart` 现已：
  - 只渲染 `DocumentNavItem[]`
  - 若存在 Phase 2-only TOC，只显示一条统一说明文案
- `lib/presentation/screens/reader/widgets/reader_bottom_bar.dart` 现已：
  - 在 V2 会话中提供按 `documentIndex` 的上一章 / 下一章
  - 在 legacy 会话中继续显示 fallback 文案
- 已新增 focused tests：
  - `test/presentation/screens/reader/reader_screen_test.dart`

### Step 5: V2 进度保存 / 恢复与 legacy 进度 best-effort 映射

- `lib/domain/repositories/book_repository.dart` / `lib/data/repositories/book_repository_impl.dart` 已新增：
  - `saveReadingProgressV2`
  - 仅在 `navigation_data_version = 2 && navigation_rebuild_state = ready` 时更新 `reading_progress_v2`
  - 增量保存前会校验当前 `ReaderDocument[]` / `TocItem[]` 边界，拒绝非法 `documentIndex`、不存在的 `tocItemId` 和 `targetDocumentIndex` 不一致的引用
  - `documentProgress` 写入前统一 clamp 到 `[0, 1]`
- `lib/services/navigation/navigation_rebuild_coordinator.dart` 现已：
  - 在旧书重建成功提交 `ready` 前读取 legacy `ReadingProgress`
  - 通过 `getChapter` 取回 legacy chapter 内容，并按 `chapter.content == ReaderDocument.htmlContent` 做 best-effort 映射
  - 代码路径约定为：仅在唯一命中时写入迁移后的 `ReadingProgressV2`；未命中或歧义时保持默认初始进度
- `lib/presentation/providers/book_providers.dart` 已新增：
  - 按阅读会话作用域隔离的 `readerInitialProgressV2Provider`
- `lib/presentation/screens/reader/reader_screen.dart` 现已：
  - 在 V2 会话进入时按已保存的 `documentIndex` 初始化列表位置
  - 基于 `ScrollablePositionedList` 的 item position + offset 控制恢复文档内近似位置
  - 基于统一 `current document` 判定计算 `documentProgress`
  - 对 V2 进度写入做 debounce，并在生命周期切换 / 页面销毁时 flush
  - legacy 会话不读取、不写入 V2 进度
- 已新增 focused tests：
  - `test/data/repositories/book_repository_impl_navigation_test.dart`
  - `test/services/navigation/navigation_rebuild_coordinator_test.dart`
  - `test/presentation/screens/reader/reader_screen_test.dart`
  - 当前已明确覆盖：
    - repository 对 `ready`/非 `ready` 的 V2 progress 写入门控，以及非法 `documentIndex` / `tocItemId` / `targetDocumentIndex` 引用被拒绝
    - ready 会话内的 V2 progress 恢复与保存
    - `AppLifecycleState.paused / hidden` 触发 V2 progress flush
    - legacy 会话不读取、不写入 V2 progress
    - legacy -> V2 best-effort 映射的唯一命中成功路径
    - legacy progress 缺失时仍可落为 `ready`
    - `chapter.content == document.htmlContent` 映射 miss 时不阻塞 `ready`
    - 多文档命中歧义时不阻塞 `ready`

### Step 6: legacy 导航职责清理

- 当前已启动的清理范围：
  - 新导入且直接 `ready` 的书不再持久化 legacy `chapters`
  - 新导入 `ready` 书的 `Book.totalChapters` 已与 V2 `ReaderDocument[]` 口径对齐
  - legacy 会话 drawer 不再把 `Chapter` 作为目录模型渲染，而是只显示 fallback 提示
  - legacy drawer 的数量提示已改为读取真实 fallback 正文数，不再复用 `Book.totalChapters`
  - reader / provider 文案开始把 legacy 路径收敛为“正文 fallback”，不再表达为正式导航能力
  - reader 侧 legacy 正文 provider / widget 已开始按 fallback 语义命名，避免继续把 `Chapter` 误用成主导航模型
- 当前仍保留的 legacy 职责：
  - 旧书 `legacy_pending / rebuilding / failed` 会话的连续正文 fallback 渲染
  - 旧进度 `ReadingProgress` 与 `Chapter.content` 作为后台重建 best-effort 映射输入
  - V2-only `ready` 书的刷新已切到独立入口；legacy 降级链路继续只服务仍有 fallback 正文的旧书状态机，详见 [`../problem/chapter_navigation_rework_step6_v2_only_ready_blockers.md`](../problem/chapter_navigation_rework_step6_v2_only_ready_blockers.md)

## 当前未完成切片

- Step 6：legacy 导航职责清理仍在进行中；旧书 fallback 正文链路和 legacy 进度映射输入尚未清理

## 当前可测试范围

- Step 0 的纯数据导航构建与断言
- adapter 到 builder 的真实 EPUB TOC 输入边界
- Step 1 的数据库升级默认值、旧书 legacy 回退、非 `ready` 状态读取隔离、`ready` 事务写入 / 回退，以及“前半段已写入、后半段失败”场景下的整体回滚
- Step 3 的旧书首次打开触发后台重建、中断恢复回退、失败清理和“当前会话保持 legacy”边界
- Step 4 的 V2 阅读页渲染、目录点击、Phase 2-only TOC 统一说明、上一章 / 下一章和 legacy fallback UI
- Step 5 的 repository 侧 V2 progress 写入门控与引用校验、ready 会话内的 V2 进度恢复/保存、生命周期 flush、legacy 会话不读不写 V2 进度，以及 legacy -> V2 best-effort 映射的唯一命中 / 缺失 / miss / 歧义路径
- Step 6 当前已落的小范围清理：新导入 `ready` 书不再写 legacy `chapters`，`Book.totalChapters` 已切到 V2 `ReaderDocument[]` 口径，legacy drawer 不再渲染 `Chapter` 目录列表且数量提示改为真实 fallback 正文数
- Step 6 当前已落的 V2-only `ready` refresh 入口：刷新成功后保持 `ready` 并原子替换新 payload，刷新失败后旧 V2 仍可读，progress 只 best-effort 继承 `documentIndex + documentProgress`，且 repository / coordinator 会拒绝仍有 persisted legacy fallback 的 ready 书误走该入口
- Step 6 当前已覆盖的 legacy fallback 失败语义：fallback 读取失败时，正文区、底栏和抽屉都会显式显示失败，不再误报“Checking / Loading”
- `Book` 新状态字段、V2 表结构、repository 新接口的静态闭合情况

## 当前不可通过 UI 直接测试的范围

- 旧书首次打开触发后台重建后的数据库状态切换与后续会话读取选择
- legacy -> V2 best-effort 进度映射的数据库写入细节

## 建议测试入口

1. 先跑 focused tests：
   `flutter test test/services/navigation/navigation_builder_test.dart test/services/navigation/navigation_source_adapter_test.dart test/data/repositories/book_repository_impl_navigation_test.dart test/services/navigation/navigation_rebuild_coordinator_test.dart test/presentation/providers/book_providers_test.dart test/presentation/screens/reader/reader_screen_test.dart`
2. 再做一次手工验证 legacy 回退：
   - 用现有书库数据启动应用
   - 确认旧书仍可打开阅读页
   - 确认旧书首次打开后不会阻塞进入阅读页
   - 若检查数据库状态，应可观察到旧书从 `legacy_pending / failed` 进入后台重建，并在成功后落为 `ready`
   - 确认 legacy 会话阅读页没有因为 Step 4 的 V2 UI 接入而崩溃
3. 手工验证新导入书籍：
   - 导入一本新 EPUB
   - 确认书籍记录已直接落为 `navigation_data_version = 2`、`navigation_rebuild_state = ready`
   - 确认新导入 `ready` 书不会再额外生成 legacy `chapters`
   - 确认阅读页已切到 V2 `ReaderDocument[]` 渲染，目录抽屉只展示 `DocumentNavItem[]`
   - 确认目录点击和上一章 / 下一章按 `documentIndex` 生效
4. 若后续继续推进 Step 6，应继续沿用现有 V2-only `ready` 原位刷新入口，再清理其他 legacy 导航职责；不要把 legacy 清理和现有进度回归混在同一批改动里
