# Reader Chapter Navigation Rewrite Plan Blockers

Date: 2026-03-22

## 文档定位

- 本文记录对 [`../plan/chapter_navigation_rewrite_plan.md`](../plan/chapter_navigation_rewrite_plan.md) 的严格审核结论，聚焦当前仍阻塞直接实施的方案级问题
- 本文属于 `docs/problem/` 下的 blocker 文档；若这些问题被 plan 吸收并关闭，应更新或归档本文
- 若与 [`./chapter_navigation_rework.md`](./chapter_navigation_rework.md) 冲突，以 Phase 1 约束文档为准；本文只指出当前 plan 的切片依赖、验证路径和落地边界仍有空洞

## 当前结论

- 当前 rewrite plan 的总体方向正确，与 Phase 1 约束文档没有根本冲突
- 截至 2026-03-22，Step 0 和 Step 1 已经开始落地，原始 blocker 中的 1 / 4 / 5 已通过 plan 调整和代码实现基本关闭
- 当前剩余 blocker 主要收敛为：`current document` 判定的前置归属、以及旧书重建触发者与同会话切换责任
- 因此后续可以继续推进 Step 2，但在 blocker 2 / 3 关闭前，不应直接并行推进旧书重建接线和阅读器 V2 交互接线

## 2026-03-22 进度回写

- 已关闭 blocker 1：
  最小 `ReadingProgressV2` 契约已经前移到 Step 1，`ready` 事务写入入口已具备 `reader_documents`、`toc_items`、`reading_progress_v2` 和书籍状态切换的完整接口形态
- 已关闭 blocker 4：
  Step 0 已补纯数据导航 builder 和 focused tests，路径规范化、TOC 线性化、usable spine / fallback、标题派生和 `DocumentNavItem[]` 派生已有稳定断言基线
- 已关闭 blocker 5：
  数据库迁移、V2 entity、单书事务写入入口、单书 V2 清理入口和 legacy / V2 读取选择边界已经显式落在 repository / database 层
- 仍未关闭 blocker 2：
  `current document` 判定尚未成为阅读器交互的统一基础能力
- 仍未关闭 blocker 3：
  旧书重建触发者、`rebuilding` 期间只读 legacy、以及同会话是否切换到 V2 的时序责任还未明确落地

## 阻塞问题

### 1. 第 3 步与第 5 步存在事务依赖冲突

问题：

- plan 第 3 步要求“新导入书籍直接原子写入 V2 ready 状态”
- 但 Phase 1 约束要求 `ready` 的单书事务内同时完成 `reader_documents`、`toc_items`、`reading_progress_v2` 和书籍状态切换
- 当前 plan 却把 V2 进度模型和 legacy 映射整体放到了第 5 步，导致第 3 步缺少完整的 `ready` 写入定义

为什么会阻塞：

- 若第 3 步先实现“ready 但没有明确定义的 `reading_progress_v2` 写入”，实现会被迫引入临时占位逻辑
- 后续第 5 步再补真实进度语义时，等于重写一次切换事务
- 这会扩大迁移面，也会增加旧书重建和新书导入两条链路的返工概率

建议调整：

- 把最小 `ReadingProgressV2` 契约前移到更早阶段
- 第 3 步若仍保留“新导入直达 ready”，则必须同时明确默认写入策略、空值策略和 legacy 映射边界
- 更稳妥的切法是：先完成最小 V2 进度写入契约，再做“新导入直达 ready”

### 2. “当前文档识别”不能被推迟到第 5 步

问题：

- plan 第 4 步已经要求实现按 `documentIndex` 的上一章 / 下一章和目录跳转
- 但 plan 第 5 步才提出“当前文档识别与 `documentProgress` 计算逻辑”
- 连续滚动阅读里，“当前文档识别”并不只是进度问题，它同时是当前目录状态、上一章 / 下一章、恢复位置和后续高亮能力的共同基础

为什么会阻塞：

- 如果第 4 步先做 UI 控件和跳转，而第 5 步才补当前文档判定，工程上很容易产生一套临时逻辑
- 临时逻辑后续大概率会和真正的进度保存 / 恢复逻辑重复或冲突
- 这会让阅读器行为在不同交互入口之间失去单一真相来源

建议调整：

- 把“当前文档识别”从第 5 步拆出来，作为阅读器 V2 交互前的基础能力
- 第 4 步只在已有统一 `current document` 逻辑的前提下接入目录点击、上一章 / 下一章和底部状态

### 3. 旧书重建触发者与同会话切换责任没有写清楚

问题：

- plan 第 3 步和第 4 步默认旧书可以在打开时触发重建，并在完成后切换读取链路
- 但当前代码基线里，阅读页是通过路由 `extra` 直接拿一个 `Book` 快照进入，页面本身只消费 `chaptersProvider`
- plan 还没有明确：谁负责触发单书重建、谁负责监听 `navigation_rebuild_state`、以及在同一次阅读会话中何时从 legacy 切到 V2

为什么会阻塞：

- 如果没有明确的 session/provider 边界，实现很容易退化成“重建成功但当前阅读页仍停留在 legacy，需要退出重进才切换”
- 这类切换时序问题通常不是数据库层能单独兜住的，必须在读取入口和会话状态层先定义清楚

建议调整：

- 在旧书重建落地前，先补一层按 `bookId` 驱动的阅读会话 provider 或等价读取选择器

需要明确的责任归属：

- 谁发起 `legacy_pending -> rebuilding`
- 谁在 `rebuilding` 期间强制只读 legacy
- 谁在事务提交后感知 `ready` 并触发 V2 重新加载
- 是否允许当前页面热切换，还是统一规定“本次会话保持 legacy，下次进入切到 V2”

### 4. 验证路线还是“场景清单”，不是“可重复样例”

问题：

- 当前 plan 已经列出较完整的 EPUB 场景，但大多仍停留在手工测试视角
- Phase 1 的核心要求是同一本 EPUB 在相同版本和算法下得到稳定的 `documentIndex`、`TocItem.order`、`targetDocumentIndex` 和 `DocumentNavItem.title`
- 这些都是非常适合用 example / fixture 固化的纯数据断言

为什么会阻塞：

- 如果先做数据库和 UI，再靠手工回归这些稳定性约束，定位问题会非常慢
- 当前仓库几乎没有章节导航相关测试基线，后续一旦改 builder、规范化或 fallback 规则，极易出现“看起来能读，但映射静默漂移”

建议调整：

- 增加一个显式的 Step 0：先做少量 fixture EPUB 或 builder 输入样例

优先固化的纯数据验证项：

- 路径规范化
- TOC 线性化
- usable spine / fallback
- `ReaderDocument.title` 派生
- `DocumentNavItem[]` 派生
- 至少先固定 4 到 6 个高价值样例，再让数据库迁移和 UI 接入建立在这些断言之上

### 5. repository / database 切片还不够具体

问题：

- plan 第 1 步写了“数据库与领域模型”，但没有把单书事务、失败清理、半成品隔离、V2 删除重建 API 这些接口形态说清楚
- 当前仓库的 `BookRepository` 仍完全围绕 `Book`、`Chapter` 和旧 `ReadingProgress` 设计
- 如果第 1 步只做 schema 和 entity，不同时明确 repository 边界，后续状态流转逻辑很容易分散到 provider 或 UI

为什么会阻塞：

- 重建流程的核心不是“表建出来”，而是“谁拥有单书事务和失败清理”
- 这部分一旦落错层，后续要把读取链路、重建状态机和导入原子切换再拉回 repository，会出现明显返工

建议调整：

第 1 步应显式补齐的产出：

- 单书事务写入入口
- 单书 V2 数据清理入口
- legacy / V2 读取选择的 repository 边界
- `rebuilding` 半成品不可读的保证方式
- 旧书删除、重新导入和重建失败时的清理归属

## 建议调整后的推进切片

1. Step 0: fixture / example 驱动的导航模型原型与纯数据断言
2. 数据库迁移 + V2 entity + 单书事务 / 清理 repository API + 最小 `ReadingProgressV2` 契约
3. 新导入书籍直达 `ready`，先只覆盖新书路径
4. 旧书 `legacy_pending -> rebuilding -> ready / failed` 状态机 + 阅读会话读取切换边界
5. 阅读器 V2 渲染、目录交互、上一章 / 下一章，以及统一的 `current document` 判定
6. V2 进度保存 / 恢复与 legacy 进度 best-effort 映射
7. legacy 导航职责清理

## 对后续推进的约束建议

- 在 blocker 未关闭前，不建议直接进入大范围数据库改造加 UI 接线并行推进
- 先通过小样例把 builder 的稳定性压实，再把事务、状态机和阅读页行为一层层接上
- 每推进一层，都应优先证明“失败可回退、重复构建结果一致、不会暴露半成品 V2 数据”
- 若后续决定允许“当前阅读会话内热切换到 V2”，必须单独补充该行为的时序说明和验证用例
