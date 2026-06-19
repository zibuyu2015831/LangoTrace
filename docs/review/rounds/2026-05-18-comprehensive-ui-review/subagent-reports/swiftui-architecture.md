# SwiftUI 架构与规范契合审查报告

## 结论摘要

- 当前 UI 未调用真实 AI、网络、同步、Keychain 或数据库，P0 风险未发现。
- 主要架构风险在于界面语言偏好、repository seam、语言空间持久化、visible empty action 和 SwiftUI navigation / state 结构。

## 主要 Findings

- P1-1：显式 interface language preference 不实际驱动多数自有 chrome。
- P1-2：UI 依赖 concrete `InMemoryLearningContentRepository` 并直接 mutate。
- P1-3：`LanguageSpaceRepository` 存在但为空且未被 session state 使用。
- P1-4：`SentencePairView` Listen 是可见空 action。
- P2-1：iPhone 一个 `NavigationStack` 包全 Tab。
- P2-2：存在 modern SwiftUI API / swiftui-pro drift，例如 `.tabItem`、manual bindings、text concatenation。
- P2-3：View files 过于 multi-purpose。
- P2-4：Core display model 仍有 ChineseUI-specific helpers。
- P3-1：macOS entry editor sheet 未来适合 item-based presentation。

## Spec Alignment Gaps

- `004-swiftui-architecture`：UI 未与 concrete in-memory repository 隔离。
- `004-swiftui-architecture`：`contentRevision` 临时桥接已横跨三端。
- `003-ui-design-system`：Listen 空 action 违反页面闭环。
- `006-interface-localization-and-language-boundaries`：显式 App 语言偏好与自有 chrome 不一致。

## 第一轮建议

1. Listen 按钮接入 unavailable / local mock feedback。
2. 修复 interface-language rendering 或降级设置承诺。
3. 执行语言空间持久化 active plan。
4. 引入 content repository protocol 或 feature store。
5. 产品 IA 裁决后重新设计 iPhone navigation shape。
6. 增加 regression tests：settings language、empty actions、route fallback、repository seam。
