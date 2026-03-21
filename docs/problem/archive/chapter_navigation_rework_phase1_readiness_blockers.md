# Chapter Navigation Rework Phase 1 Readiness Blockers

Date: 2026-03-20

## 状态

本文件用于记录 `chapter_navigation_rework.md` 在“是否可进入 Phase 1 实施”标准下，本轮复审时重新打开的文档级问题。

本文件中的问题已全部关闭，并已归档。

- 总体状态：已解决，已归档
- 已解决：4 / 4
- 归档时间：2026-03-20

说明：

- `archive/chapter_navigation_rework_blockers.md` 记录的是上一轮已关闭问题
- 本文件记录的是 2026-03-20 这轮 readiness 复审中确认的 4 个 blocker，其中前 2 个是重点复核目标，后 2 个是为恢复“可直接实施”标准而一并补齐的配套 blocker
- 这 4 个 blocker 关闭后，`chapter_navigation_rework.md` 已恢复为可直接实施的 Phase 1 约束文档
- 归档后，本文件只保留为历史记录；若未来再出现新的方案级 blocker，应在 `docs/problem/` 新建新的活跃 blocker 文档

## 阻塞问题

### 1. `ReaderDocument.documentIndex` 的生成契约再次被重新打开

状态：已解决（2026-03-20）

当前主文档虽然定义了：

- `ReaderDocument` 优先按 spine 顺序生成
- fallback 顺序使用 `TocItem.order` 去重优先，再追加剩余正文文件

独立复核时确认，曾缺少可直接实施的唯一规则：

- 主文档只定义了 TOC `href` 要“按 TOC 来源路径”规范化，但没有定义 spine item、manifest href、`book.Content.Html` key 分别相对什么基准路径做同一套规范化
- `ReaderDocument` 候选集合、usable spine 判定、去重、fallback 追加和 `targetDocumentIndex` 匹配，仍可能因不同实现者选择不同基准路径而分叉
- 在这种情况下，即使文档保留了“重复重建必须稳定”的结论，也没有给出足以保证稳定的唯一生成前提

这不是实现细节，而是 Phase 1 的基础契约。`documentIndex` 同时被用于：

- 正文渲染顺序
- 上一章/下一章
- `TocItem.targetDocumentIndex`
- `documentProgress` 恢复

如果这里不先闭合，后续实现会在解析、迁移、阅读器三层出现分叉。

本项已通过以下调整关闭：

- 在主文档中新增“正文候选集与现有正文文件定义”，明确 `book.Content.Html` 是正文候选集的唯一来源
- 明确 manifest / spine / `book.Content.Html` 的职责边界：`book.Content.Html` 决定文件是否存在，manifest 负责路径映射，spine 负责顺序
- 明确 manifest item 即使声明为 HTML/XHTML，只要未进入 `book.Content.Html`，就不是“现有正文文件”，对应 spine item 也不得视为 usable
- 明确 fallback 追加“剩余正文文件”时，剩余集合只能来自正文候选集，不能来自其他未进入解析输出的 HTML/XHTML 资源
- 在主文档验收中新增“正文候选集判定验收”，要求覆盖 manifest-only HTML 资源、usable spine 判定和 fallback 追加边界

### 2. `DocumentNavItem.title` fallback 与 Phase 1 目录 UI 的唯一行为边界再次被重新打开

状态：已解决（2026-03-20）

当前主文档一方面写明：

- Phase 1 目录 UI 只渲染 `DocumentNavItem[]`

另一方面又要求：

- unresolved `TocItem`
- 带 `anchor` 的 TOC 节点
- 同文件多目录点节点

在 UI 中必须显式表现为“Phase 2 才支持”。

这两组约束目前不是同一件事：

- 如果 UI 只渲染 `DocumentNavItem[]`，那么细粒度 `TocItem` 根本不会出现
- 如果这些节点必须显式表现出来，就需要另一套 UI 呈现规则

独立复核时确认，主文档虽然已经选定“只展示 `DocumentNavItem[] + 一条统一说明`”这一唯一 UI 方案，但该方案仍依赖一个未定义前提：

- fallback 顺序依赖 `TocItem.order`
- `DocumentNavItem` 标题优先使用“第一个已匹配、`anchor == null` 且标题非空白的 `TocItem.title`”
- 但主文档没有定义 `epubBook.Chapters` 如何唯一展平为线性 `TocItem.order`

这会直接导致多人实现时至少出现两种分叉：

- 无 usable spine 的 EPUB，`ReaderDocument.documentIndex` 可能因为 `TocItem.order` 线性化方式不同而不同
- 同一 `ReaderDocument` 命中多个候选 `TocItem` 时，“第一个匹配标题”也可能因为线性化方式不同而不同

本项已通过以下调整关闭：

- 在主文档中新增 `ReaderDocument.title` 的唯一生成契约，明确标题只允许按“HTML `<title>` -> `h1..h6` -> file stem -> `fileName`”链路生成
- 明确标题候选文本的统一空白清洗规则，避免多人实现时对“空白标题”的判定不一致
- 明确 `DocumentNavItem.title` 的完整优先级链只允许是“最小 `TocItem.order` 的清洗后合格 `TocItem.title` -> `ReaderDocument.title`”
- 明确 `DocumentNavItem.title` 命中 `TocItem` 时也必须写入清洗后的标题文本，而不是保留原始字符串
- 明确 UI 层不得再以 HTML `<title>`、正文首标题、文件名或书名做二次标题猜测
- 在主文档验收中新增“标题契约验收”，要求同时覆盖“多命中时取最小 `TocItem.order` 且写入清洗后结果”“只有 `anchor` TOC 节点”“命中的 `TocItem.title` 全为空白”“完全没有命中 `TocItem`”四类场景

### 3. 迁移策略方向已定，但切换状态机仍不可执行

状态：已解决（2026-03-20）

当前主文档已经明确采用“新增 V2 导航数据 + 旧书按需重建”的路线，这是正确方向，但还缺少最少可执行状态机。

目前未定义清楚的点包括：

- 书籍层到底使用哪些状态字段，例如 `navigation_data_version`、`needs_navigation_rebuild`、`rebuild_failed_at`
- 何时允许从旧链路切到 V2 链路
- 哪一步算“重建成功”，切换是否要求原子完成
- 重建中断、部分写入、二次重试时如何处理旧数据和半成品 V2 数据
- 用户首次打开旧书且重建失败时，如何保证仍稳定回退到 Phase 0

如果这些规则不先写清楚，迁移步骤仍然只是方向，不足以指导实现。

本项已通过以下调整关闭：

- 在主文档中新增最小状态字段集合：`navigation_data_version`、`navigation_rebuild_state`、`navigation_rebuild_failed_at`
- 明确 `legacy_pending -> rebuilding -> ready/failed` 的唯一状态流转
- 明确 V2 启用只能发生在单书事务提交成功之后
- 明确中断恢复、失败清理、重试和 Phase 0 回退规则
- 明确新导入书籍必须直接原子落到 `ready`，不能先进入 legacy 状态

### 4. 验收标准还不足以证明“可以进入实现”

状态：已解决（2026-03-20）

当前主文档已经有完成标准和测试矩阵，但还缺少对核心承诺的验证闭环。

尚未被验收项覆盖的关键点包括：

- 同一本 EPUB 重复重建后，`ReaderDocument.documentIndex` 和 `targetDocumentIndex` 保持一致
- 迁移过程中断或失败后，不会暴露半成品 V2 数据
- Phase 1 目录 UI 对 unresolved/细粒度 TOC 节点的最终表现符合唯一方案
- 旧书升级失败后，仍能稳定停留在 Phase 0 最小阅读体验

当前测试矩阵更像“场景覆盖”，还不是“稳定性承诺的验证定义”。

本项已通过以下调整关闭：

- 在主文档中把重复重建一致性写入 Phase 1 完成标准
- 新增迁移失败、中断恢复、原子切换的闭环验收
- 新增目录 UI 最终行为验收，明确只允许 `DocumentNavItem[] + 一条统一说明`
- 新增 Phase 0 回退路径验收，并补入遗留书失败/重试场景

## 解除阻塞的判定条件

以下条件全部满足后，才允许进入 Phase 1 实施：

1. `chapter_navigation_rework.md` 与本文件状态保持一致，并恢复为可直接实施的 Phase 1 约束文档
2. 本文件中确认的 4 个阻塞项被逐条关闭
3. 主文档中的范围、映射、迁移、验收定义已更新为唯一且可执行的版本
4. 本文件从活跃 blocker 清单转为归档记录

判定结果：以上条件已满足。

## 备注

本文件是新一轮文档阻塞清单，不是实现方案本身。

本轮独立复核确认，以下内容仍可视为已闭合：

1. `manifest href`、spine item、TOC href、`book.Content.Html` key 的统一 `fileName` 规范化基准已定义
2. `epubBook.Chapters -> TocItem.order` 的唯一展平与编号规则已定义
3. 迁移状态机、原子切换、中断恢复与 Phase 0 回退主流程已定义
4. 验收矩阵已覆盖重复重建、路径规范化、目录 UI 边界与迁移失败闭环方向

本轮归档的 4 个 readiness blocker 已全部关闭：

1. `ReaderDocument.documentIndex` 已补齐正文候选集 / 现有正文文件的唯一判定前提
2. `DocumentNavItem.title` 已补齐命中 `TocItem` 与无合格 `TocItem` 两条路径上的唯一标题契约
3. 迁移切换状态机已补齐到可直接实施的最小可执行版本
4. 验收标准已补齐到可验证稳定性承诺的闭环版本
