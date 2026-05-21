# AI Provider 模型级能力解析器重构方案

状态：Done
类型：refactor
创建日期：2026-05-21
最后更新日期：2026-05-21

## 1. 用户确认记录

- 2026-05-21：用户在 iOS 人工测试中选择 `OpenRouter` Provider，并输入支持图片能力的模型 `openai/gpt-5.4-image-2`，发现“图片理解”开关仍被禁用，UI 显示“当前 Provider 不支持”。
- 2026-05-21：代码检查确认当前 UI 只读取 `AIProviderPreset.capabilities.imageUnderstanding` 这个 Provider 静态布尔值；`OpenRouter` 被归入 `.openAICompatibleText`，因此图片理解能力固定为 `false`，不会考虑具体模型。
- 2026-05-21：用户确认当前设计不正确，要求立即优化，并强调这是 App 基础架构，必须一次性完成最优设计，不要留下隐患，同时为后续扩展留出空间。
- 2026-05-21：经架构讨论，采纳推荐方向：引入 Provider / Adapter / Endpoint / Model / User Enablement / Probe Result 分层能力解析，避免继续用单一 Provider 布尔值决定模型级能力。

## 2. 问题描述

AI Provider 设置页当前用 Provider preset 的静态能力布尔值控制图片理解开关：

```swift
draft.text.endpoint.provider.capabilities.imageUnderstanding
```

这在 OpenAI 这类官方 Provider 上暂时可用，但对 OpenRouter、Custom OpenAI-compatible、Ollama/local、SiliconFlow、DashScope 等聚合服务或兼容层是错误抽象。原因是这些 Provider 的能力并不由 Provider 名称单独决定，而是由至少五个因素共同决定：

1. Provider preset 是否允许表达某类能力。
2. 当前 adapter 是否知道如何构造该能力的请求体。
3. Endpoint purpose 是否适合承载该能力。
4. 当前 model 是否支持该输入或输出形态。
5. 用户是否明确允许发送对应敏感输入，例如图片。

当前设计把这些因素压扁为一个布尔值，导致：

- OpenRouter 中支持图片输入的模型被 UI 误挡，无法测试。
- Custom OpenAI-compatible 无法表达“我知道这个模型支持图片输入”。
- Gemini preset 可以声明图片能力，但当前 adapter 图片 probe 未接入，容易混淆“产品能力”和“代码已支持的测试能力”。
- 后续接入 TTS、Embedding、Speech Recognition、OCR、本地模型、动态模型列表时会继续复制同一类错误。
- UI 文案“当前 Provider 不支持”在模型级能力场景下不准确，误导用户认为服务商整体不支持。

## 3. 复现方式

1. 启动 iOS App，进入 AI Provider 设置页。
2. 将文本模型 Provider 选择为 `OpenRouter`。
3. Base URL 使用 `https://openrouter.ai/api/v1`。
4. 文本模型填写一个支持图片能力的 OpenRouter 模型，例如 `openai/gpt-5.4-image-2`。
5. 填入 API Key。
6. 查看“能力边界”中的“图片理解”开关。

## 4. 预期行为

当 Provider 是 OpenRouter 或 Custom OpenAI-compatible 这类模型能力由用户选择的 Provider，且当前 adapter 已支持图片输入 probe 时：

- UI 不应直接显示“当前 Provider 不支持”。
- 图片理解开关应可用，但必须明确提示“图片理解功能需要选择支持图片输入的模型”。
- 用户显式开启图片理解后，配置测试应携带项目内置合成图片进行真实 probe。
- 若模型或路由实际不支持图片输入，测试结果应显示模型、请求或 Provider 返回的失败，而不是在 UI 层预先误挡。

## 5. 实际行为

当前 `OpenRouter` preset 走 `AIProviderCapabilitySet.openAICompatibleText`，其中：

```swift
imageUnderstanding: false
```

因此 `AIProviderCapabilityBoundaryView` 收到 `supportsImageUnderstanding == false`，禁用 Toggle 并展示“当前 Provider 不支持”。用户即使填写了支持图片能力的模型，也无法启用图片理解 probe。

## 6. 根因分析

置信度：95%

根因是 AI Provider 能力模型层级错误：代码把 Provider preset 当成最终能力事实源，缺少模型级能力策略和 adapter 可测能力解析。

当前关键证据：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift` 中 `AIProviderCapabilitySet.openAICompatibleText.imageUnderstanding == false`。
- `AIProviderPreset.capabilities` 对除 OpenAI、Gemini、Custom 外的大多数 provider 返回 `.openAICompatibleText`。
- `OpenRouter` 因此静态继承 `imageUnderstanding == false`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 直接把 `draft.text.endpoint.provider.capabilities.imageUnderstanding` 传给 UI。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift` 中 Toggle 被 `.disabled(!supportsImageUnderstanding)` 控制。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift` 已经支持 OpenAI-compatible Chat 的图片请求体，说明这不是 adapter 完全不能测的问题，而是 UI / draft 能力判断提前挡住。

## 7. 备选原因

- 备选原因 1：OpenRouter 对该模型的图片输入格式和 OpenAI-compatible Chat 兼容格式存在差异。该风险可能存在，但不能解释 UI 开关被禁用；它应该在 probe 阶段暴露，而不是阻止用户开启。
- 备选原因 2：`openai/gpt-5.4-image-2` 更偏图片生成，不适合作为图片理解测试模型。即使成立，也不应由 Provider 静态布尔值拦截；模型能力失败应由真实 probe 结果表达。
- 备选原因 3：用户 API Key 权限不足或 OpenRouter 路由不可用。这只会影响测试请求结果，不应影响开关可用性。

## 8. 目标

1. 建立长期稳定的 AI Provider 能力解析架构，分离 Provider preset、Adapter 请求能力、Endpoint purpose、Model capability policy、用户显式授权和 Probe 结果。
2. 修复 OpenRouter / Custom OpenAI-compatible 下模型级图片能力无法启用的问题。
3. 保留隐私边界：用户未显式开启图片理解时，不发送任何图片输入。
4. 保留测试边界：只有 adapter 已支持图片请求体时，才允许进入图片 probe。
5. 保留扩展能力：后续可自然接入 OpenRouter models API、用户自定义模型能力、Gemini / Anthropic 图片 adapter、TTS、Embedding、Speech Recognition 和 OCR 能力测试。
6. 避免短期补丁：不得只把 OpenRouter 的 `imageUnderstanding` 改为 `true`。

## 9. 不做什么

- 不在本任务中接入 OpenRouter models API 动态拉取能力列表。
- 不根据模型名字符串做脆弱判断，例如 `model.contains("image")`。
- 不实现 Anthropic / Gemini 图片请求格式。
- 不新增用户照片、生活记录附件、OCR、照片写作或 Prompt Preset 执行。
- 不改变图片理解合成 probe 的测试素材和 Prompt 契约。
- 不把用户显式启用图片理解等同于模型已经验证可用。
- 不把模型能力声明写入诊断日志、请求体或外部同步目录。

## 10. 决策依据

### 10.1 为什么不能继续使用 Provider 布尔值

Provider 布尔值只能表达“服务商整体是否具备某类产品能力”，不能表达：

- 同一 Provider 下不同模型的差异。
- 聚合 Provider 的路由差异。
- 兼容 Provider 的用户自定义能力。
- adapter 当前代码是否已实现请求体。
- 用户是否允许发送图片、音频或其他敏感输入。

这会在图片理解之后继续影响 TTS、Embedding、语音识别、本地模型和对象存储能力。

### 10.2 为什么不直接把 OpenRouter 设为支持图片理解

这是短期可用但长期错误的修复。OpenRouter 上既有支持图片输入的模型，也有纯文本模型。如果把 OpenRouter 静态设为支持图片理解，UI 会误导用户认为所有 OpenRouter 模型都可处理图片。

更合理的表达是：OpenRouter 的图片输入能力是 `modelDependent`，当前 adapter 可以测试，用户可以显式启用，然后由真实 probe 结果验证。

### 10.3 为什么第一阶段不动态拉取模型列表

动态模型列表适合作为后续增强，不适合作为本轮基础架构修复的前置条件：

- 会引入额外网络请求、缓存、失败状态和隐私说明。
- OpenRouter、OpenAI、Gemini、Anthropic、本地模型的能力字段并不统一。
- 用户可能使用企业代理、自定义兼容服务或未公开模型，动态列表无法覆盖。
- 当前最紧急的问题是能力决策层级错误，必须先修正本地模型。

### 10.4 为什么需要用户显式授权

图片理解会发送图片输入。即使本轮 probe 只发送项目内置蓝色方块 PNG，也必须保持长期隐私模型一致：图片、照片、音频等敏感输入只有在用户明确启用对应能力后才可发送。

## 11. 推荐架构

### 11.1 五层能力决策链

```text
Provider Preset
  -> Adapter Capability
  -> Endpoint Purpose
  -> Model Capability Policy
  -> User Enablement
  -> Probe Result
```

含义：

- `Provider Preset`：描述服务商或配置模板，例如 OpenAI、OpenRouter、Gemini、Custom、Ollama。
- `Adapter Capability`：描述当前代码是否知道如何构造某能力请求体，例如 OpenAI-compatible Chat 是否支持 image input。
- `Endpoint Purpose`：描述 endpoint 用途，例如 text generation、TTS、embedding。图片理解当前是 text endpoint 的可选多模态输入能力。
- `Model Capability Policy`：描述具体模型能力如何判定，例如已知支持、已知不支持、由模型决定、用户声明。
- `User Enablement`：描述用户是否明确允许这个 endpoint 发送图片输入。
- `Probe Result`：真实测试结果，是当前配置是否可用的最终证据。

### 11.2 Source of Truth 边界

第一阶段必须明确区分三类事实，避免新的 resolver 只是把旧布尔值换个名字：

1. **能力决策事实**：由 Provider preset、adapter、endpoint purpose 和 model policy 重新计算，作为 UI 展示、Toggle 接受条件和 save / probe snapshot 的来源。
2. **运行期防线事实**：`AIProviderEndpointInput.supportsImageInput` / `AIProviderEndpointSaveInput.supportsImageInput` 只能表示“这个 endpoint 在当前配置下允许进入图片输入请求路径”，不得表示“模型已经被验证支持图片理解”。
3. **验证事实**：只有 `AIProviderConfigurationProbeResult` 能表达当前配置是否真实可用。

因此：

- UI 不得从已保存 endpoint 的 `supportsImageInput` 反推 Toggle 可用状态；加载 saved profile 后仍应基于 provider、adapter、purpose 和 model 重新计算 display decision。
- 保存时写入的 `supportsImageInput` 应来自 resolver 的 `canProbe` 或等价运行期决策，用于服务层防御和历史配置快照；它不是模型能力注册表。
- `imageInputEnabled` 仍只表示用户显式授权；即使 `supportsImageInput == true`，用户未开启时也不得发图片。
- 非 text generation endpoint 必须同时清空 `supportsImageInput` 和 `imageInputEnabled`，避免未来 TTS / Embedding endpoint 被误用为图片输入通道。

### 11.3 新增核心类型

建议在 `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift` 或拆出的新文件中先落地 UI draft 层 resolver。若后续 Core 也需要保存或跨模块共享，再提升到 `LangoTraceCore`。

由于 `AIProviderPreset` 目前仍在 UI package，第一阶段不强行迁移 preset 到 Core，避免扩大重构面。但需要把以下边界写进代码和测试：

- resolver 不得进入 `LangoTraceAI`，AI package 只消费 Core endpoint input，不反向依赖 UI preset。
- adapter 请求格式能力必须与 `AIProviderConfigurationProbeService.supportsImageProbe(_:)` 保持一致，测试至少覆盖 OpenAI Responses、OpenAI-compatible Chat、Gemini 和 Anthropic。
- 如果后续出现非 UI 入口创建 AI Provider 配置，必须把 provider preset / capability policy 上移到 Core 或正式 architecture 文档，不得复制一份并行规则。

第一阶段推荐类型：

```swift
enum AIProviderCapabilitySupport: Equatable {
    case supported
    case unsupported
    case modelDependent
    case adapterUnsupported
}

struct AIProviderCapabilityPolicy: Equatable {
    var textGeneration: AIProviderCapabilitySupport
    var structuredJSON: AIProviderCapabilitySupport
    var imageInput: AIProviderCapabilitySupport
    var speechSynthesis: AIProviderCapabilitySupport
    var embedding: AIProviderCapabilitySupport
}

struct AIProviderAdapterCapabilityPolicy: Equatable {
    var canProbeText: Bool
    var canProbeStructuredJSON: Bool
    var canProbeImageInput: Bool
    var canProbeSpeechSynthesis: Bool
    var canProbeEmbedding: Bool
}

struct AIProviderCapabilityDecision: Equatable {
    var support: AIProviderCapabilitySupport
    var canToggle: Bool
    var canProbe: Bool
    var requiresUserAssertion: Bool
    var shouldPersistImageSupport: Bool
    var explanationKey: String
}
```

`shouldPersistImageSupport` 第一阶段应等价于 `canProbe`，但保留独立字段用于防止调用点误把 `support == .modelDependent` 直接等同于可持久化或可发送。

### 11.4 能力解析器

新增 resolver：

```swift
enum AIProviderEndpointCapabilityResolver {
    static func imageInputDecision(
        provider: AIProviderPreset,
        adapterKind: AIProviderAdapterKind,
        purpose: LangoTraceCore.AIProviderEndpointPurpose,
        modelName: String
    ) -> AIProviderCapabilityDecision
}
```

第一阶段规则：

| Provider / Adapter | Provider policy | Adapter can probe image | UI can toggle | 说明 |
| --- | --- | --- | --- | --- |
| OpenAI + OpenAI Responses | supported | true | true | 官方 Provider，当前 adapter 已支持 |
| Custom OpenAI-compatible + Chat | modelDependent | true | true | 用户声明模型能力，probe 验证 |
| OpenRouter + Chat | modelDependent | true | true | 模型能力由 OpenRouter 模型决定，probe 验证 |
| Gemini + Gemini adapter | supported 或 modelDependent | false | false | 产品层可表达能力，但当前 adapter 图片 probe 未接入 |
| Anthropic + Anthropic adapter | modelDependent 或 adapterUnsupported | false | false | 当前不实现图片请求格式 |
| DeepSeek / Mistral / Groq / Kimi / DashScope / GLM / SiliconFlow / Ollama | unsupported 或 modelDependent | 视 adapter 和后续决策 | 第一阶段默认 false，除非明确提升为 modelDependent | 避免扩大范围 |

注意：OpenRouter 和 Custom 的 `canToggle == true` 不表示模型已验证支持，只表示用户可以授权并发起受控测试。

## 12. 涉及的代码文件路径

### 12.1 预计修改

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
  - 将 `AIProviderCapabilitySet` 从布尔集合升级或替换为能力策略。
  - 为 `OpenRouter` 和 `Custom OpenAI-compatible` 表达 `modelDependent` 图片输入能力。
  - 增加 adapter capability policy 或提供 resolver 所需信息。

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
  - 不再直接使用 `provider.capabilities.imageUnderstanding` 判断图片输入。
  - 在更新 provider、生成 save input、生成 draft probe snapshot、加载 profile 时统一使用 resolver 决策。
  - 保存输入中的 `supportsImageInput` 应来自 resolver 的 `shouldPersistImageSupport` 或等价运行期防线，而不是 Provider 布尔值。
  - `imageInputEnabled` 仍必须受用户显式开关控制。
  - 加载 saved profile 时，如果旧数据中 `imageInputEnabled == true`，但当前 resolver 已不可 toggle / probe，应在 draft 层降级清空，避免历史配置绕过新策略；如果是 OpenRouter / Custom 的 model-dependent 状态，则不应被旧 Provider 布尔值清空。

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
  - 加固 `AIProviderEndpointInput.normalized()`：当 `purpose != .textGeneration` 时，同时清空 `supportsImageInput` 与 `imageInputEnabled`。
  - 补充 Core 测试，防止未来 TTS / Embedding endpoint 带着图片输入能力穿过服务边界。

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
  - 图片理解 UI 的状态输入从 `supportsImageUnderstanding: Bool` 改为 `AIProviderCapabilityDecision` 或 presentation model。
  - Toggle setter 使用 resolver 决策决定是否接受用户输入。

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
  - `AIProviderCapabilityBoundaryView` 支持 `supported`、`unsupported`、`modelDependent`、`adapterUnsupported` 不同说明。
  - 文案不再把所有禁用状态都说成“当前 Provider 不支持”。

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
  - 新增或更新能力说明文案。
  - 推荐中文文案：
    - `图片理解功能需要选择支持图片输入的模型`
    - `当前请求格式暂不支持图片测试`
    - `当前 Provider 预设不支持图片输入`

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
  - 复查服务层是否只信任 endpoint `supportsImageInput` 与 `imageInputEnabled`，不反查 UI provider 布尔值。
  - 若现有行为已正确，只补充测试，不做无关重构。

### 12.2 预计测试

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/AIProviderConfigurationTests.swift`
  - 覆盖非 text generation endpoint normalized 后同时清空 `supportsImageInput` 与 `imageInputEnabled`。

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`
  - 覆盖 capability policy 不再被 Provider 布尔值压扁。
  - 覆盖 OpenRouter / Custom 的图片输入状态为 `modelDependent`。
  - 覆盖 resolver 对 OpenAI Responses、OpenAI-compatible Chat、Gemini、Anthropic、纯文本 Provider 的 `support` / `canToggle` / `canProbe` 决策。

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
  - 覆盖 OpenRouter + 用户开启图片理解后，draft snapshot requested capabilities 包含 `.imageUnderstanding`。
  - 覆盖 OpenRouter 未开启时不请求图片 probe。
  - 覆盖 Gemini / Anthropic 在 adapter 未接入时不能开启或不能 probe。
  - 覆盖 UI source 不再直接读取 `provider.capabilities.imageUnderstanding` 控制 Toggle。
  - 覆盖 loaded saved profile 不使用旧 `supportsImageInput` 作为 UI Toggle source of truth。

- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift`
  - 若服务层需要调整 endpoint support 语义，补充 OpenAI-compatible model-dependent endpoint 能跑图片 probe 的用例。

## 13. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderProbeImageFixture.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift`

## 14. 涉及的文档路径

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
  - 需要补充 Provider preset 不能作为模型级能力最终事实源。
  - 需要明确 OpenRouter / Custom 等模型相关 Provider 的图片输入能力由模型和 probe 决定。

- `docs/platform-page-inventory.md`
  - 需要更新 AI Provider 设置页能力边界说明，避免继续写成 Provider 静态支持。

- `docs/prompts/ai-provider/provider-configuration-probe.md`
  - 若 Prompt 不变，仅检查是否需要补充 OpenRouter / Custom 的适用说明。

- `docs/plans/done/2026-05-21-feature-ai-provider-image-understanding-probe.md`
  - 作为历史方案不回写修改；本方案应引用并修正其“Provider preset 支持”这一阶段性表述。

## 15. 具体实施步骤

### Phase 1：测试先行，锁定错误行为

1. 在 `AIProviderConfigurationTests.swift` 新增测试：非 text generation endpoint normalized 后同时清空 `supportsImageInput` 与 `imageInputEnabled`。
2. 在 `AIProviderSettingsTests.swift` 新增测试：OpenRouter 的图片输入策略是 `modelDependent`，不是 `unsupported`。
3. 在 `AIProviderSettingsTests.swift` 新增测试：Custom OpenAI-compatible 的图片输入策略是 `modelDependent`。
4. 在 `AIProviderSettingsTests.swift` 新增测试：Gemini / Anthropic 当前因 adapter 图片 probe 未接入，决策为不可 probe，不得误显示为 Provider 整体不支持。
5. 在 `AIProviderSettingsProbeTests.swift` 新增测试：OpenRouter + 用户启用图片理解时，`configurationProbeRequestedCapabilities` 包含 `.imageUnderstanding`。
6. 在 `AIProviderSettingsProbeTests.swift` 新增 source-boundary 测试：`AIProviderSettingsView.swift` 不再以 `provider.capabilities.imageUnderstanding` 直接控制图片理解开关。
7. 在 `AIProviderSettingsProbeTests.swift` 新增 loaded profile 测试：UI 决策从 live resolver 计算，旧 `supportsImageInput` 不作为 Toggle 可用性的事实源。
8. 运行聚焦测试，确认新增测试在当前代码下失败。

推荐命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

### Phase 2：引入能力策略与 resolver

1. 在 UI package 中新增或扩展能力策略类型。
2. 为 `AIProviderPreset` 提供 capability policy，而不是只提供布尔 capabilities。
3. 为 `AIProviderAdapterKind` 提供 adapter capability policy。
4. 新增 `AIProviderEndpointCapabilityResolver.imageInputDecision(...)`。
5. 初始规则中只把 OpenAI、OpenRouter、Custom OpenAI-compatible 纳入图片输入可 toggle 范围；其他 Provider 保持保守。
6. 运行新增 policy 测试。

推荐命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
```

### Phase 3：改造 Draft 和 Snapshot

1. 修改 `AIProviderDraftConfiguration` 的 provider 更新逻辑：当新 provider 的图片决策不可 toggle 时，清空 `imageUnderstandingEnabled`。
2. 修改 `configurationProbeRequestedCapabilities`：只有用户启用且 resolver `canProbe == true` 时，才包含 `.imageUnderstanding`。
3. 修改 `makeConfigurationProbeDraftSnapshot(operationID:)`：`supportsImageInput` 和 `imageInputEnabled` 来自 resolver 决策与用户开关，而不是 Provider 布尔值。
4. 修改保存输入映射，确保 profile endpoint 的 `supportsImageInput` 不再被 Provider 静态布尔值错误压制；同时保留它作为服务层防御字段，而不是 UI source of truth。
5. 修改 loaded profile 映射：对历史数据执行 resolver 降级，但保留 OpenRouter / Custom model-dependent 的用户启用状态。
6. 运行 draft / probe 聚焦测试。

推荐命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

### Phase 4：改造 UI 展示与文案

1. 修改 `AIProviderCapabilityBoundaryView` 入参，从 `supportsImageUnderstanding: Bool` 改为 capability decision 或专用 presentation model。
2. 对 `modelDependent` 显示“图片理解功能需要选择支持图片输入的模型”，并允许 Toggle。
3. 对 `adapterUnsupported` 显示“当前请求格式暂不支持图片测试”，并禁用 Toggle。
4. 对 `unsupported` 显示“当前 Provider 预设不支持图片输入”，并禁用 Toggle。
5. 对 `supported` 保持简洁说明。
6. 更新 `Localizable.xcstrings`。
7. 运行 UI package 聚焦测试。

推荐命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

### Phase 5：服务层复查与必要加固

1. 检查 `AIProviderConfigurationProbeService` 是否只依赖 endpoint snapshot 的 `supportsImageInput` / `imageInputEnabled`。
2. 确认 OpenAI-compatible Chat image probe 请求体可用于 OpenRouter 的 `/chat/completions` 兼容路径。
3. 如有必要，增加测试覆盖 model-dependent endpoint 进入 image probe 时仍发送 data URL。
4. 不在服务层引入 UI provider preset 反向依赖。

推荐命令：

```bash
swift test --package-path Packages/LangoTraceAI --filter LangoTraceAITests
```

### Phase 6：文档同步

1. 更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`。
2. 更新 `docs/platform-page-inventory.md`。
3. 检查 `docs/prompts/ai-provider/provider-configuration-probe.md` 是否需要补充适用范围说明。
4. 在本方案“实施记录”中记录最终代码提交、验证命令和人工测试结果。

### Phase 7：完整验证与人工测试准备

1. 运行文档检查。
2. 运行完整工程验证。
3. 构建并启动 iPhone、iPad、macOS 端供人工测试。

推荐命令：

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
scripts/verify.sh
```

## 16. 回归测试方案

必须覆盖以下用例：

- OpenAI Responses：图片理解显示可开启，开启后 snapshot 请求 `.imageUnderstanding`。
- OpenRouter：图片理解显示 `modelDependent`，Toggle 可开启，开启后 snapshot 请求 `.imageUnderstanding`。
- Custom OpenAI-compatible：图片理解显示 `modelDependent`，Toggle 可开启，开启后 snapshot 请求 `.imageUnderstanding`。
- OpenRouter 未开启图片理解：snapshot 不请求 `.imageUnderstanding`。
- Gemini：如果 adapter 图片 probe 未接入，UI 不得误称 Provider 不支持，应表达请求格式暂不支持测试或等价文案。
- Anthropic：当前不实现图片 adapter，不发图片请求。
- 纯文本 Provider：图片理解禁用且文案为 Provider 预设不支持。
- 非 text generation endpoint：normalized 后 `supportsImageInput` 与 `imageInputEnabled` 均为 false。
- 用户从支持图片输入的 provider 切换到不支持 provider 后，`imageUnderstandingEnabled` 自动清空。
- 已保存 profile 加载时，图片输入能力不因旧 Provider 布尔值被错误清空。
- UI source-boundary：SwiftUI View 不直接拼 capability 判断，不直接创建请求。

## 17. 复查方法

代码复查时逐项确认：

- 是否还有 `provider.capabilities.imageUnderstanding` 直接控制 UI Toggle、snapshot 或 save input。
- 是否还有把 persisted `supportsImageInput` 当作模型能力事实源或 UI Toggle source of truth 的路径。
- OpenRouter 和 Custom 是否被表达为 `modelDependent`，而不是静态 `supported` 或 `unsupported`。
- Adapter 未实现图片请求格式的 Provider 是否不能发图片 probe。
- 用户未开启图片理解时，任何路径都不会发送图片 data URL。
- 非 text generation endpoint 是否无法携带图片输入能力穿过 Core normalized 边界。
- `requestedCapabilities` 仍只是 UI / 服务请求描述，不是安全授权来源。
- Probe 结果仍不记录图片 base64、请求体、响应体、API Key 或 Authorization header。
- 文案是否避免把模型级能力错误说成 Provider 整体能力。

## 18. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
swift test --package-path Packages/LangoTraceAI --filter LangoTraceAITests
```

完整验证：

```bash
scripts/verify.sh
```

文档验证：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 19. 文档影响检查

本任务涉及 AI Provider、隐私边界、Provider 配置测试和三端设置页事实源，属于必须更新文档的范围。

预计更新：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/platform-page-inventory.md`
- 本方案文件

可能更新：

- `docs/prompts/ai-provider/provider-configuration-probe.md`
  - 若 Prompt 内容不变，只补充适用 Provider / Model-dependent 说明。

不更新：

- 历史 done plan 不回写覆盖，只在本方案中记录阶段性方案被新架构修正。

## 20. 实施记录

- 2026-05-21：创建方案。当前仅完成架构设计与实施路径记录，尚未修改生产代码。
- 2026-05-21：系统架构审查后补充 source of truth 边界：`supportsImageInput` 只作为运行期防线和保存快照，不作为模型能力事实源；补充非 text generation endpoint 必须清空图片输入能力的 Core 级不变量；补充 loaded profile 不得用旧布尔值驱动 UI Toggle 的测试要求。
- 2026-05-21：完成 TDD 实施。新增 Core 测试覆盖非 text generation endpoint 清空图片输入支持与启用状态；新增 UI 测试覆盖 OpenAI、OpenRouter、Custom、Gemini、Anthropic、DeepSeek 和非文本 endpoint 的图片输入决策；新增 probe 测试覆盖 OpenRouter model-dependent 启用、未启用不请求图片、loaded profile 不使用旧 `supportsImageInput` 作为 UI source of truth、SwiftUI / draft source-boundary。
- 2026-05-21：完成代码落地。新增 `AIProviderEndpointCapabilityResolver`、capability policy / adapter policy / decision；OpenRouter 和 Custom OpenAI-compatible 图片输入表达为 `modelDependent`；SwiftUI 能力边界改为读取 decision 并显示模型相关、adapter 不支持或 Provider 预设不支持文案；draft snapshot / save input / loaded profile 均通过 resolver 计算；Core `AIProviderEndpointInput.normalized()` 对非文本 endpoint 同时清空 `supportsImageInput` 和 `imageInputEnabled`。
- 2026-05-21：完成文档同步。更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/platform-page-inventory.md` 和 `docs/prompts/ai-provider/provider-configuration-probe.md`，明确 Provider preset 不是模型级图片输入最终事实源，OpenRouter / Custom 由模型和 probe 决定，`supportsImageInput` 只作为运行期防线和保存快照。
- 2026-05-21：聚焦验证通过：`swift test --package-path Packages/LangoTraceCore --filter AIProviderConfigurationTests`、`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`、`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`、`swift test --package-path Packages/LangoTraceAI --filter LangoTraceAITests`。
- 2026-05-21：完整验证通过：`scripts/verify.sh`。验证覆盖 XcodeGen、Core / Data / UI package 测试、iPhone 17 模拟器构建、iPad Pro 13-inch (M5) 模拟器构建、macOS arm64 构建、SwiftLint、SwiftFormat、文档占位扫描和 `git status --short` 输出。

## 21. 完成标准

满足以下条件才可将本方案移入 `docs/plans/done/`：

- OpenRouter + OpenAI-compatible Chat adapter 下，图片理解开关可开启，并显示模型相关能力说明。
- Custom OpenAI-compatible 下，用户可显式声明并开启图片理解测试。
- Provider、Adapter、Model、User Enablement、Probe Result 五层边界在代码中可见，不再由单一 Provider 布尔值决定图片输入。
- OpenAI、OpenRouter、Custom、Gemini、Anthropic、至少一个纯文本 Provider 的能力状态均有测试覆盖。
- 图片理解 probe 仍只发送项目内置合成图片，不发送用户照片或生活记录。
- 相关 docs 已同步，且不与当前代码事实冲突。
- 聚焦测试和 `scripts/verify.sh` 通过。
- iPhone、iPad、macOS 至少完成构建；若需要人工测试，启动本地模拟器和 macOS App。

## 22. 剩余风险

- OpenRouter 某些模型虽然页面标注多模态，但其 Chat Completions 兼容路径、路由 provider 或账号权限可能仍拒绝图片输入；这应作为 probe 失败结果展示，不作为 UI 预先拦截理由。
- Custom OpenAI-compatible 完全依赖用户声明模型能力，可能出现用户启用后模型不支持的情况；该风险由明确文案和真实测试结果承担。
- 后续如果接入动态模型列表，需要新增缓存、刷新、失败降级和隐私说明；本任务只为该能力预留架构位置。
- 现有 `AIProviderCapabilitySet` 已被多个测试引用，重构时需要避免一次性扩大到 TTS / Embedding 行为变更。
