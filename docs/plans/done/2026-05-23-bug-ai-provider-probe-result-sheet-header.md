# AI Provider 测试结果面板顶部样式修复

状态：Done  
日期：2026-05-23  
类型：Bug Fix / UI  
范围：AI Provider 设置页测试结果 sheet 顶部布局

## 背景

用户在 iPhone 17 模拟器中使用 OpenRouter TTS 测试成功后，测试结果面板可以正确展示“测试成功”和各能力状态，但半高 sheet 顶部视觉拥挤：系统拖拽柄、标题行和背景模糊内容叠在一个很窄区域里，顶部观感不够干净。

该问题不影响 Provider / TTS 测试链路，本任务只修复结果面板呈现样式。

## 根因

`AIProviderProbeResultPanelContent` 原先直接从 `VStack` 顶部开始绘制标题行，并依赖系统 sheet 的默认拖拽柄。半高 sheet 下背景内容被模糊透出，默认拖拽柄与面板内容的顶部间距不足，导致标题区不具备独立的视觉层级。

## 已实施

1. 在紧凑宽度的 AI Provider 测试结果 sheet 上隐藏系统 drag indicator。
2. 在 `AIProviderProbeResultPanelContent` 内增加 `AIProviderProbeResultSheetHandle`，让面板顶部拥有稳定自定义 handle。
3. 抽出 `AIProviderProbeResultHeaderRow`，把状态图标、标题和关闭按钮组织成独立标题行。
4. 在标题行与 capability rows 之间加入 `Divider()`，避免列表起点贴近标题。
5. 保持现有测试逻辑、能力行、语音试听按钮、重试按钮和 compact detents 行为不变。
6. 更新 `docs/platform-page-inventory.md` 和 `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`，记录结果面板顶部样式约束。

## 测试记录

先更新 UI package 中 AI Provider 设置探针相关 source-boundary 测试，固定以下约束：

- 结果面板有自定义顶部 handle。
- 结果面板 sheet 隐藏系统 drag indicator。
- 顶部标题行与能力列表之间有明确分隔。

红灯验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

结果：失败，新增断言捕获当前实现缺少 `AIProviderProbeResultSheetHandle`、`AIProviderProbeResultHeaderRow`、`Divider()` 和 `.presentationDragIndicator(.hidden)`。

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

结果：通过，15 tests。

完整 UI package 验证：

```bash
swift test --package-path Packages/LangoTraceUI
```

结果：通过，207 tests。

统一验证：

```bash
scripts/verify.sh
```

结果：通过；SwiftLint 仍有既有 warning，0 serious。
