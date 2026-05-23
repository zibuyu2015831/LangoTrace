# learning-content 实现地图

状态：Current Implementation Map

最后更新：2026-05-23

## 1. 对应规范

- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`

## 2. 当前实现

- 内存学习内容模型和 repository：`Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- GRDB 学习内容 repository：`Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- Data 边界协议：`Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift`
- 学习材料生成 Core 契约：`Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift`
- 学习材料 AI service 与 Prompt Registry：`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`、`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialPromptRegistry.swift`
- iPhone 记录创建和详情：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- iPad 记录详情承载：`Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- macOS 记录详情承载：`Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- Entry editor、detail 和 mock practice supporting views：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- App Shell 装配：`LangoTraceApp/AppEnvironment.swift`

当前已经实现：

- `InMemoryLearningContentRepository` 仍可作为测试替身和开发期 seed preview。
- `GRDBLearningContentRepository` 已提供真实 Entry、LearningMaterial、句子分析、修改说明、memory candidate、practice candidate 和 learning material operation 摘要的本地持久化路径。
- App Shell 已将真实 learning content repository 装配为 `GRDBLearningContentRepositoryBridge`，不再把用户创建的真实 Entry 和生成结果落入内存 repository。
- iPhone 可通过记录创建 sheet 保存到 GRDB repository，并进入详情。
- `LearningContentRepository` 已提供 Entry body 更新能力；iPhone / iPad / macOS 复用的 `EntryDetailView` 可以从详情页编辑母语原文。保存原文只更新本地 `entries.body` / `updated_at`，不自动触发 AI Provider 请求。
- iPhone / iPad / macOS 记录详情在无学习材料时显示一个核心动作 `生成学习材料`；点击后经 `LearningMaterialGenerationActions` 进入 App Shell 编排，读取默认文本 Provider、解析 Keychain secret、调用 `LearningMaterialGenerationService`，再保存到 GRDB。
- `learning_materials.source_entry_body_hash` 记录当前 material 生成时对应的 Entry body hash；Store 通过当前 Entry body hash 与 rendering/material hash 比较推导 `sourceEntryIsStale`。原文编辑后已有学习材料显示“基于旧记录”，用户显式点击重新生成后才会发送当前原文给 Provider。
- 学习文本可编辑；编辑后 analysis 进入 stale 状态；用户可点击 `重新分析`，仅重建当前学习文本的 analysis，不改原始 Entry 或重新生成 learning text。
- 记录详情中的母语原文和目标语言学习文本使用 `EntryDetailTextCard` 顶部工具区；动态标题来自当前语言空间显示名，不硬编码具体语种，正文全宽展示，不再使用右上角悬浮按钮挤压文本列。
- 长文本在 UI / Store 层按 `LearningMaterialLengthEstimator` 阻断，避免直接发送给 Provider。
- iPad `workspaceOverview` / route detail 和 macOS Today / Entries detail 均复用共享 `EntryDetailView` helper，注入与 iPhone 一致的生成、取消、learning text 保存、重新分析、原文更新和练习入口。iPad / macOS 仍需后续人工验收大屏布局、AI Provider 披露和创建入口保存失败恢复。

## 3. 已知偏差

- `LanguageSpaceRepository` 仍是空协议。
- Settings capability 仍通过 learning content repository 过渡提供；长期应拆为独立 provider，避免内容 repository 承担设置能力来源职责。
- `GRDBLearningContentRepositoryBridge` 是旧同步 UI 协议到真实 GRDB repository 的过渡层；它已经不再返回 `unsaved-*` 内存 Entry，持久化失败会向上抛出。后续 iPad / macOS 接入和更完整错误恢复时，应继续演进为 async facade。
- iPhone 生成中状态已有取消入口；取消会把当前 operation 标记为 cancelled，并让 Store 丢弃 late result。第一版取消不承诺底层 HTTP task 一定被立即终止。
- 成功生成和重新分析使用 `GRDBLearningContentRepository` 的组合写入 API，保证 material / analysis / operation succeeded summary 在同一个 `DatabaseQueue.write` 事务内完成。
- Store 层 `contentEmpty` / `contentTooLong` / `operationInProgress` preflight 阻断会通过 App Shell action 写入本地 failed operation summary，不发送 Provider。
- App Shell 创建 GRDB bridge 失败时使用显式 unavailable repository，不再 fallback 到 `InMemoryLearningContentRepository(seedEntries: [])`。
- 当前真实学习材料请求支持 OpenAI Responses / OpenAI-compatible Chat；Anthropic / Gemini 学习材料请求体尚未接入，会按 unsupported provider / model 边界处理。
- 练习候选仍是候选入口；TTS、录音、真实练习评分、OCR、照片附件和同步尚未接入。
- 导出、可恢复备份、FTS、向量索引和对象级同步尚未实现。
- TTS、录音、Speech、OCR、照片和同步尚未接入。

## 4. 复查方法

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceUI
rg "GRDBLearningContentRepository|LearningMaterialGenerationActions|LearningMaterialGenerationService|EntryDetailView|PracticeSession" Packages/LangoTraceData Packages/LangoTraceAI Packages/LangoTraceUI LangoTraceApp
scripts/verify.sh
```

如果 Data package 在某个阶段没有测试目标或没有测试用例，应在任务方案中记录实际 package 状态，并至少运行相关 UI / Core 测试和文档检查。
