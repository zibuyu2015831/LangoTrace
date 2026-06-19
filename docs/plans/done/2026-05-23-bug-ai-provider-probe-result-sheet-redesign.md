# AI Provider 测试结果面板 Apple 风格重设计

状态：Done  
日期：2026-05-23  
类型：Bug Fix / UI  
范围：AI Provider 设置页测试结果 bottom sheet

## 背景

用户在 iPhone 17 模拟器中继续验证 OpenRouter TTS 测试时反馈，测试结果面板仍然“不好看”。截图显示当前面板虽然已隐藏系统 drag indicator，但仍存在明显 Apple UI 违和感：

- 顶部状态标题靠左且图标过重，像调试工具标题，不像 iOS bottom sheet。
- 测试中状态下能力列表像表格堆叠，缺少 grouped list 的层级。
- 禁用的“重新测试”大按钮在底部发白，形成无意义的大块视觉噪声。
- 当前 active / testing 行的视觉反馈过重，抢走标题和结果状态的焦点。

本任务只重设计结果面板展示，不改 Provider / TTS 测试请求、能力状态判断、试听播放 seam 或持久化逻辑。

## 设计原则

1. 遵循 iOS bottom sheet 习惯：顶部使用克制 handle、居中状态标题、右上关闭按钮。
2. 测试中状态优先表达“正在进行”，不展示不可点击的大号主按钮。
3. 能力结果使用 grouped card，不做整行高亮；状态靠图标、文字和右侧状态共同表达，不能只靠颜色。
4. 结果完成后才展示“重新测试”操作，且保持底部 thumb zone。
5. 保持 44pt 最小触控目标和现有本地化 key。

## 已实施

1. `AIProviderProbeResultPanelContent` 改为状态 chrome、grouped capability list 和 footer action 三段式布局。
2. 新增 `AIProviderProbeResultChrome`：顶部 handle 居中，状态标题居中，关闭按钮置于右上；测试中使用小号 `ProgressView`。
3. 新增 `AIProviderProbeCapabilityList`：能力结果进入 grouped card，行间用细分隔，去掉整行 active 背景。
4. 调整 `AIProviderProbeCapabilityRow`：图标缩小、文字层级降低、行高稳定为 52pt，保留右侧状态与成功 TTS 试听按钮。
5. `Retry` 按钮只在非测试中展示，避免测试中禁用大按钮造成发白底部噪声。
6. 更新 `docs/platform-page-inventory.md` 和 `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`，沉淀结果面板 Apple 风格约束。

## 测试记录

红灯验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

结果：失败，新增 source-boundary 断言捕获旧实现缺少 `AIProviderProbeResultChrome`、`AIProviderProbeCapabilityList`、`ProgressView()`、非测试中才显示重试按钮和 grouped card。

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
