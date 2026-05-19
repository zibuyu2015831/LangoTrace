# 任务方案：Welcome 双语展示与 lint 长度收口

状态：Done
类型：bug
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

2026-05-19：用户指出 `scripts/verify.sh` 仍有 4 个非 serious SwiftLint 长度 warning，需要修复；同时指出英文界面下 Welcome 示例卡片的原始随笔和改写都变成英文，无法明确体现语言学习 App，应保持双语展示。

## 1. bug 描述

Welcome 示例卡片在英文界面中把原始随笔也本地化成英文，导致 `source note -> rewrite` 的学习关系不清晰；另外 `WelcomeView.swift` 和 `WelcomeHomeOptimizationTests.swift` 超过 SwiftLint 的 file length / type body length 阈值。

置信度：95%

## 2. 复现方式

1. 将模拟器或 App 界面语言设置为英文。
2. 打开首次启动 Welcome 页面。
3. 查看示例卡片：`My note` 和 `Rewrite` 均为英文。
4. 运行 `scripts/verify.sh`，观察 SwiftLint warning。

## 3. 预期行为

- Welcome 示例卡片应保持双语：原始随笔作为生活线索使用中文，目标语言改写使用英文。
- `scripts/verify.sh` 不再报告 Welcome 相关 SwiftLint file length / type body length warning。

## 4. 实际行为

- 英文界面下 `My note` 和 `Rewrite` 同为英文，学习闭环表达不清晰。
- `scripts/verify.sh` 报告：
  - `WelcomeHomeOptimizationTests.swift` file length
  - `WelcomeHomeOptimizationTests.swift` type body length
  - `WelcomeView.swift` file length
  - `WelcomeView.swift` type body length

## 5. 根因分析

- `sourceNoteKey` 参与普通界面本地化，英文 locale 下被翻译为英文，丢失“用户原始随笔”的双语对照含义。
- Welcome 页面多轮迭代后将多平台布局 helper 和测试集中在单个文件，超过 SwiftLint 阈值。

## 6. 目标

- 所有界面语言下，三张示例的 `sourceNote` 都固定展示中文生活线索，`rewrittenText` 固定展示英文目标表达。
- 保留 section 标题和场景/难度等界面 chrome 的本地化。
- 拆分 Welcome 视图布局 helper 与测试文件，消除 4 个 SwiftLint warning。

## 7. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView+Layout.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeLayoutTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeTracePreviewContentTests.swift`

## 8. 不做什么

- 不接入真实目标语言选择逻辑。
- 不实现真实 AI、TTS、录音、语音转文本、持久化或权限。
- 不改变三张示例的难度排序。
- 不新增截图自动化。

## 9. 证据与决策依据

- Welcome 是首次解释产品价值的页面，必须让用户立即看到“生活记录原文 -> 目标语言表达”的跨语言关系。
- 当前早期默认学习闭环是中文生活线索到英文表达；Welcome 示例应清楚表达这一点，即使界面 chrome 使用英文、日文、法文等 locale。
- SwiftLint warning 虽非 serious，但用户明确要求修复，且拆分文件能提升后续维护性。

## 10. 实施方案

1. 先更新测试：断言所有 locale 的 `sourceNote` 为中文，所有 locale 的 `rewrittenText` 为英文，并新增源码拆分结构断言。
2. 运行 UI package 测试，确认新测试失败。
3. 更新 `Localizable.xcstrings`，让 `sourceNote` 固定中文、`rewrittenText` 固定英文。
4. 将 Welcome 布局 helper 从 `WelcomeView.swift` 拆到 `WelcomeView+Layout.swift`；将布局测试从 `WelcomeHomeOptimizationTests.swift` 拆到 `WelcomeHomeLayoutTests.swift`。
5. 运行 `swift test --package-path Packages/LangoTraceUI`、`git diff --check`、`scripts/verify.sh`。
6. 验证通过后将方案移动到 `docs/plans/done/`。

## 11. 复查方法

- 英文界面 Welcome 卡片中 `My note` 下是中文生活线索，`Rewrite` 下是英文表达。
- `scripts/verify.sh` 不再出现 Welcome 相关 SwiftLint 长度 warning。
- iPhone、iPad、Mac Welcome 仍共用同一示例卡片内容。

## 12. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
git diff --check
scripts/verify.sh
```

## 13. 文档影响检查

本任务修复 Welcome 示例展示和代码组织，不改变产品北极星、AI Provider、权限、数据、同步、StoreKit 或发布策略，因此不新增 ADR 或长期 spec。

## 14. 实施记录

2026-05-19：创建方案，准备按 TDD 先补充双语与 lint 结构测试。

2026-05-19：已新增 `WelcomeTracePreviewContentTests` 双语断言，先确认所有非中文 locale 的 `sourceNote` 仍被翻译时测试失败；新增 `WelcomeSourceOrganizationTests`，先确认 `WelcomeView+Layout.swift` 和 `WelcomeHomeLayoutTests.swift` 尚不存在时测试失败。

2026-05-19：已更新 `Localizable.xcstrings`：三张 Welcome 示例的 `sourceNote` 在 8 种界面语言下固定为中文生活线索，`rewrittenText` 在 8 种界面语言下固定为英文目标表达；section 标题、场景、难度、配音和跟读提示仍按界面语言本地化。

2026-05-19：已拆分 Welcome 源码：`WelcomeView.swift` 保留入口结构，`WelcomeView+Layout.swift` 承载平台布局 helper，`WelcomeCapsuleLabel.swift` 承载胶囊标签组件。已拆分布局测试到 `WelcomeHomeLayoutTests.swift`，保留内容/文案测试在原文件中。

2026-05-19：验证通过：

- `swift test --package-path Packages/LangoTraceUI`
- `git diff --check`
- `scripts/verify.sh`

`scripts/verify.sh` 中 SwiftLint 结果为 `Found 0 violations, 0 serious in 94 files`。

## 15. 完成标准

- 双语展示测试通过。
- SwiftLint 长度 warning 清零。
- 指定验证命令通过。
- 方案移动至 `docs/plans/done/`。

## 16. 剩余风险

- Welcome 示例仍是静态示例；真实目标语言选择和动态双语内容将在后续学习闭环中处理。
