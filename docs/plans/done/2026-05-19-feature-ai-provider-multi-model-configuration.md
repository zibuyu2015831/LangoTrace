# AI Provider 多模型配置页重构方案

Status: Verified

Type: feature

Created: 2026-05-19

Last Updated: 2026-05-19

## 用户确认记录

- 2026-05-19：用户指出当前 AI Provider 设置页仍把“高级模型”作为展开项展示，但真实产品中应区分文本模型、语音模型和向量模型。
- 2026-05-19：用户确认先按“按能力分组的配置页”思路创建方案文档。本确认只覆盖方案创建，不代表已批准开始实现。
- 2026-05-19：用户进一步提出边界问题：同一 Provider 可能文本生成、语音合成、向量化共用同一个 API Key，但请求地址和模型不同；也可能三类能力分别使用三个不同 Provider。方案需要重新区分“凭证”和“模型 endpoint”。
- 2026-05-19：用户确认“确认无误后开始实施”，本方案进入实现阶段。

## 需求描述

AI Provider 设置页需要从单一 Provider + Base URL + API Key + 文本模型 + “高级模型”展开结构，重构为按模型用途分组的真实级配置页。

目标用户可能同时配置三类请求信息：

1. 文本模型：用于文本生成，也可在用户勾选后承担图片理解。
2. 语音生成模型：用于后续 TTS / 语音生成。
3. 向量模型：用于后续 Embedding / 长期记忆 / 本地可重建索引。

三类模型可能来自不同 Provider、不同 Base URL、不同 API Key 和不同模型名，也可能来自同一 Provider、共用同一 API Key、但使用不同请求地址和模型名。因此 UI、mock 配置模型和后续 Provider 边界都不应继续把语音模型、向量模型藏在“高级模型”里，也不应把 API Key 强行复制进每个模型 endpoint。

## 现状描述

当前实现已提交于 `ba8abb7 Refine AI provider settings UI`：

- `AIProviderSettingsView.swift` 当前包含 Provider、连接信息、凭证、模型、保存/测试动作。
- `modelSection` 中固定展示文本模型，并通过 `DisclosureGroup` 展示 `advancedModels`。
- `advancedModels` 里包含向量模型、语音模型和能力边界。
- `AIProviderDraftConfiguration` 目前只有一组 `provider`、`baseURL`、`apiKeyDraft`、`chatModel`、`embeddingModel`、`ttsModel`。
- `AIProviderCapabilitySet` 当前是 Provider preset 的能力描述，不能表达“用户是否启用图片理解、语音生成、向量模型”这些页面级选择。

## 目标

1. 删除“高级模型”概念，改成“文本模型”“语音生成模型”“向量模型”三类业务配置。
2. 文本模型卡片内展示能力边界：
   - 文本生成默认开启，作为文本模型必备能力，不提供关闭入口。
   - 图片理解默认关闭，由用户显式勾选开启。
3. 语音生成模型和向量模型拥有独立 endpoint 边界，可以使用与文本模型不同的 Provider、Base URL、API Key 和模型名；也可以引用文本模型使用的同一份凭证。
4. 保存按钮保存整页 mock 配置状态；测试请求当前仍为模拟测试，不发网络。
5. 页面保持 iPhone 设置页的简洁感，避免恢复开发标记式说明。

## 范围

### 代码范围

- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- 修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- 修改 `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`

### 文档范围

- 更新 `docs/platform-page-inventory.md`
- 更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`
- 必要时补充 `docs/product-main-reference.md` 第 23 节中 Provider 与模型配置的产品说明

## 不做什么

- 不实现真实 Keychain 存储。
- 不实现真实 Provider 网络请求。
- 不实现真实图片理解、TTS 或 Embedding 调用。
- 不做 Provider 配置同步。
- 不在本任务中设计计费、模型价格或 Provider 健康检查。
- 不把 API Key 写入普通数据库、日志、导出包或同步目录。

## 证据与决策依据

### 用户反馈

用户截图指出当前页面中“高级模型”不符合真实产品语义，并明确要求：

- 去除高级模型设定。
- 改成语音模型和向量模型。
- 文本模型能力边界包含“文本生成”和“图片理解”。
- 文本生成默认选中。
- 图片理解由用户勾选。
- 用户可能同时配置三个模型的请求信息，文本、语音生成、向量模型分别使用独立配置。

### 项目文档依据

- `docs/spec/005-ai-provider-prompt-and-privacy.md`：Provider 配置页可在真实网络和 Keychain 接入前提供真实级 mock 表单；敏感凭证必须和非敏感配置分层；后续 AI 请求从 Provider 配置读取。
- `docs/platform-page-inventory.md`：AI Provider 设置页当前为 Local Mock，主路径保持设置表单质感。
- `docs/technical-framework-roadmap.md`：AI Provider、TTS、Embedding、向量化处理和 Keychain 都属于后续真实能力边界。

### 设计判断

“高级模型”是错误的信息架构，因为语音生成和向量化不是高级选项，而是不同业务能力。真实用户可能只配置文本模型，也可能配置三类能力，并且三类能力可能使用不同 Provider。页面结构应直接表达业务用途，而不是按复杂度归类。

### 边界问题复盘

本方案必须同时覆盖以下真实配置形态：

1. **同一 Provider、同一 API Key、不同 endpoint/model**：例如文本模型、语音合成和向量模型都使用同一个服务账号和 API Key，但请求地址、adapter、模型名不同。此时 UI 不应要求用户重复粘贴三遍 API Key。
2. **同一 Provider、不同 API Key**：例如文本生成用高权限 key，向量化用低权限 key。此时三类能力必须能选择独立凭证。
3. **不同 Provider、不同 API Key**：例如文本模型用 OpenAI，语音合成用另一个 TTS Provider，向量模型用本地或兼容服务。此时三类能力的 Provider、Base URL、模型、凭证都必须独立。
4. **无 API Key 的本地 Provider**：例如本地 Ollama 或局域网服务。UI 需要允许某些 Provider 的凭证为空，但不能把“无凭证”推广到所有云端 Provider。
5. **同一模型 endpoint 的多能力复用**：文本生成和图片理解属于文本模型 endpoint 的能力开关。图片理解不是单独 Provider endpoint，除非未来明确引入独立视觉模型配置。

因此长期结构应是：**能力 endpoint 引用凭证**，而不是每个 endpoint 内嵌一份 API Key 字符串。当前 UI mock 可以简化展示，但数据结构和文档必须先表达这个方向。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProviderSettingsTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`

## 涉及的文档路径

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/platform-page-inventory.md`
- `docs/product-main-reference.md`
- `docs/plans/done/2026-05-19-feature-ai-provider-settings-page.md`
- `docs/plans/done/2026-05-19-bug-ai-provider-settings-ui-and-save-copy.md`
- `docs/plans/done/2026-05-19-bug-ai-provider-settings-simplify-layout.md`

## 目标页面结构

```text
AI Provider

文本模型
  Provider
  Base URL
  API Key
  文本模型
  能力
    文本生成：默认开启，不可关闭
    图片理解：默认关闭，可勾选

语音生成模型
  启用语音生成
  Provider
  Base URL
  API Key
  语音模型

向量模型
  启用向量模型
  Provider
  Base URL
  API Key
  向量模型

保存配置
测试请求
状态提示
```

## 数据结构设计

引入页面级 mock 配置结构，用于表达“凭证”和“模型 endpoint”的分离。命名可以在实现时按 Swift 风格微调，但语义必须保持清晰：

```swift
enum AIProviderCredentialReference: Equatable {
    case textCredential
    case independent
}

struct AIProviderCredentialDraftConfiguration: Equatable {
    var provider: AIProviderPreset
    var apiKeyDraft: String
    var requiresAPIKey: Bool
}

struct AIProviderEndpointDraftConfiguration: Equatable {
    var provider: AIProviderPreset
    var baseURL: String
    var model: String
    var credentialReference: AIProviderCredentialReference
    var independentCredential: AIProviderCredentialDraftConfiguration
}

struct AITextModelDraftConfiguration: Equatable {
    var endpoint: AIProviderEndpointDraftConfiguration
    var textGenerationEnabled: Bool
    var imageUnderstandingEnabled: Bool
}

struct AISpeechModelDraftConfiguration: Equatable {
    var isEnabled: Bool
    var endpoint: AIProviderEndpointDraftConfiguration
}

struct AIEmbeddingModelDraftConfiguration: Equatable {
    var isEnabled: Bool
    var endpoint: AIProviderEndpointDraftConfiguration
}

struct AIProviderDraftConfiguration: Equatable {
    var text: AITextModelDraftConfiguration
    var speech: AISpeechModelDraftConfiguration
    var embedding: AIEmbeddingModelDraftConfiguration
    var saveState: AIProviderSaveState
    var testState: AIProviderTestState
}
```

设计要求：

- 文本配置必填，`textGenerationEnabled` 永远为 `true`。
- `imageUnderstandingEnabled` 默认 `false`，仅影响 UI 和 mock 状态，不发起图片请求。
- 文本 endpoint 的 `credentialReference` 固定等价于独立凭证，因为它是默认凭证来源。
- 语音生成配置默认 `isEnabled == false`，用户启用后才校验 Provider、Base URL、凭证来源和语音模型。
- 向量配置默认 `isEnabled == false`，用户启用后才校验 Provider、Base URL、凭证来源和向量模型。
- 语音生成和向量模型默认可以选择“使用文本模型凭证”，以覆盖同一 Provider 共用 API Key、但 endpoint/model 不同的常见场景。
- 当某个能力卡片选择不同 Provider 时，默认切换为“独立凭证”，避免跨 Provider 误用 API Key。用户仍可手动选择共享凭证，但 UI 必须给出短提示，说明只有同一账号体系下才应共享。
- 如果 Provider preset 标记为本地或不需要 API Key，则对应凭证可以为空；云端 Provider 默认要求 API Key。
- Provider 变更时只重置当前卡片的默认 Base URL 和模型名，不影响其他卡片。

## UI 设计方案

### 文本模型卡片

- 标题：`文本模型`
- 展示 Provider 选择、Base URL、API Key、文本模型。
- 文本模型凭证是页面的默认凭证来源。后续语音生成和向量模型可以引用它，也可以改用独立凭证。
- 能力边界使用两行设置项：
  - `文本生成`：左侧 checkmark，右侧状态 `已开启`，不可点击。
  - `图片理解`：使用 Toggle 或 Checkbox 样式，默认关闭。
- 如果当前 Provider preset 不支持图片理解，`图片理解` 控件置灰，并显示短状态 `当前 Provider 不支持`。

### 语音生成模型卡片

- 标题：`语音生成模型`
- 顶部使用 Toggle：`启用语音生成`
- 未启用时只展示标题和 Toggle。
- 启用后展示 Provider、Base URL、语音模型字段。
- 凭证区域使用简洁选择：
  - `使用文本模型凭证`
  - `使用独立凭证`
- 选择独立凭证时才展示 API Key 输入。
- 如果当前 Provider preset 没有默认语音模型，模型字段为空，由用户填写。

### 向量模型卡片

- 标题：`向量模型`
- 顶部使用 Toggle：`启用向量模型`
- 未启用时只展示标题和 Toggle。
- 启用后展示 Provider、Base URL、向量模型字段。
- 凭证区域使用简洁选择：
  - `使用文本模型凭证`
  - `使用独立凭证`
- 选择独立凭证时才展示 API Key 输入。
- 如果当前 Provider preset 没有默认向量模型，模型字段为空，由用户填写。

### 凭证共享规则

- 页面默认把文本模型凭证作为“主凭证”。
- 语音生成和向量模型如果选择相同 Provider，可以默认提供“使用文本模型凭证”。
- 语音生成和向量模型如果切换到不同 Provider，默认切换为“使用独立凭证”。
- 共享凭证只共享敏感凭证，不共享 Base URL、请求格式、adapter 或模型名。
- 保存时应保存为“endpoint 配置 + credential reference”的关系，而不是把同一个 API Key 文本复制到多个 endpoint。
- 当前 UI mock 不写 Keychain，但后续真实接入时应让多个 endpoint 引用同一个 Keychain item，而不是生成多份重复密钥。

### 操作区

- 保存配置仍为主按钮。
- 测试请求仍为次按钮。
- 当前阶段的测试请求是 mock 检查：
  - 文本模型字段缺失时提示补齐文本模型配置。
  - 语音生成已启用但字段缺失时提示补齐语音生成配置。
  - 向量模型已启用但字段缺失时提示补齐向量模型配置。
- 不展示“当前版本不写入钥匙串”这类开发说明在主路径；对应边界保留在文档和测试中。

## 实施方案

### 1. 更新回归测试

在 `AIProviderSettingsTests.swift` 中新增测试：

- 源码不再包含 `aiProviderSettings.advancedModels.title`。
- 源码包含 `aiProviderSettings.textModel.title`、`aiProviderSettings.speechModel.title`、`aiProviderSettings.embeddingModelGroup.title`。
- Draft 默认文本生成开启、图片理解关闭。
- 语音生成和向量模型默认关闭。
- 启用语音生成后，其字段参与 readiness 校验。
- 启用向量模型后，其字段参与 readiness 校验。
- 语音生成和向量模型选择“使用文本模型凭证”时，不要求重复填写 API Key。
- 语音生成和向量模型选择“使用独立凭证”时，云端 Provider 必须校验独立 API Key。
- 切换到不同 Provider 时，凭证来源默认变为独立凭证。

### 2. 重构 Draft 模型

在 `AIProviderDraftConfiguration.swift` 中：

- 提取通用 endpoint draft。
- 提取凭证 draft，避免每个 endpoint 内嵌 API Key。
- 将当前单一 `provider/baseURL/apiKeyDraft/model` 拆成 text/speech/embedding 三个 endpoint 配置。
- 为 speech/embedding 增加凭证引用模式：使用文本模型凭证或独立凭证。
- 保留 `saveState` 和 `testState`。
- 将 readiness 从单一字段列表改成分组校验。

### 3. 重构 Provider 默认值

在 `AIProviderSettingsModels.swift` 中：

- 保留 `AIProviderPreset`。
- 为 Provider 提供按用途读取默认模型的方法或属性：
  - `defaultTextModel`
  - `defaultSpeechModel`
  - `defaultEmbeddingModel`
- 保留 Provider 能力描述，但不要把 Provider 支持能力和用户启用状态混为一个字段。
- 增加 Provider 是否默认需要 API Key 的描述，至少区分云端 Provider 和本地 Provider。

### 4. 重构设置页 UI

在 `AIProviderSettingsView.swift` 中：

- 删除 `showsAdvancedModels`。
- 删除“高级模型” DisclosureGroup。
- 新增三个卡片区域：
  - `textModelSection`
  - `AIProviderOptionalModelSection` for speech
  - `AIProviderOptionalModelSection` for embedding
- 抽取可复用的 endpoint 表单子视图，避免三类卡片重复大量 TextField 代码。
- 抽取可复用的凭证来源选择控件，避免语音生成和向量模型重复实现共享/独立凭证逻辑。
- 保持每个交互控件最小 44pt 点击区域。

### 5. 更新本地化

在 `Localizable.xcstrings` 中：

- 删除或停止使用 `aiProviderSettings.advancedModels.title`。
- 新增文本模型、语音生成模型、向量模型、启用语音生成、启用向量模型、文本生成、图片理解、使用文本模型凭证、使用独立凭证等 key。
- 保持中文和英文都有明确翻译。

### 6. 更新文档

- 在 `docs/spec/005-ai-provider-prompt-and-privacy.md` 补充：Provider 配置页按模型用途分组，不再使用高级模型概念。
- 在 `docs/spec/005-ai-provider-prompt-and-privacy.md` 补充：模型 endpoint 与敏感凭证分离；多个 endpoint 可以引用同一凭证。
- 在 `docs/platform-page-inventory.md` 更新 AI Provider 设置页描述。
- 如产品主参考第 23 节仍用单一 Provider 配置表达三类能力，则补充三类模型可独立配置的说明。

## 复查方法

1. 代码复查：
   - 搜索 `advancedModels`，确认 UI 主路径不再使用。
   - 搜索 `AIProviderDraftConfiguration`，确认文本、语音、向量配置边界清楚。
   - 搜索 `credentialReference` 或等价命名，确认 speech/embedding 可以引用文本模型凭证，也可以使用独立凭证。
   - 搜索 `URLSession|dataTask|uploadTask|Authorization`，确认本任务没有引入真实网络请求。
2. UI 复查：
   - iPhone 页面中不出现“高级模型”。
   - 文本模型卡片展示文本生成和图片理解。
   - 语音生成模型和向量模型是独立卡片。
   - 语音生成和向量模型在共享凭证时不重复展示 API Key 输入，在独立凭证时展示 API Key 输入。
   - 保存配置、测试请求仍在页面底部附近。
3. 文档复查：
   - 页面清单、AI Provider 规范和任务方案描述一致。
   - 不把当前 mock 状态描述为真实 Keychain 已完成。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
git diff --check
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
scripts/verify.sh
```

## 文档影响检查

本任务影响 AI Provider、敏感凭证边界、Embedding / 向量化配置边界、TTS 配置边界和页面清单。实现完成后必须同步检查：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/platform-page-inventory.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`

不需要新增 ADR，因为本方案不改变“本地优先、用户自带 Provider、敏感凭证进入 Keychain 或等价安全存储、AI 请求走 Provider 层”的核心决策。

## 实施记录

- 2026-05-19：创建方案文档，状态为 Draft，等待用户确认是否进入实现。
- 2026-05-19：用户确认开始实施，状态更新为 In Progress。
- 2026-05-19：新增 AI Provider 设置测试，先验证旧 draft 缺少 text/speech/embedding 和凭证引用模型，测试编译失败。
- 2026-05-19：重构 UI draft 为文本、语音、向量三类 endpoint，并引入文本凭证引用和独立凭证选择。
- 2026-05-19：更新 iOS 设置页，删除“高级模型”，改为三类模型卡片；图片理解默认关闭，文本生成默认开启。
- 2026-05-19：同步更新 AI Provider 规范、页面清单和产品主参考中的多模型 endpoint / 凭证引用边界。
- 2026-05-19：抽取 `AIProviderSettingsComponents.swift` 承载 endpoint 表单、凭证来源选择和能力边界组件，保持主 View 简洁并满足 lint 长度约束。
- 2026-05-19：验证通过：`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`、`swift test --package-path Packages/LangoTraceUI`、`swiftlint --no-cache`、`swiftformat --lint . --cache ignore`、`git diff --check`、文档占位符扫描、`scripts/verify.sh`。
- 2026-05-19：后续可用性修正见 `docs/plans/active/2026-05-19-bug-ai-provider-api-key-field-usability.md`。该修正不改变本方案的数据结构边界，只调整 Provider 行内展示、API Key 标签、显示/隐藏按钮和面向用户的 API Key 文案。

## 完成标准

- AI Provider 设置页不再展示“高级模型”。
- 文本模型、语音生成模型、向量模型以独立业务配置呈现。
- 文本生成默认开启且不可关闭。
- 图片理解默认关闭且由用户显式勾选。
- 语音生成和向量模型可独立启用，并拥有独立 Provider、Base URL 和模型字段。
- 语音生成和向量模型既可引用文本模型凭证，也可使用独立凭证。
- 同一 API Key 不因多个 endpoint 引用而在 mock 配置中复制成多份独立密钥。
- 当前阶段不发网络、不写 Keychain。
- `swift test --package-path Packages/LangoTraceUI` 和 `scripts/verify.sh` 通过。
- 文档同步完成，任务方案移入 `docs/plans/done/`。

## 剩余风险

- 三类模型都允许独立配置会增加页面长度，需要在实现时控制卡片密度和默认折叠策略。
- 不同 Provider 对图片理解、TTS、Embedding 的支持差异较大，当前 mock preset 只能表达第一轮常见能力，真实接入时仍需逐 Provider 校准。
- 后续真实 Keychain 接入时，需要把 `credentialReference` 映射为稳定 Keychain item 引用，并处理密钥轮换、删除共享凭证时的引用检查、以及导出/同步时凭证永不同步的问题。
