# 文档审查：一键生成学习材料闭环

审查类型：专项审查
日期：2026-05-23
代码快照：d1f0d52d109be040035943c74545fd052e8a86c1
状态：In Progress
当前事实源：`docs/product-main-reference.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/learning-content/impl.md`、`docs/platform-page-inventory.md`、`docs/prompts/learning-material/one-tap-learning-material.md`
后续覆盖记录：`docs/plans/active/2026-05-22-feature-one-tap-learning-material-flow.md`
可作为依据：No

## 1. 触发原因

一键生成学习材料闭环触发了数据库 schema、GRDB repository、AI Provider 真实学习请求、Prompt Registry、Keychain 编排、App Shell 装配、iPhone 记录详情主流程和隐私披露边界变化，命中事件触发专项审查条件。

用户已确认本轮 UI 只先完成 iOS / iPhone；iPad 和 macOS 记录详情真实学习材料生成入口必须等 iOS 人工测试通过后再推进。

## 2. 审查范围

- `docs/plans/active/2026-05-22-feature-one-tap-learning-material-flow.md`
- `docs/product-main-reference.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/learning-content/impl.md`
- `docs/platform-page-inventory.md`
- `docs/prompts/learning-material/one-tap-learning-material.md`

## 3. 相关源码、脚本和配置

- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialPromptRegistry.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningMaterialGenerationActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `scripts/verify.sh`

## 4. 结论摘要

本轮审查确认长期文档已从“Entry / Rendering 仍为内存 mock、真实学习请求未接入”的旧事实，更新为当前实现事实：

- iPhone 记录详情已接入一个核心 AI 动作 `生成学习材料`。
- 真实生成请求经 App Shell action seam 进入 AI service，不由 SwiftUI View 直接读取 Keychain、拼 URLRequest 或访问 Provider SDK。
- Entry、LearningMaterial、analysis、candidate 和 operation 摘要已进入 GRDB repository。
- 原始 Entry 正文只读；派生 learning text 可编辑；重新分析只更新当前 learning text 的 analysis 和候选内容。
- iPad / macOS UI 接入明确延后，不能标记为三端完成。

## 5. 问题清单

| 编号 | 严重度 | 类型 | 证据 | 处理 |
| --- | --- | --- | --- | --- |
| R1 | P0 | 当前事实源过期 | `docs/spec/learning-content/impl.md` 仍写 Entry / Rendering 没有 GRDB repository | 已更新为 GRDB learning content repository、App Shell 装配和 iOS-only UI 落地事实 |
| R2 | P0 | 隐私 / AI 边界过期 | `docs/spec/005-ai-provider-prompt-and-privacy.md` 仍写真实学习内容请求未接入 | 已补充当前文本 Entry 的用户触发请求、非阻断确认、日志脱敏和平台范围 |
| R3 | P1 | 数据规范过期 | `docs/spec/007...` 仍只记录语言空间 GRDB 已落地，Entry / LearningMaterial 仍是后续项 | 已补充 Entry / LearningMaterial / candidate / operation 的 GRDB 主数据、导出、删除和测试边界 |
| R4 | P1 | 页面事实过期 | `docs/platform-page-inventory.md` 把记录详情标为 Implemented / Local Mock | 已标注 iOS Implemented / iPad macOS Deferred，并更新 iPad / macOS 后续接入边界 |
| R5 | P2 | Prompt Registry 状态过期 | Prompt 文档写生产代码尚未实现 | 已更新为 `LearningMaterialPromptRegistry` / `LearningMaterialGenerationService` 已接入，完整 Prompt 设计由文档维护 |

## 6. 文档修改记录

- 更新 `docs/product-main-reference.md`：补充 Entry 正文只读、LearningMaterial 作为 Rendering 第一版真实持久化形态、可编辑 learning text 和 iOS 优先范围。
- 更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`：补充一键学习材料真实请求、非阻断 AI 披露、结构化 JSON 和敏感字段禁止落日志规则。
- 更新 `docs/spec/007-data-storage-migration-export-and-attachments.md`：补充 learning content GRDB 主数据、operation 摘要、导出 / 备份排除字段和测试要求。
- 更新 `docs/spec/learning-content/impl.md`：从纯内存 mock 更新为 GRDB repository + AI generation service + iOS UI 的当前实现地图。
- 更新 `docs/platform-page-inventory.md`：记录 iPhone 已落地，iPad / macOS 待 iOS 人工测试通过后接入。
- 更新 `docs/prompts/learning-material/one-tap-learning-material.md`：修正生产代码实现状态。
- 更新本 active plan 实施记录：补充 App Shell、iPhone UI、可编辑 learning text、重新分析和文档同步阶段。

## 7. 用户澄清

无待澄清问题。用户已确认本轮先做 iOS / iPhone，iPad / macOS 待 iOS 端人工测试通过后再进行。

## 8. 延后项和原因

- iPad / macOS 真实学习材料生成 UI 接入：延后到 iOS 端人工测试通过后，避免三端同时接入时扩大 UI 和人工验收范围。
- Settings capability provider 长期拆分：当前仍通过 learning content repository 过渡提供，后续应拆出独立 provider。
- 完整 async facade：当前使用 `GRDBLearningContentRepositoryBridge` 兼容旧 UI 读取协议，后续平台接入时继续演进。
- Anthropic / Gemini 学习材料请求体：第一版不接入，保持 unsupported provider / model 边界。

## 9. 验证命令与结果

阶段性已通过：

- `swift test --package-path Packages/LangoTraceCore`
- `swift test --package-path Packages/LangoTraceData`
- `swift test --package-path Packages/LangoTraceAI`
- `swift test --package-path Packages/LangoTraceUI`
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
- `git diff --check`
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`

待最终收口：

- iOS 端人工测试记录。
- 本 review 状态从 `In Progress` 更新为 `Verified`。

完整自动验证：

- 2026-05-23：`scripts/verify.sh` 通过，覆盖 XcodeGen、Core / Data / AI / UI package tests、iPhone 17 / iPad Pro 13-inch / macOS build、SwiftLint、SwiftFormat lint、docs placeholder scan 和 `git status --short`。SwiftLint 保留 85 条 warning-level 风格告警，退出码为 0。

## 10. 剩余风险

- 当前 Prompt 代码使用紧凑英文模板加 Codable 校验，尚未完整展开本文档中的长版 Prompt 和 Provider-native JSON Schema 绑定；当前可用，但后续应继续收敛为更强结构化输出。
- iOS 真实 Provider 人工测试依赖可控 API Key / Provider 配置；自动化测试使用 mock HTTP response，不能证明外部 Provider 行为稳定。
- iPad / macOS 共享 `EntryDetailView` 但未接入真实生成 UI；后续平台接入必须复查大屏布局、状态展示和 AI 披露。
