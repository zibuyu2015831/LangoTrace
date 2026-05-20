# 文档审查索引

本文档是所有文档审查轮次的长期索引。单轮细节放在 `docs/review/rounds/<round-id>/` 中。

## 最新状态摘要

- 最近审查轮次：`2026-05-20-language-space-data-infrastructure`。
- 最近完成时间：2026-05-20。
- 待用户澄清的问题数：0。
- 延后项：0。

## 轮次索引

| 轮次 ID | 类型 | 启动时间 | 完成时间 | 状态 | 当前事实源 | 后续覆盖记录 | 可作为依据 | 链接 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `2026-05-20-language-space-data-infrastructure` | 专项审查 | 2026-05-20 | 2026-05-20 | Verified | `docs/review/rounds/2026-05-20-language-space-data-infrastructure/` | `docs/plans/done/2026-05-20-feature-language-space-data-infrastructure.md`、`docs/README.md`、`docs/architecture/001-initial-module-boundaries.md`、`docs/development/environment.md`、`docs/development/mvp-development-roadmap.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/navigation/impl.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/testing/README.md` | Yes | [README](rounds/2026-05-20-language-space-data-infrastructure/README.md) |
| `2026-05-19-ios-page-element-design-audit` | 专项审查 | 2026-05-19 | 2026-05-19 | Verified | `docs/review/rounds/2026-05-19-ios-page-element-design-audit/` | `docs/plans/done/2026-05-19-feature-ios-page-element-convergence-and-mock-photo-writing.md` | Yes | [README](rounds/2026-05-19-ios-page-element-design-audit/README.md) |
| `2026-05-18-comprehensive-ui-review` | 专项审查 | 2026-05-18 | 2026-05-18 | Verified | `docs/review/rounds/2026-05-18-comprehensive-ui-review/` | `docs/plans/done/2026-05-18-feature-first-round-ui-convergence.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/spec/ui-design/mvp-ui-flow-and-design-system.md` | Yes | [README](rounds/2026-05-18-comprehensive-ui-review/README.md) |
| `2026-05-18-development-doc-system-audit` | 专项审查 | 2026-05-18 | 2026-05-18 | Verified | `docs/README.md`、`docs/spec/`、`docs/review/README.md` | `docs/plans/done/2026-05-18-docs-development-system-audit.md` | Historical Only | [README](rounds/2026-05-18-development-doc-system-audit/README.md) |
| `2026-05-17-string-catalog-interface-language-settings` | 专项审查 | 2026-05-17 | 2026-05-17 | Verified | `docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/spec/interface-localization/impl.md` | `docs/plans/done/2026-05-17-feature-string-catalog-interface-language-settings.md` | Historical Only | [README](rounds/2026-05-17-string-catalog-interface-language-settings/README.md) |
| `2026-05-17-interface-localization-foundation` | 专项审查 | 2026-05-17 | 2026-05-17 | Verified | `scripts/verify.sh`、`docs/testing/README.md`、`docs/spec/009-testing-and-verification.md` | `docs/plans/done/2026-05-17-feature-interface-localization-foundation.md` | Historical Only | [README](rounds/2026-05-17-interface-localization-foundation/README.md) |

状态含义：

- `Verified`：该轮在当时快照下已完成并验证；保留为审计记录，不自动成为当前事实源。
- `Deferred`：该轮仍有延后项；读取时必须查看延后项和当前事实源。
- `Superseded`：该轮的问题或建议已被后续 plan、review、commit 或长期文档覆盖；仍可作为历史证据。
- `Invalidated`：该轮结论基于错误前提或已被后续确认推翻；仅作为历史过程记录，不再作为依据。

`可作为依据` 字段取值：

- `Yes`：当前仍可直接作为事实或决策依据。
- `Historical Only`：只能作为审计记录、代码快照和决策回溯材料；当前事实以 `当前事实源` 为准。
- `No`：结论已失效，保留原始记录但不得作为依据。

## 重审触发日志

| 日期 | 触发原因 | 触发的轮次 | 涉及文档 |
| --- | --- | --- | --- |
| 2026-05-20 | 语言空间数据基础设施实现触发数据层、启动闭环、语言空间闭环、包依赖和 App 启动结构专项文档影响检查 | `2026-05-20-language-space-data-infrastructure` | `docs/plans/done/2026-05-20-feature-language-space-data-infrastructure.md`、`docs/README.md`、`docs/architecture/001-initial-module-boundaries.md`、`docs/development/environment.md`、`docs/development/mvp-development-roadmap.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/navigation/impl.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/testing/README.md` |
| 2026-05-18 | 用户确认全面 UI 审核方案，要求调用专业 skill 和子代理，从产品定位、Apple 三端交互、设计系统、docs 规范和代码契合度完成深审 | `2026-05-18-comprehensive-ui-review` | `docs/plans/active/2026-05-18-feature-comprehensive-ui-review-and-design-uplift.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/006-interface-localization-and-language-boundaries.md` |
| 2026-05-19 | 用户要求统一 iOS 请求预览卡片结论，并从项目定位和愿景出发审查 iOS 所有页面的每一个元素 | `2026-05-19-ios-page-element-design-audit` | `docs/product-main-reference.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md`、`Packages/LangoTraceUI/Sources/LangoTraceUI/` |
| 2026-05-18 | 第一轮 UI 收敛实施已覆盖 iPhone IA、显式本地化、learning content seam、Entry local preview、iPad 响应式、macOS Settings/commands、状态矩阵和 Memory 三层摘要，并把长期规范同步为当前事实源；原语言空间 lifecycle active 方案已被 2026-05-20 语言空间数据基础设施方案取代 | `2026-05-18-comprehensive-ui-review` | `docs/plans/done/2026-05-18-feature-first-round-ui-convergence.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/spec/ui-design/mvp-ui-flow-and-design-system.md`、`docs/plans/done/2026-05-20-feature-language-space-data-infrastructure.md` |
| 2026-05-18 | 用户要求基于项目定位、Apple 三端愿景和 Apple 相关 skill 审核开发文档体系，重点深审 `docs/spec/` | `2026-05-18-development-doc-system-audit` | `docs/README.md`、`docs/spec/`、`docs/product-main-reference.md`、`docs/technical-framework-roadmap.md`、`docs/review/README.md` |
| 2026-05-17 | String Catalog、App shell locale 注入、设置入口和 package resources 变更 | `2026-05-17-string-catalog-interface-language-settings` | `docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/testing/README.md`、`docs/archive/superpowers/plans/2026-05-17-string-catalog-interface-language-settings.md` |
| 2026-05-17 | `scripts/verify.sh` 增加 Data package 测试 | `2026-05-17-interface-localization-foundation` | `scripts/verify.sh`、`docs/README.md`、`docs/testing/README.md` |

## 长期健康度追踪

| 轮次 | 问题数 | 代码问题记录数 | 新会话可用抽样 |
| --- | --- | --- | --- |
| `2026-05-20-language-space-data-infrastructure` | 3 个问题，已修复 missing current fallback、iOS 重命名闭环和长期文档事实漂移；剩余风险是 App 层独立测试 target、存储错误视图、全语言翻译和 iPad/macOS 管理 UI | 2 个代码/测试问题，1 个文档事实问题 | 通过：README 覆盖发现、处理、剩余风险和验证记录 |
| `2026-05-19-ios-page-element-design-audit` | P1 5 个，P2 5 个，P3 3 个；核心结论是 iOS 主流程去说明化，请求预览只在显式外部 AI 请求中出现 | 13 个元素级设计 / 交互问题 | 通过：单轮 README 覆盖 Welcome、Onboarding、记录、详情、练习、记忆、设置、unavailable 和共享组件 |
| `2026-05-18-comprehensive-ui-review` | P1 9 个，P2/P3 多项，已进入第一轮 UI 收敛实施；语言空间删除、真实持久化、真实 AI/TTS/同步和完整截图矩阵仍由独立计划或后续验证承接 | 9 个 P1 级代码 / 架构 / 交互问题，第一轮已覆盖主要 UI / 架构 seam | 通过：README、page-map、findings、skill-evidence、spec-gap-review、分域报告和第一轮收敛方案可独立恢复任务背景 |
| `2026-05-18-development-doc-system-audit` | 8 个问题，均已修复为长期文档或实现地图 | 0 | 通过：spec 入口、数据 / 权限 / 测试规范、实现地图和阅读路径均已写回 |
| `2026-05-17-string-catalog-interface-language-settings` | 0 个阻断问题，3 个延后项 | 0 | 通过：验证命令、String Catalog 边界和视觉记录风险均已写入单轮记录 |
| `2026-05-17-interface-localization-foundation` | 0 | 0 | 通过：入口文档、验证脚本和测试文档均能指向当前验证方式 |
