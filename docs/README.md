# Docs Structure

`docs/` contains project documentation with different audiences and purposes. Do not treat every document here as the same kind of source of truth.

## Directories

- `docs/problem/`
  - 面向实施和评审。
  - 记录当前实施边界、阻塞项、数据契约、迁移规则和验收口径。
  - 如果某项内容会直接影响实现、迁移、数据契约或验收口径，应优先看这里。
  - 如果某项内容主要是在回答“接下来按什么顺序推进、分几步做、怎么验证推进过程”，它通常不属于这里。

- `docs/plan/`
  - 面向实施推进。
  - 记录已经接受的推进方案、任务拆解、推荐落地顺序和验证路线。
  - 这里可以描述阶段推进方式，但不替代 `docs/problem/` 中的绑定约束；若两者冲突，以 `docs/problem/` 为准。

- `docs/progress/`
  - 面向阶段状态同步。
  - 记录里程碑进展、当前完成度、剩余事项和时间线。
  - 这里用于汇报现状，不单独定义实现约束。

- `docs/knowledge/`
  - 面向开发者理解背景知识。
  - 记录概念解释、领域知识、实现思路拆解和学习笔记。
  - 这里的文档用于帮助人理解问题，不默认作为 agent 执行任务时的必读规范。
  - 若与 `docs/problem/` 的实施约束存在差异，以 `docs/problem/` 为准。

## Standalone Guides

- `docs/logging_guide.md`
  - 日志相关改动的配套说明。
  - 修改日志行为时应同步更新。
