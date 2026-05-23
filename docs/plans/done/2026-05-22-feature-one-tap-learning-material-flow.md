# 任务方案：一键生成学习材料闭环

状态：Done
类型：feature
创建日期：2026-05-22
最后更新日期：2026-05-23

## 用户确认记录

- 2026-05-22：用户确认采用“一键生成学习材料”的方向：不再拆分“生成学习材料”和“改写优化”两个按钮；AI 在同一次生成请求中根据输入内容判断母语记录、目标语言写作、混合文本或不确定文本，并返回学习文本和学习分析。
- 2026-05-22：用户确认派生学习文本允许编辑；用户编辑后可以重新进行拆分单句、语法分析和词句提取。
- 2026-05-22：用户提出原始输入不应允许再编辑；本方案采纳该方向，并从交互、产品定位和数据可追溯性角度明确为实施原则。
- 2026-05-23：用户确认本任务采用“完整 GRDB 持久化路径”，不以 `InMemoryLearningContentRepository` 原型作为真实学习闭环完成口径；本次补充存储数据结构、Prompt 完整文本和结构化 JSON 输出契约。
- 2026-05-23：严格复审后补充 repository 演进路径、soft delete 查询语义、operation 生命周期、非阻断 AI 披露、Core 验证和 execution-readiness gate；本方案仍需用户确认后才可实现。
- 2026-05-23：再次复审数据存储结构和文档实施步骤后，补充迁移恢复策略、导出边界、数据库枚举约束、operation 单行摘要语义、analysis 部分失败规则，以及 `docs/spec/007-data-storage-migration-export-and-attachments.md` 和 `docs/spec/learning-content/impl.md` 的规范更新落点。
- 2026-05-23：代码复核后补充应用编排层、`LearningContentStore` async 迁移、settings capability 解耦、`EntrySource` / `inputKind` 语义分层、Prompt 一致性测试、hash / JSON schema version 和 v3 fixture 迁移测试约束。
- 2026-05-23：用户确认本轮实现先完成 iOS / iPhone 端；iPad 和 macOS 端待 iOS 端人工测试通过后再另行推进。底层 Core / Data / AI / App Shell 仍按三端可复用边界建设，但本轮 UI 可交付范围只包含 iOS。
- 2026-05-23：用户确认“该方案审核通过”，并要求根据该方案开始实施，直至方案完整落地；每个阶段均需检查、测试和 commit。

## 1. 需求描述

当前 iPhone 首页点击“写一句”后，用户保存文本记录并进入记录详情。下一阶段需要把详情页从本地预览推进到真实 AI 学习闭环：

1. 记录详情页只保留一个核心 AI 动作：`生成学习材料`。
2. 用户点击后立即进行 AI 处理，不再弹出请求确认环节。
3. AI 在同一次请求中识别输入类型，并按不同路径生成学习材料：
   - 母语记录：生成目标语言表达、逐句对照、语法讲解、词句提取和练习候选。
   - 目标语言写作：生成优化稿、修改说明、逐句分析、语法讲解、词句提取和练习候选。
   - 混合文本：保留混合语境，按主要意图生成学习材料，并在结果中说明处理依据。
   - 不确定文本：默认按母语记录处理，同时在结果元数据中标记不确定。
4. 用户可以编辑 AI 生成或优化后的学习文本。
5. 用户编辑学习文本后，可以重新分析，重新生成单句拆分、语法分析和词句提取。
6. 保存后的原始输入作为 Entry 原始记录，不允许直接编辑。

## 2. 现状描述

当前代码和文档事实：

- iPhone 记录入口由 `HeroActionCard` 提供，`写一句` 打开 `EntryEditorView`。
- `EntryEditorView` 通过 `TextField` 和 `TextEditor` 收集标题与正文，保存后调用 `contentStore.createEntry`。
- `PhoneMainView` 在保存后关闭 sheet，并导航到 `.entryDetail(entry.id)`。
- `EntryDetailView` 当前展示原始记录、目标语言文本区域、逐句内容、本地预览生成入口和练习条目。
- `LearningEntry` 表示用户原始生活记录，当前字段包括 `id`、`spaceID`、`title`、`body`、`source`、`scene`、`createdAt` 和 `practiceSummary`。
- `LearningRendering` 表示基于 Entry 的目标语言学习版本，当前字段包括 `targetText`、`promptLabel`、`providerLabel`、`isMock` 和 `sentences`。
- `InMemoryLearningContentRepository.generateLocalPreview` 当前通过本地 mock 生成 Rendering、PracticeItem 和 MemoryItem。
- AI Provider 配置、保存和合成测试已经存在，但真实学习内容请求、Prompt Preset 执行、请求日志和学习材料生成尚未接入。

## 3. 目标

本任务完成后，应达到以下目标：

1. `Entry` 成为不可直接编辑的原始记录快照；保存前草稿可编辑，保存后原始正文只读。
2. 记录详情页提供唯一主动作 `生成学习材料`。
3. 点击 `生成学习材料` 后进入明确的处理中状态，并通过 AI Provider / Prompt 边界发起一次结构化生成请求。
4. 一次生成请求返回学习文本、输入类型判断、逐句拆分、语法讲解、词句候选、练习候选和非敏感生成元数据。
5. 目标语言写作输入的结果包含优化稿和修改说明，但不覆盖用户原始输入。
6. 学习文本允许用户编辑；编辑后分析结果进入过期状态。
7. 用户可触发 `重新分析`，基于当前学习文本重建逐句拆分、语法分析和词句提取，不重新生成学习文本。
8. 用户可触发 `重新生成`，从原始 Entry 再生成一版新的学习文本和学习分析。
9. 长文本在发出 AI 请求前由 App 层做长度控制，避免把明显过长的内容直接发送给 Provider。
10. 文档同步更新产品、AI 隐私、页面清单和必要的实现地图。

## 4. 范围

本任务范围：

- iPhone 记录详情页的一键学习材料生成入口。
- 本轮 UI 可交付范围仅限 iOS / iPhone；iPad / macOS 的入口、状态展示和平台适配待 iOS 端人工测试通过后另行制定或开启后续任务。
- 底层 Core / Data / AI / App Shell 仍按三端可复用边界建设，避免为 iOS 写入平台专属数据模型、Prompt、Provider 或 repository 逻辑。
- 学习材料生成的 Core / Data / AI / UI 模型边界。
- Prompt Preset 注册与结构化输出契约。
- 原始 Entry 不可直接编辑的产品与数据规则。
- 可编辑 Rendering / LearningText 与可重建 Analysis 的交互闭环。
- 短文本和中等文本的请求策略，以及长文本阻断和选段入口说明。

## 5. 不做什么

本任务不实现以下内容：

- 不实现照片、音频、OCR 或历史记忆上下文发送。
- 不实现 TTS、录音、听写、回译或真实练习评分。
- 不实现 Prompt Preset 自定义、导入或导出。
- 不实现同步、备份、导出和向量索引。
- 不允许编辑保存后的原始 Entry 正文。
- 不把原始 Entry 改写为 AI 优化稿。
- 不在点击 `生成学习材料` 后再弹出阻断式确认。
- 不把语言检测结果作为不可纠正的绝对事实；AI 输出必须携带输入类型判断和置信提示。
- 不把 UI 文案、语言空间展示名或本地化字符串作为 Prompt 语言事实源。
- 本轮不实现 iPad / macOS 记录详情页的学习材料生成 UI 接入、创建入口 async 保存状态、平台适配和人工验收；这些工作必须等 iOS 端人工测试通过后再推进。

## 6. 证据与决策依据

产品依据：

- `docs/product-main-reference.md` 明确核心闭环是“记录 -> 转换 -> 对照 -> 听说 -> 输出 -> 提取 -> 复习 -> 沉淀”。
- 同一文档明确支持目标语言自主写作闭环：用户直接用目标语言记录生活，再由 AI 检测、修改、讲解和沉淀。
- `docs/product-main-reference.md` 第 18 节已经定义 `Entry` 是用户原始生活记录，`Rendering` 是 AI 基于 Entry 生成的目标语言学习版本。

交互依据：

- 一个核心按钮符合“首页围绕一个主动作”的产品方向，降低“我应该先生成还是先优化”的决策负担。
- 原始输入不允许保存后直接编辑，是最优推荐方案。原因：
  - 语迹的产品定位是“生活痕迹”和“真实生活材料”，原始 Entry 是事实锚点，不应被后续优化过程反复覆盖。
  - 学习材料需要可追溯到用户当时的真实表达；如果原始输入可编辑，历史 AI 输出、练习记录、词句候选和复习上下文会失去稳定来源。
  - 用户需要修改学习表达时，应编辑派生学习文本，而不是改写原始生活记录。
  - 保存前草稿已经提供修改机会；保存后如果用户确实记录错了，应通过删除重建或未来的复制为新记录能力处理，而不是让原文和派生结果在同一对象上互相污染。
  - 原始正文只读不等于所有元数据冻结；标题、标签、场景等非正文元数据后续可以单独设计编辑能力。

隐私与 AI 边界依据：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 要求照片、日记、音频、历史记忆和目标语言写作内容只有在用户明确触发相关能力时才发送给 Provider。
- 本方案把 `生成学习材料` 定义为明确触发 AI 的动作；点击即表示对当前 Entry 文本发起本次 AI 学习材料请求。
- 不设置阻断确认，但必须在按钮、加载状态和结果元数据中表达这是 AI 生成，不暗示本地生成。
- 长文本、照片、音频、历史记忆和多条记录上下文仍需要更强的边界；本任务只覆盖当前文本 Entry。
- 当前文本 Entry 属于中风险 AI 请求，因为会发送用户主动输入的生活记录或目标语言写作文本。采用非阻断确认的前提是：按钮附近、生成中状态和结果元数据都必须明确披露“将发送当前文本给已配置的 AI Provider / 已由 AI 生成”，并提供 Provider / 模型 / Prompt 版本的非敏感回溯信息；未来照片、音频、OCR、历史记忆或多条 Entry 上下文不得复用该低摩擦边界。

## 7. 涉及的代码文件路径

预计修改：

- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/InMemoryLearningContentRepositoryTests.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/`
- `LangoTraceApp/AppEnvironment.swift`

可能新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialPromptRegistry.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningMaterialGenerationView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningMaterialEditorView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningMaterialGenerationTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`

## 9. 涉及的文档路径

预计同步更新：

- `docs/product-main-reference.md`
- `docs/platform-page-inventory.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/learning-content/impl.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/prompts/`

只读参考：

- `docs/plans/README.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/review/README.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.0 审核后架构修订要求

2026-05-22 严格方案审核结论：本方案产品方向成立，但不能按原草案直接实现。实现前必须纳入以下架构修订，否则会出现包依赖倒置、状态竞争或真实用户内容丢失。

必须采用的模块边界：

```text
App Shell
  - 装配 GRDB repositories、Keychain credential store、AI generation service 和 UI action closures

UI package
  - 只持有 View state、presentation model 和 action closure
  - 不 import LangoTraceAI
  - 不创建 URLRequest
  - 不读取 Keychain

Core package
  - 承载跨 UI / AI / Data 共享的生成请求和结果 DTO
  - 承载输入类型、生成状态、错误分类、长度等级等稳定领域枚举

AI package
  - 负责 Prompt 渲染、Provider 请求体构造、响应解析和结构校验
  - 只依赖 Core，不依赖 Data 或 UI

Data package
  - 负责 Entry、LearningMaterial、Analysis、MemoryCandidate、PracticeCandidate 的存储和查询
  - 不依赖 AI
```

原因：

- 当前 `LangoTraceAI/Package.swift` 只依赖 `LangoTraceCore`；当前 `LangoTraceUI/Package.swift` 只依赖 `LangoTraceCore` 和 `LangoTraceData`。如果把 `LearningMaterialGenerationModels` 放在 AI package，Data 和 UI 都不能稳定引用，除非引入错误依赖方向。
- 当前 UI 已有 `AIProviderSettingsActions` 这种由 App Shell 注入 closure 的模式，学习材料生成也应新增类似 `LearningMaterialGenerationActions`，由 `LangoTraceApp/AppEnvironment.swift` 装配真实服务。
- `View` 不能直接访问网络、Keychain 或具体 Provider；真实请求必须经 AI service 和 App Shell action seam。

因此，跨模块模型优先落在 Core。Data 可以定义持久化 record / repository 细节，但不得要求 AI import Data。

#### 11.0.1 应用编排层

本任务必须新增明确的应用编排层，不能让 SwiftUI View、`LearningContentStore`、AI package 或 Data repository 各自拼接完整流程。

推荐新增：

```swift
public struct LearningMaterialGenerationActions: Sendable {
    public var generateMaterial: @Sendable (LearningMaterialGenerationRequest) async -> LearningMaterialGenerationActionResult
    public var analyzeCurrentText: @Sendable (LearningMaterialAnalysisRequest) async -> LearningMaterialGenerationActionResult
    public var recordBlockedOperation: @Sendable (
        DiagnosticOperationID,
        String,
        LearningMaterialOperationKind,
        LearningMaterialGenerationFailureCategory,
        LearningMaterialEstimatedTokenBucket
    ) async -> Void
    public var cancelOperation: @Sendable (
        DiagnosticOperationID,
        String,
        String?,
        LearningMaterialOperationKind,
        LearningMaterialEstimatedTokenBucket
    ) async -> Void
}
```

或在 App target 内新增等价 use case：

```swift
struct LearningMaterialGenerationUseCase: Sendable {
    func generate(_ request: LearningMaterialGenerationRequest) async -> LearningMaterialGenerationActionResult
    func analyze(_ request: LearningMaterialAnalysisRequest) async -> LearningMaterialGenerationActionResult
}
```

编排层职责：

1. 读取当前 Entry、Language Space 和默认文本模型 Provider 配置。
2. 在请求前做长度估算、空文本、Provider 未配置、默认 profile 删除、endpoint disabled、endpoint purpose 非 text generation、credential missing / inaccessible 等 preflight。
3. 为每次生成或重新分析创建 `DiagnosticOperationID`，并调用 Data repository 写入 `started` operation 摘要。
4. 通过 Keychain reference 解析 secret；secret 只在编排层和 AI service 调用边界短生命周期存在，不进入 UI、日志、数据库或错误对象。
5. 将已规范化的 endpoint 输入、短生命周期 secret、Prompt 输入和 operation id 传入 `LearningMaterialGenerationService.generate` 或 `analyze`；AI package 只完成 Prompt 渲染、Provider 请求体构造、HTTP adapter 调用、结构化 JSON 解析和字段级校验，不再自行读取 Provider repository 或 Keychain。
6. 调用 Data repository 在事务中保存成功结果和 `succeeded` operation 摘要。
7. 对取消、网络、timeout、provider rejected、unsupported provider / model、invalid structured response、persistence failed 等错误映射为 Core 中稳定的 `LearningMaterialGenerationFailureCategory`。
8. 保证取消不写成失败；Provider 返回后如果 operation 已过期或当前 Entry / space 不匹配，不得覆盖 UI 当前状态。

依赖方向：

```text
App Shell / Use Case
  -> Data repository
  -> AI service
  -> Keychain credential store
  -> Diagnostic logger
  -> Core DTO / error / state

UI
  -> LearningMaterialGenerationActions only

AI
  -> Core only

Data
  -> Core only
```

禁止事项：

- SwiftUI View 不得直接读取 Provider profile、Keychain、`DatabaseQueue`、`URLRequest` 或 Provider SDK。
- `LearningContentStore` 不得直接解析 secret 或构造 Provider 请求体。
- `LearningMaterialGenerationService` 不得 import `LangoTraceData` 或直接落库。
- `GRDBLearningContentRepository` 不得 import `LangoTraceAI` 或调用 AI service。

#### 11.0.2 operation 生命周期总图

生成请求必须按以下阶段执行：

```text
UI action
  -> use case preflight
  -> Data: insert started operation
  -> Keychain: resolve secret
  -> AI: request + structured parse
  -> Data: save material + analysis + candidates + succeeded operation in one write transaction
  -> UI: refresh current entry detail state
```

失败 / 取消路径：

```text
preflight blocked
  -> optionally write blocked operation summary when entryID is known
  -> UI blocked / recoverable state

network / provider / parse failed
  -> Data: update same operation row to failed
  -> UI retryable failure state

cancelled
  -> Data: update same operation row to cancelled when started exists
  -> UI previous stable state

persistence failed after AI success
  -> Data: no partial material remains
  -> operation marked failed with persistenceFailed when possible
  -> UI shows save failure and allows regenerate
```

`started`、AI 网络请求和 `succeeded` 不得处于同一个数据库事务。只有成功时的 material、analysis、candidates 和 operation `succeeded` 摘要必须处于同一个 `DatabaseQueue.write` 边界。

### 11.1 产品与交互模型

采用单按钮模型：

```text
按钮文案：生成学习材料
```

按钮语义：

- 对当前 Entry 文本发起 AI 学习材料生成。
- 不要求用户先选择“母语记录”或“目标写作”。
- 不弹出请求确认。
- Provider 未配置、文本为空、文本过长、网络失败、配额失败或请求取消时，展示可恢复状态。

结果层级：

```text
Entry 原始记录
  - 用户保存时的原始正文
  - 保存后只读
  - 作为所有生成版本的事实来源

LearningText / Rendering 学习文本
  - AI 根据 Entry 生成的目标语言表达或目标语言优化稿
  - 用户可编辑
  - 可生成多个版本
  - 可被设为当前学习版本

LearningAnalysis 学习分析
  - 逐句拆分
  - 语法讲解
  - 词句候选
  - 练习候选
  - 依赖当前学习文本，可重建
```

目标语言写作的结果不需要先让用户确认后再分析。首次请求直接返回完整结果：

```text
原文：用户输入的目标语言文本，只读保留
优化稿：AI 生成的更自然版本，可编辑
修改说明：AI 解释关键修改
学习分析：基于优化稿生成
```

用户编辑学习文本后的状态：

```text
文本已修改，分析需要更新

主动作：重新分析
次动作：放弃修改
更多动作：重新生成
```

### 11.2 输入类型自路由

AI 生成请求必须返回稳定的 `inputKind`：

```swift
public enum LearningMaterialInputKind: String, Codable, Sendable {
    case nativeRecord
    case targetWriting
    case mixed
    case uncertain
}
```

Prompt 输入必须包含稳定语言事实：

```swift
public struct LearningMaterialGenerationInput: Sendable {
    public var entryID: String
    public var sourceText: String
    public var nativeLanguageCode: String
    public var targetLanguageCode: String
    public var proficiencyLevelCode: String
    public var promptMode: LearningMaterialPromptMode
}
```

`promptMode` 第一版只需要：

```swift
public enum LearningMaterialPromptMode: String, Sendable {
    case automaticLearningMaterial
    case analyzeCurrentLearningText
}
```

这些类型必须位于 Core 或等价共享层。AI service、Data repository 和 UI action 不得各自复制一套同名枚举。

#### 11.2.1 `EntrySource` 与 `inputKind` 语义分层

`EntrySource` 只表示 Entry 的采集来源或创建模态，不表示语言类型或 AI 处理路径。

第一版语义：

- `EntrySource.typedText`：用户从“写一句”文本入口创建的原始记录。用户可能输入母语、目标语言、混合文本或不确定文本。
- `EntrySource.photoWriting`：未来照片写作入口创建的记录。本任务不发送照片、OCR 或附件内容。
- `EntrySource.targetLanguageWriting`：保留为未来显式目标语言写作入口或导入场景的来源标记；当前 `写一句` 入口不使用它。

`LearningMaterialInputKind` 才是 AI 学习材料生成的任务路由结果：

- `nativeRecord`：AI 判断原文主要是母语生活记录。
- `targetWriting`：AI 判断原文主要是目标语言写作，需要优化稿和修改说明。
- `mixed`：AI 判断原文混合母语和目标语言。
- `uncertain`：AI 无法稳定判断，按母语记录或保守策略处理，并在结果中给出判断说明。

实现要求：

- Prompt 输入可以包含 `EntrySource` 作为来源元数据，但不得用它替代语言判断。
- Data 查询、UI 状态和练习候选不得把 `.typedText` 等同于 `nativeRecord`。
- 测试必须覆盖 `.typedText` Entry 返回 `targetWriting`、`mixed` 和 `uncertain` 的路径。
- 如果未来开放显式目标语言写作入口，应另开任务定义入口文案、隐私披露和 `EntrySource.targetLanguageWriting` 的写入条件。

### 11.3 请求类型

第一版定义两类请求：

1. 生成请求：

```text
Entry 原始正文 -> 学习文本 + 学习分析
```

2. 分析请求：

```text
当前学习文本 -> 学习分析
```

生成请求用于首次点击 `生成学习材料` 和用户主动 `重新生成`。

分析请求用于用户编辑学习文本后点击 `重新分析`。它不重新优化全文，不改变原始 Entry，不生成新的 Entry。

### 11.4 长度策略

App 层必须在发出 AI 请求前估算长度。第一版采用保守阈值：

```text
<= 800 estimated tokens：
  直接进行一次完整生成请求。

801 - 3000 estimated tokens：
  允许生成，但输出深度降级：限制每句讲解长度、词句候选数量和练习候选数量。

> 3000 estimated tokens：
  阻止直接全量生成，提示用户先选择一段。
```

界面不显示 token。中文 UI 文案：

```text
内容较长，先选择一段生成学习材料。
```

第一版可以先提供阻断和说明，不实现完整分段选择器；如果要实现选段，需在本方案中追加明确 UI 和测试步骤后再动代码。

### 11.5 数据模型方向

最小模型可以在现有 `LearningRendering` 上扩展，但实现时应优先避免把所有分析字段塞进单一大结构。推荐拆分：

```swift
public struct LearningMaterial: Equatable, Identifiable, Sendable {
    public var id: String
    public var entryID: String
    public var inputKind: LearningMaterialInputKind
    public var learningText: String
    public var originalGeneratedText: String
    public var revisionSummary: [LearningRevision]
    public var analysis: LearningMaterialAnalysis
    public var providerLabel: String
    public var promptLabel: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isCurrent: Bool
}

public struct LearningMaterialAnalysis: Equatable, Sendable {
    public var sentences: [LearningSentenceAnalysis]
    public var memoryCandidates: [LearningMemoryCandidate]
    public var practiceCandidates: [LearningPracticeCandidate]
    public var sourceTextHash: String
}
```

`sourceTextHash` 用于判断学习文本编辑后分析是否过期，不记录敏感明文摘要到日志。

### 11.6 原始输入不可编辑规则

实现中必须遵守：

- `EntryEditorView` 中的草稿在保存前可编辑。
- 保存后的 Entry 正文在详情页只读展示。
- 详情页不提供编辑原始正文按钮。
- AI 生成、优化和用户改动都写入派生学习文本，不回写 Entry 正文。
- 如果用户编辑派生学习文本，分析状态变为过期。
- 未来若需要修正原始记录，应另开任务设计“复制为新记录”或“创建修正版 Entry”，不能在本任务中直接开放原文编辑。

### 11.7 UI 状态

记录详情页需要支持以下状态：

- 无学习材料：显示原始记录和 `生成学习材料`。
- 生成中：按钮禁用，显示 AI 处理中状态和取消入口。
- 生成成功：显示原始记录、学习文本、分析结果和编辑入口。
- 生成失败：显示错误类别、重试入口和不丢失原始记录说明。
- 文本已编辑：显示分析过期提示和 `重新分析`。
- 重新分析中：只更新分析区，不遮挡原始记录。
- Provider 未配置：引导进入 AI Provider 设置。
- 内容过长：引导选择一段或缩短文本。

非阻断 AI 披露要求：

- 无学习材料状态下，主按钮附近必须用简短说明表达“点击后会把当前文本发送给已配置的 AI Provider 生成学习材料”，不得只写“本地预览”或暗示本地处理。
- 该披露必须和 `EntryEditorView` 的“保存到本机”隐私提示形成清晰分层：保存 Entry 仍是本机写入；只有用户在详情页主动点击 `生成学习材料` 才会发送当前 Entry 文本给已配置的 AI Provider。不得让用户误以为保存动作已经上传，也不得让用户误以为生成动作仍是纯本地处理。
- 生成中状态必须展示 AI 处理中语义，并保留取消入口。
- 生成成功后，结果元数据必须展示非敏感来源信息：Provider preset、模型名、Prompt id / version、生成时间或最近更新时间。
- Provider 未配置时不应静默禁用主按钮；应展示进入 AI Provider 设置的入口，并说明需要先配置文本模型。

### 11.8 测试计划

先写失败测试，再实现代码。

Data package 测试：

- `createEntry` 后原始 Entry 不产生学习材料。
- 生成学习材料不会修改 Entry 正文。
- 编辑学习文本只更新 LearningMaterial / Rendering，不更新 Entry。
- 学习文本编辑后 analysis 状态变为过期。
- 重新分析更新 analysis，不改变 Entry 和 learningText。
- 首次生成结构化响应 analysis 缺失或非法时整次失败，不落半成品 material。
- 重新分析失败时不删除旧 analysis，不覆盖 learningText，并保持当前编辑后的 stale 状态。
- 删除 Entry 后 active entry、current material、memory candidate、practice candidate 和 practice session 查询都不再返回该 Entry 的内容。
- operation 记录按 `started -> succeeded`、`started -> failed`、`started -> cancelled` 生命周期写入；成功落库时 material / analysis / operation summary 处于同一事务。
- operation 使用单行摘要语义，同一 `operation_id` 只能有一行，状态更新不追加重复行。
- 迁移测试验证 v3 fixture 到当前 schema、空库迁移、重复 migrator、枚举 CHECK、current material 唯一约束和关键 active 查询。

Core package 测试：

- `LearningMaterialLengthEstimator` 对 CJK、拉丁词和混合文本返回稳定 bucket。
- `LearningMaterialGenerationState` 禁止同一 Entry 重复生成，并能表达 generated、editing stale、analyzing、failed、cancelled 和 blocked。
- `LearningMaterialGenerationFailureCategory` 覆盖 Provider 未配置、credential missing、网络、timeout、provider rejected、unsupported provider / model、content too long、invalid structured response、cancelled、persistence failed 和 unknown。
- `LearningMaterialInputKind`、`LearningMaterialPromptMode` 和 `LearningMaterialAnalysisStatus` 的 raw value 与 Prompt / 数据库契约一致。
- `EntrySource` 与 `LearningMaterialInputKind` 语义分层测试：`.typedText` 不被当作母语记录事实，`inputKind` 才决定目标写作、混合文本和不确定文本的渲染路径。

AI package 测试：

- 母语输入返回 `nativeRecord` 和目标语言学习文本。
- 目标语言输入返回 `targetWriting`、优化稿、修改说明和分析。
- 混合输入返回 `mixed`，并保留主要语义。
- 不确定输入返回 `uncertain` 或降级为 `nativeRecord`，但必须带判断说明。
- 结构化 JSON 缺字段时返回可诊断错误。
- 请求日志不包含原文、学习文本、响应全文或 API Key。
- Prompt rendering snapshot 测试固定 `builtin.learning_material.generate.v1` 和 `builtin.learning_material.analyze_current_text.v1` 的 prompt id、version、输入变量、JSON schema version 和隐私边界，避免代码 Prompt 与 `docs/prompts/` 漂移。

UI package 测试：

- 记录详情无学习材料时只有一个核心动作 `生成学习材料`。
- 详情页不包含编辑原始正文入口。
- 主按钮附近、生成中状态和结果元数据都明确表达 AI Provider 调用边界。
- 生成中禁用重复点击。
- 学习文本可编辑。
- 编辑学习文本后出现 `重新分析`。
- Provider 未配置时出现设置入口。
- 内容过长时不发起请求并显示说明。
- 离开详情页、切换 Entry 或切换语言空间后，旧 operation 结果不得覆盖当前 UI 状态。
- Settings 能力列表在 learning content repository 迁移到 GRDB 后不回退、不丢失 AI Provider / Sync / Privacy / Import Export 等入口。

### 11.9 状态机与并发边界

实现前必须先定义可测试的生成状态机，不能只在 View 里用多个布尔值拼接状态。

推荐状态：

```swift
public enum LearningMaterialGenerationState: Equatable, Sendable {
    case idle
    case generating(operationID: DiagnosticOperationID)
    case generated(materialID: String)
    case editing(materialID: String, analysisIsStale: Bool)
    case analyzing(materialID: String, operationID: DiagnosticOperationID)
    case failed(LearningMaterialGenerationFailureDisplay)
    case cancelled(materialID: String?)
    case blocked(LearningMaterialGenerationBlockReason)
}
```

并发规则：

- 同一 Entry 同一时间只允许一个生成或重新分析任务运行。
- 重复点击 `生成学习材料` 时，UI 必须禁用按钮；service / store 层也要通过 operation id 或 entry id 防重。
- use case 层必须维护 in-flight operation registry 或等价防重机制，不能只依赖 View 按钮禁用。防重 key 至少包含 `spaceID`、`entryID` 和 operation kind。
- 用户切换 Entry、切换语言空间、关闭 sheet 或离开详情页时，UI task 必须可取消。
- 取消后的结果不得落库为失败；如果 Provider 请求已返回但 operation id 已过期，不得覆盖当前 UI 状态。
- 用户离开详情页后的后台策略必须在实现中二选一并测试：
  - 取消策略：详情页 task 生命周期结束即取消 operation，已写入 `started` 的 operation 更新为 `cancelled`。
  - 继续策略：operation 继续在 use case 层完成并落库，返回详情页时从 repository 恢复生成结果。
  - 第一版推荐取消策略，减少后台任务和过期 UI 刷新复杂度。
- 切换语言空间期间的返回结果必须同时校验 `entryID` 和 `spaceID`，避免旧空间结果刷新到新空间 UI。
- `重新生成` 必须创建新的 LearningMaterial 版本或明确替换当前版本；不得在旧分析尚未清理时半更新。
- `重新分析` 只能更新当前学习文本对应的 analysis；如果用户在请求期间继续编辑文本，返回结果必须丢弃或标记过期，不能覆盖新文本。

### 11.10 错误边界和恢复策略

必须定义稳定错误分类，不让 UI 解析底层错误字符串。

最低错误分类：

```swift
public enum LearningMaterialGenerationFailureCategory: String, Equatable, Sendable {
    case providerNotConfigured
    case credentialMissing
    case networkUnavailable
    case timeout
    case providerRejected
    case unsupportedProvider
    case unsupportedModel
    case contentTooLong
    case invalidStructuredResponse
    case cancelled
    case persistenceFailed
    case unknown
}
```

恢复策略：

- Provider 未配置：展示进入 AI Provider 设置的入口。
- Credential missing：展示重新输入 API Key 的入口，不显示 Keychain account。
- Timeout / network：允许重试，不删除 Entry 和已有 LearningMaterial。
- Invalid structured response：允许重试，并记录非敏感诊断事件。
- Persistence failed：请求结果不得只停留在不可恢复内存状态；UI 应提示保存失败并允许重新生成。
- Cancelled：回到上一个稳定状态，不写失败日志和持久验证事件。

补充错误映射：

- default profile 不存在或已 soft delete：映射为 `providerNotConfigured`。
- 文本 endpoint 不存在、disabled 或 purpose 不是 `text_generation`：映射为 `providerNotConfigured` 或 `unsupportedProvider`，UI 文案应引导进入 AI Provider 设置检查文本模型。
- Keychain secret 缺失：映射为 `credentialMissing`。
- Keychain secret 存在但不可访问、权限失败或解码失败：映射为 `credentialMissing` 的可恢复 UI 文案，诊断属性可记录非敏感内部分类 `credentialInaccessible`。
- Anthropic / Gemini 第一版未实现真实学习材料请求体时：映射为 `unsupportedProvider` 或 `unsupportedModel`，不得伪装成网络失败。
- preflight 阻断如果 entryID 已知，应写入 operation 摘要；`prompt_id` / `prompt_version` 使用本次将使用的内置 Prompt id / version，Provider 相关字段允许为空。

### 11.11 持久化分期要求

本方案不能把“真实 AI 学习材料生成”完整落地在 `InMemoryLearningContentRepository` 上并宣称完成。当前 `AppDatabase` 只有 language space、AI Provider 配置和 diagnostic events，没有 Entry / Rendering / LearningMaterial schema；如果真实请求结果只存在内存中，重启后用户生成的学习材料会丢失，违反本地优先和主数据规则。

已确认采用完整路径：本任务同时新增 GRDB schema、repository 和迁移测试，持久化 Entry、LearningMaterial、Analysis、MemoryCandidate 和 PracticeCandidate。`InMemoryLearningContentRepository` 只能作为测试替身或开发期 mock，不作为真实学习闭环完成口径。

原因是本功能会处理真实用户原文和 AI 输出；这些都属于主数据或派生学习主数据，不适合只存在内存中。

最低 GRDB schema 设计问题必须在实现前写清：

- `entries` 表：`id`、`space_id`、`title`、`body`、`source`、`scene`、`created_at`、`deleted_at`。
- `learning_materials` 表：`id`、`entry_id`、`input_kind`、`learning_text`、`original_generated_text`、`prompt_id`、`provider_preset_id`、`model_name`、`is_current`、`created_at`、`updated_at`。
- `learning_material_analyses` 或等价子表：按句子、语法说明、词句候选和练习候选拆分；如果第一版用 JSON blob，必须记录后续拆表条件和导出影响。
- 外键删除语义：删除 Entry 时如何处理 material、analysis、memory candidate 和 practice candidate。
- 多版本语义：同一 Entry 可以有多个 LearningMaterial，但只能有一个 current material。
- 事务边界：生成结果落库时，LearningMaterial、analysis、candidate 必须在同一写事务内完成。

### 11.12 Provider 请求服务边界

不能直接复用 `AIProviderConfigurationProbeService` 作为学习材料生成服务。该服务当前定位是配置合成测试，Prompt、日志和 validation event 都服务于 endpoint 验证，不是用户内容生成。

必须新增学习材料专用服务：

```swift
public struct LearningMaterialGenerationService: Sendable {
    public func generate(_ input: LearningMaterialGenerationInput) async throws
        -> LearningMaterialGenerationResult

    public func analyze(_ input: LearningMaterialAnalysisInput) async throws
        -> LearningMaterialAnalysisResult
}
```

服务职责：

- 使用默认文本 generation endpoint。
- 接收编排层传入的已规范化 endpoint 输入和短生命周期 plaintext secret；不得自行读取 Provider repository、Keychain、`DatabaseQueue` 或 App 环境。
- 按 adapter 构造 OpenAI Responses / OpenAI-compatible Chat 请求体。
- 应先明确 Anthropic / Gemini 的第一阶段策略：支持则实现请求体；不支持则返回 `unsupportedModel` 或 `unsupportedProvider`，不得误报为网络失败。
- 解析严格结构化 JSON，并校验必填字段、数组长度、语言 code 和输入类型枚举。
- 记录非敏感诊断事件：operation id、provider preset id、model、duration、failure category、input kind、estimated length bucket。
- 不记录原文、学习文本、响应全文、词句候选正文、API Key、Authorization header 或完整请求体。

### 11.13 长度估算与输出规模

当前方案的 token 阈值方向合理，但实现前必须定义可测试估算器。第一版不得引入重型 tokenizer 依赖；推荐在 Core 中实现近似估算：

```text
CJK 字符：约 1 字 = 1 token
拉丁单词：约 1 词 = 1.3 tokens
其他字符：按 4 字符 = 1 token 的保守估算
最终取上界，并按 800 / 3000 分桶
```

中等文本输出降级必须转成 Prompt 和解析约束：

- 每条句子讲解最多 2 条要点。
- 词句候选最多 12 个。
- 练习候选最多 6 个。
- 单次返回句子数最多 20 句；超过时进入选段或后续分段任务，不允许无限制生成。

### 11.14 原始 Entry 不可编辑的代码级约束

当前 `LearningEntry.body` 是 `public var`，这不等于 repository 已有编辑能力，但会削弱“原始输入不可编辑”的模型表达。实现时必须至少满足以下之一：

1. 将 `LearningEntry.body`、`source`、`createdAt` 改为 `let`，只保留标题、标签、场景等未来可编辑元数据为可变字段；或
2. 新增明确的 `OriginalEntrySnapshot` / `EntryRecord` 模型承载不可变正文，UI 只读使用该模型；或
3. 如果暂不改公开属性，必须用测试证明 repository 没有正文更新接口，UI 没有正文编辑入口，所有编辑只发生在 LearningMaterial。

推荐采用第 1 种，符合当前早期开发阶段可重构原则，且能让模型表达产品决策。

### 11.15 完整 GRDB 存储设计

本任务新增迁移 `v4_create_learning_content_infrastructure`。如果实现时已经存在其他迁移，按实际序号顺延，但迁移名称和职责仍保持“学习内容主数据基础设施”这一边界，不混入 Prompt Registry、Provider 配置或同步 schema。

迁移恢复和验证口径：

- 生产迁移不提供破坏性回滚，不以“让用户清空容器”作为正常恢复路径。
- 实现时必须提供从 v3 fixture 迁移到 v4、空库直接迁移到 v4、重复执行 migrator 不重复建表的测试。
- 如果迁移失败，App 应保持原数据库文件不被业务写入半成品 schema；错误进入可诊断但非敏感日志。
- 开发期需要回滚时通过测试 fixture 或开发容器重建处理，不把回滚逻辑写入产品路径。
- 迁移测试必须验证新增表、关键 index、唯一约束、枚举 CHECK、外键行为和 UTC epoch seconds 字段。

#### 11.15.1 数据对象归类

- `entries`：主数据。保存用户主动创建的原始生活记录正文；正文保存后不可直接编辑。
- `learning_materials`：派生学习主数据。保存 AI 生成或用户编辑后的当前学习文本版本；可多版本。
- `learning_material_sentences`：派生分析数据。保存句子级拆分、对照、语法讲解和排序。
- `learning_material_revision_notes`：派生分析数据。保存目标语言写作优化时的修改说明。
- `memory_candidates`：候选主数据。保存从当前学习材料中提取的词、短语、表达和错误模式；用户确认前不是正式记忆。
- `practice_candidates`：候选主数据。保存跟读、听写、回译、造句等练习入口候选；用户开始练习前不是正式练习记录。
- `learning_material_operations`：非敏感请求元数据。保存生成 / 重新分析 operation 的阶段、Provider、模型、耗时、长度分桶、错误分类；不得保存原文、Prompt 全文、请求体、响应体或 API Key。

#### 11.15.2 表结构

`entries`：

```sql
CREATE TABLE entries (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  source TEXT NOT NULL,
  scene TEXT NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  deleted_at REAL,
  CHECK (length(trim(body)) > 0),
  CHECK (source IN ('typedText', 'photoWriting', 'targetLanguageWriting'))
);

CREATE INDEX idx_entries_space_created_at
ON entries(space_id, deleted_at, created_at DESC);
```

字段规则：

- `body` 是原始正文，不提供 update path；保存后的错字修正通过删除重建或未来“复制为新记录”任务处理。
- `title`、`scene` 后续可独立设计 metadata 编辑；本任务不开放正文编辑。
- `updated_at` 首版等于创建时间；未来 metadata 编辑时更新，不代表正文变化。
- `source` 第一版取值沿用 `EntrySource`：`typedText`、`photoWriting`、`targetLanguageWriting`。本任务真实入口只写入 `typedText`；`photoWriting` 仍属于未来附件任务。
- `source` 不得用于推断 `learning_materials.input_kind`。同一个 `typedText` Entry 可以生成 `nativeRecord`、`targetWriting`、`mixed` 或 `uncertain` 的 LearningMaterial。

`learning_materials`：

```sql
CREATE TABLE learning_materials (
  id TEXT PRIMARY KEY,
  entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
  space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
  input_kind TEXT NOT NULL,
  prompt_mode TEXT NOT NULL,
  learning_text TEXT NOT NULL,
  original_generated_text TEXT NOT NULL,
  analysis_source_hash TEXT NOT NULL,
  analysis_status TEXT NOT NULL,
  prompt_id TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  provider_profile_id TEXT,
  provider_endpoint_id TEXT,
  provider_preset_id TEXT NOT NULL,
  model_name TEXT NOT NULL,
  is_current INTEGER NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  deleted_at REAL,
  CHECK (length(trim(learning_text)) > 0),
  CHECK (input_kind IN ('nativeRecord', 'targetWriting', 'mixed', 'uncertain')),
  CHECK (prompt_mode IN ('automaticLearningMaterial', 'analyzeCurrentLearningText')),
  CHECK (analysis_status IN ('fresh', 'stale', 'missing', 'failed')),
  CHECK (is_current IN (0, 1))
);

CREATE INDEX idx_learning_materials_entry_created_at
ON learning_materials(entry_id, deleted_at, created_at DESC);

CREATE UNIQUE INDEX idx_learning_materials_current_per_entry
ON learning_materials(entry_id)
WHERE is_current = 1 AND deleted_at IS NULL;
```

字段规则：

- `learning_text` 是当前可编辑学习文本；用户编辑只改这里和 `analysis_status` / `analysis_source_hash`。
- `original_generated_text` 保留 AI 首次返回的学习文本快照，用于对比用户编辑，不随用户编辑变化。
- `analysis_source_hash` 使用本机计算的稳定哈希判断分析是否匹配当前 `learning_text`；不得进入诊断日志。
- `analysis_status` 取值：`fresh`、`stale`、`missing`、`failed`。
- `provider_profile_id` 和 `provider_endpoint_id` 保存为弱引用字符串；Provider 配置删除后历史材料仍可展示，不因外键 restrict 阻止用户清理配置。
- `provider_preset_id` 和 `model_name` 是非敏感元数据，允许展示给用户和进入导出。
- `space_id` 是为了查询性能和未来对象级同步保留的冗余字段；写入时必须验证它与 `entries.space_id` 一致。测试必须覆盖跨空间 material 写入被拒绝。

`learning_material_sentences`：

```sql
CREATE TABLE learning_material_sentences (
  id TEXT PRIMARY KEY,
  material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  native_sentence TEXT NOT NULL,
  target_sentence TEXT NOT NULL,
  literal_translation TEXT NOT NULL,
  natural_translation TEXT NOT NULL,
  grammar_notes_json TEXT NOT NULL,
  key_points_json TEXT NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  CHECK (position >= 0)
);

CREATE UNIQUE INDEX idx_learning_material_sentences_position
ON learning_material_sentences(material_id, position);
```

字段规则：

- `native_sentence` 是面向学习者的母语释义或对照，不是原始 Entry 正文的逐句回放。
- 句子表首版保留 `grammar_notes_json` 和 `key_points_json`，避免过早拆出过多小表。
- JSON 字段必须由 Data 层通过 `Codable` 结构编码，不能在 UI 中拼字符串。
- `grammar_notes_json` 和 `key_points_json` 顶层必须包含 `schemaVersion`，第一版固定为 `1`。Data 层必须有集中 encoder / decoder 和兼容解码测试。
- 后续如果需要跨 Entry 统计错误模式，再把 grammar notes 拆成规范表；首版以稳定展示和导出为主。

`learning_material_revision_notes`：

```sql
CREATE TABLE learning_material_revision_notes (
  id TEXT PRIMARY KEY,
  material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  original_text TEXT NOT NULL,
  revised_text TEXT NOT NULL,
  reason_native TEXT NOT NULL,
  category TEXT NOT NULL,
  created_at REAL NOT NULL,
  CHECK (position >= 0),
  CHECK (category IN ('grammar', 'wordChoice', 'naturalness', 'clarity', 'tone', 'structure'))
);

CREATE UNIQUE INDEX idx_learning_material_revision_notes_position
ON learning_material_revision_notes(material_id, position);
```

字段规则：

- 只在 `inputKind == targetWriting` 或混合文本中确有优化时写入。
- `category` 取值：`grammar`、`wordChoice`、`naturalness`、`clarity`、`tone`、`structure`。

`memory_candidates`：

```sql
CREATE TABLE memory_candidates (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
  entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
  material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
  sentence_id TEXT REFERENCES learning_material_sentences(id) ON DELETE SET NULL,
  kind TEXT NOT NULL,
  text TEXT NOT NULL,
  explanation_native TEXT NOT NULL,
  example_target TEXT NOT NULL,
  example_native TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  CHECK (kind IN ('word', 'phrase', 'sentencePattern', 'grammarPoint', 'errorPattern')),
  CHECK (difficulty IN ('easy', 'medium', 'hard')),
  CHECK (status IN ('candidate'))
);

CREATE INDEX idx_memory_candidates_space_status
ON memory_candidates(space_id, status, created_at DESC);
```

字段规则：

- `kind` 取值：`word`、`phrase`、`sentencePattern`、`grammarPoint`、`errorPattern`。
- `difficulty` 取值：`easy`、`medium`、`hard`。
- `status` 首版只写 `candidate`；用户确认进入正式 MemoryItem 另开任务。

`practice_candidates`：

```sql
CREATE TABLE practice_candidates (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES language_spaces(id) ON DELETE CASCADE,
  entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
  material_id TEXT NOT NULL REFERENCES learning_materials(id) ON DELETE CASCADE,
  sentence_id TEXT REFERENCES learning_material_sentences(id) ON DELETE SET NULL,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  prompt_text TEXT NOT NULL,
  answer_text TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at REAL NOT NULL,
  updated_at REAL NOT NULL,
  CHECK (kind IN ('listening', 'shadowing', 'dictation', 'backTranslation')),
  CHECK (status IN ('candidate'))
);

CREATE INDEX idx_practice_candidates_entry_kind
ON practice_candidates(entry_id, kind, created_at DESC);
```

字段规则：

- `kind` 取值沿用现有 `PracticeItem.Kind`：`listening`、`shadowing`、`dictation`、`backTranslation`。
- `status` 首版只写 `candidate`；真实练习记录和评分另开任务。

`learning_material_operations`：

```sql
CREATE TABLE learning_material_operations (
  id TEXT PRIMARY KEY,
  operation_id TEXT NOT NULL,
  entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
  material_id TEXT REFERENCES learning_materials(id) ON DELETE SET NULL,
  operation_kind TEXT NOT NULL,
  status TEXT NOT NULL,
  failure_category TEXT,
  prompt_id TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  provider_profile_id TEXT,
  provider_endpoint_id TEXT,
  provider_preset_id TEXT,
  model_name TEXT,
  input_kind TEXT,
  estimated_token_bucket TEXT NOT NULL,
  duration_ms INTEGER,
  created_at REAL NOT NULL,
  completed_at REAL,
  CHECK (operation_kind IN ('generate', 'analyze')),
  CHECK (status IN ('started', 'succeeded', 'failed', 'cancelled')),
  CHECK (failure_category IS NULL OR failure_category IN (
    'providerNotConfigured',
    'credentialMissing',
    'networkUnavailable',
    'timeout',
    'providerRejected',
    'unsupportedProvider',
    'unsupportedModel',
    'contentTooLong',
    'invalidStructuredResponse',
    'cancelled',
    'persistenceFailed',
    'unknown'
  )),
  CHECK (input_kind IS NULL OR input_kind IN ('nativeRecord', 'targetWriting', 'mixed', 'uncertain')),
  CHECK (estimated_token_bucket IN ('short', 'medium', 'tooLong'))
);

CREATE INDEX idx_learning_material_operations_entry_created_at
ON learning_material_operations(entry_id, created_at DESC);

CREATE UNIQUE INDEX idx_learning_material_operations_operation_id
ON learning_material_operations(operation_id);
```

字段规则：

- `operation_kind` 取值：`generate`、`analyze`。
- `status` 取值：`started`、`succeeded`、`failed`、`cancelled`。
- 该表采用单行 operation 摘要语义：`started` 先插入一行，后续成功、失败或取消更新同一 `operation_id` 行，不追加多行事件流。
- 取消不写成失败。
- `provider_preset_id` 允许为空，用于 Provider 未配置、内容过长等 preflight 阻断摘要；一旦请求进入真实 Provider 调用或生成成功，必须写入 Provider / model 元数据。
- 该表与 `diagnostic_events` 职责不同：它是用户可回溯的生成元数据摘要；`diagnostic_events` 是开发诊断流。两者都不能记录敏感正文。

#### 11.15.3 删除和版本规则

- 删除 Entry：soft delete `entries.deleted_at`。首版 UI 删除时同时将相关 `learning_materials.deleted_at` 标记为同一时间；候选表保留行但不在 active 查询中展示。未来导出 / 恢复和同步任务可再设计 tombstone。
- 删除 LearningMaterial：soft delete `learning_materials.deleted_at`，级联子表仍由外键在 hard delete 时清理。首版 UI 不提供单独删除历史版本入口。
- 重新生成：在同一事务内把旧 current material 的 `is_current` 置为 0，插入新 material 并置为 1，再插入 sentence、revision、memory candidate 和 practice candidate。
- 重新分析：不创建新 material；在同一事务内删除当前 material 的旧 sentence、memory candidate、practice candidate、revision note，插入新分析结果，更新 `analysis_status = fresh` 和 `analysis_source_hash`。
- 用户编辑 learning text：只更新 `learning_materials.learning_text`、`updated_at`、`analysis_status = stale` 和新的 `analysis_source_hash`；不修改 `entries.body`、`original_generated_text` 或旧 operation 记录。

analysis 部分失败规则：

- 首次生成请求必须把学习文本和 analysis 视为同一结构化结果；任一必填 analysis 字段缺失、枚举非法或数组超限时，整次 generation 失败，不落 `learning_materials` 半成品。
- `重新分析` 失败时不得删除旧 sentences / candidates，也不得覆盖 `learning_text`；只更新 operation 为 failed，并将 material 保持 `stale`。如果旧 analysis 原本是 fresh，UI 仍应提示“当前编辑后的分析未更新”，而不是展示失败结果为最新分析。
- 如果持久化过程中 material 写入成功但 analysis / candidates 写入失败，必须由同一事务回滚，不能出现 material 成功但 analysis 缺失的半成功状态。
- `analysis_status = missing` 仅用于未来导入、恢复或显式无分析对象的兼容状态；本任务第一版不把 AI 结构化解析失败保存为 missing。

候选 active 查询规则必须显式实现，不能只依赖候选表自身字段：

- `memory_candidates` 和 `practice_candidates` 首版不含 `deleted_at` 字段；所有 active 查询必须 join `entries` 和 `learning_materials`，并过滤 `entries.deleted_at IS NULL`、`learning_materials.deleted_at IS NULL`、`learning_materials.is_current = 1`。
- 如果实现时不希望每次 join，应给候选表增加 `deleted_at` 并在删除 Entry / LearningMaterial 的同一事务内同步 soft delete；不得出现 Entry 已删除但候选仍在首页或练习入口展示的状态。
- 测试必须覆盖删除 Entry 后 `memoryItems(for:)`、`practiceItems(for:)`、`practiceSession(for:)` 不再返回该 Entry 的候选内容。

外键要求：

- `AppDatabase` 必须确认 GRDB 连接启用 foreign key enforcement，迁移测试应显式验证违反 `entries.space_id`、`learning_materials.entry_id`、candidate `material_id` 的写入失败。
- 如果 GRDB 默认行为或测试 database 配置无法保证外键开启，必须在 `AppDatabase` 初始化时显式配置，并记录在 `docs/spec/007-data-storage-migration-export-and-attachments.md`。

#### 11.15.4 导出、备份和未来同步边界

本任务不实现导出、备份和同步 UI，但新增 schema 已经进入真实主数据路径，必须在数据设计中保留长期边界：

- 用户可读导出未来可以包含 `entries.body`、`learning_materials.learning_text`、句子分析、修改说明、memory candidates 和 practice candidates。
- 可恢复备份未来可以包含表结构所需的稳定 ID、空间归属、版本状态、soft delete 状态、非敏感 Provider / model / Prompt 版本元数据和 operation 摘要。
- 普通导出和备份都不得包含 API Key、Authorization header、完整请求体、完整响应体、完整 system / user prompt、Keychain account、Base URL 中的敏感 query 或诊断日志中的敏感字段。
- `grammar_notes_json`、`key_points_json` 等 JSON blob 必须由 Data 层 Codable record 统一编码，并带有可测试的 schema version 或等价解码兼容策略；不得让 UI 写入任意 JSON 字符串。
- 未来同步不能把 SQLite 文件整体作为唯一同步对象；本任务新增表必须保留对象级 ID、更新时间、soft delete 和来源引用，为后续 Sync Engine 做对象级冲突解决留出边界。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 必须在实现后同步记录上述 Entry / LearningMaterial / candidate / operation 的导出和删除边界。

#### 11.15.5 Repository 接口方向

Data package 新增 `GRDBLearningContentRepository`，替换真实 App Shell 中的内存 repository。不能只新增一个孤立的 material repository，否则当前 `LearningContentStore` 仍会依赖同步 `LearningContentRepository` 的 entry selection、memory、practice 和 settings 查询，真实数据与 UI 状态会分裂。

推荐演进路径：

1. 将现有 `LearningContentRepository` 演进为 async 友好的真实内容 facade，或新增 `LearningContentRepositoryV2` 并让 `LearningContentStore` 一次性迁移到 async 边界。
2. `GRDBLearningContentRepository` 同时负责 Entry 列表、Entry 选择、current material、学习文本编辑、analysis 替换、memory candidate、practice candidate 和 settings capability 查询。
3. `InMemoryLearningContentRepository` 仅作为测试替身和 seed preview，不作为 App Shell 真实装配；实现完成后 `LangoTraceApp/AppEnvironment.swift` 必须使用 `GRDBLearningContentRepository(database: databaseFactory.database())` 或等价 factory。
4. 如果为了降低一次性改动量保留旧协议，必须在方案实施记录中明确 bridge 期限，并用测试证明旧内存 repository 不参与真实生成结果保存。

协议保持 UI 友好，但真实写入必须是事务级方法：

```swift
public protocol LearningMaterialRepository: AnyObject, Sendable {
    func createEntry(_ draft: NewLearningEntryDraft, in spaceID: String) async throws -> LearningEntry
    func entries(for spaceID: String) async throws -> [LearningEntry]
    func currentMaterial(for entryID: String) async throws -> LearningMaterial?
    func saveGeneratedMaterial(_ result: LearningMaterialGenerationResult, for entryID: String) async throws -> LearningMaterial
    func updateLearningText(materialID: String, learningText: String) async throws -> LearningMaterial
    func replaceAnalysis(_ result: LearningMaterialAnalysisResult, materialID: String) async throws -> LearningMaterial
    func recordOperation(_ summary: LearningMaterialOperationSummary) async throws
}
```

实现要求：

- `saveGeneratedMaterial`、`replaceAnalysis` 和成功 operation 摘要写入必须在同一 `DatabaseQueue.write` 边界内完成，避免 UI 成功但数据半落库。
- operation 生命周期必须拆分：网络请求前用单独事务写入 `started`；请求取消、网络失败或结构化解析失败后用单独事务写入 `cancelled` / `failed`；请求成功后的 material / analysis / operation `succeeded` 必须同事务写入。
- 不得要求 `started`、网络请求和 `succeeded` 全部处于同一个数据库事务；长时间持有 `DatabaseQueue.write` 等待网络会阻塞本地读写并破坏 UI 响应。
- `createEntry` 必须校验 `language_spaces.id` 存在且未删除。
- 所有 active 查询都必须过滤 `deleted_at IS NULL`。
- 所有时间使用可注入 clock，保存为 UTC epoch seconds，沿用现有语言空间基础设施风格。
- 迁移测试必须验证 current material 唯一约束、Entry 删除后的 active 查询、重新分析不修改 Entry 正文、用户编辑后 analysis stale。

#### 11.15.6 `LearningContentStore` async 迁移

当前 `LearningContentStore` 依赖同步 `LearningContentRepository`，迁移到真实 GRDB repository 时必须同步调整 Store，而不是只给生成按钮增加 async 调用。

第一版推荐 Store 状态：

```swift
@MainActor
final class LearningContentStore: ObservableObject {
    @Published private(set) var entries: [LearningEntry] = []
    @Published private(set) var selectedEntry: LearningEntry?
    @Published private(set) var memoryItems: [MemoryItem] = []
    @Published private(set) var settingsCapabilities: [SettingsCapability] = []
    @Published private(set) var loadingState: LearningContentLoadingState = .idle
    @Published private(set) var generationStates: [String: LearningMaterialGenerationState] = [:]
}
```

最低迁移要求：

1. `ensureSeeded` 不再作为真实主路径 seed mock 的入口。真实 App Shell 启动后通过 async `load(spaceID:)` 从 GRDB 读取 Entry / current material / memory / practice summary。
2. `createEntry` 改为 async throwing 或通过 action 返回可恢复错误；UI 保存按钮需要 loading / failure 状态，不能假设写入永远同步成功。
3. `rendering(for:)` 应演进为 `currentMaterial(for:)` 或兼容 presentation model；如果保留 `LearningRendering` 作为 UI 展示模型，必须由 Data 层或 Store 层从 `LearningMaterial` 投影，不得继续代表 mock-only 事实。
4. 生成 / 重新分析完成后，Store 至少局部刷新当前 Entry 的 current material、practice candidates、memory candidates；小数据阶段允许全量刷新，但必须在方案实施记录中说明并保留后续优化点。
5. Store 错误状态必须区分加载失败、创建 Entry 失败、生成失败、重新分析失败和刷新失败，UI 不得吞掉持久化错误。
6. 本轮只接入 iOS / iPhone UI；但 Store 状态、presentation model 和 action 边界不得写成 iOS 专属，后续 iPad / macOS 接入时应能复用同一个 material 和 generation state。
7. 测试必须覆盖 App Shell 不再装配 `InMemoryLearningContentRepository` 作为真实 learning content repository。

过渡兼容：

- 如果为降低一次性改动保留旧同步协议，必须新增 adapter / bridge，明确 bridge 只服务旧 UI 读取，不保存真实生成结果。
- bridge 期限必须写入实施记录；完成标准仍要求真实生成结果由 GRDB repository 持久化并在重启后可恢复。

#### 11.15.7 Settings capability 解耦

当前 `settingsCapabilities(for:)` 挂在 `LearningContentRepository` 上，但 AI Provider、Sync、Privacy、Import Export 等能力不是 learning content 主数据职责。本任务迁移 repository 时必须同时处理该隐藏耦合。

推荐方案：

```swift
public protocol SettingsCapabilityProviding: Sendable {
    func settingsCapabilities(for spaceID: String) -> [SettingsCapability]
}
```

实现方向：

- 将静态能力列表移动到 UI package 的 presentation provider 或 Data package 的独立 provider，具体落点以现有 package 依赖最小化为准。
- `LearningContentStore` 可以组合 `LearningContentRepository` 和 `SettingsCapabilityProviding`，但 `GRDBLearningContentRepository` 不应长期负责返回 Sync / Privacy / Import Export 这类非内容能力。
- 如果本任务不拆分协议，必须在 `GRDBLearningContentRepository.settingsCapabilities(for:)` 标注为过渡兼容，并新增测试防止 SettingsView 能力列表丢失。
- 三端 Settings detail 仍必须复用现有 `SettingsCapabilityDetailView` 入口；不得为 iPad / macOS 复制平台专属 AI Provider 设置表单。

完成标准增加：

- 实现后搜索 `settingsCapabilities(for:)`，确认它不再迫使 learning content repository 承担长期 settings source 职责，或实施记录中明确过渡期限和后续拆分任务。

### 11.16 Prompt 与结构化 JSON 契约

本任务新增 Prompt Registry 文档：

```text
docs/prompts/learning-material/one-tap-learning-material.md
```

该文档保存两个内置 Prompt 的完整英文版本、中文版本、输入变量、隐私边界和 JSON schema：

- `builtin.learning_material.generate.v1`：用于首次 `生成学习材料` 和 `重新生成`。
- `builtin.learning_material.analyze_current_text.v1`：用于用户编辑学习文本后的 `重新分析`。

实现要求：

- 代码中的英文 Prompt 必须与 Prompt Registry 文档一致；如果代码用模板拼接，文档必须能完整还原最终 system / user prompt。
- Prompt 必须要求 Provider 只返回 JSON object，不使用 Markdown code fence、自然语言前后缀或半结构化文本。解析层可以为兼容 OpenAI-compatible Provider 的实际行为剥离包裹整个 JSON object 的常见 Markdown code fence；剥离后仍必须按同一 JSON schema 做字段级校验。自然语言前后缀、缺字段、非法枚举、额外不允许字段或数组超限仍映射为 `invalidStructuredResponse`，不得落半成品。
- 响应解析后必须做字段级校验：枚举值、数组数量、字符串空值、语言 code、句子数量和候选数量；`analysis_source_hash` 由 App 对当前 `learning_text` 本机计算，模型不返回 hash。
- 生成请求的 JSON 顶层必须包含 `schema_version = "learning_material.v1"`。
- `input_kind` 必须是 `nativeRecord`、`targetWriting`、`mixed` 或 `uncertain`。
- `learning_text` 必须是目标学习语言文本；如果原输入已经是目标语言，则必须是优化后的目标语言文本。
- `analysis` 必须基于 `learning_text`，不能基于原始 Entry。
- 中等长度文本必须执行输出规模限制：最多 20 句、12 个 memory candidates、6 个 practice candidates。
- Prompt 不得要求模型返回用户 API Key、Provider 信息、系统内部 ID、完整 Prompt 文本或日志字段。

Prompt 一致性验证：

- AI package 必须新增 Prompt rendering snapshot 测试，固定两个内置 Prompt 的 prompt id、version、输入变量、system / user prompt 主要结构和 JSON schema version。
- `docs/prompts/learning-material/one-tap-learning-material.md` 必须能完整还原最终发送给 Provider 的 system / user prompt。若代码使用模板拼接，文档必须列出模板、变量和渲染示例。
- 测试不得把用户真实生活记录写入 snapshot fixture；只允许 synthetic sample。
- Prompt snapshot 变化必须同时更新 Prompt Registry 文档和本方案实施记录。

`analysis_source_hash` 规则：

- 第一版使用固定算法：`SHA256(UTF8(normalizedLearningText))`。
- `normalizedLearningText` 第一版只做换行规范化：将 CRLF 和 CR 统一为 LF；不 trim、不折叠空白、不大小写转换。
- hash 只写入 `learning_materials.analysis_source_hash`，不得进入 diagnostic event、operation 摘要、普通 UI 文案或错误对象。
- 测试必须覆盖同一文本 hash 稳定、换行规范化稳定、文本编辑后 hash 变化，以及重新分析成功后 hash 与当前 `learning_text` 匹配。

JSON blob schema version：

- `grammar_notes_json` 和 `key_points_json` 由 Data package 内部 Codable record 编码。
- 顶层字段必须包含 `schemaVersion: 1`。
- 解码失败应映射为 Data repository 可诊断错误，不得让 UI 直接处理任意 JSON 字符串。

### 11.17 JSON 字段到数据库字段的映射

生成请求映射：

```text
response.input_kind                      -> learning_materials.input_kind
response.learning_text                   -> learning_materials.learning_text
response.learning_text                   -> learning_materials.original_generated_text
response.revision_notes[]                -> learning_material_revision_notes
response.analysis.sentences[]            -> learning_material_sentences
response.analysis.memory_candidates[]    -> memory_candidates
response.analysis.practice_candidates[]  -> practice_candidates
request prompt/provider/model metadata   -> learning_materials prompt/provider/model fields
operation summary                        -> learning_material_operations
```

分析请求映射：

```text
response.analysis.sentences[]            -> replace learning_material_sentences
response.analysis.memory_candidates[]    -> replace memory_candidates for material
response.analysis.practice_candidates[]  -> replace practice_candidates for material
computed hash of current learning_text   -> learning_materials.analysis_source_hash
analysis success                         -> learning_materials.analysis_status = fresh
operation summary                        -> learning_material_operations
```

不落库字段：

- 模型返回的 `routing_reason` 不单独落主表，首版可进入用户可见生成摘要或 operation 非敏感摘要；不得进入诊断日志正文。
- 原始 request body、response body、system prompt、user prompt、Authorization header、API Key、完整用户原文日志都不落库。
- `confidence` 只用于 UI 提示和非敏感元数据；首版不作为排序、自动纠错或阻断条件。

### 11.18 迁移 fixture 与实施就绪 gate

Data package 必须新增 v3 -> v4 迁移 fixture 或等价 SQL builder，不能只测空库迁移。

推荐 fixture 路径：

```text
Packages/LangoTraceData/Tests/LangoTraceDataTests/Fixtures/v3-language-space-ai-provider.sqlite
```

如果不提交二进制 sqlite fixture，则必须提供测试 helper，用 SQL 构造 v3 schema 和代表性数据：

- 至少 1 个 active language space。
- 至少 1 个 deleted language space。
- 至少 1 个 default AI Provider profile。
- 至少 1 个 text generation endpoint。
- 至少 1 条 diagnostic event。

迁移测试必须覆盖：

- v3 fixture 迁移到当前 schema。
- 空库直接迁移到当前 schema。
- 重复 migrator 不重复建表或破坏数据。
- 新增表、关键 index、唯一 current material、枚举 CHECK、foreign key 行为和 UTC epoch seconds 字段。
- v3 既有 language space / AI Provider / diagnostic 数据迁移后仍可读取。

实施就绪 gate：

本方案只有在以下内容已经写入第 11 节后，才可以从 Draft 转为可请求用户确认的 implementation-ready 状态：

1. 应用编排层和 operation 生命周期。
2. `LearningContentStore` async 迁移和三端刷新策略。
3. Settings capability 解耦或过渡兼容方案。
4. `EntrySource` 与 `LearningMaterialInputKind` 语义分层。
5. Prompt 一致性测试、hash 算法、JSON blob schema version、v3 fixture 迁移测试。

上述 gate 已在本节补齐；当前仍需用户确认后才能进入实现。

## 12. 复查方法

代码复查：

- 搜索 `EntryEditorView`、`EntryDetailView`、`LearningEntry`、`LearningRendering`、`LearningMaterial`，确认原始 Entry 正文没有更新路径。
- 搜索 `生成学习材料` 和对应 localization key，确认记录详情页只有一个主 AI 动作。
- 搜索 AI 请求入口，确认 SwiftUI View 不直接拼 URLRequest、不直接读 Keychain、不直接调用 Provider SDK。
- 检查 Prompt 输入只使用稳定语言 code，不使用展示名或本地化文案反推目标语言。

交互复查：

- 保存一条母语记录，进入详情，点击 `生成学习材料`，确认无阻断确认并进入处理状态。
- 保存一条目标语言文本，确认结果包含优化稿、修改说明和学习分析。
- 编辑学习文本，确认原始记录未变化，分析提示需要更新。
- 点击 `重新分析`，确认只更新分析内容。
- 输入超长文本，确认请求发出前被阻断。

文档复查：

- 检查产品主参考、AI 隐私规范、数据存储规范、learning-content 实现地图、页面清单和 Prompt Registry 是否同步更新。
- 检查是否有“两个按钮”“改写优化主按钮”“可编辑原始正文”等过期描述。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceUI
```

完整验证：

```bash
scripts/verify.sh
```

文档检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 14. 文档影响检查

本任务影响产品主流程、AI 请求边界、Prompt Preset、Entry / Rendering 数据语义和三端页面清单。实现时必须同步检查：

- `docs/product-main-reference.md`：补充一键生成、可编辑学习文本、原始 Entry 只读。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：补充当前文本 Entry 的显式按钮触发语义、结构化输出、非阻断确认边界和日志限制。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：补充 Entry / LearningMaterial / candidate / operation 的 GRDB 主数据边界、迁移恢复策略、soft delete active 查询、导出/备份敏感字段排除和未来同步对象级边界。
- `docs/spec/learning-content/impl.md`：把当前实现地图从内存 mock 更新为本任务落地后的 GRDB repository、真实 AI generation service、Prompt Registry、测试入口和仍未完成能力。
- `docs/platform-page-inventory.md`：更新记录详情能力状态，从 Local Mock 过渡到真实 AI 学习材料生成或阶段性实现状态。
- `docs/prompts/`：登记学习材料生成 Prompt 的输入变量、输出契约、隐私边界和版本。
- `docs/spec/002-navigation-and-routing.md`：确认记录详情仍是主流程，不新增独立改写入口。
- `docs/spec/003-ui-design-system.md`：确认主动作、状态表达和可编辑学习文本的 UI 规则。
- `docs/review/`：如果实现改动触及数据、AI Provider、Prompt、包边界或 App Shell 装配，应按文档审查机制记录专项审查或在实施记录中说明跳过原因。

## 15. 实施记录

- 2026-05-23：进入实现阶段。第 0 阶段先将用户审核通过、iOS 优先范围和每阶段检查 / 测试 / commit 要求写入方案，随后按 Core -> Data -> AI -> App Shell -> iOS UI -> Docs / Review 的 TDD 顺序推进。
- 2026-05-23：阶段 1 Core 契约落地。先新增 `LearningMaterialGenerationTests` 并确认 `swift test --package-path Packages/LangoTraceCore` 因缺少 `LearningMaterialInputKind`、`LearningMaterialPromptMode`、`LearningMaterialAnalysisStatus`、`LearningMaterialGenerationFailureCategory`、`LearningMaterialLengthEstimator`、`LearningMaterialGenerationState` 和 Core 层 `EntrySource` 失败；随后新增 Core 学习材料生成模型、长度估算器和状态机，并将 `EntrySource` 从 Data 上移到 Core。验证：`swift test --package-path Packages/LangoTraceCore` 通过，`swift test --package-path Packages/LangoTraceData` 通过。
- 2026-05-23：阶段 2 Data 持久化基础落地。先新增 `GRDBLearningContentRepositoryTests` 并确认 `swift test --package-path Packages/LangoTraceData` 因缺少 `GRDBLearningContentRepository`、`NewLearningEntryDraft`、`LearningMaterialGenerationResult`、`LearningMaterialAnalysis`、operation summary 和 v3 SQL helper 失败；随后新增 v4 `entries` / `learning_materials` / sentences / revision notes / memory candidates / practice candidates / operation summary schema，显式启用 foreign key，新增 GRDB learning content repository，并补充共享 DTO。验证：`swift test --package-path Packages/LangoTraceData`、`swift test --package-path Packages/LangoTraceCore`、`swift test --package-path Packages/LangoTraceUI` 均通过。
- 2026-05-23：阶段 3 AI 生成服务基础落地。先新增 `LearningMaterialGenerationServiceTests` 并确认 `swift test --package-path Packages/LangoTraceAI` 因缺少 `LearningMaterialPromptRegistry`、`LearningMaterialGenerationService`、service request / error 和 Core generation / analysis input DTO 失败；随后新增 Prompt Registry、OpenAI-compatible Chat / Responses 请求构造、结构化 JSON 解析、unsupported adapter 映射和 target writing revision 解析。验证：`swift test --package-path Packages/LangoTraceAI`、`swift test --package-path Packages/LangoTraceCore`、`swift test --package-path Packages/LangoTraceData` 均通过。Prompt Registry 文档已存在，代码 prompt 与文档完整提示词的一致性将在 Docs / Review 阶段统一收口。
- 2026-05-23：阶段 4 App Shell 与 iPhone 生成入口落地。先新增 UI store / iPhone convergence 测试并确认缺少 generation actions、async 状态、唯一主动作、AI 披露、Provider 未配置和长文本阻断路径时失败；随后新增 `LearningMaterialGenerationActions`，将 `LearningContentStore` 接入 async generation state，`PhoneMainView` 只在 iPhone 详情传入生成 action，`AppEnvironment` 通过 GRDB repository、默认文本 Provider、Keychain secret 和 `LearningMaterialGenerationService` 编排真实生成并落库。iPad / macOS 不接入真实生成 UI。验证：Core、Data、AI、UI 聚焦测试、iPhone 17 build、`git diff --check` 和 docs placeholder scan 通过。
- 2026-05-23：阶段 5 可编辑 learning text 与重新分析落地。先新增 AI analyze service、Data material lookup、UI store stale / analyze 和 iPhone source tests；随后实现 `LearningMaterialGenerationService.analyze`、`GRDBLearningContentRepository.material(id:)`、`LearningContentStore.updateLearningText` / `analyzeCurrentLearningText`、iPhone detail learning text editor、`重新分析` 入口和 App Shell analyze 编排。重新分析失败会写 operation failed 摘要；material 缺失时不创建错误 operation。验证：AI、Data、UI、Core 聚焦测试、iPhone 17 build、`git diff --check` 和 docs placeholder scan 通过。
- 2026-05-23：阶段 6 文档同步开始。已更新 product 主参考、AI Provider / Prompt 隐私规范、数据存储规范、learning-content 实现地图、页面清单和 Prompt Registry 实现状态；明确本轮 UI 只完成 iOS / iPhone，iPad / macOS 待 iOS 人工测试通过后再推进。后续仍需运行完整 `scripts/verify.sh`、记录 iOS 人工测试结果，并根据最终代码快照完成文档审查记录。
- 2026-05-23：阶段 7 格式 / lint 收口和完整自动验证。已按 SwiftFormat / SwiftLint 要求拆分长行、补充局部 lint 说明并提交格式收口。验证：`scripts/verify.sh` 通过，覆盖 XcodeGen、Core / Data / AI / UI package tests、iPhone 17 / iPad Pro 13-inch / macOS build、SwiftLint、SwiftFormat lint、docs placeholder scan 和 `git status --short`；SwiftLint 仍有 85 条 warning-level 既有风格告警，退出码为 0。剩余收口项：iOS 端人工测试记录和最终 review 状态更新。
- 2026-05-23：阶段 8 iOS 人工测试和 AI JSON Schema 收口。iPhone 17 模拟器中完成 `写一句 -> 保存 -> 记录详情 -> 生成学习材料 -> 编辑 learning text -> 保存修改 -> 重新分析` smoke；真实 OpenRouter `openai/gpt-4o` 首次暴露模型输出结构不稳定问题，随后将 OpenAI-compatible Chat 请求升级为 strict JSON Schema 并保留 fenced JSON 容错。复测结果：`generate|succeeded|openai/gpt-4o`、`analyze|succeeded|openai/gpt-4o`，`learning_materials.analysis_status = fresh`，practice candidates 写入 3 条。最终验证：`scripts/verify.sh` 通过，SwiftLint 保留 86 条 warning-level 既有风格告警，退出码为 0；SwiftFormat lint 通过。本任务已完成 iOS / iPhone 范围，iPad / macOS UI 接入仍按用户确认延后到后续任务。
- 2026-05-23：iOS 实现后复核发现当前实现不能直接归档为完成。已确认落地项：Core DTO / 状态机 / 长度估算、GRDB v4 learning content schema、`GRDBLearningContentRepository`、`LearningMaterialGenerationService`、`LearningMaterialGenerationActions`、iPhone 详情主动作、learning text 编辑 / 重新分析、Prompt Registry 和长期文档同步。需要修复或明确收口的偏差：`LearningMaterialGenerationActions` 当前没有 `cancelOperation`，iPhone 生成中状态也没有取消入口；成功路径中 `saveGeneratedMaterial` 与 `succeeded` operation 摘要是两个写事务，不满足“material / analysis / operation summary 同事务”要求；`contentEmpty` / `contentTooLong` 等 Store 层 preflight 阻断不会写 operation 摘要；`GRDBLearningContentRepositoryBridge.createEntry` 在持久化失败时会返回 `unsaved-*` 内存 Entry，仍可能让 UI 误以为保存成功；App Shell 在 GRDB repository 创建失败时 fallback 到 `InMemoryLearningContentRepository(seedEntries: [])`，这与真实主路径不得回退到内存 repository 的完成口径冲突。另有合理实现偏差：真实 OpenRouter 测试后保留 fenced JSON 容错，文档已从“拒绝 code fence”调整为“Prompt 禁止，但解析层可剥离顶层 code fence 后继续严格 schema 校验”。
- 2026-05-23：架构取舍复核后按“方案为主，吸收合理容错”完成收口：`LearningMaterialGenerationActions` 增加 `recordBlockedOperation` 与带 entry/material/kind/bucket 上下文的 `cancelOperation`；`LearningContentStore` 支持取消运行中 operation 并丢弃 late result；iPhone 生成中状态复用主动作提供取消入口；`GRDBLearningContentRepository` 增加 `saveGeneratedMaterial(... operationSummary:)` 与 `replaceAnalysis(... operationSummary:)`，保证成功 material / analysis / operation summary 同事务；Store 层 `contentEmpty` / `contentTooLong` / `operationInProgress` preflight 阻断会写本地 failed operation summary；`GRDBLearningContentRepositoryBridge.createEntry` 不再返回 `unsaved-*`，持久化失败向上抛出；App Shell 创建 GRDB bridge 失败时使用显式 unavailable repository，不再 fallback 到内存 repository。fenced JSON 容错继续保留。

## 16. 完成标准

任务可以从 `active/` 移入 `done/` 的条件：

- 用户已确认本方案进入实现。
- 记录详情页只有一个核心 AI 动作 `生成学习材料`。
- 本轮仅要求 iOS / iPhone 端记录详情页完成该入口和状态闭环；iPad / macOS 端保持不接入真实学习材料生成 UI，待 iOS 端人工测试通过后另行推进。
- 原始 Entry 正文保存后不可直接编辑。
- 学习材料生成通过 `LearningMaterialGenerationActions` 或等价 use case 编排，SwiftUI View 不直接访问 AI service、Keychain、`DatabaseQueue` 或 Provider SDK。
- `LearningContentStore` 已迁移到 async GRDB facade 或有明确过渡 bridge，真实生成结果不进入内存 repository。
- Settings capability 已从 learning content repository 长期职责中拆出，或实施记录明确过渡兼容期限和后续拆分任务。
- `EntrySource` 与 `LearningMaterialInputKind` 语义已分层，`.typedText` 不被当作母语记录事实。
- AI 生成请求一次返回学习文本和学习分析。
- 目标语言写作结果包含优化稿和修改说明。
- 学习文本可编辑，编辑后可重新分析。
- 重新分析不修改 Entry 正文，也不重新生成学习文本。
- 长文本在 App 层阻断或进入选段流程，不直接全量请求。
- Core、Data、AI、UI 聚焦测试通过。
- Prompt rendering snapshot、`analysis_source_hash`、JSON blob schema version 和 v3 -> v4 迁移 fixture / SQL builder 测试通过。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。
- iOS 端人工测试通过并记录结果；iPad / macOS 未接入状态必须在实施记录和页面清单中标明为后续任务，不得误标为三端完成。
- 相关长期文档已经同步更新。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 和 `docs/spec/learning-content/impl.md` 已按真实落地状态更新，且没有继续把 learning content 描述为纯内存 mock。

## 17. 剩余风险

- AI 自动判断母语记录和目标语言写作可能误判，尤其是短文本、混合语言和初学者错误文本。第一版通过结构化 `inputKind`、判断说明和可编辑学习文本降低风险。
- 一次请求同时生成文本和分析，响应可能较慢。第一版通过长度阈值和中等文本输出降级控制体验。
- 不设置阻断式确认会提高主流程效率，但也要求按钮、加载状态和 Provider 设置清楚表达 AI 调用。涉及照片、音频、历史记忆或多条记录上下文时，不能复用本任务的非确认边界。
- 原始 Entry 不可编辑可能让误保存用户感到受限。第一版保留保存前编辑、删除重建和未来复制为新记录的扩展空间。
- 当前真实 Entry / Rendering 持久化 schema 尚未完成，因此本任务必须先落地完整 GRDB learning content infrastructure，不能以 `InMemoryLearningContentRepository` 原型作为完成口径；如需分期 prototype，必须另开任务并改变完成标准。

## 18. 严格方案审核记录

审核日期：2026-05-22

审核视角：系统架构、产品愿景、并发/性能、异常边界、状态同步、数据一致性。

审核结论：Needs Changes。产品方向和关键交互决策成立，但原方案在模块边界、持久化分期、请求状态机和错误恢复上不够可执行。已在第 11 节补充硬性修订要求；未纳入这些修订前，不应进入实现。

### 18.1 代码现状准确性检查

准确项：

- 方案对 iPhone `写一句` 当前路径的描述准确：`PhoneMainView` 中 `.entryEditor` sheet 使用 `EntryEditorView`，保存后调用 `contentStore.createEntry(...)` 并导航到 `.entryDetail(entry.id)`。
- 方案对 `EntryDetailView` 当前结构的描述准确：详情页展示原始记录、目标语言文本、逐句内容、本地预览入口和练习条目。
- 方案对当前 Data mock 状态的描述准确：`LearningContentRepository` 只有 `createEntry`、`generateLocalPreview`、`rendering`、`practiceItems`、`memoryItems` 等内存闭环接口，没有真实 Entry / Rendering GRDB repository。
- 方案对 AI Provider 阶段的描述基本准确：当前 AI package 已有配置合成测试、HTTP client、Keychain-backed service 装配，但尚无真实学习内容生成服务。

不完整项：

- 原方案未明确 `LangoTraceAI`、`LangoTraceData`、`LangoTraceUI` 当前 package 依赖方向。当前 `LangoTraceAI` 只依赖 Core；UI 不依赖 AI。若按原方案把共享生成模型放进 AI package，会导致 Data / UI 无法引用，或诱发错误依赖。
- 原方案未点出 `LearningEntry.body` 当前是 `public var`。这和“原始输入不可编辑”的产品决策不是直接冲突，因为 repository 没有 update 接口，但模型表达不够强。
- 原方案未明确 `AppDatabase` 目前没有 Entry / LearningMaterial schema。真实 AI 结果如果只落内存，不能满足本地优先主数据要求。

### 18.2 关键问题

- P0：共享模型归属不清，可能造成包依赖倒置。
  - 证据：`LangoTraceAI/Package.swift` 只依赖 `LangoTraceCore`；`LangoTraceUI/Package.swift` 依赖 Core 和 Data，不依赖 AI。
  - 影响：如果 `LearningMaterialGenerationModels` 放在 AI package，Data 和 UI 无法使用；如果让 AI import Data，会破坏现有推荐依赖方向。
  - 修订：第 11.0 和 11.2 已规定跨模块 DTO、枚举和错误分类进入 Core，AI 只负责请求和解析，Data 只负责持久化。

- P0：真实 AI 学习材料生成不能只使用内存 repository。
  - 证据：`AppDatabase` 当前迁移只覆盖 `language_spaces`、AI Provider 配置和 diagnostics，没有 Entry / LearningMaterial 表。
  - 影响：真实用户原文和 AI 输出会在重启后丢失；这与本地优先和“个人语言记忆系统”定位冲突。
  - 修订：第 11.11 已明确采用完整 GRDB 路径；如需 prototype 分期，必须另开任务并改变完成标准，不能在本方案内宣称真实学习闭环完成。

- P1：缺少生成请求状态机和防重规则。
  - 证据：当前 UI 本地预览是同步 closure；真实 AI 请求将变为 async，原方案只列 UI 状态，没有 operation id、取消、重复点击和 stale result 规则。
  - 影响：用户重复点击、切换 Entry、编辑文本期间返回旧结果，都可能造成 UI 与持久状态不一致。
  - 修订：第 11.9 已补充状态机、operation id、防重、取消和 stale result 丢弃规则。

- P1：错误边界不够细，不能支撑可恢复 UI。
  - 证据：AI Provider 现有配置测试已区分 missing credential、timeout、cancelled、invalid response 等；原学习材料方案只笼统写 Provider 未配置、网络失败等。
  - 影响：UI 会被迫解析底层错误或显示泛化失败，诊断日志也难以定位阶段。
  - 修订：第 11.10 已补充学习材料专用 failure category 和恢复策略。

- P1：请求服务边界不应复用配置 Probe。
  - 证据：`AIProviderConfigurationProbeService` 的 Prompt、validation event 和持久摘要服务于配置测试；真实学习内容请求会包含用户原文和派生学习文本。
  - 影响：混用会污染 Provider validation 语义，也可能把用户内容带入不应持久化的配置测试路径。
  - 修订：第 11.12 已要求新增 `LearningMaterialGenerationService`，并定义日志脱敏、adapter 支持和响应校验边界。

- P2：长度阈值缺少可测试估算器和输出规模约束。
  - 证据：原方案写 `800 / 3000 estimated tokens`，但仓库没有 tokenizer 依赖，也没有估算函数。
  - 影响：不同实现者会用不同口径，UI 阻断、Prompt 降级和测试难以稳定。
  - 修订：第 11.13 已定义第一版估算口径和输出上限。

- P2：原始输入不可编辑需要代码级表达。
  - 证据：`LearningEntry.body` 当前为 `public var`，虽然 repository 没有正文更新接口，但模型对“原文只读”的表达不够强。
  - 影响：后续 UI 或 repository 扩展可能误把 Entry 当作可编辑草稿。
  - 修订：第 11.14 已给出三种实现方式，并推荐将正文相关字段改为 `let`。

### 18.3 四维切片

并发/性能边界：

- 必须避免同一 Entry 同时运行多个生成 / 分析请求。
- 必须支持取消，不让已经过期的 operation id 覆盖当前 UI。
- 中等文本必须限制句子、词句候选和练习候选数量，避免一次响应过大。
- 长文本必须在请求前阻断；不能等 Provider 返回错误后再处理。

异常边界：

- Provider 未配置、Keychain credential missing、timeout、network、provider rejected、unsupported provider / model、invalid JSON、persistence failed 和 cancelled 必须区分。
- 诊断日志只能记录非敏感分类、operation id、duration、provider/model 和长度分桶。
- 结构化响应缺字段必须变成可诊断错误，不得让 UI 处理半成品对象。

状态同步：

- Entry 是原始事实源；LearningMaterial 是派生学习文本；Analysis 依赖当前 learning text。
- 用户编辑 learning text 后，analysis 必须进入 stale 状态。
- `重新分析` 只能更新 analysis，不得改 Entry 或重新生成 learning text。
- `重新生成` 必须产生新版本或明确替换 current material，并保证 UI、repository 和 memory/practice candidates 同步。

数据一致性：

- 真实完成口径需要 GRDB schema 和事务；内存闭环只能作为测试替身或另行定义的 prototype 任务。
- 同一 Entry 可以有多个 LearningMaterial，但 current material 需要唯一性约束。
- schema 必须通过 SQL CHECK 或 Data 层集中校验固定枚举取值，避免非法字符串进入长期主数据。
- operation 表采用单行摘要语义，`operation_id` 唯一；如果未来需要事件流，应另建 operation events 表。
- 生成和重新分析的半成功必须回滚或保持旧稳定状态，不能保存缺失 analysis 的半成品学习材料。
- 删除 Entry、删除 material、重建 analysis、候选 Memory / Practice 的外键和清理规则必须明确。
- 原始 Entry 正文不应被 AI 输出或用户学习文本编辑覆盖。

### 18.4 收益点复核

确认收益：

- 单按钮 `生成学习材料` 更符合“写完就学习”的主路径，降低用户决策成本。
- AI 自路由能同时覆盖母语记录和目标语言写作，不需要拆两个并列按钮。
- 原始 Entry 只读、学习文本可编辑，能同时保护生活记录真实性和学习材料可修正性。
- `重新分析` 把用户编辑后的学习文本纳入后续练习和记忆，符合“把自己的表达变成能力”的产品愿景。

新增代价：

- 需要比原方案更完整的数据模型和状态机。
- Prompt 输出必须严格结构化，测试成本高于本地预览。
- 不弹请求确认要求按钮、加载态、设置页和日志边界更清晰；未来照片、音频、历史记忆不能复用该低摩擦边界。

### 18.5 实施步骤清晰度复核

当前方案在本次复审修订后已经具备主要架构边界，但进入编码前仍需要按 TDD 顺序拆成可执行子任务。实现时至少按以下顺序推进：

1. Core：新增共享 DTO、状态机、错误分类和长度估算器测试。
2. Data：新增 GRDB schema / async repository facade，迁移 Entry、LearningMaterial、Analysis、MemoryCandidate、PracticeCandidate 和 operation 记录。
3. AI：新增 LearningMaterialGenerationService、Prompt 文档、请求体构造、结构化解析和脱敏诊断。
4. UI：先改造 iOS / iPhone 记录详情页状态、学习文本编辑、重新分析和错误恢复；iPad / macOS 暂不接入本轮 UI。
5. App Shell：装配 generation actions，解析 saved profile 和 Keychain secret。
6. Docs：更新 product、`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/learning-content/impl.md`、page inventory、Prompt Registry 和必要 review round。
7. Verification：运行 Core/Data/AI/UI 聚焦测试、敏感字段扫描、`scripts/verify.sh` 和 iOS 端人工 UI 验证；iPad / macOS 人工 UI 验证留到后续平台接入任务。

### 18.6 剩余疑问

- Anthropic / Gemini 在本任务第一版是否必须支持？当前建议是不支持真实学习材料生成请求体时返回明确 `unsupportedProvider` / `unsupportedModel`，UI 显示当前模型暂不支持该能力，而不是泛化为网络失败。
- 是否允许保存后编辑 Entry 标题、标签、场景？当前建议本任务只冻结正文；标题、标签、场景可另开轻量 metadata 编辑任务。

### 18.7 2026-05-23 复审补充结论

复审结论：Needs Changes，但可通过本文新增约束转为 implementation-ready。新增必须满足的 gate：

- Repository gate：不得只新增孤立的 `LearningMaterialRepository`；必须明确 `LearningContentStore` 从同步内存 repository 迁移到 async GRDB facade 的路径，或用过渡 bridge 测试证明真实生成结果不会落入内存闭环。
- Persistence gate：`InMemoryLearningContentRepository` 只能作为测试替身和 mock preview；真实 App Shell 必须装配 GRDB learning content repository。
- Migration/export gate：迁移必须覆盖 v3 fixture、空库、重复 migrator、关键 CHECK / index / foreign key；数据规范必须记录导出、备份、删除和未来同步边界。
- Delete/query gate：候选表 active 查询必须 join Entry / Material 删除状态，或候选表自身增加 `deleted_at` 并事务同步；删除 Entry 后不得显示候选 Memory / Practice。
- Operation gate：operation `started`、失败 / 取消、成功落库是不同事务阶段；operation 表使用唯一 `operation_id` 的单行摘要；只有成功 material / analysis / operation summary 必须同事务写入。
- Analysis gate：首次生成 analysis 非法时整次失败不落半成品；重新分析失败不得删除旧 analysis 或覆盖当前学习文本。
- Privacy gate：非阻断确认必须通过按钮说明、生成中状态和结果元数据披露 AI Provider 调用，不得把中风险文本请求伪装成本地处理。
- Verification gate：聚焦验证必须包含 Core、Data、AI、UI 四个 package；Core 负责 DTO、状态机、错误分类和长度估算器。

### 18.8 2026-05-23 代码复核补充

审核视角：系统架构、活代码一致性、真实实施链路、隐藏耦合和执行条件。

审核结论：Needs Changes -> 可转入用户确认 gate。方案的产品方向、核心数据边界、Provider 边界和 GRDB 完成口径成立；本次复核发现的编排层不清、同步 repository 迁移低估、settings capability 隐藏耦合和 Prompt / hash / fixture 等执行细节缺口，已补入第 11.0.1、11.0.2、11.2.1、11.8、11.9、11.10、11.15、11.16 和 11.18。方案仍保持 Draft，进入实现前仍需要用户明确确认。

#### 18.8.1 代码现状复核

准确项：

- iPhone 入口链路描述准确。`PhoneMainView` 中 `.entryEditor` sheet 保存后调用 `contentStore.createEntry(title:body:source:)`，并导航到 `.entryDetail(entry.id)`；当前入口固定传入 `.typedText`。
- `EntryDetailView` 结构描述准确。当前详情页显示 `entry.body`、`rendering?.targetText`、逐句区域、本地预览入口和练习入口；没有原始正文编辑入口。
- `LearningContentStore` 和 `LearningContentRepository` 仍是同步接口；`generateLocalPreview` 是同步本地 mock。
- `AppEnvironment.bootstrap()` 当前真实装配语言空间 GRDB repository、AI Provider 配置 service 和 Keychain credential store，但 learning content 仍装配 `InMemoryLearningContentRepository(seedEntries: [])`。
- `AppDatabase` 当前迁移只有 `v1_create_language_space_infrastructure`、`v2_create_ai_provider_configuration`、`v3_create_diagnostic_events`，没有 Entry / LearningMaterial 表。
- package 依赖方向描述准确：`LangoTraceAI` 只依赖 Core；`LangoTraceUI` 依赖 Core 和 Data，不依赖 AI。

需要补充或修正的项：

- `EntrySource.targetLanguageWriting` 当前不是 UI 可选项；`写一句` 无论用户写中文、英文或混合文本，都保存为 `.typedText`。因此第一版不能用 `EntrySource` 推断输入类型，必须完全依赖 AI 返回的 `LearningMaterialInputKind`，并在文档中明确 `EntrySource` 是采集来源 / 模态，不是语言分类事实。
- `settingsCapabilities(for:)` 当前挂在 `LearningContentRepository` 上，且由 `InMemoryLearningContentRepository.serviceSettingsCapabilities` 返回 AI Provider、Sync、Local Data、Privacy 等能力状态。迁移到 `GRDBLearningContentRepository` 时，如果照搬当前协议，会把设置能力元数据继续耦合在 learning content repository 中；如果不照搬，则 SettingsView 会丢能力列表。
- 方案提出 `LearningMaterialGenerationService` 和 repository，但还没有定义一个明确的编排层来串联：长度预检、Provider 配置读取、Keychain secret 解析、operation started、AI 请求、结构化校验、成功事务落库、失败 / 取消 operation 更新、UI state 回写。若由 SwiftUI / `LearningContentStore` 拼装，容易把 Data / AI / Keychain 责任重新拉回 UI；若由 AI service 直接落库，又会破坏 AI 不依赖 Data 的边界。
- `analysis_source_hash` 的算法、输入规范化和隐私属性未定。虽然数据库同时保存 `learning_text`，但 hash 仍需稳定算法和测试口径，否则 stale 判定、导出和迁移测试会漂移。
- v3 fixture 迁移测试要求正确，但仓库当前没有 fixture 目录和 fixture 生成约定。实现前应明确 fixture 存放位置、构造方式和是否使用 SQL snapshot，避免迁移测试只覆盖空库。

#### 18.8.2 新增关键问题

- P0：缺少应用编排层，真实调用链责任仍不完整。
  - 证据：当前 App Shell 已用 `AIProviderSettingsActions` closure 装配 Provider 设置保存 / 测试链路；学习材料方案只要求新增 AI service 和 repository，未明确等价的 `LearningMaterialGenerationActions` 或 application use case 负责跨 AI / Data / Keychain 的完整事务阶段。
  - 影响：实现者可能让 SwiftUI View 或 `LearningContentStore` 直接编排网络、Keychain 和数据库 operation；也可能让 AI package import Data，破坏第 11.0 的依赖边界。
  - 必须修订：新增 `LearningMaterialGenerationActions` 或 `LearningMaterialGenerationUseCase` 边界，由 App Shell 装配。UI 只调用 action；AI service 只返回解析后的 Core result；Data repository 只负责事务；use case 负责 preflight、operation 生命周期、AI 调用和落库顺序。

- P0：同步 `LearningContentRepository` 到 async GRDB facade 的迁移范围仍低估。
  - 证据：当前 `LearningContentStore.reload()` 同步读取 entries、selectedEntry、memoryItems、settingsCapabilities；`PhoneMainView`、Practice、Memory 和 Settings 都依赖这些同步 published 值。
  - 影响：只把生成 / 分析方法改成 async 会形成双事实源：Entry 列表仍来自内存同步 repository，LearningMaterial 来自 GRDB；或 UI 缺 loading / error / refresh 状态，导致启动、切换语言空间、生成完成后的刷新不稳定。
  - 必须修订：第 11.15.5 需要补充 Store 迁移策略：`LearningContentStore` 增加 async load / refresh 状态、错误状态、生成后局部刷新规则，以及对 Phone / iPad / macOS 共享详情页的更新传播方式。若采用 bridge，必须限定 bridge 生命周期并测试 App Shell 不再装配内存 repository。

- P1：settings capability 与 learning content repository 的隐藏耦合需要拆开或显式保留。
  - 证据：当前 `LearningContentRepository` 协议包含 `settingsCapabilities(for:)`；`InMemoryLearningContentRepository` 返回 AI Provider、Sync、Local Data、Privacy、Import/Export 等设置能力，明显不是学习内容主数据职责。
  - 影响：新增 `GRDBLearningContentRepository` 后如果继续实现该方法，会把设置能力常量复制进 Data repository；如果删除该方法，SettingsView / 三端 settings detail 会断链。
  - 建议修订：优先新增 `SettingsCapabilityProvider` 或静态 capability source，由 App Shell / UI Store 组合；如果本任务不拆分，必须明确 `GRDBLearningContentRepository.settingsCapabilities` 只是过渡兼容，并加测试覆盖 SettingsView 能力列表不回退。

- P1：`EntrySource` 与 `inputKind` 的语义需要明确分层。
  - 证据：当前保存文本入口固定 `.typedText`；方案 schema 允许 `targetLanguageWriting`，同时又要求 AI 自路由判断 `targetWriting`。
  - 影响：后续实现可能错误地把 `.typedText` 当母语记录，把 `.targetLanguageWriting` 当目标语言写作，导致当前主入口无法正确处理用户直接写目标语言的文本。
  - 建议修订：第一版规定 `EntrySource` 只表示采集来源，`LearningMaterialInputKind` 才表示语言 / 任务路由；`targetLanguageWriting` 是否继续保留为 source 枚举应另行说明，不能作为 Prompt 输入类型事实。

- P1：Prompt Registry 和代码 prompt 一致性缺少可执行检查。
  - 证据：方案要求文档能完整还原 system / user prompt，但验证命令只列 package 测试和文档检查，没有指定 prompt registry diff / snapshot test。
  - 影响：真实请求 Prompt 很容易在代码和文档间漂移，后续隐私审查无法根据 `docs/prompts/` 复原真实发送内容。
  - 建议修订：AI package 增加 prompt rendering snapshot test，或提供脚本校验 `builtin.learning_material.generate.v1` / `analyze_current_text.v1` 的 prompt id、version、输入变量和 JSON schema 与文档一致。

- P2：`analysis_source_hash` 和 JSON blob schema version 需要实现级定义。
  - 证据：方案要求稳定 hash 和 JSON blob 可测试 schema version，但没有指定 hash 算法、规范化规则、schema version 字段位置或 Data 层 record 类型命名。
  - 影响：stale 判定、迁移、导出和兼容解码测试无法稳定。
  - 建议修订：规定第一版使用固定算法，例如 `SHA256(UTF8(normalizedLearningText))`，其中 normalizedLearningText 只做换行规范化或完全不规范化；`grammar_notes_json` / `key_points_json` 使用 Data package 内部 Codable record，顶层包含 `schemaVersion`。

- P2：v3 fixture 迁移测试缺少仓库约定。
  - 证据：当前 Data tests 主要使用 in-memory database 和 repository 构造，没有看到既有 schema fixture 目录。
  - 影响：实现者可能只测试空库迁移，无法证明真实 v3 数据库升级到 v4 的兼容性。
  - 建议修订：在 Data tests 下新增明确 fixture 路径或 helper，例如 `Packages/LangoTraceData/Tests/LangoTraceDataTests/Fixtures/v3-language-space-ai-provider.sqlite` 或 SQL builder，并在测试名中固定覆盖 v3 -> v4。

#### 18.8.3 四维切片补充

并发 / 性能边界：

- 方案已覆盖同一 Entry 防重、取消、长文本阻断和中等文本输出限制；还需明确 use case 层持有 in-flight operation registry，而不是只靠 View 禁用按钮。
- `DatabaseQueue.write` 不得跨网络请求，方案已写清；实现时要测试 started 与 succeeded / failed 分事务，成功 material / analysis / operation 同事务。
- `LearningContentStore` async 化后需要避免每次生成完成全量同步刷新所有 entries / memory / practice，首版至少定义局部刷新或可接受的小数据全量刷新边界。

异常边界：

- 方案错误分类基本完整；还需补充 default text endpoint disabled、default profile deleted、endpoint purpose 不是 text generation、Keychain secret inaccessible 与 credential missing 的区别是否映射到同一 UI 文案。
- `Provider 未配置` 和 `内容过长` 这类 preflight 阻断是否写 `learning_material_operations` 需要统一。当前表允许 `provider_preset_id` 为空，但 `prompt_id` / `prompt_version` 必填；实现时必须明确 preflight operation 是否仍绑定内置 prompt。

状态同步：

- Entry 原文、LearningMaterial 当前版本、Analysis stale 状态的关系已经清晰。
- 尚需定义 UI route lifecycle：用户在 generation 期间离开详情页后，operation 是否继续后台完成并落库，还是随 UI task 取消。若随 UI 取消，App Shell action 要收到 cancellation 并写 cancelled operation；若继续完成，返回详情页必须能从 repository 恢复 generated 状态。
- 语言空间切换期间的 operation 结果必须以 entryID / spaceID 双重校验，避免旧空间生成结果刷新到新空间 UI。

数据一致性：

- schema 草案覆盖主表、子表、候选表和 operation 表，方向正确。
- 需要补充外键启用和测试口径：迁移测试应显式验证 FK 行为、唯一 current material、soft delete active 查询和非法枚举 CHECK。
- `learning_materials.space_id` 与 `entries.space_id` 可能不一致；写入 repository 必须校验 material.spaceID == entry.spaceID，或去掉冗余字段并通过 join 获取。若保留冗余字段，必须有测试阻止跨空间 material。

#### 18.8.4 实施条件结论

当前方案不应在未获用户确认时直接进入实现，状态应保持 `Draft`。本次补充后，application use case / action 编排层、repository async 迁移、settings capability 解耦、Prompt / hash / fixture gate 已经具备文档级执行约束。

达到 implementation-ready 前，至少需要把以下内容补入第 11 节：

1. `LearningMaterialGenerationActions` 或 `LearningMaterialGenerationUseCase` 的职责、输入输出、依赖和 operation 生命周期。
2. `LearningContentStore` 从同步内存 repository 到 async GRDB facade 的迁移步骤、loading / error 状态和三端刷新策略。
3. `settingsCapabilities` 从 learning content repository 拆分或过渡保留的明确方案。
4. `EntrySource` 与 `LearningMaterialInputKind` 的语义分层。
5. Prompt 文档与代码一致性测试、hash 算法、JSON blob schema version、v3 fixture 约定。

这些修订已经补入第 11 节；本方案可以进入用户确认 gate。确认后再按 TDD 顺序实施。

### 18.9 2026-05-23 系统架构师复核补充

审核视角：代码事实一致性、应用编排责任、隐私披露一致性、跨平台实现链路和实施就绪条件。

审核结论：Approved With Notes。方案的主方向、数据完成口径、Provider 边界、状态机、迁移 gate 和验证范围已经足以进入用户确认 gate；但实施时必须严格执行本节新增的两项收紧约束，否则容易在 Keychain 责任和用户隐私理解上产生偏差。

新增准确性确认：

- `EntryEditorView` 当前以 `Form` 承载标题、正文和“保存到本机”隐私提示；保存按钮只检查正文非空，没有 loading / persistence failure 状态。
- iPad 和 macOS 已复用同一个 `EntryDetailView` 展示详情，但创建入口和承载方式不同：iPad 通过 sheet 使用 `EntryEditorView`，macOS 通过 `MacEntryEditorOverlay` / `MacEntryEditorSheet`。因此本任务改造详情页能力时可以共享，但创建入口的 async 保存状态需要分别接入。
- `AIProviderConfigurationService` 现有配置测试链路会在 AI package 中组合 repository、Keychain credential store 和 probe service；学习材料生成方案不能照搬该组合方式，因为学习材料还要同时写 Entry / Material 主数据，必须由 App Shell / use case 编排 Data、AI 和 Keychain 的事务顺序。

新增问题与修订：

- P0：Keychain secret 解析责任曾在第 11.0.1 和第 11.12 表述不一致。
  - 证据：第 11.0.1 要求应用编排层解析 secret；第 11.12 原先又把“通过 Keychain reference 解析 secret”列为 `LearningMaterialGenerationService` 职责。
  - 影响：实现者可能让 AI service 同时读取 Provider repository / Keychain，又让 use case 写 operation 和 material，形成双编排层；也可能让 AI package 间接承担 Data 生命周期，破坏第 11.0 的边界。
  - 修订：第 11.0.1 和第 11.12 已统一为 App Shell / use case 解析默认 profile、endpoint 和 Keychain secret；AI package 的 generation service 只接收已规范化 endpoint、短生命周期 plaintext secret、Prompt 输入和 operation id，并负责请求构造、发送、解析和结构校验。

- P1：保存到本机的隐私提示与后续 AI 发送动作需要明确分层。
  - 证据：当前 `EntryEditorView` 在创建记录时展示“保存到本机，不会发送到外部 AI。”；本方案又采用详情页 `生成学习材料` 的非阻断 AI 调用。
  - 影响：如果详情页只放一个按钮而不解释边界，用户可能把保存时的本地承诺误读为后续生成也完全本地，或者误以为保存动作已经上传。
  - 修订：第 11.7 已补充披露要求：保存 Entry 是本机写入；只有用户在详情页主动点击 `生成学习材料` 才发送当前 Entry 文本给已配置 Provider。实现时按钮附近、生成中状态和结果元数据都必须保持该分层。

四维复核补充：

- 并发 / 性能：当前状态机和 operation gate 已覆盖防重、取消、stale result、长度阻断和输出规模；实现时仍需在 use case 层持有 in-flight registry，不能只依赖 View 禁用按钮。
- 异常边界：错误分类足够启动实现；但 credential missing、credential inaccessible、endpoint disabled 和 unsupported provider 的 UI 文案可以归并，诊断分类必须保留细分。
- 状态同步：详情页共享有利于三端一致，但创建入口不是单一组件；`createEntry` async 化后，iPhone / iPad sheet 和 macOS overlay 都必须处理保存中、保存失败和避免重复保存。
- 数据一致性：GRDB 完成口径、current material 唯一约束、soft delete active 查询、operation 单行摘要和 v3 fixture gate 已经清楚；实施时必须测试 `learning_materials.space_id` 与 `entries.space_id` 不一致的防线，或取消冗余 `space_id`。

实施条件结论：

- 可以进入用户确认 gate，但不能直接编码；状态仍应保持 `Draft`，直到用户明确确认。
- 确认后建议先拆成 TDD 子任务执行：Core DTO / 状态机 / 长度估算 -> Data schema / repository / fixture -> AI generation service / Prompt snapshot -> App Shell use case -> UI 三端状态接入 -> docs / review / verify。

### 18.10 2026-05-23 实施范围收窄确认

用户确认：本轮实现仅先完成 iOS / iPhone 端，iPad 和 macOS 端待 iOS 端人工测试通过后再进行。

方案修订：

- 第 4 节范围已收窄为 iOS / iPhone UI 可交付；底层 Core / Data / AI / App Shell 仍保持三端可复用，不写 iOS 专属业务模型。
- 第 5 节明确排除本轮 iPad / macOS 记录详情页 UI 接入、创建入口 async 保存状态和平台人工验收。
- 第 11.15.6、18.5 和第 16 节已同步改为先完成 iOS UI 和 iOS 人工测试；iPad / macOS 平台接入必须在后续任务中推进并单独验收。

实施要求：

- 实现时不得为了“仅 iOS”而把 repository、Prompt、Provider request、operation、LearningMaterial DTO 或持久化 schema 写成 iOS-only。
- 页面清单和实施记录必须清楚标记：本任务完成后，真实学习材料生成 UI 首先仅 iOS 可用；iPad / macOS 仍处于后续接入状态。
