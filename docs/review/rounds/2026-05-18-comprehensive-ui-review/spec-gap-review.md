# 规范完整性与代码契合审查

## 需要更新的规范

### `docs/spec/002-navigation-and-routing.md`

缺口：

- 仍将 iPhone `今日 / 记录 / 练习 / 记忆 / 设置` 五 Tab 写为强制规则。
- 同一文档又要求设置低干扰、不抢主流程，二者冲突。
- iPad / macOS footer AI / Sync / Settings 关系需要更细地定义为状态入口、配置入口和系统设置入口。
- macOS Settings scene、commands 和快捷键需要从后续候选升级为第一轮 Mac 原生性要求。

建议：

- 将 iPhone 新结构改为 `记录 / 练习 / 记忆` 加低干扰设置入口，或先标注五 Tab 已被本轮审查推翻。
- 定义 Space summary / language-space lifecycle placeholder，不再把语言空间入口作为纯 unavailable 死路。

### `docs/spec/003-ui-design-system.md`

缺口：

- token 文档仍偏方向性，未覆盖 light / dark / high contrast / reduce transparency。
- 状态矩阵不足，`ready / local mock / unavailable / warning / error / permission denied / sync conflict` 需要明确。
- `langoPanel` 的使用边界缺失，导致卡片堆叠。
- Empty / unavailable / loading / error 的组件契约不完整。

建议：

- 增加状态矩阵、action hierarchy、platform surface adapter、responsive text pattern。

### `docs/spec/004-swiftui-architecture.md`

缺口：

- 已写 `contentRevision` 是临时状态，但缺少退出条件。
- 没有明确 `LearningContentRepository` protocol / feature store 的最低 UI seam。
- interface-language 本地化 resolver 与 SwiftUI locale 的关系需要写入实现约束。

建议：

- 规定 UI 只能依赖 repository protocol 或 feature store，concrete in-memory 只在 bootstrap / preview / tests 出现。
- 规定自有 chrome 本地化必须受显式 interface-language preference 控制。

### `docs/spec/006-interface-localization-and-language-boundaries.md`

缺口：

- 规范方向正确，但代码仍有 `ChineseUI` display model 和 `localizedText()` 不受显式偏好控制。
- 需要增加测试要求：系统语言与 App 内选择不同的场景。

建议：

- 增加本地化 resolver 验证要求和 language display projection 规则。

### `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`

缺口：

- 仍保留 iPhone 五 Tab 的 MVP 页面地图。
- `Entry -> Rendering -> Practice -> Memory` 中 Rendering 自动生成的 mock 心智需要改为显性状态。
- Memory 三层模型未反映到 MVP 页面地图。

建议：

- 更新为本轮审查后的第一轮 UI 收敛目标，避免继续以旧 IA 为实现依据。

## 代码与规范偏差

- `PhoneMainView.swift` 五 Tab 实现与本轮审查结论冲突。
- `PhoneMainView.swift` 一个 `NavigationStack` 包全 Tab，不符合 per-tab state preservation 预期。
- `OnboardingView.swift` 和 `LearningLanguage.swift` 仍有 ChineseUI display assumptions。
- `LocalizedChrome.swift` 的 localization resolver 不受显式 interface language preference 驱动。
- `LearningContent.swift` 在 `createEntry` 中自动创建 Rendering / Practice / Memory，需在真实 AI 前收敛。
- `LearningContentComponents.swift` Listen button 是空 action。
- `PadMainView.swift` 固定 HStack 和 `horizontalSizeClass` 处理不足。
- `MacMainView.swift` 没有 Settings scene / commands / keyboard shortcuts。
- `LangoTraceDesign.swift` 固定浅色 RGB 和 token coverage 不足。

## 文档状态建议

- 本 review 作为第一轮 UI 收敛和规范更新的当前依据。
- active plan 完成审查后不应直接移入 done，因为第一轮 UI 收敛尚未实现；应更新为“Review Completed / Implementation Pending”或拆分后续 plan 后再收口。
