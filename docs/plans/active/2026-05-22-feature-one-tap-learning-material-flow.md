# 任务方案：一键生成学习材料闭环

状态：Draft
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
- 当前状态仍为 Draft。进入实现前，需要用户明确确认本方案可以开始实施。

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
- iPad / macOS 共享 `EntryDetailView` 的同一能力入口与状态展示。
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

AI package 测试：

- 母语输入返回 `nativeRecord` 和目标语言学习文本。
- 目标语言输入返回 `targetWriting`、优化稿、修改说明和分析。
- 混合输入返回 `mixed`，并保留主要语义。
- 不确定输入返回 `uncertain` 或降级为 `nativeRecord`，但必须带判断说明。
- 结构化 JSON 缺字段时返回可诊断错误。
- 请求日志不包含原文、学习文本、响应全文或 API Key。

UI package 测试：

- 记录详情无学习材料时只有一个核心动作 `生成学习材料`。
- 详情页不包含编辑原始正文入口。
- 主按钮附近、生成中状态和结果元数据都明确表达 AI Provider 调用边界。
- 生成中禁用重复点击。
- 学习文本可编辑。
- 编辑学习文本后出现 `重新分析`。
- Provider 未配置时出现设置入口。
- 内容过长时不发起请求并显示说明。

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
- 用户切换 Entry、切换语言空间、关闭 sheet 或离开详情页时，UI task 必须可取消。
- 取消后的结果不得落库为失败；如果 Provider 请求已返回但 operation id 已过期，不得覆盖当前 UI 状态。
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
- 通过 Keychain reference 解析 secret，但不把 secret 暴露给 UI。
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
- AI service 必须只接受 JSON object，不接受 Markdown code fence、自然语言前后缀或半结构化文本。
- 响应解析后必须做字段级校验：枚举值、数组数量、字符串空值、语言 code、句子数量和候选数量；`analysis_source_hash` 由 App 对当前 `learning_text` 本机计算，模型不返回 hash。
- 生成请求的 JSON 顶层必须包含 `schema_version = "learning_material.v1"`。
- `input_kind` 必须是 `nativeRecord`、`targetWriting`、`mixed` 或 `uncertain`。
- `learning_text` 必须是目标学习语言文本；如果原输入已经是目标语言，则必须是优化后的目标语言文本。
- `analysis` 必须基于 `learning_text`，不能基于原始 Entry。
- 中等长度文本必须执行输出规模限制：最多 20 句、12 个 memory candidates、6 个 practice candidates。
- Prompt 不得要求模型返回用户 API Key、Provider 信息、系统内部 ID、完整 Prompt 文本或日志字段。

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

尚未开始实现。

## 16. 完成标准

任务可以从 `active/` 移入 `done/` 的条件：

- 用户已确认本方案进入实现。
- 记录详情页只有一个核心 AI 动作 `生成学习材料`。
- 原始 Entry 正文保存后不可直接编辑。
- AI 生成请求一次返回学习文本和学习分析。
- 目标语言写作结果包含优化稿和修改说明。
- 学习文本可编辑，编辑后可重新分析。
- 重新分析不修改 Entry 正文，也不重新生成学习文本。
- 长文本在 App 层阻断或进入选段流程，不直接全量请求。
- Core、Data、AI、UI 聚焦测试通过。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。
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
4. UI：改造 EntryDetailView 状态、学习文本编辑、重新分析和错误恢复。
5. App Shell：装配 generation actions，解析 saved profile 和 Keychain secret。
6. Docs：更新 product、`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/learning-content/impl.md`、page inventory、Prompt Registry 和必要 review round。
7. Verification：运行 Core/Data/AI/UI 聚焦测试、敏感字段扫描、`scripts/verify.sh` 和三端手动 UI 验证。

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
