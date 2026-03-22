# EPUB 路径解析与规范化

## 文档定位

这是一篇面向开发者的背景知识文档，用来解释 EPUB 实现里最容易踩坑的一类问题：同样看起来像一个 `href`，但它可能并不是按同一个基准路径去解析。

它的目标是：

- 帮助理解 EPUB 中不同路径来源的解析基准
- 帮助理解为什么路径规范化会直接影响目录跳转、图片加载和正文映射
- 作为总览文《EPUB 解析与章节跳转实现》的专题延伸

它不承担的作用是：

- 不作为本仓库实现约束
- 不直接定义某个字段的唯一契约

## 为什么这是 EPUB 实现里的高风险点

很多 EPUB 问题表面上像“目录跳错了”或“图片没显示”，本质上其实是路径解析错了。

常见现象包括：

- 目录项存在，但点开后跳到错误文件
- 同一个正文文件在不同数据源里匹配不上
- 图片、样式、字体链接失效
- 同一本书在不同阅读器里表现不一致

原因通常不是路径字符串本身太复杂，而是：

- 没有区分“这个路径是从哪里来的”
- 没有按正确的基准目录解析
- 解析后没有统一做规范化

## EPUB 中常见的几类路径来源

实现时至少要分清下面几类来源。

### 1. `container.xml` 到 OPF

`META-INF/container.xml` 会告诉阅读器包文件 `*.opf` 在哪里。

例如：

```text
META-INF/container.xml
OEBPS/content.opf
```

这里的 `full-path` 是相对 EPUB 包根目录的，不是相对某个正文文件。

### 2. manifest item 的 `href`

`opf` 里的 manifest 记录资源路径。

例如：

```text
Text/chapter1.xhtml
Styles/book.css
Images/cover.jpg
```

这些 `href` 通常要相对 OPF 所在目录去解析，而不是相对包根目录，也不是相对当前正文文件。

### 3. TOC 项目的 `href`

不管是 EPUB 2 的 `toc.ncx`，还是 EPUB 3 的导航文档，目录项里的目标路径通常要相对“目录来源文档自身所在目录”去解析。

例如：

```text
../Text/chapter3.xhtml#section2
chapter5.xhtml#part1
#subsection
```

这里最容易犯的错，是误把它们按 OPF 目录或包根目录解析。

### 4. 正文 XHTML 内部资源链接

正文文件里的图片、样式和内部超链接，通常要相对“当前正文文件自身所在目录”去解析。

例如正文位于：

```text
Text/chapter1.xhtml
```

正文中引用：

```text
../Images/pic1.jpg
../Styles/book.css
chapter2.xhtml#p5
```

这些链接的基准是 `Text/`，不是 OPF，也不是 TOC。

## 为什么“同一条路径”会在不同上下文里含义不同

下面这个字符串本身没有问题：

```text
chapter3.xhtml#s2
```

但它到底指向哪里，取决于它出现在哪。

- 若它来自 `toc.ncx`，就相对 `toc.ncx` 所在目录解析
- 若它来自 `nav.xhtml`，就相对 `nav.xhtml` 所在目录解析
- 若它来自正文里的 `<a href>...</a>`，就相对当前正文文件解析

所以实现里真正应该保存和传递的，不只是一个 `href`，而是：

- 原始 `href`
- 它来自哪种来源
- 它的解析基准是什么

## 常见规范化步骤

路径解析完成后，通常还要做统一规范化，否则后续匹配很容易失败。

常见步骤包括：

1. 先拆分 `path` 和 `fragment`
2. 对 `path` 做 percent-decoding
3. 把 `\` 统一为 `/`
4. 归一化 `.` 和 `..`
5. 去掉多余的前导 `./` 或 `/`
6. 根据需求决定是否保留原始大小写
7. 将 `fragment` 作为独立字段处理，而不是继续拼在完整路径里

例如：

```text
../Text/./chapter1.xhtml#p3
```

规范化后可以得到：

```text
Text/chapter1.xhtml
fragment = p3
```

## 为什么要把 `path` 和 `fragment` 分开

`chapter1.xhtml#p3` 实际上在表达两层定位：

- 先定位到资源文件 `chapter1.xhtml`
- 再定位到文件内部的锚点 `p3`

如果不先拆开：

- 文件级匹配会很麻烦
- 去重会失真
- 目录项和正文文档的映射会变得不稳定

因此很多实现会统一存成：

```text
fileName = Text/chapter1.xhtml
anchor = p3
```

## 常见错误模式

### 1. 把所有路径都当成相对 OPF

这会导致 TOC 链接和正文内部链接经常解析错。

### 2. 把所有路径都当成相对包根

有些书碰巧能工作，但换一本目录文件不在根目录的书就会出错。

### 3. 规范化前直接拿字符串比较

例如：

- `Text/ch1.xhtml`
- `./Text/ch1.xhtml`
- `Text/./ch1.xhtml`

它们可能本质指向同一资源，但裸字符串不相等。

### 4. 把大小写规则写死

不同 EPUB 制作链路和不同平台的行为不完全一致。实现时如果一开始就强行全部转小写，可能会引入新的歧义。

### 5. 忘记 fragment 是可选的

不是每个目录项都会带锚点，也不是每个锚点都一定存在。

## 什么时候你应该怀疑是路径问题

出现下面这些现象时，应优先排查路径解析：

- manifest、spine、TOC、正文资源 key 明明像在指向同一文件，却对不上
- 某些书能跳转，某些书始终跳不到
- 目录能打开文件，但跳不到具体小节
- 图片和 CSS 在部分章节失效

## 调试时最值得打印的内容

如果你在实现阅读器，调试日志里最有价值的通常不是“跳转失败”四个字，而是：

- 原始 `href`
- 来源类型
- 解析基准
- 解析后的 `fileName`
- 解析出的 `fragment`
- 最终命中的目标文档

一旦这几项能稳定打印出来，很多 EPUB 导航问题会变得非常好查。

## 与总览文的关系

这篇文档展开的是总览文里“相对路径解析”那一小节。

如果你还没读总览，建议先看：

- [`epub_parsing_and_chapter_navigation.md`](./epub_parsing_and_chapter_navigation.md)

如果你接下来想继续深入，最自然的下一篇是：

- [`epub_toc_models_and_linearization.md`](./epub_toc_models_and_linearization.md)
