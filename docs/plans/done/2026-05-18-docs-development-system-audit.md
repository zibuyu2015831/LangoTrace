# 任务方案：开发文档体系审核与 spec 深审

状态：Verified
类型：docs
创建日期：2026-05-18
最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户要求基于 `AGENTS.md` 对 `docs/` 开发文档体系做一次审核和评估，要求调用 Apple 应用相关 skill，站在项目定位和愿景基础上深入评估，特别检查 `spec` 部分是否全面、准确、严谨。
- 2026-05-18：已在会话中形成方案，用户确认“Implement the plan”，允许创建本任务方案和对应文档审查 round。

## 1. 需求或 bug 描述

对 LangoTrace 的开发文档体系做一次面向后续 AI 辅助开发的治理审核。审核重点不是润色文案，而是判断当前 `docs/` 是否能让新会话基于项目定位、Apple 三端愿景、SwiftUI Multiplatform 技术路线和当前代码状态做出正确开发决策。

本轮尤其需要深审 `docs/spec/`：

- 是否覆盖当前阶段最关键的产品、架构、平台交互、AI、隐私、本地化和验证边界。
- 是否与 `product-main-reference.md`、`technical-framework-roadmap.md`、ADR、当前 Swift Package 和 App shell 事实一致。
- 是否足够严谨，能避免 AI 在导航、UI、Provider、隐私、语言空间、三端平台适配上自行发明新规则。

## 2. 现状描述

当前 `docs/` 已完成统一入口和文档治理机制：

- `docs/README.md` 是根入口，`AI_ENTRY_POINT.md`、`CLAUDE.md`、`AGENTS.md` 指向同一入口内容。
- `docs/plans/` 已替代历史 worklog，作为任务方案生命周期目录。
- `docs/review/` 已定义日常文档影响检查、事件触发专项审查和里程碑轻量全审。
- `docs/spec/` 当前包含导航与路由、UI 设计系统、SwiftUI 架构、AI Provider / Prompt / 隐私、界面国际化与语言边界等第一批核心规范。

当前工程仍处于 MVP 早期，已有 SwiftUI Multiplatform App shell、Core / Data / UI / AI / Speech / Sync package 边界、Mock 学习内容、三端页面骨架、界面语言设置基础和验证脚本。真实数据库、真实 AI、真实语音、真实同步和 StoreKit 尚未接入。

## 3. 目标

- 形成一次可归档的文档体系专项审查记录。
- 从产品定位、Apple 三端体验、SwiftUI 架构、本地优先和用户自带 Provider 角度评估 `docs/` 是否能指导后续开发。
- 输出 `docs/spec/` 的准确性、完整性、严谨性和可执行性问题清单。
- 明确哪些问题应直接修订文档，哪些需要用户澄清，哪些应分流为后续 feature / bug / refactor / docs 任务。
- 确认是否需要新增领域模型、数据存储、权限隐私、错误状态、测试验证、日志诊断、StoreKit / 发布等 spec。

## 4. 范围

本轮检查范围：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/architecture/`
- `docs/decisions/`
- `docs/plans/README.md`
- `docs/review/`
- `docs/testing/`
- `docs/spec/`
- 与文档断言相关的当前代码、配置、脚本和测试。

重点深审：

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/ui-design/`
- `docs/spec/interface-localization/`

## 5. 不做什么

- 不在本轮直接修改 Swift 代码。
- 不把审查中发现的代码 bug 顺手修掉；需要另开 bug 或 refactor 任务方案。
- 不把历史过程记录重写成当前事实。
- 不把尚未实现的真实数据库、AI、Speech、Sync、StoreKit 能力写成已完成。
- 不将 Apple HIG 或 SwiftUI skill 规则机械照搬为项目规则；只采纳与 LangoTrace 产品定位和当前阶段相关的约束。

## 6. 证据与决策依据

本轮依据：

- `docs/README.md` 中的项目北极星、核心决策、按任务类型阅读路径和完成前检查。
- `docs/product-main-reference.md` 中“用生活记录学习语言”的产品定位、语言空间和核心学习闭环。
- `docs/technical-framework-roadmap.md` 中 SwiftUI Multiplatform、SQLite / GRDB、Provider、Sync Adapter、本地优先和测试边界。
- `docs/decisions/` 中 SwiftUI Multiplatform、XcodeGen、语言空间、本地优先和用户自带 Provider ADR。
- 当前 `project.yml`、`scripts/verify.sh`、Swift packages、App shell 和测试文件。
- 已安装并调用的 Apple 相关 skill：iOS、iPadOS、macOS、SwiftUI Expert。

## 7. 涉及的代码文件路径

无。本文档任务不修改 Swift 代码。

## 8. 参考的代码文件路径

- `project.yml`
- `scripts/verify.sh`
- `LangoTraceApp/`
- `Packages/LangoTraceCore/`
- `Packages/LangoTraceData/`
- `Packages/LangoTraceUI/`
- `Packages/LangoTraceAI/`
- `Packages/LangoTraceSpeech/`
- `Packages/LangoTraceSync/`

## 9. 涉及的文档路径

预计新增或更新：

- `docs/plans/done/2026-05-18-docs-development-system-audit.md`
- `docs/review/rounds/2026-05-18-development-doc-system-audit/README.md`
- `docs/review/INDEX.md`

审查参考：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/architecture/`
- `docs/decisions/`
- `docs/spec/`
- `docs/testing/README.md`
- `docs/review/README.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

1. 创建本 active 任务方案，记录用户确认、范围、证据、步骤和验证方式。
2. 创建 `docs/review/rounds/2026-05-18-development-doc-system-audit/README.md`，作为本次专项审查的控制面。
3. 更新 `docs/review/INDEX.md`，登记本轮审查为 In Progress。
4. 审查时按以下顺序执行：
   - 产品定位和核心决策一致性。
   - Apple 三端平台体验完整性。
   - `docs/spec/` 逐份准确性和严谨性深审。
   - 当前代码、配置、测试与文档断言抽样核对。
   - 缺失 spec、跨文档冲突和后续任务分流。
5. 审查输出必须记录问题描述、决策依据、涉及代码文件路径、优化方向和复查方法。
6. 如问题较多或需要多轮澄清，将普通专项审查升级为复杂 round，并新增 `reports/`、`questions/`、`proposals/` 和 `consistency_check.md`。

## 12. 复查方法

- 从新 AI 会话视角检查：读取入口文档和相关 spec 后，是否能说清当前实现状态、下一步边界和验证方式。
- 抽样追踪核心能力：首次启动、语言空间、AI 请求预览、iPad 工作台、macOS 设置入口。
- 对每个 spec 判断其断言类型：当前实现事实、产品决策、架构决策、未来计划或历史过程。
- 对 Apple 平台规则判断其适配性：iPhone、iPadOS、macOS 是否各自有足够明确的开发边界。

## 13. 验证命令

文档产物完成前至少运行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如果后续审查导致代码、工程配置、验证脚本或 Swift package 变化，再运行：

```bash
scripts/verify.sh
```

## 14. 文档影响检查

本任务本身影响文档审查体系和任务方案体系：

- 新增 active 任务方案。
- 新增文档审查 round。
- 更新文档审查索引。

本轮最终已按审查结论修改长期 spec、实现地图、入口文档和审查索引。修改依据和验证结果已写入本方案与对应 review round。

## 15. 实施记录

- 2026-05-18：创建 active 任务方案。
- 2026-05-18：创建专项审查 round 入口。
- 2026-05-18：更新文档审查索引。
- 2026-05-18：完成本轮文档产物验证：
  - `find docs -maxdepth 3 -type f | sort`：通过，已确认 active 任务方案进入文档树。
  - `find docs/review/rounds -maxdepth 2 -type f | sort`：通过，已确认专项审查 round 入口存在。
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：退出码 1，无命中。
  - `git diff --check`：通过。
  - `git status --short`：仅显示本轮新增 / 修改的文档文件。
- 2026-05-18：进入 `docs/spec/` 深审，新增 `docs/review/rounds/2026-05-18-development-doc-system-audit/reports/spec-deep-audit.md`，登记 8 个 spec 问题，并同步更新审查 round README 的结论摘要和问题清单。
- 2026-05-18：完成 spec 深审后的文档验证：
  - `find docs -maxdepth 3 -type f | sort`：通过。
  - `find docs/review/rounds/2026-05-18-development-doc-system-audit -maxdepth 3 -type f | sort`：通过，已确认 round README 和 spec 深审报告存在。
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：退出码 1，无命中。
  - `git diff --check`：通过。
  - `git status --short`：仅显示本轮文档变更。
- 2026-05-18：按用户要求对 spec 深审问题做基于代码的严格复审，新增 `docs/review/rounds/2026-05-18-development-doc-system-audit/reports/spec-findings-rereview.md`；确认 8 个问题均可保留，并收窄 `SPEC-007`、`SPEC-008` 的描述，避免把已有内存学习内容闭环和测试文档误判为不存在。
- 2026-05-18：完成复审后的文档验证：
  - `find docs -maxdepth 3 -type f | sort`：通过。
  - `find docs/review/rounds/2026-05-18-development-doc-system-audit -maxdepth 3 -type f | sort`：通过，已确认复审报告存在。
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：退出码 1，无命中。
  - `git diff --check`：通过。
  - `git status --short`：仅显示本轮文档变更。
- 2026-05-18：根据复审结论完善长期 docs 体系：
  - 修正 `006` 状态和主流界面语言扩展实现状态。
  - 修正 MVP UI 当前事实，区分内存 mock 闭环和真实持久化缺口。
  - 新增数据存储、权限隐私、测试验证 3 个 spec。
  - 新增 interface localization、navigation、learning content 3 个实现地图。
  - 同步 `docs/spec/README.md`、`docs/README.md`、本轮 review README 和 `docs/review/INDEX.md`。
- 2026-05-18：完成长期 docs 体系完善后的文档验证：
  - `find docs -maxdepth 3 -type f | sort`：通过，已确认新增 spec 和实现地图进入文档树。
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：退出码 1，无命中。
  - `git diff --check`：通过。
  - `git status --short`：仅显示本轮文档变更。
- 2026-05-18：按用户要求执行收口复查，发现 `reports/spec-deep-audit.md` 原始问题表仍保留 `Open` 状态；已更新为 `Fixed` 并补充修复落点说明。复查还确认本轮 review README、任务方案、spec 入口、根入口和新增 spec / impl map 之间的状态一致。

## 16. 完成标准

- done 任务方案存在且范围、依据、步骤、验证方式明确。
- 专项审查 round 存在且登记为 Verified。
- `docs/review/INDEX.md` 已登记本轮审查和完成状态。
- 文档检查命令已运行，并记录结果。
- 后续执行者能从本方案、review round、spec 入口和实现地图理解当前文档体系边界。

## 17. 剩余风险

- 本轮没有修改 Swift 代码，也未运行 `scripts/verify.sh`；这是文档限定任务的有意边界。
- 后续真实数据、权限接入、macOS command surface、8 语言翻译和发布材料仍需按新增 spec 创建独立任务方案。
- Apple skill 内容已作为审查辅助依据筛选使用，长期规则仍以 LangoTrace 产品定位、ADR、代码事实和用户确认共同决定。
