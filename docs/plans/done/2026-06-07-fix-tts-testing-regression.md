# 修复 AI Provider 语音测试与播放回归

状态：Done
类型：bug
创建日期：2026-06-07
最后更新：2026-06-07
关联基线：`3e839261d3bb2d8907b144a6d04d559deeedaafd`

## 1. Bug 描述 (已修复)

用户反馈目前的语音生成测试功能（TTS Testing）失效，但在 5 月 24 日的版本中是可以使用的。表现为：
- 在 AI Provider 设置页中，即使配置了语音模型，点击“测试请求”后，语音合成的结果展示异常（通常显示为“未启用”或直接跳过）。
- 部分 Provider（如自定义 OpenAI 兼容适配器）在保存后，点击“听”按钮无法播放音频。

## 2. 复现方式

1. 打开 AI Provider 设置页。
2. 配置一个支持 TTS 的 Profile（如 OpenAI 或 OpenRouter）。
3. 启用语音生成，填写模型名。
4. 点击“测试请求”。
5. **预期**：结果面板应显示语音合成的测试状态（成功或具体错误）。
6. **实际**：结果面板显示语音合成为“未启用”，或测试根本没有触发语音部分。

## 3. 根因分析

通过对比 5 月 24 日（`f5116d6`）与当前代码，发现多处回归和逻辑漏洞：

### 3.1 探测服务中的静默失败 (AIProviderConfigurationService)
在 `mergedSavedTTSProbeResult` 方法中，最近的重构引入了一个宽泛的 `catch` 块。当凭证解析失败时，该方法会直接返回原始的 `textResult`。
- **后果**：由于 `textResult` 默认将 `speechSynthesis` 状态设为 `.notEnabled`，真正的错误被隐藏，用户只能看到误导性的“未启用”状态。

### 3.2 UI 按钮启用逻辑缺失 (AIProviderDraftConfiguration)
`AIProviderDraftConfiguration.configurationProbeReadiness` 属性在判断是否允许发起探测请求时，漏掉了对语音合成（Speech）的检查。
- **后果**：如果用户只配置了语音模型，按钮可能无法置灰。

### 3.3 强制要求文本节点 (AIProviderConfigurationService)
`testDefaultConfiguration` 方法要求 Profile 必须至少包含一个启用的 `textGeneration` 或 `embedding` 节点。
- **后果**：TTS-Only Profile 无法通过校验。

### 3.4 适配器支持缺失 (SentenceTTSGenerationService)
漏掉了对 `customOpenAICompatibleAudioSpeech` 的支持，导致保存后的播放失败。

## 4. 修复方案 (已实施)

### 4.1 核心服务修复 (LangoTraceAI)
1. **AIProviderConfigurationService**:
   - 修正了 `mergedSavedTTSProbeResult` 的 `catch` 逻辑，确保失败时返回包含对应错误 category 的结果。
   - 修改了 `testDefaultConfiguration` 的准入条件，允许只有 `tts` 节点启用的 Profile 进行测试。
2. **SentenceTTSGenerationService**:
   - 在 `adapter(for:)` 中补齐了 `customOpenAICompatibleAudioSpeech` 的支持。

### 4.2 UI 逻辑修复 (LangoTraceUI)
1. **AIProviderDraftConfiguration**:
   - 更新了 `configurationProbeReadiness`，当 `speech.isEnabled` 且符合完成条件时，允许发起探测。

## 5. 验证结果

### 5.1 自动化测试
- **UI 层**: 新增 `AIProviderSettingsProbeTests.ttsOnlyDraftAllowsConfigurationProbe`，验证 TTS-Only 配置下的探测就绪状态。
- **AI 层**: 运行 `LangoTraceAI` 全量测试，所有 99 项测试均通过。
- **综合**: 验证了自定义适配器支持和错误状态透传。

### 5.2 手动验证 (建议步骤)
- 在 iPhone/iPad 模拟器中创建一个仅启用语音合成的 Profile，验证“测试请求”按钮是否可用。
- 故意输入错误的 API Key，验证 TTS 测试是否能显示“鉴权失败”，而非“未启用”。
- 使用自定义 OpenAI 兼容接口，验证保存后的逐句播放功能。
