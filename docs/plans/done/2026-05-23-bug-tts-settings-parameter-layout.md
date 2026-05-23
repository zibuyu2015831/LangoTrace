# 任务方案：TTS 参数设置区样式修复

状态：Done
类型：bug
创建日期：2026-05-23
最后更新：2026-05-23

## 1. 用户确认记录

- 2026-05-23：用户反馈 AI Provider 设置页语音生成模型中，音色和格式缺少标题，语速设置项不好看，“朗读指令”含义不清楚，要求整体重新设计该区域样式。该请求视为已确认立即修复。

## 2. Bug 描述

AI Provider 设置页的 TTS 参数区域把 `Picker` 直接渲染为菜单控件，iPhone 上只看到 `coral` 和 `MP3`，可见标题弱或缺失；语速使用 `Stepper` 的默认减号 / 加号样式，视觉上与设置页其它输入控件不一致；“朗读指令”对普通用户不够明确。

## 3. 复现方式

1. 打开 iPhone 设置页。
2. 进入 `AI Provider`。
3. 启用 `语音生成模型`。
4. 查看 Base URL、语音模型、API Key 后面的 TTS 参数区。

## 4. 预期行为

- 音色、格式、语速、风格说明都有清晰标题。
- 音色和格式的可选值以同一行标题和值呈现，值右侧使用菜单箭头。
- 语速以同一套设置页视觉语言呈现，避免孤立的系统 stepper。
- “朗读指令”改为更面向用户的“朗读风格”，用于描述语气、节奏、表达风格等可选提示。

## 5. 实际行为

- 音色和格式看起来像两行孤立文本，标题不明显。
- 语速控件像系统默认 stepper，和周围输入框、分段控件不协调。
- “朗读指令”不够直观，用户难以理解要填写什么。

## 6. 根因分析

置信度：90%。

根因是 `AIProviderOptionalModelSection.speechTTSFields` 直接使用 `Picker` 和 `Stepper`，没有复用设置页已有 row / input 视觉语言，也没有给复杂文本字段提供面向用户的说明文案。

## 7. 范围

涉及代码：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/TTSProviderSettingsTests.swift`

涉及文档：

- `docs/platform-page-inventory.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`

不做：

- 不改变 TTS 数据模型、Provider adapter、probe 请求和保存逻辑。
- 不新增真实 voice 列表 API。
- 不改动逐句播放逻辑。

## 8. 实施方案

已完成：

1. 新增 `TTSMenuSettingRow` 和 `TTSSpeedSettingRow`：左侧标题和说明，右侧菜单值或语速步进控件，保证 44pt 触控高度。
2. 将音色和格式改为标题明确的菜单行。
3. 将语速改为设置页内统一视觉的紧凑参数行，保留减 / 加按钮和当前倍速值，并补可访问性标签和值。
4. 将 “Instructions / 朗读指令” 文案改为 “Speaking style / 朗读风格”，并补说明文案。
5. 更新 UI 源码测试，检查新组件、标题 key 和说明 key 存在，避免回退到裸 Picker / Stepper。
6. 同步页面清单和 UI 设计规范。

## 9. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
swiftformat . --cache ignore
swiftlint --no-cache --quiet
git diff --check
```

如改动触发 Swift 工程整体风险，继续运行：

```bash
scripts/verify.sh
```

实际验证：

- 2026-05-23：`swift test --package-path Packages/LangoTraceUI` 通过，207 tests。
- 2026-05-23：`swiftformat . --cache ignore` 通过，0 files formatted。
- 2026-05-23：`swiftlint --no-cache --quiet` 通过，仍有既有 warning 级 lint 输出，无 serious。
- 2026-05-23：`git diff --check` 通过。
- 2026-05-23：文档占位扫描 `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'` 无匹配。
- 2026-05-23：`scripts/verify.sh` 通过，覆盖 XcodeGen、Core/Data/UI 包测试、iPhone/iPad/macOS build、SwiftLint、SwiftFormat lint、文档占位扫描和 `git status --short`。

## 10. 完成标准

- TTS 参数区标题清晰，音色和格式不再表现为无标题孤立菜单。
- 语速控件视觉与设置页一致，44pt 触控目标成立。
- 文案改为“朗读风格”并有简短说明。
- UI package 测试通过，文档同步。

## 11. 剩余风险

- 本次已通过代码结构测试、编译和完整验证脚本；最终视觉仍建议用户在模拟器中人工复核截图。
