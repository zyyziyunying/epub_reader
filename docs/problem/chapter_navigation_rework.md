# Reader Chapter Navigation Rework Constraints

Date: 2026-03-22

## 执行前置条件

阻塞问题归档：

- [`archive/chapter_navigation_rework_blockers.md`](./archive/chapter_navigation_rework_blockers.md)
- [`archive/chapter_navigation_rework_phase1_readiness_blockers.md`](./archive/chapter_navigation_rework_phase1_readiness_blockers.md)

截至 2026-03-20，本轮 readiness blocker 已全部关闭并归档。本文恢复为可直接实施的 Phase 1 约束文档；若后续再发现新的方案级空洞，必须先在 `docs/problem/` 补新的 blocker 文档，再继续实现。

## 文档定位

- 本文是章节导航重构的 Phase 1 约束文档，负责定义必须遵守的数据契约、迁移边界、UI 范围和验收口径
- 后续实施顺序、分批推进方式和验证路线见 [`../plan/chapter_navigation_rewrite_plan.md`](../plan/chapter_navigation_rewrite_plan.md)
- 若实现过程中再发现新的阻塞问题，应先补文档，再继续开发

## 为什么必须重写

- 旧版阅读器的章节导航能力建立在滚动高度估算和运行时 widget 定位上，不是基于 EPUB 原始 TOC 或稳定定位模型
- 旧 `Chapter` 同时承担正文渲染单元、目录项、跳转目标和进度锚点职责，模型边界错误
- 旧 `ReadingProgress` 仅保存 `chapterIndex + scrollPosition`，无法稳定表达阅读位置
- 因此 Phase 1 不再恢复 legacy 定位逻辑，而是直接切换到新的 V2 导航模型

## Phase 1 范围收敛

Phase 1 的稳定性边界明确如下：

- Phase 1 唯一保证的直接定位单元是 `ReaderDocument`
- `TocItem` 在 Phase 1 中会全量解析并保存，但并不等于“每个 `TocItem` 都具备直接跳转能力”
- Phase 1 的阅读器导航 UI 只提供文档级导航，不直接承诺对原始 TOC 的每个节点做精确跳转
- 阅读器中的“上一章/下一章”控制在 Phase 1 中按 `ReaderDocument` 移动，不按 `TocItem` 移动

### Phase 1 退化策略

- 导入阶段仍然保留完整 `TocItem[]`
- 阅读器目录 UI 在 Phase 1 只渲染文档级导航项 `DocumentNavItem`，该模型由 `ReaderDocument + TocItem` 派生，不要求落库
- `DocumentNavItem` 与 `ReaderDocument` 一一对应，因此每个可点击入口都只能跳到某个正文文档顶部
- 带 `anchor` 的 TOC 节点和同一正文文件内的多个 TOC 节点，在 Phase 1 中只保留元数据，不承诺单独可点击
- 这类细粒度 TOC 节点在 Phase 2 才升级为精确跳转目标

### Phase 1 目录 UI 唯一边界

- 阅读器目录抽屉在 Phase 1 只展示一组可点击列表：`DocumentNavItem[]`
- 原始 `TocItem` 树在 Phase 1 中不渲染为目录行，不提供禁用项，不提供“近似跳转”按钮
- 若本书存在任一 Phase 2 才支持的 TOC 节点，目录抽屉只额外展示一条不可点击的统一说明文案，不逐项枚举这些节点
- 统一说明文案的触发条件是：存在 `targetDocumentIndex == null` 的 `TocItem`，或存在 `anchor != null` 的 `TocItem`，或存在多个 `TocItem` 指向同一 `targetDocumentIndex`

### Phase 2-only TOC 判定规则

满足以下任一条件的 `TocItem`，都视为“Phase 2-only TOC”：

- `targetDocumentIndex == null`
- `anchor != null`
- 存在另一个 `TocItem` 与其共享同一 `targetDocumentIndex`

这些节点在 Phase 1 中必须被保留和持久化，但不能渲染成可点击目录项。

## 核心模型

### 正文渲染单元 `ReaderDocument`

最少字段：

- `id`
- `bookId`
- `documentIndex`
- `fileName`
- `title`
- `htmlContent`

用途：

- 阅读器正文数据源
- 稳定跳转的基础单元
- 进度恢复的定位基础

### 目录项 `TocItem`

最少字段：

- `id`
- `bookId`
- `title`
- `order`
- `depth`
- `parentId`
- `fileName`
- `anchor`
- `targetDocumentIndex`

用途：

- 保留 EPUB 原始目录元数据
- 为 Phase 1 派生文档级导航项提供来源
- 为 Phase 2 目录树展示和精确跳转提供基础

### 文档级导航项 `DocumentNavItem`

约束：

- `DocumentNavItem` 只由 `ReaderDocument + TocItem` 派生，不单独作为持久化源模型
- 每个 `ReaderDocument` 只允许对应一个 `DocumentNavItem`
- Phase 1 中所有可点击目录入口都只能来自 `DocumentNavItem[]`

## TOC 与正文映射契约

导入 EPUB 时拆出两类数据：

- `ReaderDocument`：按下述唯一生成契约生成
- `TocItem`：统一从 `epubBook.Chapters` 生成，并按下述唯一线性化契约赋予稳定 `order`

核心原则：

- 正文渲染顺序和目录结构分离
- 不再用单一 `Chapter` 兼做正文与目录
- 不再把章节导航建立在滚动百分比估算上

### `TocItem` 唯一生成与线性化契约

`TocItem[]` 的生成必须遵守以下唯一规则：

1. `TocItem` 的唯一结构来源是 `epubBook.Chapters` 返回的根节点列表；应用层不额外自行合并 nav 与 NCX，也不基于标题、href、depth 做二次重排
2. 生成 `TocItem[]` 时，必须对根节点列表执行稳定前序遍历（pre-order DFS）：先输出当前节点，再按原始子节点顺序递归输出其子节点
3. 根节点顺序和同层兄弟节点顺序必须保持解析库返回顺序；应用层不得自行按字典序或其他规则重排
4. `TocItem.order` 按遍历输出顺序连续分配 `0..n-1`
5. `TocItem.depth` 以根节点为 `0`，子节点为 `parent.depth + 1`
6. `TocItem.parentId` 取遍历时的父节点；根节点 `parentId = null`
7. 每个 `TocItem` 在生成阶段都必须保留一个仅解析期使用的 `tocSourcePath` 上下文，用于后续把该节点的 `href` 解析为统一 `fileName`；该字段不要求持久化
8. 同一本 EPUB 在相同 `navigation_data_version`、相同线性化算法和相同解析库版本下重复重建时，必须得到相同的 `TocItem.order`、`depth` 和 `parentId` 结构
9. 若未来修改了 `TocItem` 的线性化或编号算法，必须提升 `navigation_data_version` 并触发全量重建，不能在同一版本号下静默改变既有 `TocItem.order`

### 正文候选集与现有正文文件定义

为避免实现分叉，Phase 1 的正文候选判定只允许依赖解析库已经成功产出的 `book.Content.Html`，不允许应用层再根据 manifest、ZIP 文件存在性或其他启发式自行扩充正文集合。

1. `book.Content.Html` 中每个 entry 的 key 都必须先按本节规范化规则归一为 `fileName`
2. 规范化后 `fileName` 非空的 entry，才定义为“现有正文文件”；该定义不再参考 manifest media-type、ZIP 目录扫描结果或二次 HTML 解析结果
3. “正文候选集”定义为上述现有正文文件按规范化 `fileName` 去重后的集合
4. 若多个 `book.Content.Html` entry 规范化后得到同一 `fileName`，只保留原始 key 字符串按字典序最小的那条作为该 `fileName` 的唯一正文来源，其他同名 entry 一律忽略
5. manifest item 或 ZIP 资源即使声明为 HTML/XHTML，只要其规范化 `fileName` 不在正文候选集中，就视为“非现有正文文件”；它不能单独进入 `ReaderDocument[]`，也不能让对应 spine item 变为 usable
6. 因此 manifest、spine 和 `book.Content.Html` 的职责固定为：`book.Content.Html` 决定正文候选是否存在；manifest 只负责通过 `href` / `idref` 提供路径映射；spine 只负责在正文候选集之上提供优先顺序

### `ReaderDocument` 唯一生成契约

`ReaderDocument[]` 的生成必须遵守以下唯一规则：

1. 每个 `ReaderDocument` 必须一一对应正文候选集中的一个规范化 `fileName`，其 `htmlContent` 和 `title` 都只能来自该 `fileName` 的唯一正文来源
2. `ReaderDocument[]` 只收录正文候选集中的文档，不收录图片、样式、字体、NCX 等非正文资源，也不收录 manifest / ZIP 中声明为 HTML/XHTML 但未进入正文候选集的资源
3. 生成前先对正文候选集统一应用本节的路径规范化和去重规则，`documentIndex` 在最终结果上按 `0..n-1` 连续分配
4. 对某个 spine item，只有当它的 `idref -> manifest item -> 规范化 fileName` 成功落到正文候选集中时，才定义为“可解析到现有正文文件”；否则该 spine item 视为 unusable
5. 若 `epubBook.Schema.Package.Spine.Items` 中存在至少一个 usable spine item，则视为“usable spine”，`ReaderDocument[]` 必须按 spine item 顺序生成
6. usable spine 模式下，`ReaderDocument[]` 纳入所有 usable spine item，对 `IsLinear == true/false` 一视同仁；`IsLinear` 只作为后续元数据保留，不改变 Phase 1 的文档顺序和上一章/下一章顺序
7. usable spine 模式下，正文候选集中存在但未进入 usable spine 的正文文件，不进入 `ReaderDocument[]`
8. 若同一规范化 `fileName` 在 spine 中出现多次，只保留第一次出现对应的 `ReaderDocument`，后续重复项不得生成新的 `documentIndex`
9. 若不存在 usable spine，则进入 fallback：先按 `TocItem.order` 收集“能解析到正文候选集成员”的规范化 `fileName` 并去重，再把正文候选集中剩余正文文件按规范化 `fileName` 字典序追加到末尾
10. fallback 模式下，只有正文候选集中的文件允许进入 `ReaderDocument[]`；manifest-only、ZIP-only 或其他未进入 `book.Content.Html` 的 HTML/XHTML 资源一律不得被追加
11. 同一本 EPUB 在相同 `navigation_data_version`、相同规范化算法和相同解析库版本下重复重建时，必须得到相同的 `fileName -> documentIndex` 映射
12. 若未来修改了上述正文候选判定、usable spine 判定、排序或去重算法，必须提升 `navigation_data_version` 并触发全量重建，不能在同一版本号下静默改变既有 `documentIndex`

### 路径来源与规范化基准

在本节中，`fileName` 一律指“包内相对路径 + POSIX 分隔符”的规范形式。所有路径来源都必须先归一到这一形式，才能参与 `ReaderDocument` 去重、usable spine 判定、fallback 追加和 `TocItem.targetDocumentIndex` 匹配。

- `opfPath`：OPF package document 在 EPUB 包内的相对路径
- `opfBaseDir`：`opfPath` 所在目录；若 OPF 位于包根目录，则为空路径
- `tocSourcePath`：某个 `TocItem` 所在 nav/NCX/目录来源文档在 EPUB 包内的相对路径
- `tocBaseDir`：`tocSourcePath` 所在目录；若目录来源文档位于包根目录，则为空路径

四类来源的唯一解析基准如下：

1. manifest item 的 `href` 必须先相对 `opfBaseDir` 解析，再进入规范化流程
2. spine item 不自行解析路径；必须先通过 `idref` 找到对应 manifest item，再直接继承该 manifest item 的规范化 `fileName`。若 `idref` 缺失、manifest item 缺失或解析后不指向现有正文文件，该 spine item 视为 unusable
3. `TocItem.href` 必须先拆分 `path` 和 `fragment`，再把 `path` 相对 `tocBaseDir` 解析为包内路径；若 `path` 为空，则视为引用 `tocSourcePath` 自身。解析完成后，`fragment` 写入 `anchor`
4. `book.Content.Html` 的 key 视为解析库输出的包内资源标识，不再额外相对 `opfBaseDir` 或 `tocBaseDir` 重新解析；只对 key 字符串本身应用与其他来源相同的规范化步骤
5. `ReaderDocument.fileName`、`TocItem.fileName`、manifest 解析结果、spine 解析结果和 `book.Content.Html` key 都必须在上述各自唯一基准下收敛到同一规范形式；任何层都不得再额外引入新的相对路径基准或大小写折叠规则

### 规范化规则

所有用于匹配的正文路径都统一转换成“包内相对路径 + POSIX 分隔符”的规范形式：

1. 按“路径来源与规范化基准”先确定当前来源的原始 `path`、`fragment` 和解析基准
2. 对 `path` 做 percent-decoding
3. 将 `\` 统一替换为 `/`
4. 归一化 `.` 和 `..` 段
5. 去掉前导 `./` 和 `/`
6. 保留原始大小写，不主动转小写
7. 对 TOC 来源，空 `fragment` 记为 `null`；非空 `fragment` 原样写入 `anchor`
8. 规范化结果若为空字符串，视为 unresolved，不进入 `ReaderDocument[]`

### 匹配规则

- `ReaderDocument.fileName` 也必须使用同一规范化规则保存
- 用规范化后的 `fileName` 做精确字符串匹配，生成 `targetDocumentIndex`
- 匹配成功时，`TocItem.targetDocumentIndex` 指向目标 `ReaderDocument.documentIndex`
- 匹配失败时，`TocItem.targetDocumentIndex = null`，并标记为 unresolved，不参与 Phase 1 直接跳转
- `DocumentNavItem` 标题选择和 fallback 顺序中引用的“第一个 `TocItem`”，都必须以最小 `TocItem.order` 为准，而不是以运行时遍历顺序为准

### `ReaderDocument.title` 唯一生成契约

`ReaderDocument.title` 必须只从该文档的唯一正文来源派生，不能在 UI 层再次临时猜测。唯一规则如下：

1. `ReaderDocument.title` 的唯一输入，是该 `ReaderDocument.fileName` 对应正文来源的 `htmlContent`
2. 每个候选标题文本在判空或写入最终标题前，都必须先执行同一清洗规则：提取纯文本、将连续空白折叠为单个空格、再做 `trim`；下文提到的“标题经空白折叠后非空白”和“清洗后的 `TocItem.title`”都以此规则为准
3. 标题提取优先级固定为：HTML `<title>` -> 第一个非空白 `h1` -> 第一个非空白 `h2` -> 第一个非空白 `h3` -> 第一个非空白 `h4` -> 第一个非空白 `h5` -> 第一个非空白 `h6`
4. 若 HTML 中不存在有效标题，则回退到 `ReaderDocument.fileName` 的最后一个 path segment 去掉扩展名后的结果
5. 若上述 file stem 仍为空，则回退到完整 `ReaderDocument.fileName`
6. `ReaderDocument.title` 在生成阶段确定并持久化；`DocumentNavItem`、阅读器 UI 和迁移逻辑不得再引入 HTML `<title>`、正文首标题、书名或其他二次 fallback 来源
7. 同一本 EPUB 在相同 `navigation_data_version`、相同标题提取算法和相同解析库版本下重复重建时，必须得到相同的 `ReaderDocument.title`
8. 若未来修改了标题提取或 fallback 规则，必须提升 `navigation_data_version` 并触发全量重建，不能在同一版本号下静默改变既有标题

### 文档级导航派生规则

Phase 1 的目录 UI 不直接消费原始 `TocItem[]`，而是派生 `DocumentNavItem[]`：

- 每个 `ReaderDocument` 只生成一个 `DocumentNavItem`
- `DocumentNavItem.documentIndex = ReaderDocument.documentIndex`
- 对当前 `ReaderDocument`，只考虑满足 `targetDocumentIndex == ReaderDocument.documentIndex` 且 `anchor == null` 的 `TocItem`
- 上述候选 `TocItem.title` 在参与判空和最终赋值前，都必须先应用与 `ReaderDocument.title` 候选相同的标题文本清洗规则
- 标题优先使用其中 `TocItem.order` 最小且清洗后非空白的那个 `TocItem.title` 的清洗结果
- 若不存在满足条件的 `TocItem`，则唯一回退到已持久化的 `ReaderDocument.title`
- UI 层不得再用 HTML `<title>`、正文首标题、文件名或书名对 `DocumentNavItem.title` 做二次猜测
- `DocumentNavItem` 的排列顺序跟随 `ReaderDocument.documentIndex`

### 顺序规则

- 阅读器正文渲染顺序以 `ReaderDocument.documentIndex` 为准
- Phase 1 的上一章/下一章以 `ReaderDocument.documentIndex` 为准
- 原始 TOC 顺序保留在 `TocItem.order` 中，供 Phase 2 的目录树使用

## 进度模型定义

阅读进度从旧模型：

- `chapterIndex`
- `scrollPosition`

演进为新模型：

- `documentIndex`
- `documentProgress`
- `tocItemId` 可选
- `anchor` 可选

字段语义明确如下：

- `documentIndex`：当前所在 `ReaderDocument`
- `documentProgress`：范围 `[0, 1]`，定义为“当前文档内已滚动偏移 / 当前文档可滚动总偏移”
- `tocItemId`：可选，仅在当前位置可被某个导航项稳定表达时保存
- `anchor`：可选，保留给 Phase 2 的精确恢复

补充约束：

- 若当前文档高度不足一屏，`documentProgress = 0`
- Phase 1 保存和恢复时，默认以 `documentIndex + documentProgress` 为主
- Phase 2 若支持精确锚点恢复，则 `anchor` 优先级高于 `documentProgress`

误差声明：

- Phase 1 只承诺“恢复到同一 `ReaderDocument` 内的近似位置”
- 字体、行高、边距、图片加载状态变化后，允许文档内像素级偏差
- 但不允许再漂移到其他 `ReaderDocument`

## V2 迁移与切换约束

这次重构不做“旧表直接原地改列”的迁移，而是采用“新增 V2 导航数据 + 旧书按需重建”的策略。

### 迁移原则

- `ReaderDocument` 和 `TocItem` 依赖重新解析原始 EPUB，不能仅靠旧 `chapters` 表 SQL 转换得到
- 迁移必须允许旧书逐本重建，不能要求一次性全库成功
- 迁移失败不能破坏现有书籍记录和源 EPUB 文件
- Phase 1 期间允许 `Chapter` 继续作为 legacy 数据存在，但新的阅读器导航能力不得再以它为权威来源

### 书籍级状态字段

书籍层至少新增以下状态字段：

- `navigation_data_version`：`0` 表示当前仍停留在 legacy / Phase 0 链路，`2` 表示已生成并启用 V2 导航数据
- `navigation_rebuild_state`：枚举值固定为 `legacy_pending | rebuilding | ready | failed`
- `navigation_rebuild_failed_at`：最近一次重建失败时间；仅 `failed` 时允许非空

其中：

- 旧书在数据库升级后统一初始化为 `navigation_data_version = 0`、`navigation_rebuild_state = legacy_pending`
- Phase 1 上线后的新导入书籍，不应先落到 legacy 状态；要么与 V2 数据一起原子写入为 `ready`，要么整次导入失败

### 切换状态机

最小可执行状态机如下：

1. `legacy_pending`
   说明：旧书尚未生成 V2 导航数据
   读取链路：只能走 Phase 0 / legacy 数据链路
   进入条件：数据库升级后的旧书，或中断恢复后重置，或人工清空 V2 后重新排队
   离开条件：打开书籍触发重建，转入 `rebuilding`
2. `rebuilding`
   说明：当前书籍正在生成 V2 导航数据
   读取链路：仍然只能走 Phase 0 / legacy 数据链路，不能读取任何 V2 半成品
   进入条件：从 `legacy_pending` 或 `failed` 发起一次新的重建尝试
   离开条件：重建事务成功后转入 `ready`；任一解析 / 写入失败后转入 `failed`
3. `ready`
   说明：V2 数据已完整提交并正式启用
   读取链路：阅读器只能走 V2 数据链路，不再混读 legacy `chapters`
   进入条件：一次书籍级原子事务成功写入完整 V2 数据并提交
   离开条件：后续若 `navigation_data_version` 升级，需要显式清空 V2 并重新转入 `legacy_pending`
4. `failed`
   说明：最近一次重建失败
   读取链路：继续走 Phase 0 / legacy 数据链路
   进入条件：从 `rebuilding` 发生任一解析失败、映射失败、事务失败或外部文件缺失
   离开条件：下次打开或手动重试时重新进入 `rebuilding`

### 原子切换规则

- V2 的 `reader_documents`、`toc_items`、`reading_progress_v2` 必须以“单书事务”写入，不能分多次提交后再拼装
- 启用 V2 的唯一切换点，是同一事务内完成以下动作后提交成功：
  1. 删除该书历史 V2 数据
  2. 写入新的 `reader_documents`
  3. 写入新的 `toc_items`
  4. 写入可稳定映射的 `reading_progress_v2`
  5. 将书籍状态更新为 `navigation_data_version = 2` 且 `navigation_rebuild_state = ready`
- 只有在上述事务提交后，Provider / Repository 才允许把该书的读取链路切换到 V2
- 任何未提交事务中的 V2 数据，都不得被 UI、Provider 或 Repository 读取

### 中断、失败与重试规则

- 若应用启动或打开书籍时发现状态仍为 `rebuilding`，但当前不存在活跃重建任务，必须将其视为“上次中断的重建”
- 中断恢复时，先删除该书所有 V2 半成品数据，再把状态重置为 `navigation_data_version = 0`、`navigation_rebuild_state = legacy_pending`
- 任一重建失败后，必须删除该书本次尝试写入的 V2 数据，并写回 `navigation_data_version = 0`、`navigation_rebuild_state = failed`、`navigation_rebuild_failed_at = now`
- `failed` 状态不得阻塞打开阅读页；阅读器必须稳定回退到 Phase 0 最小阅读体验
- 从 `failed` 发起重试时，流程与 `legacy_pending -> rebuilding` 完全一致，不允许复用上次失败遗留的半成品数据

### 旧进度处理策略

- 不承诺把旧 `chapterIndex + scrollPosition` 无损迁移到新模型
- 若旧 `chapterIndex` 与新 `documentIndex` 可一一对应，可做 best-effort 映射
- 无法稳定映射时，旧进度直接失效，新阅读器从目标文档顶部或书籍顶部开始
- 进度迁移失败不得阻塞书籍导入、展示和重新解析
- legacy 进度迁移进入 V2 时，Phase 1 默认只写 `documentIndex + documentProgress`；`tocItemId` 和 `anchor` 默认写 `null`

## Phase 1 完成边界

满足以下条件后，Phase 1 才算完成：

1. 导入后可以稳定得到 `ReaderDocument[]` 和 `TocItem[]`
2. 同一本 EPUB 在相同 `navigation_data_version` 下重复重建时，`ReaderDocument.fileName -> documentIndex` 映射、`TocItem.order`、`TocItem.targetDocumentIndex` 和 `DocumentNavItem.title` 保持一致
3. manifest href、spine item、TOC href、`book.Content.Html` key 若指向同一正文文件，最终都必须收敛到同一规范化 `fileName`
4. “现有正文文件”和正文候选集的唯一来源固定为 `book.Content.Html`；manifest 或 ZIP 中未进入该集合的 HTML/XHTML 资源不得进入 `ReaderDocument[]`
5. usable spine 存在时，`ReaderDocument[]` 严格按 spine 顺序生成；usable spine 不存在时，fallback 顺序严格按“`TocItem.order` 去重后优先，剩余正文文件按规范化路径字典序追加”执行
6. 阅读器正文按 `ReaderDocument.documentIndex` 稳定渲染
7. `DocumentNavItem.title` 必须唯一按“清洗后的合格 `TocItem.title` -> `ReaderDocument.title`”链路生成
8. 目录 UI 只基于 `DocumentNavItem[]` 做文档级跳转，且不渲染原始 `TocItem` 行
9. 若存在 Phase 2-only TOC，目录 UI 只显示一条不可点击的统一说明，不提供伪精确跳转
10. 上一章 / 下一章可以稳定跳到相邻 `ReaderDocument`
11. 带 `anchor` 或同文件多目录点的 EPUB 不会崩溃，也不会伪装成精确跳转
12. 迁移过程中断或失败后，不会暴露半成品 V2 数据，也不会错误切到 V2 链路
13. 旧书升级失败时，仍能维持 Phase 0 最小阅读体验，且允许后续重试
14. 重新打开书籍时，能够恢复到同一 `ReaderDocument` 的近似位置

## 明确不支持的能力

- EPUB CFI
- Phase 1 中原始 `TocItem` 节点级别的精确跳转
- Phase 1 中同文档内多个 section 的单独定位
- 依赖 HTML 内部复杂锚点映射的精确高亮
