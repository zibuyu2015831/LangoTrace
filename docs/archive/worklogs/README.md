# 开发工作记录

本目录用于记录语迹 LangoTrace 每一次重要功能开发、bug 修复、重构、技术调研和工程杂项任务。它是具体工作的过程记录入口，目标是让后续开发可以回溯：

```text
需求或问题 -> 分析 -> 方案 -> 用户确认 -> 实施 -> 文档影响检查 -> 验证 -> 关联提交
```

## 1. 为什么只设一个目录

开发记录不拆分为 `requirements/`、`bugs/`、`refactors/` 等多个目录，避免开发时因为文档存放位置产生困扰。

功能开发、bug 修复、重构、调研和工程杂项都放在 `docs/plans/done/`，通过文件名中的 `type` 和文档内的 `类型` 字段区分。

## 2. 文件命名规范

统一命名：

```text
YYYY-MM-DD-<type>-<short-topic>.md
```

允许的 `type`：

- `feature`：新功能、产品体验、用户路径。
- `bug`：缺陷分析与修复。
- `refactor`：结构调整，不改变用户可见行为。
- `research`：开发前技术验证、方案比较。
- `chore`：工程配置、工具、文档体系、环境类任务。

示例：

```text
2026-05-17-feature-first-launch-language-space.md
2026-05-17-feature-swiftui-app-shell.md
2026-05-17-bug-language-space-switch-loses-entry.md
2026-05-17-refactor-ai-provider-boundary.md
2026-05-17-research-grdb-migration-strategy.md
2026-05-17-chore-xcodegen-project-setup.md
```

如果同一天同主题需要多份记录，可以在文件名末尾增加序号：

```text
2026-05-17-feature-swiftui-app-shell-02.md
```

文件名要求：

- 日期使用本地日期。
- `type` 使用固定小写英文。
- `short-topic` 使用小写英文和连字符。
- 不在文件名中使用空格、中文、下划线或过长描述。

## 3. 状态流转

建议状态：

```text
Draft -> User Approved -> In Progress -> Implemented -> Verified -> Archived
```

含义：

- `Draft`：方案草稿，不能开始实现。
- `User Approved`：用户已确认，可以开始实现。
- `In Progress`：正在实现。
- `Implemented`：代码或文档已经改完，但验证尚未完成。
- `Verified`：已完成验证并记录结果。
- `Archived`：工作已完成并归档，不再活跃。

bug 任务也使用同一状态流转。复现、根因和修复方案写在模板的分析与方案章节中，不需要单独目录或单独模板。

## 4. 何时必须创建工作记录

以下任务必须先创建 worklog，并经用户确认后再实现：

- 新功能。
- bug 修复。
- 架构调整。
- 数据模型、迁移、导出、备份相关任务。
- AI 请求、Prompt、Provider、隐私、权限、同步、StoreKit 相关任务。
- 影响 iPhone、iPad、macOS 用户路径或多端体验的任务。
- 会改变开发规范、模块边界或长期维护方式的任务。

以下任务可以跳过 worklog：

- 明确低风险的错别字修正。
- 非行为性的轻量文档修正。
- 用户明确要求“直接改，不需要记录”的小任务。

如果跳过 worklog，最终答复中应说明原因。

## 5. 工作流程

默认流程：

1. 创建 `docs/plans/done/YYYY-MM-DD-<type>-<short-topic>.md`。
2. 使用 [模板](TEMPLATE.md) 写清背景、目标、范围、不做什么、分析、方案、风险和验证方式。
3. 等待用户审核。
4. 用户确认后，将状态改为 `User Approved`。
5. 开始实现。
6. 实现后补充实施记录、验证结果和关联提交。

复杂功能可以在 worklog 中链接到：

- `docs/superpowers/specs/`
- `docs/archive/superpowers/plans/`
- `docs/decisions/`
- `docs/architecture/`
- `docs/testing/`
- `docs/review/`

worklog 是“每次工作的封面和过程记录”，不是替代规格、计划、ADR 或测试文档。

## 5.1 文档影响检查

重要任务完成前，应在 worklog 中记录文档影响检查。

至少回答：

- 本次变更是否影响 `docs/README.md` 的项目当前状态、阅读路径或完成前检查。
- 本次变更是否影响产品主参考、技术路线、架构文档、guidelines、testing 或 release 文档。
- 本次变更是否命中 `docs/review/README.md` 中的专项审查触发条件。
- 如果不更新文档，理由是什么。

命中数据库、AI Provider、Keychain、权限、同步、StoreKit、发布验证、ADR 冲突、首次启动闭环、语言空间闭环、本地记录闭环、验证脚本、XcodeGen、包边界或 App 启动结构变化时，应创建 `docs/review/rounds/YYYY-MM-DD-<topic>/README.md`；若跳过，必须在 worklog 中说明原因。

## 6. AI 开发提示

AI 在准备执行功能开发、bug 修复、重构或高风险文档任务前，应先检查是否需要创建 worklog。

如果需要创建 worklog：

- 先写 worklog。
- 不开始实现。
- 等用户确认。

如果用户要求立即实现，而任务属于必须创建 worklog 的范围，AI 应先创建 worklog 并说明这是进入实现前的门槛。

## 7. 当前状态

状态：Accepted

适用阶段：SwiftUI 工程初始化前、MVP 早期开发、后续长期维护。

## 8. 变更记录

- 2026-05-17：创建统一开发工作记录目录。原因：为功能开发和 bug 修复建立可回溯过程记录，同时避免目录拆分过细。影响范围：开发流程、AI 会话入口、文档体系。是否需要 ADR：否。
- 2026-05-17：补充文档影响检查要求。原因：让重要开发任务在收尾前检查文档与代码、决策和验证口径是否同步。影响范围：worklog 工作流程、文档审查机制。是否需要 ADR：否。
