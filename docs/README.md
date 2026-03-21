# Docs Structure

`docs/` contains project documentation with different audiences and purposes. Do not treat every document here as the same kind of source of truth.

## Directories

- `docs/problem/`
  - 面向实施和评审。
  - 记录当前方案、阻塞项、阶段约束和需要落地执行的项目决策。
  - 如果某项内容会直接影响实现、迁移、数据契约或验收口径，应优先看这里。

- `docs/knowledge/`
  - 面向开发者理解背景知识。
  - 记录概念解释、领域知识、实现思路拆解和学习笔记。
  - 这里的文档用于帮助人理解问题，不默认作为 agent 执行任务时的必读规范。
  - 若与 `docs/problem/` 的实施约束存在差异，以 `docs/problem/` 为准。

## Standalone Guides

- `docs/logging_guide.md`
  - 日志相关改动的配套说明。
  - 修改日志行为时应同步更新。
