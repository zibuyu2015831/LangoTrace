# 架构决策记录

本目录用于保存 ADR（Architecture Decision Record）。

ADR 只记录不可轻易反转的重要取舍，不维护 implementation 文档、阶段 runbook 或单项任务方案。若需要记录当前实现地图，应写入 `docs/spec/<module>/impl.md` 或 `docs/architecture/`；若需要记录执行步骤，应写入 `docs/development/` 或 `docs/plans/active/`。

每个重要技术或产品结构决策都应记录：

- 背景。
- 决策。
- 备选方案。
- 影响。
- 风险。
- 复审条件。

当前决策：

- [ADR-001：从项目初始化阶段采用严格工程化文档体系](001-use-strict-engineering-documentation.md)
- [ADR-002：使用 SwiftUI Multiplatform 作为 Apple 三端主框架](002-use-swiftui-multiplatform.md)
- [ADR-003：使用 XcodeGen 管理 Xcode 工程生成](003-use-xcodegen-for-project-generation.md)
- [ADR-004：采用语言空间作为核心信息模型](004-use-language-space-as-primary-model.md)
- [ADR-005：坚持本地优先和用户自带 Provider](005-local-first-and-user-owned-providers.md)
- [ADR-006：采用系统级三层学习者模型（Learner Model）](006-system-level-three-layer-learner-model.md)
