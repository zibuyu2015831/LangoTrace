# 文档审查：开发文档体系与 spec 深审

审查类型：专项审查
日期：2026-05-18
代码快照：df338b5
状态：Verified

关联任务方案：

- `docs/plans/done/2026-05-18-docs-development-system-audit.md`

## 1. 触发原因

用户要求对 `docs/` 开发文档体系做一次深入审核和评估，判断该体系是否能指导 AI 正确理解 LangoTrace、参与后续开发，并特别评估 `docs/spec/` 是否全面、准确、严谨。

本轮必须站在项目定位和愿景基础上执行，并调用 Apple 应用相关 skill，从 iOS、iPadOS、macOS 和 SwiftUI 工程角度检查文档体系。

## 2. 审查范围

核心审查范围：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/architecture/`
- `docs/decisions/`
- `docs/spec/`
- `docs/testing/README.md`
- `docs/review/README.md`

重点深审：

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/ui-design/`
- `docs/spec/interface-localization/`

## 3. 相关源码、脚本和配置

本轮只读参考以下实现事实：

- `project.yml`
- `scripts/verify.sh`
- `LangoTraceApp/`
- `Packages/LangoTraceCore/`
- `Packages/LangoTraceData/`
- `Packages/LangoTraceUI/`
- `Packages/LangoTraceAI/`
- `Packages/LangoTraceSpeech/`
- `Packages/LangoTraceSync/`

## 4. 结论摘要

spec 深审初稿见：

- `reports/spec-deep-audit.md`
- `reports/spec-findings-rereview.md`

当前结论：

- `docs/spec/` 的总体方向正确，已经覆盖导航、UI、SwiftUI 架构、AI / Prompt / 隐私、界面国际化等高风险方向。
- 本轮已修复审查确认的主要文档体系问题：状态和事实层级已回正，缺失的高风险 spec 已补齐，验证权威关系已明确，关键模块实现地图已建立。
- 数据存储 / 迁移 / 导出、权限 / 本地隐私 / 日志、测试与验证现在已有 spec 级入口；`docs/testing/README.md` 继续作为具体测试流程和清单的主入口。
- 2026-05-18 复审确认 8 个问题均可保留，其中 `SPEC-007` 和 `SPEC-008` 已收窄措辞，避免误判已有内存学习内容闭环和测试文档。

## 5. 问题清单

审查时按以下分类记录问题：

| ID | 严重度 | 类型 | 问题 | 证据 | 优化方向 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| SPEC-001 | P1 | 文档准确性问题 | `006` 界面国际化规范仍标 Draft，但已被入口列为核心规范并被代码采用。 | `docs/spec/README.md`、`docs/spec/006-interface-localization-and-language-boundaries.md`、`InterfaceLanguagePreference.swift`、`project.yml` | 将 `006` 升级为 Accepted，或在入口明确其 Draft 非强制性质。 | Fixed |
| SPEC-002 | P0 | spec 过度承诺 | 多语言扩展文档标 Implemented，但 String Catalog 仍有大量 key 未覆盖新增 6 语言。 | `2026-05-18-interface-language-expansion-design.md`、`Localizable.xcstrings` 完整性检查 | 改为部分实现状态，并新增 String Catalog 覆盖检查。 | Fixed |
| SPEC-003 | P1 | 文档完整性缺口 | 数据存储、迁移、导出和附件边界缺少正式 spec。 | `docs/spec/README.md`、`mvp-ui-flow-and-design-system.md`、`DataBoundary.swift` | 新增数据存储 / 迁移 / 导出 spec。 | Fixed |
| SPEC-004 | P1 | 文档完整性缺口 | AI 隐私规则已有，但权限、本地隐私、Keychain、日志诊断缺少跨能力统一执行规则源。 | `003`、`005`、`docs/spec/README.md` | 新增权限与本地隐私 / 日志诊断 spec。 | Fixed |
| SPEC-005 | P2 | Apple 平台完整性缺口 | macOS Settings scene、菜单、快捷键、多窗口仍缺少阶段门槛。 | `002`、`004`、`LangoTraceApp.swift` | 细化 Mac command surface 的 spec 或 impl map。 | Fixed |
| SPEC-006 | P2 | spec 缺少实现地图 | 高风险模块没有 `impl.md`，当前事实散在长期规范和 done plans。 | `docs/spec/README.md`、`docs/spec/` 目录结构 | 为 interface localization、navigation、MVP content 补实现地图。 | Fixed |
| SPEC-007 | P2 | 文档准确性问题 | MVP UI 规格未分层表达内存 Entry / Rendering / Practice / Memory 闭环已存在与真实持久化缺口。 | `mvp-ui-flow-and-design-system.md`、`LearningContent.swift`、`PhoneMainView.swift` | 更新当前事实，区分真实持久化缺口和内存闭环已落地。 | Fixed |
| SPEC-008 | P2 | 测试与验证缺口 | 测试与验证内容已存在，但缺少 spec 级入口或对 `docs/testing/README.md` 的明确委托关系。 | `003`、`006`、UI 审查规格、`docs/testing/README.md`、`docs/spec/README.md` | 新增测试与验证 spec 或在 testing README 中建立 spec 级入口。 | Fixed |

类型取值：

- 文档准确性问题
- 文档完整性缺口
- 跨文档冲突
- spec 过度承诺
- spec 缺少实现地图
- 需要用户澄清
- 需要另开代码任务

## 6. 文档修改记录

- 2026-05-18：创建本轮专项审查入口。
- 2026-05-18：创建关联 active 任务方案。
- 2026-05-18：更新 `docs/review/INDEX.md` 登记本轮审查。
- 2026-05-18：完成 `docs/spec/` 深审初稿，新增 `reports/spec-deep-audit.md` 并将 8 个问题登记到本 README。
- 2026-05-18：完成基于代码的严格复审，新增 `reports/spec-findings-rereview.md`，并回修 `SPEC-004`、`SPEC-007`、`SPEC-008` 的问题表述。
- 2026-05-18：根据复审结论完善长期文档体系：
  - `docs/spec/006-interface-localization-and-language-boundaries.md`：状态升级为 Accepted。
  - `docs/spec/interface-localization/2026-05-18-interface-language-expansion-design.md`：状态改为 Partially Implemented，并补充 String Catalog 覆盖检查口径。
  - `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`：修正 MVP UI 当前事实，区分内存 mock 闭环和真实持久化缺口。
  - `docs/spec/007-data-storage-migration-export-and-attachments.md`：新增数据存储、迁移、导出与附件规范。
  - `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：新增权限、本地隐私与诊断日志规范。
  - `docs/spec/009-testing-and-verification.md`：新增测试与验证入口规范，明确委托 `docs/testing/README.md`。
  - `docs/spec/interface-localization/impl.md`、`docs/spec/navigation/impl.md`、`docs/spec/learning-content/impl.md`：新增实现地图。
  - `docs/spec/README.md`、`docs/README.md`：同步新规范和阅读路径。
- 2026-05-18：完成收口复查，发现 `reports/spec-deep-audit.md` 原始问题表仍保留 `Open` 状态；已同步为 `Fixed`，并补充修复落点，避免后续检索误判。

## 7. 用户澄清

当前无。

如审查中出现无法从现有文档、代码或 ADR 判断的产品 / 架构意图，在此记录问题，并等待用户确认后再写入长期文档。

## 8. 延后项和原因

本轮无未处理的审查问题。

有意不做的事项：

- 不在本轮直接修 Swift 代码。
- 不把未接入的数据库、AI、Speech、Sync、StoreKit 能力写成已完成。
- 不把 Apple skill 的通用规则机械照搬为项目规则。

## 9. 验证命令与结果

已运行：

```bash
find docs -maxdepth 3 -type f | sort
find docs/review/rounds -maxdepth 2 -type f | sort
find docs/review/rounds/2026-05-18-development-doc-system-audit -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

结果：

- `find docs -maxdepth 3 -type f | sort`：通过，已列出新增 active 任务方案。
- `find docs/review/rounds -maxdepth 2 -type f | sort`：通过，已列出本轮专项审查 README。
- `find docs/review/rounds/2026-05-18-development-doc-system-audit -maxdepth 3 -type f | sort`：通过，已列出本轮 README 和 `reports/spec-deep-audit.md`。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：退出码 1，无命中。
- `git diff --check`：通过。
- `git status --short`：仅显示本轮文档变更。

复审后补充运行：

```bash
find docs -maxdepth 3 -type f | sort
find docs/review/rounds/2026-05-18-development-doc-system-audit -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

结果：

- `find docs -maxdepth 3 -type f | sort`：通过，已确认 active 任务方案仍在文档树内。
- `find docs/review/rounds/2026-05-18-development-doc-system-audit -maxdepth 3 -type f | sort`：通过，已确认 `reports/spec-findings-rereview.md` 存在。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：退出码 1，无命中。
- `git diff --check`：通过。
- `git status --short`：仅显示本轮文档变更。

长期 spec 修复后补充运行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

结果记录在关联任务方案中。

结果：

- `find docs -maxdepth 3 -type f | sort`：通过，已确认新增 `007`、`008`、`009` 和三个 `impl.md` 进入文档树。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：退出码 1，无命中。
- `git diff --check`：通过。
- `git status --short`：仅显示本轮文档变更。

## 10. 剩余风险

- 本轮长期 spec 修复已完成；后续进入真实数据、权限、macOS command surface 或 8 语言翻译落地时仍需按新规范另建任务方案。
- Apple skill 规则需要结合 LangoTrace 产品定位筛选，不能机械变成项目约束。
- 本轮未修改 Swift 代码，未运行 `scripts/verify.sh`；剩余风险仅限文档与未来实现之间的持续一致性。
