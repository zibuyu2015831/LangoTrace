# 语迹 / LangoTrace 文档总入口

本文档是语迹 LangoTrace 后续开发的文档入口。项目按“严格工程化”方式推进：产品定位、架构决策、开发计划、测试验证、发布策略和外部参考都必须有明确记录，避免关键判断只停留在聊天记录或临时笔记中。

若后续要在新的 AI 会话中继续讨论或开发，请优先携带并阅读：

- [AI 会话入口](AI_ENTRY_POINT.md)：按任务类型指引 AI 阅读相关文档，避免只从局部需求出发。

## 1. 当前阶段

当前项目处于工程初始化前阶段：

- 产品主设想、技术路线、开发环境和多端静态 HTML 原型已经建立。
- SwiftUI Multiplatform 工程尚未创建。
- 下一步应先完成原生 Apple 项目骨架，再逐步实现核心学习闭环。

## 2. 主参考文档

以下文档是后续开发的长期主参考：

- [产品主参考文档](product-main-reference.md)：产品名称、定位、核心理念、功能设想、语言空间、买断制、本地优先、AI Prompt 和长期记忆系统。
- [技术框架与开发路线参考](technical-framework-roadmap.md)：Apple 三端技术选型、SwiftUI 原生路线、SQLite / GRDB、本地优先、Provider 架构、同步和向量索引判断。
- [开发环境记录](development-environment.md)：当前 MacBook、Xcode、Simulator、Homebrew、SwiftLint、SwiftFormat、SF Symbols 等环境基线。
- [开源项目参考记录](development-open-source-references.md)：后续开发可研究的开源项目和许可证注意事项。
- [项目初始化规划](project-initialization.md)：第一阶段 SwiftUI 工程初始化的边界、目标、目录建议和验证标准。
- [文档体系规范](documentation-system.md)：文档分类、命名、更新规则、决策记录和验证记录要求。
- [AI 会话入口](AI_ENTRY_POINT.md)：后续 AI 辅助编程时的最小全局入口。

## 3. 当前关键架构与决策文档

当前已记录的初始架构与决策：

- [初始模块边界](architecture/001-initial-module-boundaries.md)：App Shell、Core、UI、Data、AI、Speech、Sync 的第一阶段边界和依赖方向。
- [ADR-001：采用严格工程化文档体系](decisions/001-use-strict-engineering-documentation.md)。
- [ADR-002：使用 SwiftUI Multiplatform](decisions/002-use-swiftui-multiplatform.md)。
- [ADR-003：使用 XcodeGen 管理 Xcode 工程生成](decisions/003-use-xcodegen-for-project-generation.md)。
- [ADR-004：采用语言空间作为核心信息模型](decisions/004-use-language-space-as-primary-model.md)。
- [ADR-005：坚持本地优先和用户自带 Provider](decisions/005-local-first-and-user-owned-providers.md)。

## 4. 文档目录结构

```text
docs/
  README.md
  product-main-reference.md
  technical-framework-roadmap.md
  development-environment.md
  development-open-source-references.md
  AI_ENTRY_POINT.md
  project-initialization.md
  documentation-system.md
  architecture/
  decisions/
  guidelines/
  development/
  release/
  research/
  testing/
  superpowers/
    specs/
    plans/
```

## 5. 目录职责

- `architecture/`：工程架构、模块边界、数据模型、同步模型、AI Provider、长期记忆和安全边界。
- `decisions/`：架构决策记录，采用 ADR 风格，记录重要取舍、背景、结论和复审条件。
- `guidelines/`：开发一致性规范，记录导航、UI、SwiftUI 架构、AI Provider 和隐私等具体开发约束。
- `development/`：阶段开发计划、工程任务拆分、初始化记录、里程碑状态和开发 runbook。
- `release/`：买断制、StoreKit、App Store、TestFlight、版本策略和发布检查清单。
- `research/`：竞品、开源项目、技术调研和设计研究。
- `testing/`：测试策略、手动测试流程、回归用例、模拟器与真机验证记录。
- `superpowers/specs/`：较大功能或架构变更的设计规格文档。
- `superpowers/plans/`：经过确认的实施计划。

## 6. 严格工程化原则

1. 重要产品或技术判断必须写入文档。
2. 每个重大功能先有规格或计划，再进入实现。
3. 每个架构取舍必须能回溯决策依据和复审条件。
4. 涉及数据、同步、隐私、AI 请求、付费、迁移和发布的功能必须有测试或验证记录。
5. 文档不是为了堆数量，而是为了降低后续开发和发布风险。
