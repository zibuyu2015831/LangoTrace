# 工作记录：文档与代码实现一致性审查

类型：chore

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/project-initialization.md`
- `docs/technical-framework-roadmap.md`
- `docs/development-environment.md`
- `docs/architecture/001-initial-module-boundaries.md`

关联 ADR：

- 无

关联提交：

- 未提交

## 1. 背景

用户要求检查 `docs/` 目录下相关文档是否需要更新，并强调文档体系内容需要和实际代码实现一一匹配。

当前代码已经从最初 App Shell 推进到产品体验骨架阶段，包含 Welcome / Onboarding / Main 启动路由、iPhone / iPad / macOS 分平台主界面、Core 语言与隐私模型、UI 侧栏折叠和 iPad 边缘手势测试。部分主文档仍停留在“工程未创建”或“首次启动功能前”的旧状态，需要修正事实描述。

## 2. 目标

- 入口文档的当前状态与代码实现一致。
- 初始化规划明确区分“历史规划”和“已落地状态”。
- 模块边界文档列出当前已实现的 package、类型和仍为空实现的边界。
- 技术路线与开发环境文档不再暗示项目仍停留在纯 App Shell 前后。
- 保持数据库、AI Provider、TTS、Speech、OCR、同步、StoreKit 等未实现能力的边界清晰。

## 3. 范围

本次处理：

- 文档事实同步。
- 当前实现快照补充。
- 验证命令说明同步。

## 4. 不做什么

本次不处理：

- Swift 代码修改。
- 新功能实现。
- 数据库、AI、同步、StoreKit 或发布策略设计。
- ADR 结论修改。
- 文档体系重组或归档。

## 5. 分析

代码侧当前事实：

- `project.yml` 已定义 `LangoTrace-iOS` 和 `LangoTrace-macOS`，iPad 作为 iOS target 的设备形态处理。
- `LangoTraceApp` 已通过 `AppEnvironment` 装配 Data / AI / Speech / Sync 的 disabled 或 empty 边界实现。
- `AppSessionState` 维护 welcome、onboarding、main 路由状态，语言空间当前仍为内存 `LanguageSpacePreview`。
- `Packages/LangoTraceCore` 已包含产品身份、平台角色、手机 Tab、语言、水平、隐私状态、启动路由和 onboarding draft。
- `Packages/LangoTraceUI` 已包含三端根视图、欢迎页、首次引导页、iPhone 主界面、iPad 主界面、macOS 主界面、底部语言空间工具区、面板折叠按钮和 iPad 面板手势 helper。
- `Packages/LangoTraceData`、`LangoTraceAI`、`LangoTraceSpeech`、`LangoTraceSync` 当前仍是协议和 disabled / empty 实现，不代表真实能力已完成。

文档侧主要偏差：

- `docs/README.md` 的当前状态过旧，只写到 App Shell 后、首次启动和语言空间功能前。
- `docs/project-initialization.md` 仍把 SwiftUI App 工程和 Swift Package 模块列为尚未创建。
- `docs/architecture/001-initial-module-boundaries.md` 没有反映当前实际类型和测试边界。
- `docs/technical-framework-roadmap.md` 缺少 Phase 0 当前进度说明。
- `docs/development-environment.md` 的下一步仍写成首次启动提问和根路由衔接，未体现这些已有内存骨架。

## 6. 方案

采用小范围文档修正：

- 保留原规划和决策文档的历史价值。
- 在关键文档中新增“当前落地状态”或“当前代码快照”。
- 不把 Mock UI 或 disabled service 描述成真实能力。
- 不新增 ADR，因为本次没有改变核心决策。

## 7. 风险与边界

- 风险：文档把 Mock UI 描述得过真，误导后续开发认为数据库、AI、同步已完成。
  - 处理：所有新增状态都明确区分“已实现骨架”和“未实现真实能力”。
- 风险：初始化规划被改成当前状态后失去历史计划价值。
  - 处理：保留规划内容，并增加状态说明，而不是重写为实施报告。

## 8. 测试与验证

完成前运行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff -- docs
git status --short
```

## 9. 用户确认记录

2026-05-17：用户要求检查并更新 `docs/` 与实际代码实现的一致性，可以开始处理。

## 10. 实施记录

- 更新 `docs/README.md` 的项目当前状态、已完成/未完成清单和验证脚本展开。
- 更新 `docs/project-initialization.md`，说明初始化规划已完成，并列出当前代码基线。
- 更新 `docs/architecture/001-initial-module-boundaries.md`，补充当前落地快照和未实现边界。
- 更新 `docs/technical-framework-roadmap.md`，补充 Phase 0 当前进度。
- 更新 `docs/development-environment.md` 的当前状态和下一步工程动作。
- 复查当前 Swift 类型后，将架构文档中的 `PrivacyStatus` 修正为实际存在的 `PrivacyStatusSeverity`、`AIProviderStatus` 和 `SyncProviderStatus`。
- 复查 `scripts/verify.sh` 后，将 `docs/README.md` 和 `docs/project-initialization.md` 中的脚本片段改为包含 `set -euo pipefail`、`cd` 和文档占位词失败门禁的实际结构。

## 11. 验证结果

已执行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff -- docs/README.md docs/project-initialization.md docs/architecture/001-initial-module-boundaries.md docs/technical-framework-roadmap.md docs/development-environment.md docs/plans/done/2026-05-17-chore-docs-code-alignment.md
rg -n "当前仓库尚未创建|SwiftUI App 工程|Swift Package 模块|处于 App Shell 后、首次启动和语言空间功能前|后续可使用的验证命令示例|RootView.swift|Resources/|Tests/|完整 onboarding|App icon。" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

结果：

- `find docs -maxdepth 3 -type f | sort` 正常列出文档树。
- 文档占位词扫描无命中。
- `git diff --check` 无输出，未发现空白错误。
- 关键词复查没有发现入口、初始化规划、架构、技术路线或开发环境文档继续声称 SwiftUI 工程和 package 尚未创建；命中项仅包括技术路线的技术栈描述、已更新后的“尚未创建或尚未实现”边界、当前工程结构中的 `Resources/`、最终品牌 App icon 未完成，以及历史 worklog 记录。
- `git status --short` 显示本次文档修改和新增 worklog；另有未跟踪目录 `case_skillatlas_review/`，本次未触碰。

追加复查：

```bash
rg -n '处于 App Shell 后|首次启动和语言空间功能前|当前仓库尚未创建：|SwiftUI App 工程。|Swift Package 模块。|RootView\.swift|后续可使用的验证命令示例|具体命令需在工程创建后|只需要落地|不需要落地|PrivacyStatus`' docs --glob '!docs/plans/done/**'
sed -n '1,80p' scripts/verify.sh
sed -n '330,365p' docs/README.md
sed -n '214,245p' docs/project-initialization.md
rg -n 'LanguageSpaceRepository|EmptyLanguageSpaceRepository|AIProvider|DisabledAIProvider|SpeechService|DisabledSpeechService|SyncService|DisabledSyncService|PrivacyStatusSeverity|AIProviderStatus|SyncProviderStatus|PadPanelGestureAction|LangoTraceRootView|AppSessionState|AppEnvironment' docs/architecture/001-initial-module-boundaries.md docs/project-initialization.md docs/README.md docs/development-environment.md Packages LangoTraceApp --glob '*.md' --glob '*.swift'
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

追加复查结果：

- 非 worklog 主文档未再命中“工程未创建”“旧阶段”“RootView.swift”“旧验证命令示例”等旧状态表述。
- `scripts/verify.sh` 与 `docs/README.md`、`docs/project-initialization.md` 中的脚本片段一致，均包含 `set -euo pipefail`、仓库根目录切换、Core/UI 测试、三端构建、SwiftLint、SwiftFormat 和文档占位词失败门禁。
- 架构文档中新增的类型名与当前 Swift 文件一致，包括 `PrivacyStatusSeverity`、`AIProviderStatus`、`SyncProviderStatus` 以及 Data / AI / Speech / Sync 的 empty / disabled 边界类型。
- 最终文档占位词扫描无命中，`git diff --check` 无输出。
