# 可访问性与本地化补审报告

## Scope

由于并行子代理数量达到上限，本域由主线程补审。依据 `iOS SwiftUI Accessibility`、`ios-design-guidelines`、`ui-ux-pro-max` 和 `docs/spec/006-interface-localization-and-language-boundaries.md`。

## Findings

- P1：显式 interface-language preference 未实际驱动多数自有 chrome，见 `LocalizedChrome.swift` 与 `LangoTraceApp.swift`。
- P1：Welcome 自动跳转缺少用户控制，影响 VoiceOver 和 timing accessibility。
- P2：unavailable sheet 缺标题、关闭按钮、滚动容器和 focus return。
- P2：Entry editor 的 `TextEditor` 缺少明确 accessible label。
- P2：language menu、practice step、sentence row、footer compact icons 存在 44pt / Dynamic Type 风险。
- P2：`LearningLanguage` / `OnboardingDraft` 中 `ChineseUI` display helpers 与界面语言边界冲突。
- P3：Section headings 需要 `.accessibilityAddTraits(.isHeader)`。
- P3：部分 hints 重复 label 或 visible summary。

## Required Updates

- 修复本地化 resolver，使显式 App 内语言偏好控制自有 SwiftUI chrome。
- 将 language display 从 Core 的 ChineseUI projection 移到 UI display helper。
- 建立 Dynamic Type 和长文案验证矩阵：iPhone SE、iPad Split View、macOS narrow window；至少覆盖 en、zh-Hans、es 和一组长名称。
- 为 sheet / popover / status row 建立统一 VoiceOver label / value / hint pattern。
