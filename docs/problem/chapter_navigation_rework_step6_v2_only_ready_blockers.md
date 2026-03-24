# Reader Chapter Navigation Rework Step 6 V2-only Ready Blockers

Date: 2026-03-24

Status: closed as of 2026-03-24. The dedicated coordinator / repository `ready-preserving refresh` entrypoint is now paired with an explicit V2-only capability guard, and legacy fallback UI no longer conflates `error` with `loading`.

## 文档定位

- 本文记录 Step 6 新增并已关闭的方案级 blocker，聚焦“无 legacy fallback 正文的 V2-only `ready` 书”在未来需要重新构建、恢复或版本升级时的官方处理链路
- 本文属于 `docs/problem/` 下的专项 blocker 文档；当前代码和约束文档已吸收这些决策，后续可视需要归档本文
- 若与 [`./chapter_navigation_rework.md`](./chapter_navigation_rework.md) 冲突，以 Phase 1 约束文档为准；本文只负责把该文档中已经暴露、但尚未完全落地的恢复方案空洞显式收口

## 当前结论

- 当前 Step 6 已落的 repository 防御是正确的：对“新导入后直接 `ready` 且未持久化 legacy `chapters`”的 V2-only 书，官方入口不得再把它降回 `legacy_pending / rebuilding / failed`
- 当前这项 blocker 已完成一轮最小收口：官方入口已补为独立的 `ready-preserving refresh`，不再需要继续讨论是否复用 legacy 降级链路
- 2026-03-24 follow-up 已补齐，当前实现可视为“已闭环但可后续归档”的完成状态：
  - legacy fallback UI 现已把 `loading / error / empty / available` 四种状态显式分开，正文区、底栏和抽屉不再把读取失败伪装成“正在检查 / 加载”
  - `ready-preserving refresh` 现已补上显式能力判断与事务内断言，只允许“无 persisted legacy fallback 的 V2-only `ready` 书”进入该入口
- 推荐收口方向已经明确：
  - 这类书后续不再设计“降回 legacy”
  - 这类书的官方恢复链路应改为“保持 `ready` 可读的原位刷新”
  - 也就是：构建新 V2 payload 的整个过程中，旧 V2 仍保持当前唯一可读版本；只有替换事务成功提交后，新的 V2 才原子生效
- 后续不得新增任何调用点，把 V2-only `ready` 书重新送回 `markNavigationRebuildInProgress` 或 `resetNavigationDataToLegacy`

## 严格审核追加风险（2026-03-23，已于 2026-03-24 关闭）

### A. legacy fallback 读取失败时，部分 UI 仍把 error 伪装成 loading

问题：

- 阅读器正文区已经会在 legacy fallback 正文读取失败时显示错误
- 但底栏和抽屉当前通过 `legacyChaptersProvider(...).maybeWhen(..., orElse: () => null)` 读取数量
- 这会把 `loading` 和 `error` 都压缩成同一个 `null` 状态
- 结果是：同一会话里正文区可能已经显示失败，但底栏和抽屉仍然显示“Checking / Loading legacy fallback”

为什么严重：

- 这会把永久错误伪装成瞬时加载，直接污染诊断语义
- 用户会得到彼此矛盾的状态提示，难以判断当前到底是“还在等”还是“已经失败”
- 这与本次 blocker 想收紧的“失败语义必须明确”目标相冲突

建议收口：

- 底栏和抽屉不要再把 `AsyncValue.error` 合并进 `null`
- 至少要把 `loading / error / empty / available` 四种状态分开渲染
- focused tests 需要补齐 legacy fallback `error` 场景，确认正文区、底栏和抽屉的文案口径一致

已落地：

- 阅读页已新增显式的 legacy fallback 状态建模，正文区、底栏和抽屉统一复用该状态语义
- focused widget test 已覆盖 fallback 读取失败时的正文区 / 底栏 / 抽屉一致性

### B. `ready-preserving refresh` 的 API 边界仍未真正锁死在 V2-only `ready` 书

问题：

- 文档已经明确约束：该入口当前只应服务“无 legacy fallback 正文的 V2-only `ready` 书”
- 但 coordinator / repository 现有实现只校验了 `book.usesV2Navigation`
- 这意味着仍有 legacy fallback 的 `ready` 书也可以走这条入口

为什么严重：

- 一旦后续调用方把“仍有 legacy fallback 的旧书 ready 状态”也接到这条链路，就会绕开现有 legacy 状态机的失败可观测语义
- 当前文档要求的边界只存在于说明文字里，还没有变成代码级防线
- 这会让 `ready-preserving refresh` 从“V2-only 例外入口”逐步滑向“所有 ready 书通用入口”，重新把状态机职责搞混

建议收口：

- 在 coordinator 或 repository 层显式校验“无 legacy fallback 正文”这一前提
- 若当前仓库暂不方便判断该前提，至少要补一个明确命名的能力判断或单独断言，而不是只靠调用方自觉
- focused tests 需要覆盖“有 persisted legacy `chapters` 的 ready 书误走 refresh 入口”时的拒绝行为

已落地：

- repository 已新增显式能力判断，并在 `refreshNavigationDataV2Ready` 事务内再次断言该边界
- coordinator 已在解析前先拒绝“仍有 persisted legacy fallback 的 ready 书”
- focused tests 已覆盖 repository / coordinator 对该误用路径的拒绝行为

## 阻塞问题

### 1. 现有状态机无法表达 V2-only `ready` 书的安全重建

问题：

- 当前 `legacy_pending / rebuilding / failed` 的读取语义都建立在“仍可稳定读 legacy fallback 正文”之上
- 但 V2-only `ready` 书已经明确不再持久化 legacy `chapters`
- 一旦把这类书送回上述状态，当前会话和后续会话都会失去稳定正文来源

为什么会阻塞：

- 这不是单纯的 UX 文案问题，而是状态机语义本身已经不成立
- repository 虽然已经挡住了降级入口，但只靠“禁止调用”并不能替代未来的官方恢复链路
- 只要后续真的出现“重新构建 V2”需求，当前状态机仍缺少合法落点

建议收口：

- 对 V2-only `ready` 书，未来的“恢复 / 重建”不再复用 legacy 状态机
- Phase 1 最小方案下，这类书在重新构建期间继续保持 `navigation_data_version = 2`、`navigation_rebuild_state = ready`
- 旧 V2 payload 在新 payload 提交成功前持续可读；失败时也继续保留旧 V2，而不是把书籍切到 legacy 状态

### 2. 缺少与 legacy 重建入口分离的官方触发点

问题：

- 当前 coordinator 只有一条旧书重建路径：先 `markNavigationRebuildInProgress`，失败后再 `resetNavigationDataToLegacy`
- 这条路径天然假设“构建期间和失败后都还能安全回到 legacy”
- V2-only `ready` 书不能复用这条链路，但目前也没有新的 repository / coordinator 官方入口

为什么会阻塞：

- 若没有新的官方入口，后续任何“手动重试”“文件修复后重建”“同版本重新解析”“未来版本升级预备实现”都只能绕开当前 API
- 这会把状态切换逻辑重新散落到 provider、UI 或临时脚本里

建议收口：

- 为 V2-only `ready` 书单独定义“ready-preserving refresh”入口
- 责任边界建议如下：
  - coordinator 负责触发解析和串行化同一本书的刷新任务
  - repository 继续复用单书事务写入 `saveNavigationDataV2Ready` 作为最终原子替换点
  - 该刷新入口不得先写 `rebuilding`，也不得在失败时写回 `failed`

### 3. 原位刷新时的进度继承语义尚未固定

问题：

- 旧书 legacy -> V2 的 best-effort 映射已经固定为 `chapterIndex + scrollPosition -> documentIndex + documentProgress`
- 但 V2-only `ready` 书原位刷新时，应该如何继承现有 `reading_progress_v2`，当前还没有明确规则
- 若直接原样复用旧 `tocItemId` / `anchor`，会把“旧 payload 的引用合法性”误投到“新 payload 的引用合法性”上

为什么会阻塞：

- `saveNavigationDataV2Ready` 当前会校验 `documentIndex`、`tocItemId` 和目标文档引用
- 如果刷新链路对旧进度没有统一规范，很容易因为引用失效把本应成功的刷新事务整体打回

建议收口：

- Phase 1 的原位刷新只承诺 best-effort 继承 `documentIndex + documentProgress`
- `tocItemId` 和 `anchor` 在刷新时统一清空为 `null`
- 若旧 `documentIndex` 超出新 `ReaderDocument[]` 范围，则回退到最小初始进度，而不是让刷新事务失败

### 4. 刷新失败的可观测性不能复用 `navigation_rebuild_failed_at`

问题：

- `navigation_rebuild_failed_at` 当前只服务于 legacy 状态机中的 `failed` 语义
- 若 V2-only `ready` 书在原位刷新时失败，再写 `failed` 会直接破坏其唯一可读链路
- 但若完全不定义失败可观测性，后续又很难在 UI 或诊断层区分“当前书仍可读，但最近一次刷新失败”

为什么会阻塞：

- 这里混淆的是两类失败：
  - 旧书尚未 ready 时的“重建失败”
  - 已 ready 书的“保持可读前提下刷新失败”
- 如果继续复用同一状态字段，读取语义和诊断语义都会互相污染

建议收口：

- Phase 1 最小实现先不为“ready-preserving refresh”引入新的持久化失败状态字段
- 失败时保持书籍记录和现有 V2 payload 不变，由调用方接住异常并做日志或上层提示
- 若后续确实需要持久化“最近一次 ready 刷新失败”，应新增独立字段或独立任务记录；不得复用 `navigation_rebuild_failed_at`

## 推荐的最小落地方案

在不扩表的前提下，建议先固定以下 Phase 1 最小方案：

1. 仅对 `usesV2Navigation == true` 且无 legacy fallback 的书开放“原位刷新”入口
2. 刷新开始时不改动书籍状态，不清空当前 V2 数据
3. 先在内存中完成 EPUB 解析与新导航数据构建
4. 用“best-effort 保留 `documentIndex + documentProgress`、清空 `tocItemId` / `anchor`”的策略准备新的初始进度
5. 仅在单书事务成功提交后，用新 `reader_documents`、`toc_items`、`reading_progress_v2` 原子替换旧 V2
6. 任一解析或写入失败都保持旧 V2 和 `ready` 状态不变

## 关闭该 blocker 所需的最小产出

- 文档层：
  - 将 Phase 1 约束文档和 progress 文档同步到“V2-only `ready` 书采用 ready-preserving refresh，而不是 legacy 降级”这一口径
- 代码层：
  - 增加独立于 legacy 重建入口的 coordinator / repository 官方刷新入口
  - 继续保留 repository 对 legacy 降级入口的防御
- 测试层：
  - `ready` 的 V2-only 书刷新成功后仍保持 `ready`，且新 payload 生效
  - 刷新失败后仍保持旧 V2 可读，不写回 legacy 状态
  - 原位刷新时只 best-effort 继承 `documentIndex + documentProgress`

## 当前建议的下一步

- 本文 blocker 已可继续维持 `closed`；若后续不再需要保留审核上下文，可视情况归档
- 继续沿用独立的 `ready-preserving refresh` 入口，不要把后续版本升级或恢复需求重新并回 legacy 状态机
- 视产品需求再决定是否补 UI 侧的显式重试 / 恢复触发点
