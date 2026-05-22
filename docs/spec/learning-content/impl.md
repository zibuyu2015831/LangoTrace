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
- Entry editor、detail 和 mock practice supporting views：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- App Shell 装配：`LangoTraceApp/AppEnvironment.swift`

当前已经实现：

- `InMemoryLearningContentRepository` 仍可作为测试替身和开发期 seed preview。
- `GRDBLearningContentRepository` 已提供真实 Entry、LearningMaterial、句子分析、修改说明、memory candidate、practice candidate 和 learning material operation 摘要的本地持久化路径。
- App Shell 已将真实 learning content repository 装配为 `GRDBLearningContentRepositoryBridge`，不再把用户创建的真实 Entry 和生成结果落入内存 repository。
- iPhone 可通过记录创建 sheet 保存到 GRDB repository，并进入详情。
- iPhone 记录详情在无学习材料时显示一个核心动作 `生成学习材料`；点击后经 `LearningMaterialGenerationActions` 进入 App Shell 编排，读取默认文本 Provider、解析 Keychain secret、调用 `LearningMaterialGenerationService`，再保存到 GRDB。
- 学习文本可编辑；编辑后 analysis 进入 stale 状态；用户可点击 `重新分析`，仅重建当前学习文本的 analysis，不改原始 Entry 或重新生成 learning text。
- 长文本在 UI / Store 层按 `LearningMaterialLengthEstimator` 阻断，避免直接发送给 Provider。
- iPad / macOS 仍未接入真实学习材料生成 UI；本轮只完成 iOS / iPhone，待 iOS 人工测试通过后再推进平台接入。

## 3. 已知偏差

- `LanguageSpaceRepository` 仍是空协议。
- Settings capability 仍通过 learning content repository 过渡提供；长期应拆为独立 provider，避免内容 repository 承担设置能力来源职责。
- `GRDBLearningContentRepositoryBridge` 是旧同步 UI 协议到真实 GRDB repository 的过渡层；后续 iPad / macOS 接入和更完整错误恢复时，应继续演进为 async facade。
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
