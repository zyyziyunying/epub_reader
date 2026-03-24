# Reader Chapter Navigation Rewrite Plan

Date: 2026-03-24

## 文档定位

- 本文用于记录章节导航重构的实施推进方案、推荐落地顺序和验证路线
- 本文是 guiding 文档，不替代绑定约束；若与 [`../problem/chapter_navigation_rework.md`](../problem/chapter_navigation_rework.md) 冲突，以 `docs/problem/` 中的约束文档为准
- 若后续实施方式明显变化，应更新本文；若方案边界本身变化，应先修改 `docs/problem/`
- 当前阶段状态同步见 [`../progress/chapter_navigation_rewrite_progress.md`](../progress/chapter_navigation_rewrite_progress.md)

## 当前代码基线

截至 2026-03-24，当前代码已推进到 Step 6，状态如下：

- Step 0 已落：
  - 导航 builder
  - `ReaderDocument` / `TocItem` / `DocumentNavItem`
  - builder focused tests
- Step 1 已落：
  - `books` 导航状态字段
  - `reader_documents` / `toc_items` / `reading_progress_v2`
  - repository 单书事务写入 / 清理入口
  - legacy / V2 读取选择边界
  - 最小 `ReadingProgressV2` 默认写入策略
- Step 2 已落：
  - 新导入书籍主链路现已直接生成并写入 V2 `ready` 数据
  - 新书导入失败不会留下 V2 半成品或残留书籍记录
- Step 3 已落：
  - 旧书 `legacy_pending -> rebuilding -> ready / failed` 重建状态机
  - 按阅读页实例建立的会话读取选择器
  - Phase 1 默认策略：当前会话保持 legacy，下次进入切到 V2
- Step 4 已落：
  - 阅读器 `ready` 会话已改为按 `ReaderDocument[]` 渲染
  - 目录抽屉只消费 `DocumentNavItem[]`
  - 上一章 / 下一章已按 `documentIndex` 生效
- Step 5 已落：
  - V2 进度保存 / 恢复已切到 `documentIndex + documentProgress`
  - legacy `chapterIndex + scrollPosition` 已接入 best-effort 映射，但不阻塞 `ready`
- Step 6 正在推进，但本轮已完成一轮关键收口：
  - 新导入且直接 `ready` 的书不再额外持久化 legacy `chapters`
  - repository 的 legacy 降级入口现已拒绝把“无 persisted legacy fallback 的 V2-only `ready` 书”切回 `legacy_pending / rebuilding / failed`
  - coordinator / repository 已补出独立的 `ready-preserving refresh` 官方入口，刷新期间旧 V2 保持可读，成功后原子替换，失败时保持旧 V2 和 `ready` 状态不变
  - `ready-preserving refresh` 现已补上显式能力判断与事务内断言，只允许“无 persisted legacy fallback 的 V2-only `ready` 书”进入
  - legacy fallback UI 现已按 `loading / error / empty / available` 四态分流；正文区、底栏和抽屉不再把 error 伪装成 loading

当前代码暂不保证：

- Step 6 整体完成；旧书 fallback 正文链路和 legacy 进度映射输入仍在
- 完全移除 `Chapter` 在过渡期兼容中的职责
- Phase 2 范围内的原始 `TocItem` 树目录、`href#anchor` 精确跳转和更细粒度目录高亮

这意味着后续工作不应再尝试给 legacy 逻辑打补丁，而应直接围绕 V2 模型补齐数据链路和阅读器能力。

## 推进原则

- 先落数据契约和切换边界，再接阅读器交互；不要先恢复 UI 入口再补底层
- 先把 V2 链路做成“可并行存在、可按书切换、失败可回退”，再考虑删除 legacy 职责
- 优先做 example / fixture 驱动的纯数据验证，再做 repository 变更和阅读页行为
- “当前文档识别”属于阅读器交互基础能力，不能晚于目录跳转和上一章 / 下一章
- 旧书重建必须先定义触发者、读取选择器和同会话切换策略；Phase 1 默认不要求会话内热切换
- 旧书 `legacy_pending / rebuilding / failed` 仍需在失败场景下保留 Phase 0 最小阅读体验；但 V2-only `ready` 书后续刷新不得再降回 legacy，而应保持 `ready` 可读并做原位刷新

## 建议实施顺序

### 0. fixture / example 驱动的导航模型原型与纯数据断言

目标：

- 先在不接数据库、不接 UI 的前提下固定导航模型构建输出
- 把路径规范化、TOC 线性化、usable spine / fallback、标题派生和 `DocumentNavItem[]` 派生压成可重复断言

建议产出：

- 4 到 6 个高价值 fixture EPUB 或等价 builder 输入样例
- 面向 `ReaderDocument[]`、`TocItem[]`、`DocumentNavItem[]` 的纯数据断言
- 覆盖相同输入重复构建时输出稳定性的测试辅助

完成后应能验证：

- 同一输入重复构建得到一致的 `fileName -> documentIndex` 映射
- `TocItem.order`、`targetDocumentIndex` 和 `DocumentNavItem.title` 稳定
- 标题 fallback、路径规范化和正文候选判定不依赖 UI 二次猜测

### 1. 数据库与领域模型 + repository 边界

目标：

- 为 `ReaderDocument`、`TocItem`、`reading_progress_v2` 和书籍级导航状态字段落库
- 建立 V2 所需的 entity、repository 和 provider 接口
- 明确 repository 拥有单书事务、失败清理、半成品隔离和 legacy / V2 读取边界
- 把最小 `ReadingProgressV2` 契约前移，为 `ready` 写入提供完整定义

建议产出：

- 数据库 schema migration
- `Book` 上的导航状态字段
- `ReaderDocument`、`TocItem`、`ReadingProgressV2` 实体
- 单书事务写入入口
- 单书 V2 数据清理 / 重置入口
- legacy / V2 读取选择的 repository 边界
- 最小 `ReadingProgressV2` 默认写入策略与空值语义
- V2 查询 / 写入 repository 方法

完成后应能验证：

- 新表可创建、可按书删除和重建
- 旧书升级后进入 `legacy_pending`
- repository 层不会误读半成品 V2 数据
- `ready` 状态的单书事务写入不依赖临时占位逻辑

### 2. 新导入书籍直达 `ready`

目标：

- 新导入书籍直接原子写入 V2 `ready` 状态
- 先只覆盖新书路径，不把旧书重建和同会话切换混在一起

建议产出：

- 新书导入事务化写入链路
- 与 `ready` 同事务提交的最小 `ReadingProgressV2` 写入
- 导入失败时的单书清理逻辑

完成后应能验证：

- 新书不会先落到 legacy 再切换
- 新书导入失败不会暴露半成品 V2 数据
- `ready` 写入路径不需要后补进度语义

### 3. 旧书重建状态机与阅读会话切换边界

目标：

- 旧书按书触发重建，并在失败或中断时回退
- 先明确谁触发重建、谁负责读取选择、以及同一次会话何时切换读取链路

建议产出：

- 旧书 `legacy_pending -> rebuilding -> ready / failed` 状态流转
- 按 `bookId` 驱动的阅读会话 provider 或等价读取选择器
- `rebuilding` 期间强制只读 legacy 的边界
- `ready` 提交后如何感知并重新加载的时序定义
- Phase 1 默认策略：本次会话保持 legacy，下次进入切到 V2；若改为热切换，需单独补行为文档和验证
- 中断恢复和失败清理逻辑

完成后应能验证：

- 旧书重建失败后仍可打开
- 中断恢复不会保留半成品 V2 数据
- 同一次阅读会话内不会出现“状态已 ready，但页面仍悬空在错误链路”的未定义行为

### 4. 阅读器 V2 渲染、统一 `current document` 判定与导航 UI

目标：

- 阅读页改为按 `ReaderDocument[]` 渲染
- 目录抽屉只消费 `DocumentNavItem[]`
- 上一章 / 下一章按 `documentIndex` 移动
- 把统一的 `current document` 判定作为目录状态、上一章 / 下一章和底部状态的共同基础

建议产出：

- 读取链路根据书籍状态选择 legacy 或 V2
- 统一的 `current document` 判定逻辑
- V2 阅读页正文列表
- 可点击的 `DocumentNavItem[]`
- Phase 2-only TOC 统一说明文案
- 文档级上一章 / 下一章

完成后应能验证：

- ready 书籍只走 V2
- 目录点击、上一章 / 下一章和底部状态共享同一套 `current document` 逻辑
- 目录点击只发生在 `DocumentNavItem[]`
- 含 `anchor` 或同文档多 TOC 节点的 EPUB 不会出现伪精确跳转

### 5. 进度保存与恢复

目标：

- 用 `documentIndex + documentProgress` 替代旧的 `chapterIndex + scrollPosition`
- 对旧进度做 best-effort 映射，但不阻塞 V2 启用

建议产出：

- V2 进度保存 / 恢复逻辑
- 基于统一 `current document` 判定的 `documentProgress` 计算逻辑
- legacy 进度映射逻辑

完成后应能验证：

- 重新打开时能回到同一 `ReaderDocument`
- 字体和间距变化后只允许文档内近似偏差
- 旧进度映射失败时不会阻塞打开

### 6. 稳定后再清理 legacy 导航职责

目标：

- 在 V2 链路稳定后，逐步移除 `Chapter` 在阅读器导航中的剩余职责
- 明确 V2-only `ready` 书未来的恢复 / 重建官方入口是独立的 `ready-preserving refresh`，而不是 legacy 降级

建议产出：

- 阅读器导航不再依赖 `Chapter`
- legacy 数据仅用于旧书过渡期 fallback 或历史兼容
- `ready-preserving refresh` 继续保持独立入口，不与 legacy 状态机复用
- repository / coordinator 对该入口继续保留“显式能力判断 + 事务内断言”的双层防线
- legacy fallback UI 继续显式区分 `loading / error / empty / available`
- 与旧定位逻辑相关的临时代码清理

完成后应能验证：

- 阅读器导航主链路只依赖 V2 数据
- legacy 逻辑不会与 V2 并存竞争
- “有 persisted legacy chapters 的 ready 书”不会误走 `ready-preserving refresh`
- legacy fallback 读取失败时，正文区、底栏和抽屉都显示失败语义，而不是沿用 loading 文案

## 推荐提交切片

截至 2026-03-24，切片 1 到 6 已完成；切片 7 正在推进，且已先收口 V2-only `ready` refresh blocker 与 legacy fallback 四态语义。

1. Step 0 fixture / example + 纯数据断言
2. 数据库迁移 + V2 实体 / repository 单书事务与清理接口 + 最小 `ReadingProgressV2` 契约
3. 新导入书籍直达 `ready`
4. 旧书重建状态机 + 阅读会话读取切换边界
5. 阅读器 V2 渲染、统一 `current document` 判定、目录交互和上一章 / 下一章
6. V2 进度保存 / 恢复 + legacy 映射
7. legacy 导航职责清理

## 验证推进方案

### 先固定可重复样例

- 不要先做完数据库和 UI 再靠手工回归验证导航契约
- Step 0 先固定 4 到 6 个高价值样例，至少覆盖普通 EPUB、usable spine 异常、fallback 路径、`href#anchor`、同文档多 TOC 节点和标题 fallback
- 优先对以下纯数据结果做固定断言：路径规范化、`ReaderDocument.documentIndex`、`TocItem.order`、`targetDocumentIndex`、`ReaderDocument.title`、`DocumentNavItem.title`

### 核心验证主题

1. 数据构建一致性
   以 [`../problem/chapter_navigation_rework.md`](../problem/chapter_navigation_rework.md) 中的“TOC 与正文映射契约”“路径来源与规范化基准”“`ReaderDocument.title` 唯一生成契约”“文档级导航派生规则”为准，优先通过 fixture / example 固化重复重建一致性、路径收敛、正文候选集判定和标题派生稳定性。
2. 目录与导航边界
   以约束文档中的“Phase 1 范围收敛”和“Phase 1 完成边界”为准，验证目录抽屉只消费 `DocumentNavItem[]`、Phase 2-only TOC 只显示统一说明、上一章 / 下一章只按 `documentIndex` 移动，且这些入口共享统一的 `current document` 判定。
3. 原子切换与失败回退
   以约束文档中的“V2 迁移与切换约束”为准，验证单书事务写入、中断恢复、失败清理、同会话切换策略，以及两类失败语义：
   - 旧书重建失败时稳定回退到 Phase 0 最小阅读体验
   - V2-only `ready` 书刷新失败时保持旧 V2 和 `ready` 状态不变，不降回 legacy
4. 进度保存与恢复
   以约束文档中的“进度模型定义”和“旧进度处理策略”为准，验证 `documentIndex + documentProgress` 的保存 / 恢复、legacy 进度 best-effort 映射不阻塞打开，以及 `ready-preserving refresh` 只 best-effort 继承 `documentIndex + documentProgress`

### 必测 EPUB 场景

- TOC 顺序与正文顺序一致的普通 EPUB
- spine 含 `linear="no"` item 的 EPUB
- manifest 或 `book.Content.Html` 中存在非 spine 正文文件的 EPUB
- manifest 声称为 HTML/XHTML、但 `book.Content.Html` 中缺失对应正文的 EPUB
- spine 缺失或不可用、必须触发 fallback 的 EPUB
- OPF、nav/NCX、正文文件位于不同目录且通过相对路径互相引用的 EPUB
- TOC 指向 `href#anchor` 的 EPUB
- 同一 XHTML 文件含多个 TOC 节点的 EPUB
- 只有 `anchor` TOC 节点、或所有匹配 TOC 标题为空白的 EPUB
- 路径包含 `../`、`./` 或 percent-encoding 的 EPUB
- 标题缺失、标题质量较差或只能回退到文件名的正文文件
- 图片较多、文档长短差异明显的内容
- 已按旧模型导入过的遗留书籍
- 旧书首次打开时重建中断、失败、重试的场景

### 回归范围

- 导入书籍
- 打开阅读页
- 目录展开与关闭
- 阅读设置变更
- `last_read_at` 更新
- 旧书删除和重新导入

## Phase 2 暂缓项

- 原始 `TocItem` 树直接驱动目录 UI
- `href#anchor` 精确跳转
- 同一正文文件多个目录节点
- 更细粒度的当前目录高亮
- HTML 内部锚点映射
- EPUB CFI
