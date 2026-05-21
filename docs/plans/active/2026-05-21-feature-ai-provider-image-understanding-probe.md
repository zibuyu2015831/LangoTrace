# AI Provider 图片理解合成测试方案

状态：User Approved
类型：feature
创建日期：2026-05-21
最后更新日期：2026-05-21

## 1. 用户确认记录

- 2026-05-21：用户提出 AI Provider 测试中的图片理解能力，希望由项目保存一张简单图片，测试时携带图片并要求 AI 回答图中内容。
- 2026-05-21：经讨论后放弃动物照片作为第一版测试素材。原因是动物容易触发 `cat` / `kitten` / `feline` / `dog` / `puppy` 等同义、年龄和类别发散，不适合做 Provider 配置连通性探测。
- 2026-05-21：用户采纳推荐方案：由本项目生成一张极简、无版权和隐私风险的白底蓝色正方形图片，用于图片理解合成 probe。
- 2026-05-21：系统架构复查确认需要进一步收紧边界：Configuration Probe 不应继续使用 text-only 命名；`requestedCapabilities` 只能作为 UI / 服务层请求描述，不作为网络请求安全授权来源；Provider preset 的图片能力与 adapter 当前可测能力必须分离。

## 2. 需求描述

在现有 AI Provider 配置页“测试请求”结果面板中，`图片理解` 已作为独立能力项展示，但当前服务层对该能力固定返回 `unsupported`，不会发送真实网络测试请求。

本任务要把 `图片理解` 从占位状态推进为可选合成测试能力：

- 当文本模型 endpoint 所属 Provider preset 支持图片理解，且用户在设置页显式启用图片输入时，测试请求应携带项目内置合成图片，验证 Provider 是否能处理图片输入并返回受控短文本。
- 当 Provider 不支持图片理解、用户未启用图片输入或 adapter 未接入图片请求格式时，图片理解能力应给出明确的 `notEnabled`、`unsupported` 或 `failed` 结果，不误报为测试成功。
- 测试图片必须是项目内置的低敏合成素材，不得使用用户照片、生活记录附件、OCR 文本、历史记忆或 Prompt Preset 内容。
- 测试 Prompt 不应泄露预期答案，不在 Prompt 中出现 `blue` 或 `square`，只描述输出结构和顺序。

## 3. 现状描述

### 3.1 当前已落地能力

- `AIProviderProbeCapability` 已包含 `.imageUnderstanding`，位于 `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`。
- `AIProviderEndpointInput` 已包含 `supportsImageInput` 和 `imageInputEnabled`，并在 `normalized()` 中确保不支持图片输入时关闭 `imageInputEnabled`。
- `AIProviderDraftConfiguration.makeTextProbeDraftSnapshot(operationID:)` 已把 UI 中的图片理解开关映射到 transient endpoint snapshot。
- `AIProviderCapabilityBoundaryView` 已在设置页展示图片理解 toggle；不支持图片理解的 Provider 会禁用该 toggle。
- `AIProviderProbeResultPanelContent` 已按 `AIProviderProbeCapability.allCases` 展示结果行，当前 UI 已能展示 `图片理解` 一项。
- `AIProviderConfigurationProbeService` 当前只执行 `.textReply` 和 `.structuredJSON` 两个真实网络 probe。
- `AIProviderConfigurationProbeService.result(...)` 当前将 `.imageUnderstanding` 固定写为 `.unsupported` 和 `.unsupportedEndpointPurpose`。
- `docs/spec/005-ai-provider-prompt-and-privacy.md` 当前规定第一阶段图片理解不得发送真实网络测试请求，因此本任务必须同步更新该长期规范。
- `docs/prompts/ai-provider/provider-configuration-probe.md` 当前只登记文本回复和 JSON 输出两个 Prompt，需要新增图片理解 probe Prompt。

### 3.2 当前方案的边界问题

当前 UI 已经展示“图片理解”，但服务层固定返回“暂不支持测试”。这使用户无法验证如下真实风险：

- Provider preset 虽声明支持图片输入，但用户配置的模型实际不支持 vision。
- OpenAI Responses adapter 或 OpenAI-compatible Chat adapter 的多模态请求体拼装错误。
- Base64 data URL、MIME type 或图片资源读取失败。
- 模型返回了长描述、带标点文本或顺序错误，无法满足受控输出契约。

## 4. 目标

1. 在 AI package 中提供一张项目内置合成图片：白底蓝色正方形。
2. 在 Configuration Probe Runner 中新增图片理解 probe，并清理已经不准确的 `TextEndpoint` / `TextProbe` 命名。
3. 当 endpoint `supportsImageInput == true` 且 `imageInputEnabled == true` 时，图片理解 probe 才可发起真实网络请求。
4. 对 OpenAI Responses 和 OpenAI-compatible Chat 两类当前已接入且本任务确认可测的 adapter 构造对应的图片输入请求体。
5. 对 Anthropic Messages 和 Gemini Generate Content 继续返回明确 unsupported，不把未接入 adapter 误判为认证失败或网络失败。
6. 严格校验模型输出，只接受规范化后的 `blue square`。
7. 不记录请求体、图片 base64、图片字节、响应体、API Key 或 Authorization header。
8. 更新 Prompt Registry、AI Provider 隐私规范和任务方案实施记录。

## 5. 不做什么

- 不接入用户照片、相册、照片写作入口或真实生活记录附件。
- 不实现真实图片写作引导、OCR、图像描述保存或 Entry / Rendering 数据写入。
- 不新增 Prompt Preset 执行链路。
- 不实现 Anthropic / Gemini 的图片请求格式，除非后续单独创建方案并审查 adapter 边界。
- 不把图片理解测试结果作为模型视觉质量评分；它只验证配置连通性、图片输入链路和基础视觉属性识别。
- 不在诊断日志、validation event 或 UI 结果中展示模型原始响应体。

## 6. 决策依据

### 6.1 为什么选择白底蓝色正方形

与动物、真实物体照片和带文字图片相比，白底蓝色正方形更适合作为第一版图片理解合成 probe：

| 方案 | 优点 | 风险 | 结论 |
| --- | --- | --- | --- |
| 动物照片 | 更接近真实照片理解 | 同义词和年龄类别发散，存在版权和 EXIF 风险 | 不作为第一版 |
| 常见物体图标 | 输出较短，视觉语义明确 | `cup` / `mug`、`phone` / `mobile` 等同义词较多 | 可作为后续增强 |
| 数字图片 | 极稳定 | 更接近 OCR，不足以代表图片理解 | 不作为第一版主 probe |
| 白底蓝色正方形 | 无版权、无隐私、可程序生成、同时验证颜色和形状 | 只覆盖基础视觉属性 | 采纳 |

### 6.2 为什么用程序生成图片

本任务虽然由 AI 辅助实现，但测试素材应采用可复现、可审计的程序生成图片，而不是外部照片或不可复现的生成式图片结果。

推荐生成规格：

- 文件路径：`Packages/LangoTraceAI/Sources/LangoTraceAI/Resources/AIProviderProbe/blue-square.png`
- 尺寸：`256 x 256`
- 背景：纯白 `#FFFFFF`
- 主体：居中蓝色正方形
- 正方形尺寸：`128 x 128`
- 正方形颜色：`#006DFF`
- 文件格式：PNG
- 元数据：不写入 EXIF 或其他不必要 metadata

实现时应优先新增一个可复现的生成脚本，而不是手工拖入外部图片：

- 推荐脚本路径：`scripts/generate-ai-provider-probe-image.swift`
- 脚本职责：生成上述固定规格 PNG；失败时明确退出非零状态。
- 该脚本只用于生成项目资源，不在 App 运行期调用。

### 6.3 Prompt 输出契约

英文 Prompt：

```text
Describe the image using exactly two lowercase English words: color then shape. Do not include punctuation or any other text.
```

中文说明版本：

```text
使用恰好两个小写英文单词描述图片：先写颜色，再写形状。不要包含标点或任何其他文本。
```

预期模型输出：

```text
blue square
```

Prompt 不包含 `blue` 或 `square`，避免把答案直接提供给模型。验收时只接受规范化后的 `blue square`，不接受 `a blue square`、`blue rectangle`、`square blue`、`blue square.` 或长句描述。

### 6.4 官方 API 依据

OpenAI 官方图片与视觉文档说明，模型可以通过图片 URL、Base64 data URL 或 file id 接收图片输入；图片输入会计入 token 和费用。OpenAI Responses API reference 也说明 `input_image` 可使用 `image_url`，其值可以是完整 URL 或 Base64 data URL。

本任务采用 Base64 data URL，是因为测试素材位于 App bundle / Swift Package resource 内，不需要上传文件或依赖外部 URL。

参考资料：

- https://developers.openai.com/api/docs/guides/images-vision
- https://developers.openai.com/api/reference/resources/responses

## 7. 涉及的代码文件路径

### 7.1 创建

- `Packages/LangoTraceAI/Sources/LangoTraceAI/Resources/AIProviderProbe/blue-square.png`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderProbeImageFixture.swift`
- `scripts/generate-ai-provider-probe-image.swift`

### 7.2 修改

- `Packages/LangoTraceAI/Package.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationServiceTests.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`

### 7.3 可能修改

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

仅当现有本地化无法准确表达图片理解测试的 `not enabled`、`unsupported`、`invalid response` 等状态时才修改。

## 8. 涉及的文档路径

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/prompts/README.md`
- `docs/prompts/ai-provider/provider-configuration-probe.md`
- `docs/plans/active/2026-05-21-feature-ai-provider-image-understanding-probe.md`

完成验证后，本方案应移动到：

- `docs/plans/done/2026-05-21-feature-ai-provider-image-understanding-probe.md`

## 9. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderProbeHTTPClient.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift`

## 10. 架构方案

### 10.1 数据流

```text
AIProviderSettingsView
  -> AIProviderDraftConfiguration.makeConfigurationProbeDraftSnapshot(operationID:)
  -> AIProviderSettingsActions.validateConfiguration
  -> AppEnvironment maps draft or saved profile input
  -> AIProviderConfigurationService
  -> AIProviderConfigurationProbeService
  -> Bundle resource blue-square.png
  -> OpenAI Responses or OpenAI-compatible Chat HTTP request
  -> parse text output
  -> strict "blue square" validation
  -> AIProviderConfigurationProbeResult
  -> UI result panel
```

### 10.2 能力执行规则

- `textReply` 仍作为第一项最小连通性 probe。
- `structuredJSON` 仍只在 `textReply` 成功后运行。
- `imageUnderstanding` 只在 `textReply` 成功、`endpoint.supportsImageInput == true`、`endpoint.imageInputEnabled == true` 且 adapter 已接入图片请求体时运行。
- `speechSynthesis` 和 `embedding` 继续保持当前未启用 / 未接入状态。
- Provider preset 的 `imageUnderstanding == true` 只表示 Provider 或产品配置层面允许用户启用图片输入，不等于当前 adapter 已支持图片 probe。例如 Gemini 当前可以表达图片理解能力，但本任务不实现 Gemini adapter 图片请求格式，因此测试结果必须是 `unsupported` 且不发送 HTTP。
- `requestedCapabilities` 只能作为 UI / 服务层请求描述，用于决定结果面板 loading 行和非敏感诊断属性；真正是否发起图片网络请求必须由 AI service 根据 normalized endpoint、adapter kind 和本任务允许的 capability probe 交集重新判断，不能信任 UI 传入值。

推荐状态映射：

| 条件 | 图片理解状态 | errorCategory |
| --- | --- | --- |
| Provider 不支持图片输入 | `unsupported` | `unsupportedEndpointPurpose` |
| Provider 支持但用户未启用图片输入 | `notEnabled` | nil |
| Adapter 尚未接入图片请求格式，例如 Gemini / Anthropic | `unsupported` | `unsupportedEndpointPurpose` |
| 图片资源读取失败 | `failed` | `invalidResponse` |
| HTTP 401 / 403 | `failed` | `authenticationFailed` |
| HTTP 404 | `failed` | `unsupportedModel` |
| 网络不可用 | `failed` | `networkUnavailable` |
| 超时 | `failed` | `timeout` |
| 取消 | `cancelled` | nil |
| 响应文本不是 `blue square` | `failed` | `invalidResponse` |
| 响应文本为 `blue square` | `succeeded` | nil |

### 10.3 请求体格式

OpenAI-compatible Chat adapter 使用 `messages[0].content` 的多模态数组：

```json
{
  "model": "<model>",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Describe the image using exactly two lowercase English words: color then shape. Do not include punctuation or any other text."
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/png;base64,<base64>"
          }
        }
      ]
    }
  ],
  "max_tokens": 8
}
```

OpenAI Responses adapter 使用 `input` message content 数组：

```json
{
  "model": "<model>",
  "input": [
    {
      "role": "user",
      "content": [
        {
          "type": "input_text",
          "text": "Describe the image using exactly two lowercase English words: color then shape. Do not include punctuation or any other text."
        },
        {
          "type": "input_image",
          "image_url": "data:image/png;base64,<base64>",
          "detail": "low"
        }
      ]
    }
  ],
  "max_output_tokens": 8
}
```

说明：

- 计划中示例使用 `<base64>` 占位说明请求体结构，实际代码不得把完整 base64 写入日志或文档实施记录。
- `detail` 使用 `low`，因为图片为 256 x 256 的简单几何图，只需验证能力连通性并降低 token 成本。
- `max_tokens` / `max_output_tokens` 限制为 8，避免模型生成长描述。

### 10.4 结果聚合

当前 `AIProviderConfigurationProbeResult.overallStatus` 只有一个总状态。实现时应保持现有语义：

- 文本和 JSON 均成功，图片理解未启用：总体继续为 `succeeded`，能力行显示 `notEnabled`。
- 文本和 JSON 均成功，图片理解因 adapter 未接入而不支持：如果用户未启用图片理解，总体继续为 `succeeded`；如果用户已启用图片理解，总体为 `failed`，能力行显示 `unsupported`，UI 可显示 partial。
- 文本和 JSON 成功，图片理解已启用但失败：持久化结果的 `overallStatus` 应为 `failed`，因为用户明确启用了图片理解；UI 层可以继续显示 partial，以表达文本能力可用但图片能力失败。
- 文本成功、JSON 或图片失败：能力行必须指出具体失败能力，`persistSyntheticProbeResult` 记录的 validation event status 使用 `overallStatus`。
- 取消任一正在执行的真实 probe：总体为 `cancelled`。

## 11. 实施路径

### 11.1 TDD 第一组：AI package 图片 fixture

1. 在 `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift` 新增测试：fixture 能从 bundle 读取 PNG，MIME 为 `image/png`，data URL 以 `data:image/png;base64,` 开头。
2. 运行聚焦测试，确认失败。
3. 创建 `scripts/generate-ai-provider-probe-image.swift` 并生成 `blue-square.png`。生成脚本必须固定尺寸、背景、主体尺寸和颜色，不读取外部图片。
4. 创建 `AIProviderProbeImageFixture.swift`，提供只读 fixture。由于现有 AI package 测试使用 `import LangoTraceAI` 而不是 `@testable import LangoTraceAI`，fixture 若要被测试直接访问，应声明为 `public`；否则测试只能通过 service 捕获请求体间接验证资源读取。

```swift
public struct AIProviderProbeImageFixture: Sendable {
    public let mimeType: String
    public let data: Data

    public var dataURLString: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}
```

5. 将 `blue-square.png` 加入 Swift Package resource，并在 `Package.swift` 配置 `.process("Sources/LangoTraceAI/Resources")`。
6. 复跑聚焦测试，确认 fixture 可读取。

### 11.2 TDD 第二组：请求体生成

1. 新增 OpenAI-compatible Chat 图片 probe 测试：
   - endpoint 支持并启用图片输入。
   - HTTP client 捕获三次请求：文本、JSON、图片。
   - 第三次请求体包含 `type: "image_url"` 和 data URL。
   - 第三次请求体不包含用户生活记录、Prompt Preset 字样或 API Key。
2. 新增 OpenAI Responses 图片 probe 测试：
   - 第三次请求体包含 `type: "input_image"`、`detail: "low"` 和 data URL。
   - URL 为 `/responses`。
3. 运行聚焦测试，确认失败。
4. 扩展 `ProbeKind`，新增 `.imageUnderstanding`。
5. 将 `body(_:endpoint:)` 拆分为文本/JSON请求体和图片请求体，避免把多模态结构混入文本 probe。
6. 明确 adapter allow-list：本任务只允许 `.openAIResponses` 和 `.openAICompatibleChat` 发送图片 probe；`.anthropicMessages` 和 `.geminiGenerateContent` 返回 unsupported 且不发 HTTP。
7. 复跑聚焦测试，确认请求体生成通过。

### 11.3 TDD 第三组：输出校验和状态映射

1. 新增成功测试：图片响应文本为 `blue square` 时，`.imageUnderstanding` 为 `.succeeded`。
2. 新增失败测试：图片响应文本为 `a blue square`、`blue square.`、`square blue` 或空字符串时，`.imageUnderstanding` 为 `.failed` 且 error 为 `.invalidResponse`。
3. 新增未启用测试：endpoint 支持图片输入但 `imageInputEnabled == false` 时，不发送第三个 HTTP 请求，能力状态为 `.notEnabled`。
4. 新增不支持测试：endpoint `supportsImageInput == false` 时，不发送第三个 HTTP 请求，能力状态为 `.unsupported`。
5. 新增 adapter 未接入测试：Gemini / Anthropic adapter 即使 endpoint `supportsImageInput == true` 且 `imageInputEnabled == true`，也不发送图片 HTTP 请求，能力状态为 `.unsupported`。
6. 运行聚焦测试，确认失败。
7. 实现 `isStrictBlueSquare(_:)`，规则为 `trim -> lowercase` 后必须 exactly equal `blue square`。
8. 扩展结果聚合函数，允许传入 image status / error / duration。
9. 复跑聚焦测试，确认通过。

### 11.4 TDD 第四组：AIProviderConfigurationService 集成

1. 在 `AIProviderConfigurationServiceTests.swift` 增加 saved profile 测试：
   - 已保存 profile 的 text endpoint 支持并启用图片输入。
   - service 通过 Keychain resolver 获取 secret。
   - probe result 中图片理解成功。
   - 持久化 validation event 仍只记录非敏感 capability/status，不记录图片内容或响应体。
2. 增加 draft 测试：
   - draft 开启图片理解时可发起三次请求。
   - draft 测试不写 Keychain、SQLite validation event 或 profile 最近验证摘要。
3. 将 AI service 公开方法从 text-only 命名改为 configuration probe 语义：
   - `testDraftTextEndpoint(_:)` 改为 `testDraftConfiguration(_:)`。
   - `testDefaultTextEndpoint(operationID:)` 改为 `testDefaultConfiguration(operationID:)`。
   - `AIProviderConfigurationProbeDraftInput` / `AIProviderConfigurationProbeSavedInput` 可增加 `requestedCapabilities`，但 service 必须重新与 endpoint 和 adapter allow-list 求交集后再决定真实网络请求。
4. 更新 `LangoTraceApp/AppEnvironment.swift`，转发新方法和 draft snapshot 的 capability 描述。
5. 运行聚焦测试，确认失败后实施最小集成修复。

### 11.5 TDD 第五组：UI draft 和结果面板

1. 在 `AIProviderSettingsProbeTests.swift` 增加测试：将 `makeTextProbeDraftSnapshot(operationID:)` 重命名为 `makeConfigurationProbeDraftSnapshot(operationID:)`，避免新能力接入后继续暴露 text-only API。
2. 增加测试：当 draft 图片理解 toggle 开启且 Provider 支持时，snapshot 的 `requestedCapabilities` 包含 `.imageUnderstanding`。
3. 增加测试：Provider 不支持图片理解时，snapshot 不请求 `.imageUnderstanding`，并且 endpoint `imageInputEnabled == false`。
4. 增加结果面板测试：当 `imageUnderstanding` 正在测试时，`AIProviderProbeResultPanelContent` 的 testing 状态应覆盖图片理解行，不只覆盖文本和 JSON。
5. 在 `AIProviderSettingsView` 中增加当前测试 capability 状态，例如 `@State private var activeProbeCapabilities: [AIProviderProbeCapability] = []`，发起测试前根据 draft 或 saved profile 设置，测试结束或关闭时清理。
6. 修改 `AIProviderProbeResultPanelContent` 的 `isTesting` 逻辑，使其基于 active capabilities，而不是写死 `textReply` / `structuredJSON`。
7. 复跑 UI 聚焦测试。

### 11.6 文档更新

1. 更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`：
   - 将“第一阶段不得为图片理解发真实网络测试请求”改为“图片理解可在用户显式启用后发送内置合成图片 probe”。
   - 明确该 probe 不发送用户照片，不代表真实照片理解质量评分。
   - 增加变更记录。
2. 更新 `docs/prompts/ai-provider/provider-configuration-probe.md`：
   - 增加 `ai-provider.configuration-probe.image-understanding.v1`。
   - 登记英文 Prompt、中文说明、输出契约、输入图片素材、隐私等级和评测方式。
3. 更新 `docs/prompts/README.md` 当前事实，如已有描述足够则只补充能力范围。
4. 在本方案实施记录写入测试命令和结果。

## 12. 复查方法

### 12.1 代码复查

复查时逐项确认：

- `AIProviderConfigurationProbeService` 没有在 SwiftUI View 中创建 `URLRequest`。
- `testDraftTextEndpoint`、`testDefaultTextEndpoint`、`makeTextProbeDraftSnapshot` 等 text-only 命名已被 configuration probe 命名替换，避免后续能力扩展继续背负错误语义。
- 图片资源读取位于 AI package，不进入 Core、Data 或 UI package。
- Core 仍只承载非敏感 enum、descriptor 和 result，不承载图片字节、base64 或 secret。
- UI 传入的 `requestedCapabilities` 不被 AI service 直接信任，真实网络 probe 由 endpoint supports/enabled 状态和 adapter allow-list 决定。
- Draft probe 仍不写 Keychain、SQLite validation event 或 profile 最近验证摘要。
- Saved profile probe 仍通过服务层解析 Keychain secret，不要求用户重新输入 API Key。
- 诊断日志和 validation event 不包含完整请求体、图片 base64、响应体、API Key、Authorization header 或 Keychain account。
- OpenAI Responses adapter 和 OpenAI-compatible Chat adapter 的图片请求体分别符合当前官方文档。
- Anthropic / Gemini 未接入时返回 unsupported，不发 HTTP 请求。

### 12.2 图片素材复查

复查时确认：

- `blue-square.png` 能在 Finder 或预览工具中肉眼识别为白底蓝色正方形。
- 图片文件尺寸为 `256 x 256`。
- 图片没有透明背景、阴影、渐变、边框、文字或多余主体。
- 文件大小保持较小，不引入外部版权和隐私信息。
- 图片不含 EXIF 或不必要 metadata。

可使用命令：

```bash
sips -g pixelWidth -g pixelHeight Packages/LangoTraceAI/Sources/LangoTraceAI/Resources/AIProviderProbe/blue-square.png
mdls -name kMDItemPixelWidth -name kMDItemPixelHeight Packages/LangoTraceAI/Sources/LangoTraceAI/Resources/AIProviderProbe/blue-square.png
```

### 12.3 请求体复查

通过测试中捕获的 `URLRequest` 检查：

- Chat 请求体第三次请求包含 `messages[0].content` 数组。
- Chat 请求体图片 item 使用 `type: "image_url"`。
- Responses 请求体第三次请求包含 `input[0].content` 数组。
- Responses 请求体图片 item 使用 `type: "input_image"` 和 `detail: "low"`。
- 两类请求体都使用 `data:image/png;base64,`。
- 两类请求体都没有用户内容、Prompt Preset 内容或明文 secret。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationProbeServiceTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationServiceTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
```

文档验证：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

完整验证：

```bash
scripts/verify.sh
```

如需要人工验证 iPad / Mac 设置页：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
```

## 14. 文档影响检查

本任务会改变长期 AI Provider 配置测试边界，因此必须更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`。由于它不改变用户真实照片上传默认策略、不改变 Keychain / SQLite 分层、不新增 Prompt Preset 执行链路、不改变 Provider 抽象的核心决策，因此不需要新增 ADR。

本任务会新增真实发送给 Provider 的固定 Prompt，因此必须更新 `docs/prompts/ai-provider/provider-configuration-probe.md`。

本任务不改变 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 的权限边界，因为不访问用户照片、相册、相机、麦克风或本机隐私权限。若实现中需要新增运行期日志采集说明，可在本方案实施记录中补充，不需要修改 spec/008。

## 15. 实施记录

- 2026-05-21：创建方案文档。尚未开始代码实现。

后续每次实施或验证都应在此处追加：

- 修改的关键文件。
- 聚焦测试命令和结果。
- 完整验证命令和结果。
- 手动验证设备和结果。
- 未能执行的检查及剩余风险。

## 16. 完成标准

- `blue-square.png` 已作为 LangoTraceAI resource 打包，并可由测试稳定读取。
- OpenAI Responses adapter 在图片理解开启时发送 `input_image` data URL 请求。
- OpenAI-compatible Chat adapter 在图片理解开启时发送 `image_url` data URL 请求。
- 图片理解 Prompt 已登记到 Prompt Registry。
- 图片理解测试只在 Provider 支持且用户启用时运行。
- 图片理解响应只接受 `blue square`。
- UI 结果面板能正确展示图片理解成功、未启用、不支持、失败和取消状态。
- Draft 测试不持久化 validation event。
- Saved profile 测试仍只记录非敏感 validation event 和最近验证摘要。
- 聚焦测试通过。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。
- 方案完成后移动到 `docs/plans/done/`，状态改为 `Verified` 或 `Done`。

## 17. 剩余风险

- 不同 OpenAI-compatible Provider 对图片输入格式支持程度不一致，可能接受 Chat Completions 文本但拒绝多模态数组。该情况应映射为图片理解能力失败或不支持，而不是整体网络异常。
- 部分模型可能把蓝色识别为近似颜色词，例如 `cyan square`。第一版仍只接受 `blue square`，因为配置探测需要稳定 canonical label，而不是开放视觉描述。
- 图片输入会产生额外 token 成本。使用低分辨率、`detail: "low"` 和短输出限制可以控制成本，但 UI 后续如需更明确成本提示，应另行评估。
- 当前结果模型没有保存原始响应体，排查个别 Provider 的视觉输出偏差时只能依赖非敏感错误分类和运行期日志。该限制符合隐私规范。
