# Reader Chapter Navigation Rewrite Plan

Date: 2026-03-22

## 文档定位

- 本文用于记录章节导航重构的实施推进方案、推荐落地顺序和验证路线
- 本文是 guiding 文档，不替代绑定约束；若与 [`../problem/chapter_navigation_rework.md`](../problem/chapter_navigation_rework.md) 冲突，以 `docs/problem/` 中的约束文档为准
- 若后续实施方式明显变化，应更新本文；若方案边界本身变化，应先修改 `docs/problem/`

## 当前代码基线

截至 2026-03-22，当前代码已经落在 Phase 0 清理后的最小阅读形态：

- 正文连续滚动阅读
- 目录列表展示，但章节项暂不可点击
- 阅读设置调整
- 进入阅读时更新 `last_read_at`

当前代码暂不保证：

- 章节点击跳转
- 上一章 / 下一章
- 章节 Slider 跳转
- 稳定的当前章节高亮
- 基于旧模型的进度恢复

这意味着后续工作不应再尝试给 legacy 逻辑打补丁，而应直接围绕 V2 模型补齐数据链路和阅读器能力。

## 推进原则

- 先落数据契约和切换边界，再接阅读器交互；不要先恢复 UI 入口再补底层
- 先把 V2 链路做成“可并行存在、可按书切换、失败可回退”，再考虑删除 legacy 职责
- 优先做可独立验证的纯数据构建与 repository 变更，再做依赖 UI 布局的阅读页行为
- 每一步都保持旧书在失败场景下仍能回到 Phase 0 最小阅读体验

## 建议实施顺序

### 1. 数据库与领域模型

目标：

- 为 `ReaderDocument`、`TocItem`、`reading_progress_v2` 和书籍级导航状态字段落库
- 建立 V2 所需的 entity、repository 和 provider 接口

建议产出：

- 数据库 schema migration
- `Book` 上的导航状态字段
- `ReaderDocument`、`TocItem`、`ReadingProgressV2` 实体
- V2 查询 / 写入 repository 方法

完成后应能验证：

- 新表可创建、可按书删除和重建
- 旧书升级后进入 `legacy_pending`
- repository 层不会误读半成品 V2 数据

### 2. 导航模型构建器

目标：

- 从原始 EPUB 稳定生成 `TocItem[]` 和 `ReaderDocument[]`
- 把路径规范化、usable spine / fallback、标题提取做成纯函数或最小副作用构建链路

建议产出：

- TOC 线性化逻辑
- 路径规范化逻辑
- 正文候选集判定逻辑
- `ReaderDocument.title` 生成逻辑
- `DocumentNavItem[]` 派生逻辑

完成后应能验证：

- 同一 EPUB 重复构建得到一致结果
- `targetDocumentIndex` 映射稳定
- 标题 fallback 不依赖 UI 二次猜测

### 3. 导入与旧书重建链路

目标：

- 新导入书籍直接原子写入 V2 ready 状态
- 旧书按书触发重建，并在失败或中断时回退

建议产出：

- 新导入事务化写入链路
- 旧书 `legacy_pending -> rebuilding -> ready / failed` 状态流转
- 中断恢复和失败清理逻辑

完成后应能验证：

- 新书不会先落到 legacy 再切换
- 旧书重建失败后仍可打开
- 中断恢复不会保留半成品 V2 数据

### 4. 阅读器 V2 渲染与导航 UI

目标：

- 阅读页改为按 `ReaderDocument[]` 渲染
- 目录抽屉只消费 `DocumentNavItem[]`
- 上一章 / 下一章按 `documentIndex` 移动

建议产出：

- 读取链路根据书籍状态选择 legacy 或 V2
- V2 阅读页正文列表
- 可点击的 `DocumentNavItem[]`
- Phase 2-only TOC 统一说明文案
- 文档级上一章 / 下一章

完成后应能验证：

- ready 书籍只走 V2
- 目录点击只发生在 `DocumentNavItem[]`
- 含 `anchor` 或同文档多 TOC 节点的 EPUB 不会出现伪精确跳转

### 5. 进度保存与恢复

目标：

- 用 `documentIndex + documentProgress` 替代旧的 `chapterIndex + scrollPosition`
- 对旧进度做 best-effort 映射，但不阻塞 V2 启用

建议产出：

- 当前文档识别与 `documentProgress` 计算逻辑
- V2 进度保存 / 恢复逻辑
- legacy 进度映射逻辑

完成后应能验证：

- 重新打开时能回到同一 `ReaderDocument`
- 字体和间距变化后只允许文档内近似偏差
- 旧进度映射失败时不会阻塞打开

### 6. 稳定后再清理 legacy 导航职责

目标：

- 在 V2 链路稳定后，逐步移除 `Chapter` 在阅读器导航中的剩余职责

建议产出：

- 阅读器导航不再依赖 `Chapter`
- legacy 数据仅用于过渡期回退或历史兼容
- 与旧定位逻辑相关的临时代码清理

完成后应能验证：

- 阅读器导航主链路只依赖 V2 数据
- legacy 逻辑不会与 V2 并存竞争

## 推荐提交切片

1. 数据库迁移 + V2 实体 / repository 接口
2. EPUB 导航模型构建器 + 纯数据测试
3. 新导入 / 旧书重建状态机 + 原子切换
4. 阅读器 V2 渲染、目录交互和上一章 / 下一章
5. V2 进度保存 / 恢复 + legacy 映射
6. legacy 导航职责清理

## 验证推进方案

### 核心验证主题

1. 数据构建一致性
   以 [`../problem/chapter_navigation_rework.md`](../problem/chapter_navigation_rework.md) 中的“TOC 与正文映射契约”“路径来源与规范化基准”“`ReaderDocument.title` 唯一生成契约”“文档级导航派生规则”为准，覆盖重复重建一致性、路径收敛、正文候选集判定和标题派生稳定性。
2. 目录与导航边界
   以约束文档中的“Phase 1 范围收敛”和“Phase 1 完成边界”为准，验证目录抽屉只消费 `DocumentNavItem[]`、Phase 2-only TOC 只显示统一说明、上一章 / 下一章只按 `documentIndex` 移动。
3. 原子切换与失败回退
   以约束文档中的“V2 迁移与切换约束”为准，验证单书事务写入、中断恢复、失败清理，以及旧书在失败场景下稳定回退到 Phase 0 最小阅读体验。
4. 进度保存与恢复
   以约束文档中的“进度模型定义”和“旧进度处理策略”为准，验证 `documentIndex + documentProgress` 的保存 / 恢复，以及 legacy 进度 best-effort 映射不阻塞打开。

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
