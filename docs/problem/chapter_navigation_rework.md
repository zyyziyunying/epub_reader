# Reader Chapter Navigation Rework Plan

Date: 2026-03-20

## 背景

当前阅读器界面已经有目录抽屉、上一章/下一章按钮和底部章节 Slider，但这些能力并不是基于 EPUB 原始目录结构实现的，而是建立在滚动高度估算和运行时 widget 定位上。

这意味着项目现在并不具备稳定的章节导航能力。继续在现有实现上补丁，只会放大后续重写成本。

因此，这一轮先统一文档，再明确把工作拆成两个阶段：

1. Phase 0：先清理现有不可靠的跳转逻辑
2. Phase 1/2：基于新模型重新实现章节导航

## 当前问题

### 1. 交互入口已经存在，但底层定位模型不可靠

当前阅读器已经有以下入口：

- 目录抽屉
- 上一章/下一章按钮
- 底部章节 Slider

但底层不是按 EPUB TOC 定位，而是按滚动位置估算，因此入口存在不代表能力可靠。

### 2. 导入阶段没有使用 EPUB TOC 作为章节导航来源

当前 `EpubParserService` 主要使用 `book.Content.Html.entries` 生成章节列表，而没有把 `epubBook.Chapters` 作为目录结构来源。

直接后果：

- 章节顺序不一定等于用户看到的目录顺序
- 无法保留原始目录层级
- 无法保留 `href#anchor`
- 无法表达同一 XHTML 内多个目录节点

### 3. 当前 `Chapter` 模型承担了错误的职责

当前 `Chapter` 同时承担了：

- 正文渲染单元
- 目录项
- 跳转目标
- 进度锚点

但它只包含：

- `id`
- `bookId`
- `index`
- `title`
- `content`

缺失：

- `fileName`
- `anchor`
- `depth`
- `parentId`
- `targetDocumentIndex`

### 4. 跳转逻辑依赖 `GlobalKey + offset` 估算

当前 `ReaderController.jumpToChapter` 依赖以下流程：

1. 已渲染则通过 `GlobalKey` 找 widget 位置
2. 未渲染则按 `maxScroll / chapters.length * index` 先估算
3. 等待渲染后再尝试二次微调

这在长短章节差异大、图片多、布局变化、目标 item 未渲染时都不稳定。

### 5. 当前章节识别依赖运行时可见区域

`_calculateCurrentChapterIndex()` 通过遍历 `chapterKeys` 判断视口中心落在哪个章节 widget 内。

问题在于：

- `ListView.builder` 只构建附近 item
- 不可见 item 没有 `currentContext`
- 结果依赖当前这一帧的布局状态

因此“当前章节”不是稳定事实，而是运行时估算。

### 6. 阅读进度模型过于粗糙

当前 `ReadingProgress` 仅保存：

- `chapterIndex`
- `scrollPosition`

其中 `scrollPosition` 是整本书滚动百分比。它会因为字体、行高、边距、图片布局变化而明显失真。

### 7. 当前实现无法支持 anchor 和同文件多目录点

一部分 EPUB 会出现：

- 一个 XHTML 对应多个目录节点
- TOC 指向 `chapter.xhtml#section-2`

当前模型无法表达这类情况，因此也无法稳定跳转。

## 结论

当前问题不是“缺少章节跳转入口”，而是“章节跳转建立在错误的数据模型和不稳定的滚动估算上”。

因此，本轮不再继续修补旧逻辑，而是先把旧逻辑清理掉，再按新模型重新实现。

## Phase 0：先清理旧逻辑

### 目标

把阅读器降级回一个稳定、简单、可维护的最小状态，为后续重写让路。

### 这一步要清理的内容

- 移除 `ReaderController` 中基于 `GlobalKey` 的章节识别逻辑
- 移除 `jumpToChapter` 及其滚动估算流程
- 移除目录抽屉中的章节点击跳转
- 移除底部栏中的上一章/下一章和章节 Slider
- 移除阅读页对旧章节跳转状态的直接依赖

### Phase 0 之后保留的能力

- 正文连续滚动阅读
- 目录列表展示
- 阅读设置调整
- 最近阅读时间更新（`last_read_at`）

### Phase 0 之后暂时不保证的能力

- 章节点击跳转
- 上一章/下一章
- 章节 Slider 跳转
- 基于旧模型的章节高亮
- 基于旧模型的进度恢复

说明：

- `last_read_at` 仅用于表达“最近一次打开/进入阅读”的时间，不作为章节定位或进度恢复依据

## 目标架构

后续实现统一采用“两层模型”：

### 1. 正文渲染单元 `ReaderDocument`

建议字段：

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

### 2. 目录项 `TocItem`

建议字段：

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

- 目录展示
- 目录点击跳转
- 当前目录项高亮

## 解析层方向

导入 EPUB 时拆出两类数据：

- `ReaderDocument`：优先按 spine 或正文顺序生成
- `TocItem`：明确从 `epubBook.Chapters` 生成

核心原则：

- 正文渲染顺序和目录结构分离
- 不再用单一 `Chapter` 兼做正文与目录
- 不再把章节导航建立在滚动百分比估算上

## 进度模型方向

阅读进度建议从：

- `chapterIndex`
- `scrollPosition`

演进为：

- `documentIndex`
- `documentProgress`
- `tocItemId` 可选
- `anchor` 可选

这样恢复位置的误差会显著小于“全书总滚动百分比”。

## 阅读器行为方向

### Phase 1：先做稳定的文档级跳转

包含：

- 用 `epubBook.Chapters` 构建 TOC
- 新增 `TocItem`
- 新增 `ReaderDocument`
- 阅读器按 `ReaderDocument[]` 渲染
- 目录点击跳到目标正文单元顶部
- 上一章/下一章按目录项移动
- 进度保存改为 `documentIndex + documentProgress`

不包含：

- anchor 精确跳转
- 同文件多个目录点定位
- EPUB CFI

### Phase 2：再补精确定位

包含：

- `href#anchor` 精确跳转
- 同一正文文件多个目录节点
- 更细粒度的当前目录高亮
- HTML 内部锚点映射

## 风险点

### 1. 数据迁移

后续数据库结构会发生变化，需要处理老数据兼容和旧书重建。

### 2. 旧 `Chapter` 依赖面

当前 `Chapter` 还承担导入和阅读器渲染职责，替换时需要分步迁移，不能一次硬删。

### 3. 列表组件能力

Phase 1 可以继续使用普通滚动容器，但不能再依赖“未渲染 item 的精确定位”。

## 当前决策

当前阶段先执行 Phase 0：

- 合并文档
- 清理旧跳转逻辑
- 保留最小可运行阅读体验

等清理完成后，再从导入层、数据模型、阅读器渲染链路重新实现章节导航。
