# ADR-002: 使用 SwiftUI Multiplatform 作为 Apple 三端主框架

日期：2026-05-17

状态：Accepted

## 背景

语迹 LangoTrace 首发目标平台是 iPhone、iPad 和 macOS。产品定位是买断制精品 App，核心体验包括写作记录、照片、音频、TTS、跟读、听写、回译、OCR、AI Provider 配置、本地优先存储和长期语言记忆。

这些能力高度依赖 Apple 平台原生体验和系统能力。付费用户会关注输入体验、权限提示、文件、相机、麦克风、语音、快捷键、多窗口、系统融合和稳定性。

## 决策

使用 SwiftUI Multiplatform 作为 Apple 三端主框架。

具体方向：

- 使用 Swift 和 SwiftUI 构建 App shell 和主要 UI。
- iOS 和 iPadOS 共享 target，但在 UI 架构中保留 iPad 专属布局。
- macOS 使用原生 macOS 窗口、菜单、快捷键和桌面工作台体验。
- 业务逻辑和基础能力通过 Swift Package 或清晰模块边界共享。

## 备选方案

### React Native

优点：

- 移动端开发效率高。
- 前端生态成熟。

缺点：

- macOS 不是一等体验。
- 原生文本编辑、窗口、菜单、快捷键、文件拖拽和 Apple 系统能力需要大量桥接。
- 对付费精品 Apple App 的质感和长期维护不够理想。

### Flutter

优点：

- 跨平台 UI 一致性强。
- 性能和生态较成熟。

缺点：

- Apple 原生质感和系统融合仍需额外打磨。
- StoreKit、Keychain、Speech、Vision、PhotosUI、文件系统和 macOS 桌面体验需要更多适配。

### Tauri

优点：

- 桌面端和本地工具能力强。
- 适合未来扩展 Windows / Linux。

缺点：

- iOS / iPadOS 上相机、音频、TTS、Speech、Apple Pencil 和 StoreKit 体验不如原生自然。
- 容易出现 WebView 感。

## 影响

- 初期开发需要使用 Xcode、Swift、SwiftUI 和 Apple 工具链。
- 后续代码应优先按 Apple 平台交互习惯设计，而不是追求三端 UI 完全一致。
- 平台差异是设计目标，不是临时适配问题。
- 如果未来扩展 Android / Windows / Web，需要重新评估跨平台策略。

## 风险

- SwiftUI Multiplatform 在复杂 macOS 交互上仍可能需要 AppKit 辅助。
- 对 Swift / Xcode 不熟悉会增加早期学习成本。
- 如果未来需要非 Apple 平台，迁移成本较高。

## 复审条件

以下情况需要复审本决策：

- 产品决定首发同时支持 Android、Windows 或 Web。
- 早期用户明确主要集中在非 Apple 平台。
- SwiftUI 在核心交互、性能或平台差异处理上出现无法接受的限制。
- 团队结构变为 Web / Flutter / React Native 优先。

