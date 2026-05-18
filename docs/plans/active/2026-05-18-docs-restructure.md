# 文档体系重整任务方案

状态：In Progress
类型：docs
创建日期：2026-05-18
最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户要求先提交已完善的 `docs-system-improvement-plan.md`，然后按照该方案开始执行。
- 2026-05-18：已提交 `1f92aa9 docs: harden documentation restructure plan`，随后进入本任务阶段 0。

## 1. 需求描述

按根目录 `docs-system-improvement-plan.md` 重整 LangoTrace 文档体系，吸收 OpenWriter `dev_docs` 的目录设计优点，让后续开发能快速判断该读什么、该写什么、该验证什么。

本次任务的核心目标：

- 将 `docs/guidelines/` 重命名为 `docs/spec/`。
- 将原 worklog 草案和 plan 合并为统一任务方案文档，后续新任务写入 `docs/plans/active/`，完成后进入 `docs/plans/done/`。
- 创建 `docs/prompts/README.md` 并固定 Prompt 文档规则。
- 重整完成后创建 `docs/_meta/directory-responsibilities.md`，记录目录职责和规则层边界。
- 逐份迁移或归档 `docs/superpowers/` 与 `docs/worklogs/`，但不删除空目录；空目录由用户手动删除。

## 2. 现状描述

当前 `docs/README.md` 仍是根入口真实内容，根目录 `AI_ENTRY_POINT.md`、`CLAUDE.md`、`AGENTS.md` 均为指向 `docs/README.md` 的软链接。

当前入口仍把新功能、bug 修复和架构调整路由到 `docs/worklogs/`，并要求开发前读取 `docs/guidelines/`。这与本次重整目标冲突，是阶段 1 和阶段 2 必须修正的入口问题。

## 3. 目标

- 入口文档不再引导新任务写入 `docs/worklogs/`。
- 规范层目录统一为 `docs/spec/`。
- 任务方案目录能够替代旧 worklog 与 `superpowers/plans`。
- Prompt 规则现在固定，后续代码内置 Prompt 以英文为准，文档保存英文和中文版本。
- `_meta` 在重整完成后成为目录职责和写入规则的权威记录。

## 4. 范围

本次范围：

- 文档目录和文档内容重整。
- 文档引用路径更新。
- 历史文档迁移、归档或删除候选判断。
- 文档体系验证命令运行。

不修改 Swift 代码、Xcode 工程、脚本或资源文件。

## 5. 不做什么

- 不创建独立 `docs/implementation/`。
- 不在第一阶段把所有 `docs/spec/*.md` 强制改成模块目录。
- 不删除 `docs/superpowers/` 和 `docs/worklogs/` 空目录。
- 未获得用户确认前，不删除任何历史文档。
- 不修改与本次重整无关的代码或文档内容。

## 6. 证据与决策依据

- 根目录计划：`docs-system-improvement-plan.md`。
- 当前入口：`docs/README.md`。
- OpenWriter 对照结论：OpenWriter 没有独立 implementation 目录，模块实现地图与 spec 同目录存储。
- 用户明确要求：`guidelines` 改名为 `spec`；`superpowers` 内容归档后由用户手动删除；`worklogs` 与 `plans` 合并；置信度使用百分比；Prompt 文档保存中英双版本。

## 7. 涉及的代码文件路径

无。本任务为文档体系重整，不修改代码。

## 8. 参考的代码文件路径

无。

## 9. 涉及的文档路径

重点修改：

- `docs/README.md`
- `docs/documentation-system.md`
- `docs/review/README.md`
- `docs/review/INDEX.md`
- `docs/guidelines/` -> `docs/spec/`
- `docs/plans/`
- `docs/prompts/README.md`
- `docs/_meta/directory-responsibilities.md`
- `docs/superpowers/**`
- `docs/worklogs/**`

参考和验证：

- `docs-system-improvement-plan.md`
- `AI_ENTRY_POINT.md`
- `CLAUDE.md`
- `AGENTS.md`

## 10. 阶段 0 基线

### 10.1 `git status --short`

阶段 0 开始前：

```text
无输出
```

### 10.2 根入口软链接

```text
AGENTS.md -> docs/README.md
AI_ENTRY_POINT.md -> docs/README.md
CLAUDE.md -> docs/README.md
```

### 10.3 `docs/guidelines/` 文件清单

```text
docs/guidelines/001-guideline-governance.md
docs/guidelines/002-navigation-and-routing.md
docs/guidelines/003-ui-design-system.md
docs/guidelines/004-swiftui-architecture.md
docs/guidelines/005-ai-provider-prompt-and-privacy.md
docs/guidelines/006-interface-localization-and-language-boundaries.md
docs/guidelines/README.md
```

### 10.4 `docs/superpowers/` 文件清单

```text
docs/superpowers/plans/2026-05-17-language-space-persistence-startup-restore.md
docs/superpowers/plans/2026-05-17-mvp-ui-flow-and-design-system-implementation.md
docs/superpowers/plans/2026-05-17-settings-and-practice-state-closure.md
docs/superpowers/plans/2026-05-17-string-catalog-interface-language-settings.md
docs/superpowers/plans/2026-05-17-three-platform-page-closure.md
docs/superpowers/plans/README.md
docs/superpowers/specs/2026-05-17-string-catalog-interface-language-settings-design.md
docs/superpowers/specs/2026-05-18-interface-language-expansion-design.md
docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md
docs/superpowers/specs/README.md
docs/superpowers/specs/mvp-ui-flow-and-design-system.md
```

### 10.5 `docs/worklogs/` 文件清单

```text
docs/worklogs/2026-05-17-bug-code-test-docs-review-fixes.md
docs/worklogs/2026-05-17-bug-ios-letterboxed-launch-screen.md
docs/worklogs/2026-05-17-bug-ipad-page-closure-and-warnings.md
docs/worklogs/2026-05-17-chore-code-test-docs-review.md
docs/worklogs/2026-05-17-chore-docs-code-alignment.md
docs/worklogs/2026-05-17-chore-docs-review-mechanism.md
docs/worklogs/2026-05-17-chore-interface-localization-guideline.md
docs/worklogs/2026-05-17-chore-swiftui-app-shell-initialization.md
docs/worklogs/2026-05-17-feature-collapsible-side-panels.md
docs/worklogs/2026-05-17-feature-interface-localization-foundation.md
docs/worklogs/2026-05-17-feature-ios-ui-quality-pass.md
docs/worklogs/2026-05-17-feature-ipad-sidebar-edge-gestures.md
docs/worklogs/2026-05-17-feature-ipad-ui-quality-pass.md
docs/worklogs/2026-05-17-feature-language-space-persistence-startup-restore.md
docs/worklogs/2026-05-17-feature-onboarding-language-display.md
docs/worklogs/2026-05-17-feature-platform-navigation-refinement.md
docs/worklogs/2026-05-17-feature-privacy-status-icons.md
docs/worklogs/2026-05-17-feature-product-shell-navigation.md
docs/worklogs/2026-05-17-feature-settings-and-practice-state-closure.md
docs/worklogs/2026-05-17-feature-string-catalog-interface-language-settings.md
docs/worklogs/2026-05-17-feature-three-platform-page-closure.md
docs/worklogs/2026-05-17-feature-ui-completeness-and-design-system-review.md
docs/worklogs/2026-05-18-bug-interface-language-settings-detail-localization.md
docs/worklogs/2026-05-18-chore-interface-language-expansion-plan.md
docs/worklogs/2026-05-18-chore-premium-ui-principles-review-plan.md
docs/worklogs/2026-05-18-feature-interface-premium-ui-convergence.md
docs/worklogs/2026-05-18-feature-premium-ui-audit.md
docs/worklogs/2026-05-18-feature-premium-ui-completion-sweep.md
docs/worklogs/2026-05-18-feature-premium-ui-page-rollout.md
docs/worklogs/README.md
docs/worklogs/TEMPLATE.md
```

## 11. 迁移清单

字段含义：源路径 / 当前用途 / 目标动作 / 目标路径 / 判断依据 / 已检查引用 / 是否包含用户确认或关键决策 / 是否需要用户确认后删除 / 执行状态。

### 11.1 `docs/superpowers/`

| 源路径 | 当前用途 | 目标动作 | 目标路径 | 判断依据 | 已检查引用 | 包含确认或决策 | 需确认后删除 | 执行状态 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `docs/superpowers/plans/2026-05-17-language-space-persistence-startup-restore.md` | 语言空间持久化与启动恢复计划，状态 Shelved | move-active | `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md` | 未完成且仍对应当前优先级 | `rg` 命中入口和历史 worklog 引用 | 是 | 否 | pending |
| `docs/superpowers/plans/2026-05-17-mvp-ui-flow-and-design-system-implementation.md` | MVP UI 闭环实施计划 | move-done | `docs/plans/done/2026-05-17-feature-mvp-ui-flow-and-design-system-implementation.md` | 相关 UI worklog 已记录 Verified/Implemented，保留为历史任务方案 | `rg` 命中 UI worklog 和 spec 引用 | 是 | 否 | pending |
| `docs/superpowers/plans/2026-05-17-settings-and-practice-state-closure.md` | 设置与练习状态闭环计划，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-settings-and-practice-state-closure.md` | 已验证任务方案，有实施追溯价值 | `rg` 命中对应 worklog | 是 | 否 | pending |
| `docs/superpowers/plans/2026-05-17-string-catalog-interface-language-settings.md` | String Catalog 与界面语言设置计划 | move-done | `docs/plans/done/2026-05-17-feature-string-catalog-interface-language-settings.md` | 已实施且被审查轮次引用 | `rg` 命中 review 与 worklog | 是 | 否 | pending |
| `docs/superpowers/plans/2026-05-17-three-platform-page-closure.md` | 三端页面闭环计划，状态 Completed | move-done | `docs/plans/done/2026-05-17-feature-three-platform-page-closure.md` | 已完成且对应 worklog 引用 | `rg` 命中对应 worklog | 是 | 否 | pending |
| `docs/superpowers/plans/README.md` | 旧实施计划目录说明 | archive | `docs/archive/superpowers/plans/README.md` | 新 `docs/plans/README.md` 将替代其当前职责，旧说明保留为迁移证据 | `rg` 命中 worklogs README | 否 | 否 | pending |
| `docs/superpowers/specs/2026-05-17-string-catalog-interface-language-settings-design.md` | String Catalog 与界面语言设置规格草案 | move-spec | `docs/spec/interface-localization/2026-05-17-string-catalog-interface-language-settings-design.md` | 属于长期界面国际化设计规格，后续可与现有 spec 合并 | `rg` 命中 review 与扩展设计引用 | 是 | 否 | pending |
| `docs/superpowers/specs/2026-05-18-interface-language-expansion-design.md` | 主流界面语言扩展方案，状态 Implemented | move-spec | `docs/spec/interface-localization/2026-05-18-interface-language-expansion-design.md` | 属于界面语言扩展规范和实施依据 | `rg` 命中历史 worklog | 是 | 否 | pending |
| `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md` | 付费级 UI 原则和审查计划 | move-spec | `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md` | 属于 UI 规范补充和审查方法，不应继续放在 superpowers | `rg` 命中多个 UI worklog | 是 | 否 | pending |
| `docs/superpowers/specs/mvp-ui-flow-and-design-system.md` | MVP 页面闭环与设计系统规格 | move-spec | `docs/spec/ui-design/mvp-ui-flow-and-design-system.md` | 属于 UI 与页面闭环规格 | `rg` 命中 UI guideline 和 plan | 是 | 否 | pending |
| `docs/superpowers/specs/README.md` | 旧规格目录说明 | archive | `docs/archive/superpowers/specs/README.md` | 新 `docs/spec/README.md` 将替代其当前职责，旧说明保留为迁移证据 | `rg` 命中少量目录说明 | 否 | 否 | pending |

### 11.2 `docs/worklogs/`

| 源路径 | 当前用途 | 目标动作 | 目标路径 | 判断依据 | 已检查引用 | 包含确认或决策 | 需确认后删除 | 执行状态 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `docs/worklogs/2026-05-17-bug-code-test-docs-review-fixes.md` | 代码/测试/文档审查修复记录，状态 Verified | move-done | `docs/plans/done/2026-05-17-bug-code-test-docs-review-fixes.md` | 已验证 bug 修复记录 | `rg` 命中自身和相关 worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-bug-ios-letterboxed-launch-screen.md` | iOS 首屏未占满修复，状态 Verified | move-done | `docs/plans/done/2026-05-17-bug-ios-letterboxed-launch-screen.md` | 已验证 bug 修复记录 | `rg` 命中相关 UI worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-bug-ipad-page-closure-and-warnings.md` | iPad 页面闭环和 warning 修复，状态 Completed | move-done | `docs/plans/done/2026-05-17-bug-ipad-page-closure-and-warnings.md` | 已完成 bug 修复记录 | `rg` 命中历史记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-chore-code-test-docs-review.md` | 代码/测试/文档审查记录，状态 Verified | move-done | `docs/plans/done/2026-05-17-chore-code-test-docs-review.md` | 审查证据仍有追溯价值 | `rg` 命中修复 worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-chore-docs-code-alignment.md` | 文档与代码一致性审查，状态 Verified | move-done | `docs/plans/done/2026-05-17-chore-docs-code-alignment.md` | 文档治理记录有追溯价值 | `rg` 命中历史记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-chore-docs-review-mechanism.md` | 文档审查机制建立记录，状态 Verified | move-done | `docs/plans/done/2026-05-17-chore-docs-review-mechanism.md` | 记录当前 review 机制来源 | `rg` 命中多个 review 说明 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-chore-interface-localization-guideline.md` | 界面国际化规范草案记录，状态 Verified | move-done | `docs/plans/done/2026-05-17-chore-interface-localization-spec.md` | 已形成长期 spec，历史过程保留 | `rg` 命中 spec 引用 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-chore-swiftui-app-shell-initialization.md` | SwiftUI App Shell 初始化记录，状态 Verified | move-done | `docs/plans/done/2026-05-17-chore-swiftui-app-shell-initialization.md` | 重要工程初始化追溯 | `rg` 命中历史记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-collapsible-side-panels.md` | iPad/Mac 可收起侧栏记录，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-collapsible-side-panels.md` | 已验证功能记录 | `rg` 命中后续导航 worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-interface-localization-foundation.md` | 界面国际化基础落地，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-interface-localization-foundation.md` | 已验证功能记录 | `rg` 命中历史记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-ios-ui-quality-pass.md` | iOS UI 质量优化，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-ios-ui-quality-pass.md` | 已验证功能记录 | `rg` 命中 UI 记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-ipad-sidebar-edge-gestures.md` | iPad 边缘手势，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-ipad-sidebar-edge-gestures.md` | 已验证功能记录 | `rg` 命中相关 worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-ipad-ui-quality-pass.md` | iPad UI 质量优化，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-ipad-ui-quality-pass.md` | 已验证功能记录 | `rg` 命中历史记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-language-space-persistence-startup-restore.md` | 语言空间持久化任务，状态 Shelved | move-active | `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md` | 未完成且仍是当前优先级 | `rg` 命中 superpowers plan | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-onboarding-language-display.md` | 首次启动语言选择优化，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-onboarding-language-display.md` | 已验证功能记录 | `rg` 命中 UI spec | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-platform-navigation-refinement.md` | 平台导航优化，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-platform-navigation-refinement.md` | 已验证功能记录 | `rg` 命中相关 worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-privacy-status-icons.md` | 隐私状态图标优化，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-privacy-status-icons.md` | 隐私边界说明有长期追溯价值 | `rg` 命中历史记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-product-shell-navigation.md` | 产品壳导航，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-product-shell-navigation.md` | 核心启动/导航历史记录 | `rg` 命中多个后续 worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-settings-and-practice-state-closure.md` | 设置与练习状态闭环，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-settings-and-practice-state-closure.md` | 已验证功能记录 | `rg` 命中 superpowers plan | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-string-catalog-interface-language-settings.md` | String Catalog 与界面语言设置闭环，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-string-catalog-interface-language-settings.md` | 已验证功能记录且被 review 引用 | `rg` 命中 review 和 superpowers | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-three-platform-page-closure.md` | 三端页面闭环，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-three-platform-page-closure.md` | 已验证功能记录 | `rg` 命中 superpowers plan | 是 | 否 | pending |
| `docs/worklogs/2026-05-17-feature-ui-completeness-and-design-system-review.md` | 页面完整性与设计系统审查，状态 Verified | move-done | `docs/plans/done/2026-05-17-feature-ui-completeness-and-design-system-review.md` | UI 审查历史记录 | `rg` 命中 superpowers plan | 是 | 否 | pending |
| `docs/worklogs/2026-05-18-bug-interface-language-settings-detail-localization.md` | 界面语言设置详情本地化 bug，状态 Verified | move-done | `docs/plans/done/2026-05-18-bug-interface-language-settings-detail-localization.md` | 已验证 bug 修复记录 | `rg` 命中历史记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-18-chore-interface-language-expansion-plan.md` | 界面语言扩展方案与首批实现，状态 Implemented | move-done | `docs/plans/done/2026-05-18-chore-interface-language-expansion-plan.md` | 已实施计划记录 | `rg` 命中 superpowers spec | 是 | 否 | pending |
| `docs/worklogs/2026-05-18-chore-premium-ui-principles-review-plan.md` | 付费级 UI 设计原则与审查计划，状态 Implemented | move-done | `docs/plans/done/2026-05-18-chore-premium-ui-principles-review-plan.md` | 已实施计划记录 | `rg` 命中 superpowers spec | 是 | 否 | pending |
| `docs/worklogs/2026-05-18-feature-interface-premium-ui-convergence.md` | 付费级 UI 风格收敛，状态 Verified | move-done | `docs/plans/done/2026-05-18-feature-interface-premium-ui-convergence.md` | 已验证功能记录 | `rg` 命中后续 UI worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-18-feature-premium-ui-audit.md` | 三端付费级 UI 全面审查，状态 Implemented | move-done | `docs/plans/done/2026-05-18-feature-premium-ui-audit.md` | 大型审查和修复证据 | `rg` 命中后续 UI worklog | 是 | 否 | pending |
| `docs/worklogs/2026-05-18-feature-premium-ui-completion-sweep.md` | 付费级 UI 收敛扫尾，状态 Implemented | move-done | `docs/plans/done/2026-05-18-feature-premium-ui-completion-sweep.md` | 已实施功能记录 | `rg` 命中后续记录 | 是 | 否 | pending |
| `docs/worklogs/2026-05-18-feature-premium-ui-page-rollout.md` | 付费级 UI 页面推广，状态 Implemented | move-done | `docs/plans/done/2026-05-18-feature-premium-ui-page-rollout.md` | 已实施功能记录 | `rg` 命中后续记录 | 是 | 否 | pending |
| `docs/worklogs/README.md` | 旧 worklog 目录规范 | archive | `docs/archive/worklogs/README.md` | 新 `docs/plans/README.md` 将替代；旧规范保留为迁移证据 | `rg` 命中入口和 review 历史 | 否 | 否 | pending |
| `docs/worklogs/TEMPLATE.md` | 旧 worklog 模板 | archive | `docs/archive/worklogs/TEMPLATE.md` | 新任务方案模板将替代；旧模板保留为迁移证据 | `rg` 命中占位扫描排除规则 | 否 | 否 | pending |

## 12. 实施方案

按 `docs-system-improvement-plan.md` 第 10 节执行：

1. 阶段 0：创建本任务方案，记录基线和迁移清单，不移动、不删除历史文件。
2. 阶段 1：将 `docs/guidelines/` 重命名为 `docs/spec/` 并修正入口引用。
3. 阶段 2：建立统一 `docs/plans/` 目录和任务方案模板。
4. 阶段 3：建立 `docs/spec/README.md` 的模块实现地图规则和 `impl-template.md`。
5. 阶段 4：建立 `docs/prompts/README.md`。
6. 阶段 5：按清单迁移或归档 `docs/superpowers/`。
7. 阶段 6：按清单迁移或归档 `docs/worklogs/`。
8. 阶段 7：创建 `_meta` 目录职责文档，将本方案移入 `docs/plans/done/`。

## 13. 复查方法

- 对每个迁移文件检查是否有引用需要更新。
- 对入口文档检查是否仍把新任务路由到旧目录。
- 对旧目录检查是否只剩用户手动删除的空目录或已归档内容。
- 对 `_meta` 检查是否覆盖每个目录职责、权威类型、写入规则和禁止事项。

## 14. 验证命令

每阶段至少运行：

```bash
find docs -maxdepth 4 -type f | sort
rg "docs/guidelines|guidelines/" docs
rg "docs/superpowers|superpowers/" docs
rg "docs/worklogs|worklogs/" docs
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*'
git diff --check
git status --short
```

本任务不修改 Swift 代码；除非后续实际改动代码或脚本，否则不运行 `scripts/verify.sh`。

## 15. 文档影响检查

本任务本身就是文档体系重整，必须同步更新：

- 总入口和阅读路径。
- 文档体系说明。
- 审查机制说明。
- 任务方案模板和目录说明。
- Prompt 文档规则。
- `_meta` 目录职责。

## 16. 实施记录

- 2026-05-18：提交执行前方案强化：`1f92aa9 docs: harden documentation restructure plan`。
- 2026-05-18：阶段 0 开始，读取 `docs/README.md` 和 `docs-system-improvement-plan.md`。
- 2026-05-18：采集当前 `git status --short`、`docs` 文件清单、旧路径引用和根入口软链接。
- 2026-05-18：创建本任务方案并建立 `docs/superpowers/`、`docs/worklogs/` 迁移清单。

## 17. 完成标准

- `docs/guidelines/` 已重命名为 `docs/spec/`。
- 新任务入口统一为 `docs/plans/active/`。
- 已完成任务统一进入 `docs/plans/done/`。
- `docs/prompts/README.md` 已创建并说明规则。
- `docs/spec/README.md` 已说明模块实现地图 `impl.md` 规则。
- `docs/_meta/directory-responsibilities.md` 已创建并被入口引用。
- `docs/superpowers/` 和 `docs/worklogs/` 已完成分类迁移或归档。
- 旧路径引用已清理到不再误导新任务。

## 18. 剩余风险

- `docs/worklogs/` 与 `docs/superpowers/` 中有多份历史文档互相引用，迁移阶段必须统一更新引用，避免断链。
- 部分历史文档状态为 `Implemented` 而非 `Verified`，迁移到 `done` 代表历史已实施记录，不等于重新验证代码现状。
- 迁移清单中的 `move-spec` 可能后续还需要进一步合并到现有 spec，本任务先完成目录归档和引用修正。
