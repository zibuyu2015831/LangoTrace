# 阅读基础设施与 AI/TTS 纵向切片方案

状态：Draft
自审核状态：Reviewed
类型：feature
创建日期：2026-06-01
最后更新日期：2026-06-01

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 以“阅读是语言学习一级场景”为前提，落地一个基础设施优先的阅读纵向切片：把产品 / 导航 / 数据 / AI / TTS 的长期规则先沉淀到开发文档，再实现阅读材料导入与呈现、手动选词、真实 AI selection explanation、真实 reading sentence TTS 播放、source anchor stale 表达，以及后续阅读 MVP 可继续扩展的正式 Reading domain 边界。

**Architecture:** 本任务是 feature 级纵向切片，但按早期开发阶段原则，不把既有三 Tab 或临时页面骨架当成长期包袱。若用户批准实施，本方案应同步更新产品主参考、导航规范、页面清单和 Reading 领域规范，并把阅读作为正式一级学习入口接入三端；同时仍不做完整资料库、词典导入、同步或 EPUB/PDF。阅读文本、结构、position、source anchor、operation summary 采用正式 GRDB 主数据与 repository；AI 解释复用现有用户自带 Provider / Keychain / HTTP client 边界并新增 reading prompt；TTS 播放复用现有 `SentenceAudioPlaybackCoordinator` / media artifact 基础设施并扩展 reading sentence source；UI 通过共享 `ReadingStore` / action seam 装配到三端正式 route。

**Tech Stack:** Swift 6、Swift Testing、SwiftUI Multiplatform、GRDB、LangoTraceCore、LangoTraceData、LangoTraceAI、LangoTraceSpeech、LangoTraceUI、Prompt Registry、现有 `scripts/verify.sh` 和文档检查脚本。

---

## 1. 用户确认记录

- 2026-06-01：用户要求根据 `docs/reference/research/2026-06-01-reading-integration-assessment.md` 立即创建详细 active plan 文档。
- 2026-06-01：本方案仅获得“创建 active plan 文档”的授权；尚未获得生产代码实现授权。
- 2026-06-01：方案初版曾将阅读确认为长期一级学习场景的设计输入，但为控制范围暂不修改 `PhoneRootTab`，不立即把 iPhone 主导航改为 `记录 / 阅读 / 练习 / 记忆`。
- 2026-06-01：用户明确要求鉴于当前项目已经实现真实 AI / TTS 请求，本次开发需要接真实 AI / TTS；同时要求重新检查并细化实施步骤。本方案因此从 research spike 调整为 feature 级阅读 AI/TTS 纵向切片。
- 2026-06-01：用户要求按早期开发阶段原则重新审查本方案：发现错误或落后的应用级设计可以主动提出推倒重来；基础设施应优先采用清晰、可扩展且符合现有架构边界的方案；开发文档是 AI 辅助编程的全局控制面，发现规范过期或更优设计时应同步更新规范并持续沉淀。
- 2026-06-01：本次复审后，前一条“不修改 `PhoneRootTab` / 不更新导航规范”的保守限制被降级为“尚未获得实施授权前不改代码”。若用户批准本 feature 实施，方案建议把阅读作为正式一级入口接入，并同步修订相关规范；这仍不等于一次性实现完整阅读 MVP。

## 2. 需求描述

根据阅读整合调研，LangoTrace 长期应把阅读作为与记录、练习、记忆并列的一级学习场景，同时保留主 slogan：

```text
用生活记录学习语言。
Learn languages from your life.
```

但调研也指出：SwiftUI 阅读交互、长文本性能、导入 preflight、词典查询、CJK / RTL 手动选词、source anchor stale、AI 请求边界和 reading sentence TTS source 都存在高风险。当前项目已经具备真实 AI 文本请求、真实 TTS 生成 / 播放和本地媒体派生资产基础设施，因此本次不应只做纯 UI / Core spike，而应完成一个窄范围真实纵向切片：用户导入或粘贴短文本后，可以手动选词或句子，显式触发 AI 解释，显式触发该句 TTS 播放，并把所有请求限制在当前选择和有限上下文内。

## 3. 当前现状

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift` 当前定义 iPhone 一级 Tab 为 `记录 / 练习 / 记忆`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift` 当前通过 `TabView` 承载三 Tab。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`、`PadMainSections.swift`、`MacMainView.swift`、`MacWorkspaceContentView.swift` 已有三端骨架，但没有阅读资料库或阅读详情入口。
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift` 当前 migration 到 `v11_add_ai_provider_endpoint_validation_summary`，没有 reading schema。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift` 当前 `TTSSentenceSource` 覆盖已有句子来源，尚无 reading document source。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift` 已能通过 OpenAI-compatible chat / responses endpoint 发起真实结构化文本请求，但该 service 面向 Entry / LearningMaterial，不应直接复用为阅读解释语义。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPClient.swift` 已提供 production-safe `AIProviderHTTPClient`；阅读 AI 能力应优先使用该通用 client，而不是在 SwiftUI View 里创建 `URLSession`。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift` 已通过 `SentenceAudioPlaybackCoordinator` 串联 TTS availability、Keychain secret resolver、media artifact cache、generation service 和 playback source resolver。
- `docs/architecture/notes/2026-05-25-dictionary-feature-extension-notes.md` 已记录词典能力边界，要求不要把词典做成独立词库产品。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md` 和 `2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` 已记录 TTS / media artifact 的长期边界。
- `docs/reference/research/2026-06-01-reading-integration-assessment.md` 原建议先做 research spike，再进入阅读 MVP；本方案根据用户补充要求，将 spike 升级为包含真实 AI/TTS 的窄范围纵向切片。
- `docs/spec/002-navigation-and-routing.md` 当前仍固定三 Tab。结合阅读调研和早期重构原则，该规范已落后于新的产品判断；如果实施本方案，不能只在代码里偷加入口，应先把规范更新为 `记录 / 阅读 / 练习 / 记忆` 的正式路线，并明确本轮只交付阅读最小闭环而不是完整书库。

## 4. 目标

1. 将阅读从隐藏或二级原型入口提升为正式一级学习场景的工程入口：
   - 产品主参考更新一句话定位和双来源学习对象。
   - 导航规范更新 iPhone 长期主 Tab 为 `记录 / 阅读 / 练习 / 记忆`。
   - 页面清单记录三端阅读 route、当前能力边界和未实现能力。
2. 验证三端阅读交互路线：
   - iPhone：正文单栏，点词或选句后出现 bottom sheet。
   - iPad：正文和 inspector 可并列。
   - macOS：资料库 / 正文 / inspector 有可扩展布局模型，支持键盘或工具栏意图。
3. 验证 10k 字级文本能按 chunk 形成稳定 presentation model，不在单个 SwiftUI body 中构建完整 token tree。
4. 验证 pasted text、`.txt`、`.md` 的导入 preflight 规则，包括空内容、编码失败、超限文件和 size gate。
5. 验证 100k 词条本地 exact lookup 的纯 Swift 索引可行性，为后续 GRDB normalized index 设计提供阈值输入；本次不做真实词典导入 UI。
6. 验证手动选择对英文、带重音拉丁文、CJK、日语和 RTL 文本不会依赖英文空格分词。
7. 验证 `source anchor` 能在 document revision / structure version 变化时表达 stale，而不是静默指向错误文本。
8. 为阅读 selection explanation 接入真实 AI Provider 请求链路：用户显式点击后，只发送 selection、句子和有限上下文，不自动发送全文。
9. 为 reading sentence TTS 接入真实 TTS 生成 / cache / playback 链路：用户显式点击句子播放时使用 `readingDocumentSentence` source，不复用 learning material source。
10. 产出 feature evidence 文档，记录测试结果、阈值建议、AI/TTS 隐私边界和后续 MVP 拆分建议。

## 5. 范围

本任务做：

- 新增 Core 层阅读模型、导入 preflight、分段分句 contract、词典 lookup index、source anchor stale 判定、AI selection explanation request / result、reading TTS source contract。
- 新增 Data 层 Reading domain 基础 schema、migration、repository 和非敏感 operation summary，只支持短文本 / Markdown inline body，但表结构必须覆盖 document、structure block / sentence、position、source anchor、import operation、AI explanation operation 的长期扩展点。
- 新增 AI 层 reading selection explanation service、Prompt Registry 文档、结构化输出解析、错误分类和日志脱敏测试。
- 扩展 TTS source / media artifact 映射，使 reading sentence TTS 使用独立 source key、owner 和 cache key。
- 新增 UI 层 reading presentation model、三端正式 reading route、AI explanation action 和 sentence TTS action；iPhone 顶层导航在用户批准实施后改为 `记录 / 阅读 / 练习 / 记忆`。
- 更新产品主参考、导航规范、页面清单、AI / Data / TTS spec 和新增 Reading 领域规范，使开发文档与新的应用级设计一致。
- 新增聚焦单元测试，覆盖导入、格式识别、编码失败、分段、lookup、selection、anchor stale、AI request contract、TTS source key、三端 presentation state。
- 新增 `docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md` 记录证据和结论。

本任务不做：

- 不做完整阅读资料库、分组、搜索、删除恢复和批量管理。
- 不做完整词典导入 UI，不落 `GRDBDictionaryRepository`。
- 不把四 Tab 改动和完整资料库混为一件事；本轮只交付一级入口 shell、导入 / 阅读 / 选择 / AI / TTS 的最小闭环。
- 不自动触发 AI explanation；只允许用户显式点击 selection explanation。
- 不自动触发 TTS；只允许用户显式点击句子播放。
- 不实现 EPUB、PDF、HTML、网页抓取、MDX、StarDict、Lingvo DSL。
- 不内置版权词典。
- 不做同步、可恢复备份、StoreKit、全文 AI 总结、全文翻译、批量 TTS、后台播放或锁屏控制。

## 6. 证据与决策依据

- `docs/reference/research/2026-06-01-reading-integration-assessment.md`：
  - 阅读应作为长期一级学习场景。
  - 主 slogan 保留，不在 slogan 中枚举阅读。
  - 实施上先验证窄范围纵向切片，再进入完整 MVP，再单独导航变更。
  - VMark 可借鉴格式注册表、大文件打开管线、文档状态单元、command bus、service tier 和 selection context，不复制跨栈实现。
- `docs/spec/002-navigation-and-routing.md`：当前 iPhone 顶层 Tab 仍是三 Tab；结合阅读调研和早期重构原则，本方案认为该规范应在本 feature 实施前同步修订，而不是让代码继续迁就旧临时信息架构。
- `docs/spec/004-swiftui-architecture.md`：三端共享业务逻辑，但 UI 按设备分别设计；View 不直接创建 repository。
- `docs/decisions/005-local-first-and-user-owned-providers.md`：阅读纵向切片不应引入默认外部请求或官方托管内容；真实 AI/TTS 必须由用户显式触发并使用用户自带 Provider。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：主数据、派生数据、附件、导出和 migration 需要明确边界。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：阅读 AI 解释属于真实 AI 能力，必须显式触发、请求预览、日志脱敏、Keychain 分层。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：TTS source 和 artifact policy 不能混淆来源。
- `docs/workflows/add-ai-provider.md`：新增 AI 能力必须写清发送内容、Provider 配置、请求日志、失败恢复和 Prompt Registry。
- `docs/workflows/add-tts-provider.md`：新增逐句播放能力必须写清固定 / 用户文本边界、TTS endpoint、voice profile、cache invalidation、取消和 media artifact policy。
- `docs/architecture/notes/2026-05-25-dictionary-feature-extension-notes.md`：词典是学习闭环工具，不是独立词典产品；查询日志不能记录完整隐私文本。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`：媒体派生资产必须有 owner、policy 和清理边界；本任务复用既有 TTS 音频 artifact，不新增导出、同步或备份承诺。

## 7. 约束映射与验证路径

### 7.1 阅读是一级学习场景，本轮应同步修订应用级导航

- 来源：`docs/reference/research/2026-06-01-reading-integration-assessment.md` 第 1、5、13 节。
- 约束：阅读已经被确认是长期一级学习场景。早期开发阶段不应为了迁就三 Tab 临时骨架，把阅读藏到“记录”或“记忆”二级入口中形成新的技术债。
- 约束：本方案仍不做完整阅读 MVP，但应把正式信息架构更新为 `记录 / 阅读 / 练习 / 记忆`，并让三端都有明确 reading route。iPhone 修改 `PhoneRootTab`，iPad / macOS 修改 sidebar / workspace selection；平台外壳不同，业务 action seam 共享。
- 验证方式：实施前更新 `docs/product-main-reference.md`、`docs/spec/002-navigation-and-routing.md` 和 `docs/platform-page-inventory.md`；实施后测试 `PhoneRootTab.allCases` 包含 `.reading` 且顺序为 `entries / reading / practice / memory`。
- 阻塞判断：若用户不同意本轮改导航，则本方案不能按当前形态进入实现，应拆回“reading infrastructure without top-level route”并明确这是临时过渡，不得伪装成长期设计。

### 7.2 本地优先与隐私边界

- 来源：ADR-005、`docs/spec/005-ai-provider-prompt-and-privacy.md`、调研文档第 7.5 节。
- 约束：本任务会发送用户选中的阅读文本到用户自带 AI Provider，但只能在用户显式点击“AI 解释”后发送 selection、所在句子、有限上下文、目标语言、母语和 Prompt id/version；不得在导入、打开阅读页、滚动、选中、保存或播放 TTS 时自动发送。
- 约束：请求预览必须展示将发送的 selection 和上下文范围；诊断日志、operation summary 和测试输出不得记录完整 selection、完整句子、完整上下文、响应体、API Key、Authorization header 或完整 Provider URL。
- 验证方式：AI service 测试检查 request body 包含 selection-only payload、Prompt id/version 和有限上下文；UI store 测试检查只有显式 action 才调用 AI；源码检索 `URLSession` 不出现在 SwiftUI View。
- 阻塞判断：若需要全文总结、全文翻译、历史记忆摘要或附件摘要，必须拆成独立 AI plan。
- 证据保留：`docs/reference/research/spikes/` 只能保存合成文本摘要、测试命令、阈值和结论；不得保存真实用户阅读材料、真实词典内容、AI 请求体或响应体。

### 7.3 数据边界

- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md`、调研文档第 6 节。
- 约束：本任务允许新增 Reading domain 基础 schema。虽然 UI 只开放短文本 / Markdown inline body，schema 不应被设计成一次性 demo；必须覆盖 document、structure block、sentence、position、source anchor、import operation、AI explanation operation summary 和后续 managed file body 的扩展位。
- 约束：阅读文档是主数据，必须归属 `LanguageSpace`，有 stable id、body hash、content revision、structure version、soft delete、import status、source kind、body storage kind、target language code、UTC 时间戳和 active 查询边界。position 默认 device scoped；source anchor 不得只靠 sentence index。
- 验证方式：`AppDatabaseTests` 必须覆盖新 migration 空库、旧库迁移、重复 migrator、外键、CHECK、唯一索引、soft delete active 查询、position device scope、source anchor stale 输入字段和 operation summary 不含原文。
- 阻塞判断：若需要 managed file body、全文搜索、dictionary import table、export manifest 或 sync state，必须拆成后续 feature plan。

### 7.4 三端 UI 边界

- 来源：`docs/spec/004-swiftui-architecture.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`。
- 约束：UI 使用 presentation model 和 SwiftUI view；平台差异在 UI 层，选择、lookup、anchor 判定在 Core / store 层。
- 验证方式：UI tests 检查 iPhone / iPad / macOS layout model，不靠截图作为唯一证据。
- 阻塞判断：若 View 直接持有 SQLite / Provider concrete，必须重写。

### 7.5 词典边界

- 来源：`docs/architecture/notes/2026-05-25-dictionary-feature-extension-notes.md`。
- 约束：本任务只验证本地 exact lookup index，不做真实词典导入、不内置词库、不做外部词典 App 跳转。
- 验证方式：fixtures 为合成 100k 词条；无版权词典文件进入仓库。
- 阻塞判断：如需真实词典格式，先新建 dictionary import plan。

### 7.6 真实 TTS 边界

- 来源：`docs/spec/011-tts-provider-configuration-and-playback.md`、`docs/workflows/add-tts-provider.md`、`docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`。
- 约束：reading sentence TTS 只能由用户点击句子播放触发；必须复用 `SentenceAudioPlaybackCoordinator`、TTS availability、Keychain secret resolver、media artifact cache 和 playback source resolver。
- 约束：reading source 必须独立于 `.entry`、`.learningMaterialSentence` 和 `.temporary`，建议新增 `TTSSentenceSource.readingDocumentSentence(documentID:sentenceID:)`，并同步 Data source columns 与 artifact key canonical representation。
- 验证方式：Core 测试验证 reading source canonical key 不与 learning material key 冲突；Data media artifact 测试验证 source columns round-trip；UI store 测试验证打开阅读页不触发 TTS，只有句子播放 action 调用 coordinator。
- 阻塞判断：批量预生成、全文朗读、后台播放、锁屏控制和音频同步不在本任务内。

### 7.7 Evidence 和 fixture 边界

- 来源：`docs/plans/README.md` 对 spike / probe / fixture / evidence 的要求。
- 约束：本任务的 fixture 必须在测试代码中动态生成或使用短合成字符串；不得提交大体积 fixture 文件。
- 验证方式：`git status --short` 和 `find docs/reference/research/spikes -type f -maxdepth 1 -print` 检查新增内容；如新增 fixture 文件，必须在本方案实施记录说明大小、内容来源、保留原因和清理条件。
- 阻塞判断：如果需要保留真实样本文档或真实词典，必须先取得用户确认并新增隐私 / 版权边界说明。

### 7.8 开发文档沉淀边界

- 来源：`docs/README.md` 第 1.2、1.3、6 节，以及用户 2026-06-01 追加原则。
- 约束：本任务如果实施，不能只修改代码和 evidence。凡是形成长期规则的内容，必须写回当前事实源：产品定位写回产品主参考，导航写回导航 spec，Reading domain 数据 / 交互 / AI / TTS 边界写回新增 Reading spec 或既有 AI / Data / TTS spec。
- 约束：研究文档和 active plan 不能成为后续实现长期依赖的唯一事实源。实现完成后，后续 AI 会话应能只通过入口文档、spec、architecture、workflow 和实现地图理解 Reading domain。
- 验证方式：最终文档影响检查必须确认新旧事实源没有混用；`docs/reference/research/*` 只能作为证据来源，不作为正式实现规范。
- 阻塞判断：如果实施者发现现有 spec 与更优 Reading 设计冲突，应先更新 spec 并在 active plan 实施记录中说明，不应为了减少 diff 继续遵守过期规范。

## 8. 涉及代码文件路径

预计新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingDocument.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingImport.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingDictionaryLookup.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSourceAnchor.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTTS.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingRepository.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportPreflightTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingDictionaryLookupTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSourceAnchorTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTTSArtifactKeyTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/AppDatabaseReadingMigrationTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingActions.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingStoreAIAndTTSTests.swift`
- `docs/prompts/reading/selection-explanation.md`
- `docs/spec/012-reading-learning-domain.md`

预计修改：

- `docs/product-main-reference.md`：更新一句话定位、一级学习对象和阅读作为一级学习场景的边界。
- `docs/platform-page-inventory.md`：登记三端阅读入口、当前实现状态和未实现能力。
- `docs/spec/002-navigation-and-routing.md`：将 iPhone 一级入口更新为 `记录 / 阅读 / 练习 / 记忆`，并补充三端 Reading route 承载规则。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：登记 reading selection-only AI request 边界。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：登记 ReadingDocument 主数据、source anchor、position、operation summary 和默认导出 / 同步待设计边界。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：登记 `readingDocumentSentence` source、owner 和 artifact policy。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`：新增 reading sentence source 和 canonical representation。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlayback.swift`：确认 `SentenceAudioRequest` 可承载 reading source；如需要则补充 non-sensitive summary。
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`：新增 Reading domain 基础 migration。
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`：扩展 TTS source columns round-trip 支持 reading document sentence。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`：注入 reading repository、AI explanation action、sentence audio playback action。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift`：新增 `.reading`，顺序为 `记录 / 阅读 / 练习 / 记忆`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`、`PadMainView.swift`、`MacMainView.swift`：增加正式 reading route，不复用记录详情作为伪入口。

预计新增文档：

- `docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md`
- `docs/prompts/reading/selection-explanation.md`
- `docs/spec/012-reading-learning-domain.md`

不应修改：

- 不应引入 EPUB / PDF / HTML / web import 的生产代码。
- 不应引入完整词典导入 repository、同步、导出或 StoreKit 代码。
- 不应把阅读 AI/TTS 直接写在 SwiftUI View 中。

## 9. 参考代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentenceAudioPlaybackActions.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPClient.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlayback.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackTests.swift`

## 10. 涉及文档路径

- `docs/reference/research/2026-06-01-reading-integration-assessment.md`
- `docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md`
- `docs/product-main-reference.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/workflows/add-ai-provider.md`
- `docs/workflows/add-tts-provider.md`
- `docs/prompts/README.md`
- `docs/architecture/notes/2026-05-25-dictionary-feature-extension-notes.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`

## 11. 实施方案

### 11.1 阶段 0：确认空白边界

- [ ] **Step 0.1：确认没有既有 reading active plan**

运行：

```bash
rg -n "reading|阅读" docs/plans/active docs/plans/done --glob '*.md'
```

预期：

- 只能命中本方案、既有调研引用或无关“阅读”普通词。
- 若存在同一 reading AI/TTS vertical slice active plan，停止并合并方案。

- [ ] **Step 0.2：确认本轮导航升级授权和规范更新范围**

运行：

```bash
git diff -- docs/product-main-reference.md docs/platform-page-inventory.md docs/spec/002-navigation-and-routing.md Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift
```

预期：

- 实施前可为空；如已有用户变更，必须阅读并合并，不得回退。
- 用户批准本方案实施后，上述文件应出现受控 diff：产品定位、导航规范、页面清单和 `PhoneRootTab` 同步进入四入口形态。
- 若用户只批准继续完善方案而未批准实现，不能修改生产代码。

- [ ] **Step 0.3：确认 Reading domain spec 写入路径**

创建或更新：`docs/spec/012-reading-learning-domain.md`

预期：

- spec 在代码实现前先定义 ReadingDocument、ReadingStructure、ReadingSourceAnchor、ReadingPosition、Reading AI explanation 和 Reading TTS source 的长期一致性边界。
- 若实施中发现 spec 与代码更优设计冲突，先更新 spec，再继续代码。

### 11.2 阶段 1：Core 导入 preflight

- [ ] **Step 1.1：写失败测试 `ReadingImportPreflightTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportPreflightTests.swift`

测试应覆盖：

```swift
import Foundation
import Testing
@testable import LangoTraceCore

@Suite("Reading import preflight")
struct ReadingImportPreflightTests {
    @Test("empty pasted text is rejected before document creation")
    func emptyPastedTextIsRejected() {
        let result = ReadingImportPreflight.evaluatePastedText(
            "   ",
            limits: .verticalSliceDefaults
        )

        #expect(result.decision == .reject(.emptyContent))
    }

    @Test("long pasted text is accepted with long text warning below hard limit")
    func longPastedTextProducesWarning() {
        let text = String(repeating: "Language learning sentence. ", count: 700)

        let result = ReadingImportPreflight.evaluatePastedText(
            text,
            limits: .init(longTextCharacterThreshold: 10_000, hardCharacterLimit: 50_000, hardByteLimit: 200_000)
        )

        #expect(result.decision == .accept)
        #expect(result.warnings.contains(.longText))
        #expect(result.characterCount == text.count)
    }

    @Test("file metadata above hard byte limit is rejected before reading bytes")
    func hardByteLimitRejectsBeforeRead() {
        let result = ReadingImportPreflight.evaluateFileMetadata(
            filename: "book.txt",
            byteSize: 2_000_001,
            limits: .init(longTextCharacterThreshold: 10_000, hardCharacterLimit: 50_000, hardByteLimit: 2_000_000)
        )

        #expect(result.decision == .reject(.fileTooLarge))
        #expect(result.shouldReadFileBody == false)
    }

    @Test("txt and markdown files are supported while other extensions are rejected")
    func supportedExtensionsAreExplicit() {
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "note.txt", byteSize: 32, limits: .verticalSliceDefaults).decision == .accept)
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "article.md", byteSize: 32, limits: .verticalSliceDefaults).decision == .accept)
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "book.epub", byteSize: 32, limits: .verticalSliceDefaults).decision == .reject(.unsupportedFormat))
    }

    @Test("invalid text bytes fail as encoding failure")
    func invalidTextBytesFailAsEncodingFailure() {
        let invalid = Data([0xFF, 0xFE, 0x00, 0xD8])

        let result = ReadingImportPreflight.decodeTextData(
            invalid,
            filename: "broken.txt",
            limits: .verticalSliceDefaults
        )

        #expect(result.decision == .reject(.encodingFailed))
        #expect(result.text == nil)
    }
}
```

- [ ] **Step 1.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingImportPreflightTests
```

预期：

- 失败原因包含 `cannot find 'ReadingImportPreflight' in scope` 或等价未定义类型错误。

- [ ] **Step 1.3：实现最小 Core preflight 模型**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingImport.swift`

实现要点：

- `ReadingImportPreflightLimits`
- `ReadingImportPreflightResult`
- `ReadingImportPreflightDecision`
- `ReadingImportPreflightWarning`
- `ReadingImportPreflightFailure`
- `ReadingImportPreflightLimits.verticalSliceDefaults`
- `ReadingImportPreflight.evaluatePastedText`
- `ReadingImportPreflight.evaluateFileMetadata`
- `ReadingImportPreflight.decodeTextData`

边界：

- pasted text 可以读取字符串，但必须先 trim 判断空。
- file metadata 检查不得读取文件内容。
- `.txt` 和 `.md` 是本任务唯一允许文件扩展名。
- decode 只支持 UTF-8 和 UTF-16 的 best-effort；失败返回 `.encodingFailed`。
- 不解析 EPUB / PDF / HTML。

- [ ] **Step 1.4：运行 Core preflight 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingImportPreflightTests
```

预期：通过。

### 11.3 阶段 2：Core 分段、分句和选择模型

- [ ] **Step 2.1：写失败测试 `ReadingTextSegmentationTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading text segmentation")
struct ReadingTextSegmentationTests {
    @Test("paragraph chunks preserve character ranges")
    func paragraphChunksPreserveRanges() {
        let text = "First sentence.\n\nSecond paragraph has two sentences. Another one."

        let chunks = ReadingTextSegmenter.segmentParagraphs(
            text,
            documentID: "doc-1",
            contentRevision: 3
        )

        #expect(chunks.count == 2)
        #expect(chunks[0].range.lowerBound == text.startIndex)
        #expect(String(text[chunks[0].range]).contains("First sentence."))
        #expect(chunks[1].contentRevision == 3)
    }

    @Test("manual selection does not require whitespace tokenization")
    func selectionSupportsCJKAndRTL() {
        let text = "今日は図書館で読みます。 שלום עולם"
        let selection = ReadingSelection(
            documentID: "doc-1",
            contentRevision: 1,
            selectedText: "図書館",
            contextText: text,
            characterOffset: 3
        )

        #expect(selection.selectedText == "図書館")
        #expect(selection.contextText.contains("שלום"))
    }

    @Test("manual selection records character range for later anchoring")
    func selectionRecordsCharacterRange() {
        let text = "Read this sentence carefully."
        let start = text.firstIndex(of: "s")!
        let end = text.index(start, offsetBy: 8)
        let selection = ReadingSelection(
            documentID: "doc-1",
            contentRevision: 1,
            selectedText: String(text[start..<end]),
            contextText: text,
            characterOffset: text.distance(from: text.startIndex, to: start),
            characterLength: text.distance(from: start, to: end)
        )

        #expect(selection.selectedText == "sentence")
        #expect(selection.characterOffset > 0)
        #expect(selection.characterLength == 8)
    }
}
```

- [ ] **Step 2.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentationTests
```

预期：失败原因包含 `ReadingTextSegmenter` 或 `ReadingSelection` 未定义。

- [ ] **Step 2.3：实现分段和选择模型**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`

实现要点：

- `ReadingTextChunk`
- `ReadingSelection`
- `ReadingTextSegmenter.segmentParagraphs`
- 用 paragraph chunk 作为首版粒度，不承诺自动 tokenization。
- `ReadingSelection` 由 UI 手动选择产生，不依赖英文空格。
- `ReadingSelection` 必须保存 `characterOffset` 和 `characterLength`，为后续 source anchor 提供最小可验证输入。

- [ ] **Step 2.4：运行测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentationTests
```

预期：通过。

### 11.4 阶段 3：100k 词典 exact lookup 验证

- [ ] **Step 3.1：写失败测试 `ReadingDictionaryLookupTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingDictionaryLookupTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading dictionary lookup")
struct ReadingDictionaryLookupTests {
    @Test("exact lookup uses normalized form and language code")
    func exactLookupUsesNormalization() {
        let entries = [
            ReadingDictionaryEntry(headword: "Résumé", normalizedHeadword: "resume", languageCode: "fr", definition: "summary"),
            ReadingDictionaryEntry(headword: "resume", normalizedHeadword: "resume", languageCode: "en", definition: "continue")
        ]
        let index = ReadingDictionaryLookupIndex(entries: entries)

        #expect(index.exactLookup("résumé", languageCode: "fr").first?.definition == "summary")
        #expect(index.exactLookup("resume", languageCode: "en").first?.definition == "continue")
    }

    @Test("synthetic 100k lookup returns deterministic result")
    func syntheticLargeLookup() {
        let entries = (0..<100_000).map { index in
            ReadingDictionaryEntry(
                headword: "word\(index)",
                normalizedHeadword: "word\(index)",
                languageCode: "en",
                definition: "definition \(index)"
            )
        }

        let lookup = ReadingDictionaryLookupIndex(entries: entries)

        #expect(lookup.exactLookup("word99999", languageCode: "en").first?.definition == "definition 99999")
        #expect(lookup.exactLookup("missing", languageCode: "en").isEmpty)
    }
}
```

- [ ] **Step 3.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingDictionaryLookupTests
```

预期：失败原因包含 `ReadingDictionaryLookupIndex` 未定义。

- [ ] **Step 3.3：实现纯内存 lookup index**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingDictionaryLookup.swift`

实现要点：

- `ReadingDictionaryEntry`
- `ReadingDictionaryLookupKey`
- `ReadingDictionaryLookupIndex`
- key 由 `languageCode + normalizedHeadword` 组成。
- 仅用于本任务的本地 lookup 验证，不作为正式词典 repository。

- [ ] **Step 3.4：运行 lookup 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingDictionaryLookupTests
```

预期：通过。

### 11.5 阶段 4：Source anchor stale 判定

- [ ] **Step 4.1：写失败测试 `ReadingSourceAnchorTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSourceAnchorTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading source anchors")
struct ReadingSourceAnchorTests {
    @Test("anchor is current when revision and selected text hash match")
    func anchorCurrentWhenRevisionAndHashMatch() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a"
        )
        let state = anchor.resolve(
            currentRevision: 4,
            currentSelectedTextHash: "hash-a"
        )

        #expect(state == .current)
    }

    @Test("anchor is stale when revision changes")
    func anchorStaleWhenRevisionChanges() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a"
        )

        #expect(anchor.resolve(currentRevision: 5, currentSelectedTextHash: "hash-a") == .stale(.revisionChanged))
    }

    @Test("anchor is stale when selected text hash changes")
    func anchorStaleWhenHashChanges() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a"
        )

        #expect(anchor.resolve(currentRevision: 4, currentSelectedTextHash: "hash-b") == .stale(.selectedTextChanged))
    }
}
```

- [ ] **Step 4.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingSourceAnchorTests
```

预期：失败原因包含 `ReadingSourceAnchor` 未定义。

- [ ] **Step 4.3：实现 anchor 判定模型**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSourceAnchor.swift`

实现要点：

- `ReadingSourceAnchor`
- `ReadingSourceAnchorResolution`
- `ReadingSourceAnchorStaleReason`
- revision 不匹配优先返回 stale。
- revision 匹配但 hash 不匹配也返回 stale。

- [ ] **Step 4.4：运行 anchor 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingSourceAnchorTests
```

预期：通过。

### 11.6 阶段 5：UI presentation model 和三端 layout

- [ ] **Step 5.1：写失败测试 `ReadingPresentationTests`**

创建：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceUI

@Suite("Reading presentation")
struct ReadingPresentationTests {
    @Test("phone uses single column and bottom sheet inspector")
    func phoneLayoutUsesBottomSheetInspector() {
        let model = ReadingLayoutModel.platform(.phone)

        #expect(model.primaryColumnCount == 1)
        #expect(model.inspectorPresentation == .bottomSheet)
    }

    @Test("pad uses reading body plus side inspector")
    func padLayoutUsesSideInspector() {
        let model = ReadingLayoutModel.platform(.pad)

        #expect(model.primaryColumnCount == 2)
        #expect(model.inspectorPresentation == .sidePanel)
    }

    @Test("mac supports library body and inspector columns")
    func macLayoutSupportsThreeColumns() {
        let model = ReadingLayoutModel.platform(.mac)

        #expect(model.primaryColumnCount == 3)
        #expect(model.inspectorPresentation == .sidePanel)
    }

    @Test("selection opens inspector without mutating document chunks")
    func selectionOpensInspector() {
        var state = ReadingPresentationState(
            layout: .platform(.phone),
            chunks: [
                .init(id: "chunk-1", text: "A short sentence for lookup.")
            ]
        )

        state.selectText("sentence", inChunkID: "chunk-1")

        #expect(state.selectedText == "sentence")
        #expect(state.isInspectorPresented)
        #expect(state.chunks.map(\.text) == ["A short sentence for lookup."])
    }
}
```

- [ ] **Step 5.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
```

预期：失败原因包含 `ReadingLayoutModel` 未定义。

- [ ] **Step 5.3：实现 UI presentation model**

创建：`Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`

实现要点：

- `ReadingPlatformRole`
- `ReadingInspectorPresentation`
- `ReadingLayoutModel`
- `ReadingDocumentPresentation`
- `ReadingChunkPresentation`
- `ReadingPresentationState`
- 不依赖 Data repository。
- 不依赖旧记录详情 route。

- [ ] **Step 5.4：添加 SwiftUI reading route view**

创建：`Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`

实现要点：

- `ReadingPreviewView`
- `ReadingBodyView`
- `ReadingInspectorView`
- View 只接收 presentation model 和 sample chunks。
- 本阶段可以先使用 sample chunks 验证 view contract；最终必须在阶段 10 接入正式 reading route 和 store。

- [ ] **Step 5.5：运行 UI 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
```

预期：通过。

### 11.7 阶段 6：10k 字长文本和 chunk 数量验证

- [ ] **Step 6.1：补充分段性能形态测试**

修改：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`

新增测试：

```swift
@Test("10k character text is chunked instead of represented as one view unit")
func tenThousandCharacterTextIsChunked() {
    let paragraph = String(repeating: "This is a language learning sentence. ", count: 25)
    let text = Array(repeating: paragraph, count: 16).joined(separator: "\n\n")

    let chunks = ReadingTextSegmenter.segmentParagraphs(
        text,
        documentID: "doc-long",
        contentRevision: 1
    )

    #expect(text.count > 10_000)
    #expect(chunks.count == 16)
    #expect(chunks.allSatisfy { !$0.text.isEmpty })
}
```

- [ ] **Step 6.2：运行分段测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentationTests
```

预期：通过。

### 11.8 阶段 7：Data Reading domain 基础 schema 与 repository

- [ ] **Step 7.1：写失败测试 `AppDatabaseReadingMigrationTests`**

创建：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/AppDatabaseReadingMigrationTests.swift`

测试应覆盖：

```swift
import GRDB
import Testing
@testable import LangoTraceData

@Suite("Reading database migration")
struct AppDatabaseReadingMigrationTests {
    @Test("empty database migrates reading tables")
    func emptyDatabaseMigratesReadingTables() throws {
        let database = try AppDatabase.inMemory()

        let tableNames = try database.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        }

        #expect(tableNames.contains("reading_documents"))
        #expect(tableNames.contains("reading_structure_blocks"))
        #expect(tableNames.contains("reading_sentences"))
        #expect(tableNames.contains("reading_source_anchors"))
        #expect(tableNames.contains("reading_import_operations"))
        #expect(tableNames.contains("reading_ai_explanation_operations"))
    }

    @Test("reading operation summary does not require raw text columns")
    func operationSummaryHasNoRawTextColumns() throws {
        let database = try AppDatabase.inMemory()

        let columns = try database.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(reading_ai_explanation_operations)")
                .map { row in row["name"] as String }
        }

        #expect(!columns.contains("selected_text"))
        #expect(!columns.contains("context_text"))
        #expect(!columns.contains("response_body"))
        #expect(!columns.contains("request_body"))
    }
}
```

- [ ] **Step 7.2：运行迁移测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceData --filter AppDatabaseReadingMigrationTests
```

预期：失败原因包含缺少 `reading_documents` 或 `reading_ai_explanation_operations`。

- [ ] **Step 7.3：新增 Reading domain 基础 migration**

修改：`Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`

新增 migration 建议命名：

```swift
v12_create_reading_domain_infrastructure
```

基础表范围：

- `reading_documents`
  - `id`
  - `space_id`
  - `title`
  - `source_kind`
  - `body_storage_kind`
  - `body`
  - `source_metadata_json`
  - `body_hash`
  - `content_revision`
  - `structure_version`
  - `target_language_code`
  - `import_status`
  - `created_at`
  - `updated_at`
  - `soft_deleted_at`
- `reading_structure_blocks`
  - `id`
  - `document_id`
  - `block_index`
  - `kind`
  - `text_hash`
  - `character_start`
  - `character_end`
  - `structure_version`
- `reading_sentences`
  - `id`
  - `document_id`
  - `block_id`
  - `sentence_index`
  - `text`
  - `text_hash`
  - `character_start`
  - `character_end`
  - `structure_version`
- `reading_positions`
  - `document_id`
  - `device_scope`
  - `block_id`
  - `sentence_id`
  - `character_offset`
  - `updated_at`
- `reading_source_anchors`
  - `id`
  - `document_id`
  - `source_revision`
  - `structure_version`
  - `block_id`
  - `sentence_id`
  - `character_start`
  - `character_end`
  - `selected_text_hash`
  - `created_at`
- `reading_import_operations`
  - `id`
  - `operation_id`
  - `space_id`
  - `document_id`
  - `source_kind`
  - `source_format`
  - `status`
  - `failure_category`
  - `character_count_bucket`
  - `byte_count_bucket`
  - `created_at`
  - `completed_at`
- `reading_ai_explanation_operations`
  - `id`
  - `operation_id`
  - `space_id`
  - `document_id`
  - `anchor_id`
  - `source_kind`
  - `status`
  - `failure_category`
  - `selection_length_bucket`
  - `context_length_bucket`
  - `provider_preset_id`
  - `adapter_kind`
  - `model_name`
  - `duration_ms`
  - `created_at`
  - `completed_at`

约束：

- `reading_documents.space_id` 外键到 `language_spaces.id`。
- `reading_structure_blocks.document_id` 外键到 `reading_documents.id`。
- `reading_sentences.document_id` 外键到 `reading_documents.id`。
- `reading_sentences.block_id` 外键到 `reading_structure_blocks.id`。
- `reading_positions.document_id` 外键到 `reading_documents.id`。
- `reading_source_anchors.document_id` 外键到 `reading_documents.id`。
- `reading_ai_explanation_operations.anchor_id` 外键到 `reading_source_anchors.id`，允许为空以表达 preflight 或失败前未形成 anchor 的情况。
- `reading_import_operations` 和 `reading_ai_explanation_operations` 不含原文、请求体、响应体和密钥。
- CHECK 必须限制 `source_kind`、`body_storage_kind`、`import_status`、operation `status`、`device_scope` 和 failure category 的已知取值；未来新增取值必须伴随 migration / spec 更新。
- 唯一索引至少覆盖 active document 查询、`document_id + block_index + structure_version`、`document_id + sentence_index + structure_version` 和 `operation_id`。

- [ ] **Step 7.4：写失败测试 `GRDBReadingRepositoryTests`**

创建：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingRepositoryTests.swift`

测试应覆盖：

- 保存 pasted text document 后可按 `space_id` 查询 active documents。
- 软删除后 active 查询不返回。
- 保存 structure blocks 和 sentences 后可按 document 读取且保留 `structure_version`。
- 保存 source anchor 后可通过 document revision / structure version / hash 判定 current 或 stale。
- 写入 import operation summary 和 AI explanation operation summary 不保存原文。
- 切换 language space 后不会读到其他空间文档。
- 同一个 `operation_id` 重复写入不能产生多条 summary。

- [ ] **Step 7.5：实现 `GRDBReadingRepository`**

创建：`Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingRepository.swift`

实现要点：

- 不把 repository 暴露给 SwiftUI View 直接使用。
- 事务内保存 document + structure blocks + sentences。
- `body_hash` 和 sentence `text_hash` 用 Core hash helper 或 Data 内部 helper 统一生成。
- operation summary 只写 length bucket、provider metadata 和 failure category。
- soft delete document 时，active document、position 和可见 sentence 查询都必须排除 deleted document；source anchor 不物理删除，以便后续 memory / practice 引用能表达 stale / unavailable。

- [ ] **Step 7.6：运行 Data 聚焦测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceData --filter Reading
swift test --package-path Packages/LangoTraceData --filter AppDatabaseTests
```

预期：通过。

### 11.9 阶段 8：真实 AI selection explanation

- [ ] **Step 8.1：创建 Prompt Registry 文档**

创建：`docs/prompts/reading/selection-explanation.md`

必填内容：

- Prompt id：`reading.selection_explanation.v1`
- Prompt version：`2026-06-01`
- 所属功能：阅读选词 / 选句 AI 解释
- 调用模块：`LangoTraceAI.ReadingSelectionExplanationService`
- 输入变量：selection、sentence、limitedContextBefore、limitedContextAfter、targetLanguageCode、nativeLanguageCode、languageLevel
- 输出契约：JSON object，字段至少包含 `schema_version`、`summary`、`meaning`、`usage_notes`、`examples`、`confidence`
- 隐私边界：包含用户选择的阅读文本和有限上下文；不包含全文、照片、音频、OCR、历史记忆、附件摘要或 API Key
- 用户触发条件：用户点击 AI 解释按钮
- 请求预览要求：显示 selection、上下文范围、Provider profile 和模型
- 日志允许字段：operation id、长度分桶、provider preset id、adapter kind、model name、failure category、duration bucket

- [ ] **Step 8.2：写失败测试 `ReadingSelectionExplanationServiceTests`**

创建：`Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`

测试应覆盖：

- OpenAI-compatible chat request 只包含 selection、sentence、limited context，不包含 document full body。
- Responses API request 使用同一 schema。
- 返回 JSON 缺字段、非法 confidence、额外字段时拒绝。
- HTTP 401 映射 authentication failure。
- 429 映射 rate limited 或 quota failure。
- 取消映射 cancelled，且不写 failed operation summary。

- [ ] **Step 8.3：创建 Core AI explanation contract**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`

模型建议：

- `ReadingSelectionExplanationRequest`
- `ReadingSelectionExplanationInput`
- `ReadingSelectionExplanationResult`
- `ReadingSelectionExplanationFailure`
- `ReadingAIExplanationOperationSummary`
- `ReadingAIExplanationLengthBucket`

约束：

- request 中可以包含 selection 和 limited context。
- summary 中只能含分桶和 provider metadata。

- [ ] **Step 8.4：实现 `ReadingSelectionExplanationService`**

创建：`Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`

实现要点：

- 使用 `AIProviderHTTPClient`，不要用 probe-only 命名的 client。
- 支持 `.openAICompatibleChat` 和 `.openAIResponses`。
- 不支持 Anthropic / Gemini 时返回 `.unsupportedProvider`，不伪装成网络错误。
- 请求体遵守 Prompt Registry。
- parser 拒绝自然语言前后缀、缺字段、非法枚举、额外字段和过长数组。

- [ ] **Step 8.5：运行 AI 聚焦测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceAI --filter ReadingSelectionExplanationServiceTests
```

预期：通过。

### 11.10 阶段 9：真实 reading sentence TTS source

- [ ] **Step 9.1：写失败测试 `ReadingTTSArtifactKeyTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTTSArtifactKeyTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading TTS artifact key")
struct ReadingTTSArtifactKeyTests {
    @Test("reading sentence source has distinct canonical key")
    func readingSentenceSourceHasDistinctKey() {
        let reading = TTSSentenceSource.readingDocumentSentence(documentID: "doc-1", sentenceID: "sent-1")
        let material = TTSSentenceSource.learningMaterialSentence(materialID: "doc-1", sentenceIndex: 1)

        #expect(reading != material)
    }
}
```

- [ ] **Step 9.2：扩展 Core TTS source**

修改：`Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`

新增：

```swift
case readingDocumentSentence(documentID: String, sentenceID: String)
```

并更新 canonical representation：

```text
readingDocumentSentence|<documentID>|<sentenceID>
```

- [ ] **Step 9.3：扩展 Data media artifact source mapping**

修改：`Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`

要求：

- `sourceColumns(_:)` 支持 reading source。
- `ownerColumns(_:)` 如需要新增 `.readingDocument(id:)`，必须同步 Core `MediaArtifactOwner`。
- round-trip 测试覆盖 ready artifact 读取后 source 不丢失。

- [ ] **Step 9.4：扩展 Core / Data 测试**

修改：

- `Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactRepositoryTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackTests.swift`

新增断言：

- reading source artifact key hash 与 learning material source 不同。
- reading source metadata 写入 / 读取 round-trip。
- reading source 不记录 sentence text 明文到 artifact path、derivation key 或 diagnostic description。

- [ ] **Step 9.5：运行 TTS source 聚焦测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTTSArtifactKeyTests
swift test --package-path Packages/LangoTraceData --filter MediaArtifactRepositoryTests
```

预期：通过。

### 11.11 阶段 10：ReadingStore 与三端 UI action seam

- [ ] **Step 10.1：写失败测试 `ReadingStoreAIAndTTSTests`**

创建：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingStoreAIAndTTSTests.swift`

测试应覆盖：

- 初始化 store 不触发 AI。
- 导入 / 打开 document 不触发 AI。
- 选择文本不触发 AI。
- 点击 explain action 才触发 AI action，且传入 selection 和 limited context。
- 点击 sentence audio action 才触发 `SentenceAudioPlaybackActions`。
- 当前 language space 切换后 store 清空旧 document state。
- AI explanation failure 进入可恢复状态，不删除 selection。
- TTS requires configuration 展示配置需求，不自动重试。
- iPhone 顶层 tab 包含 reading，且进入 reading tab 只加载本地文档，不触发 AI / TTS。

- [ ] **Step 10.2：实现 UI actions**

创建：`Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingActions.swift`

建议：

- `ReadingAIExplanationActions`
- `ReadingSentenceAudioActions`
- `ReadingImportActions`

约束：

- action closure 由 App Shell 注入。
- View 不直接 import LangoTraceAI / LangoTraceData concrete。

- [ ] **Step 10.3：实现 `ReadingStore`**

创建：`Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingStore.swift`

职责：

- `@MainActor`
- 维护 documents、selectedText、selectedSentence、inspector state、AI explanation state、sentence audio state projection。
- 调用 repository action 保存 / 读取 document。
- 调用 AI action 解释 selection。
- 调用 sentence audio action 播放 reading sentence。
- 不持有 SQLite handle、URLSession、API Key 或真实文件路径。

- [ ] **Step 10.4：实现三端阅读视图**

创建或修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`

边界：

- iPhone：新增正式 `阅读` Tab，顺序为 `记录 / 阅读 / 练习 / 记忆`；阅读 Tab 首屏承载最小阅读资料列表、导入 / 粘贴入口和最近文档。
- iPad：可在现有 workspace / sidebar route 增加 reading route。
- macOS：可在 sidebar / toolbar 增加 reading route。
- 入口命名和可见性必须在 UI 测试中锁定，避免后续回退成隐藏入口或二级 mock。

- [ ] **Step 10.5：运行 UI 聚焦测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter Reading
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
```

预期：通过。

### 11.12 阶段 11：App assembly 与真实依赖注入

- [ ] **Step 11.1：装配 reading repository**

修改：`Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift` 或当前 App assembly 所在文件。

要求：

- 使用 `GRDBReadingRepository`。
- 按当前 language space 初始化 `ReadingStore`。
- 语言空间切换时更新 reading store space id。

- [ ] **Step 11.2：装配真实 AI explanation action**

要求：

- 从已保存 AI Provider 配置和 Keychain resolver 获取 text generation endpoint 与 secret。
- 调用 `ReadingSelectionExplanationService`。
- 写入 `reading_ai_explanation_operations` 非敏感 summary。
- Provider 未配置、credential missing、unsupported provider、network、auth、rate limit、invalid response 都映射为稳定 UI 状态。

- [ ] **Step 11.3：装配真实 TTS action**

要求：

- 构造 `SentenceAudioRequest`，source 使用 `.readingDocumentSentence(documentID:sentenceID:)`。
- owner 使用 reading document owner；如 Core 暂无 owner，新增 `.readingDocument(id:)` 并同步 Data media artifact owner columns。
- 复用 `SentenceAudioPlaybackActions.coordinator(_:)`。
- 不在页面出现、滚动或 selection 时调用 TTS。

- [ ] **Step 11.4：补 assembly 级源码测试**

若当前没有 App target 测试，至少在 UI package 增加源码级 convergence 测试，检查：

- SwiftUI View 不包含 `URLSession`。
- Reading views 不直接创建 `GRDBReadingRepository`。
- Reading views 不直接读取 Keychain。
- `PhoneRootTab` 包含 `.reading`，且 `allCases` 顺序为 `entries / reading / practice / memory`。

### 11.13 阶段 12：证据文档

- [ ] **Step 12.1：创建 feature evidence 文档**

创建：`docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md`

至少记录：

- 纵向切片日期、状态、执行命令。
- 三端 layout model 结论。
- 导入 preflight 阈值建议。
- 10k 字 chunk 测试结果。
- 100k lookup 测试结果。
- CJK / 日语 / RTL 手动选择结论。
- source anchor stale 结论。
- reading AI explanation 请求边界、Prompt id/version、请求预览和日志允许字段。
- reading sentence TTS source、artifact key、cache / playback 结果。
- 本轮是否新增 fixture 文件；若新增，记录大小、内容来源、保留理由和清理条件。
- 推荐进入 MVP 的技术路线。
- 不进入 MVP 的内容。
- `docs/spec/012-reading-learning-domain.md` 是否已经吸收本轮稳定结论。
- 是否需要后续 `feature-reading-library-and-document-management` 或 `feature-reading-dictionary-and-lexeme` active plan。

- [ ] **Step 12.2：回写本 active plan 实施记录**

修改本方案的“实施记录”章节，记录：

- 已新增 / 修改文件。
- 已运行验证命令和结果。
- 若未运行完整 `scripts/verify.sh`，说明原因。

### 11.14 阶段 13：最终验证

- [ ] **Step 13.1：运行聚焦测试**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter Reading
swift test --package-path Packages/LangoTraceData --filter Reading
swift test --package-path Packages/LangoTraceAI --filter Reading
swift test --package-path Packages/LangoTraceUI --filter Reading
```

预期：通过。

- [ ] **Step 13.2：运行 package 回归**

运行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
```

预期：通过。

- [ ] **Step 13.3：运行文档检查**

运行：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

预期：

- `scripts/check-docs.sh` 通过。
- 占位词检索无命中。
- `git diff --check` 无输出。

- [ ] **Step 13.4：运行完整验证**

本任务涉及 Data migration、AI、TTS source、App assembly 和 UI action seam，必须运行：

```bash
scripts/verify.sh
```

预期：通过；若失败，必须记录失败命令、错误摘要、是否与本任务相关、补救或阻塞状态。

## 12. TDD / 测试落点

先失败测试：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportPreflightTests.swift`
  - 首个失败原因：`ReadingImportPreflight` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`
  - 首个失败原因：`ReadingTextSegmenter` / `ReadingSelection` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingDictionaryLookupTests.swift`
  - 首个失败原因：`ReadingDictionaryLookupIndex` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSourceAnchorTests.swift`
  - 首个失败原因：`ReadingSourceAnchor` 未定义。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
  - 首个失败原因：`ReadingLayoutModel` 未定义。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/AppDatabaseReadingMigrationTests.swift`
  - 首个失败原因：缺少 `reading_documents` / `reading_structure_blocks` / `reading_source_anchors` / `reading_import_operations` / `reading_ai_explanation_operations` 表。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingRepositoryTests.swift`
  - 首个失败原因：`GRDBReadingRepository` 未定义。
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`
  - 首个失败原因：`ReadingSelectionExplanationService` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTTSArtifactKeyTests.swift`
  - 首个失败原因：`TTSSentenceSource.readingDocumentSentence` 未定义。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingStoreAIAndTTSTests.swift`
  - 首个失败原因：`ReadingStore` / `ReadingAIExplanationActions` 未定义。

聚焦验证命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter Reading
swift test --package-path Packages/LangoTraceData --filter Reading
swift test --package-path Packages/LangoTraceAI --filter Reading
swift test --package-path Packages/LangoTraceUI --filter Reading
```

完整相关 package 验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
```

完整验证：

```bash
scripts/verify.sh
```

## 13. 复查方法

实施者完成后应逐项确认：

1. 产品主参考、导航规范和页面清单已把阅读作为一级学习场景和三端 route 记录清楚。
2. `PhoneRootTab.swift` 已按方案新增 `.reading`，顺序为 `记录 / 阅读 / 练习 / 记忆`。
3. `AppDatabase.swift` 只新增本方案允许的 Reading domain 基础 migration，不夹带完整资料库、同步、导出或词典导入 schema。
4. Reading models 使用正式 `Reading` 命名，边界仍限于纵向切片，不伪装成完整阅读 MVP。
5. 所有 fixture 为合成文本，不包含真实用户文本或版权词典。
6. 词典 lookup 测试使用合成 100k entries，不提交大文件 fixture。
7. Source anchor stale 判定覆盖 revision changed 和 selected text hash changed。
8. UI presentation tests 覆盖 phone / pad / mac 三端布局差异，并覆盖 selection 后 inspector presentation state。
9. AI explanation 测试证明只有显式 action 发请求，请求不包含全文、历史记忆、附件、密钥或日志敏感字段。
10. TTS 测试证明只有显式 sentence audio action 触发，reading source artifact key 不与 entry / learning material 混淆。
11. Evidence 文档记录测试命令、结果、阈值建议、AI/TTS 边界、fixture 边界和后续任务拆分。

## 14. 验证命令

创建本方案后的文档验证：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

实施后的聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter Reading
swift test --package-path Packages/LangoTraceData --filter Reading
swift test --package-path Packages/LangoTraceAI --filter Reading
swift test --package-path Packages/LangoTraceUI --filter Reading
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
```

实施后完整验证：

```bash
scripts/verify.sh
```

## 15. 文档影响检查

本 feature 纵向切片完成后必须检查：

- `docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md`：新增 evidence，记录实际验证结果。
- `docs/reference/research/2026-06-01-reading-integration-assessment.md`：如纵向切片推翻原推荐路线，应回写修正；如只是补证据，可引用 evidence。
- `docs/prompts/README.md` 和 `docs/prompts/reading/selection-explanation.md`：登记真实 reading AI explanation Prompt。
- `docs/product-main-reference.md`：必须更新一句话定位、一级学习对象和主 slogan 保留边界。
- `docs/platform-page-inventory.md`：必须登记 iPhone / iPad / macOS 阅读 route、当前能力、未实现能力和代码路径。
- `docs/spec/002-navigation-and-routing.md`：必须更新 iPhone 一级入口为 `记录 / 阅读 / 练习 / 记忆`，并补充三端 reading route 承载规则。
- `docs/spec/012-reading-learning-domain.md`：必须新增或更新 Reading domain 规范，覆盖导入、document、structure、position、source anchor、selection AI、reading TTS、词典边界和非目标。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：必须更新阅读 selection-only AI 边界、请求预览和日志允许字段。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：必须补充 ReadingDocument 主数据、structure、source anchor、position、operation summary 和删除 / 导出 / 同步默认边界。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：必须更新 readingDocumentSentence source、reading document owner 和 artifact policy。
- `docs/spec/009-testing-and-verification.md`：若纵向切片形成稳定手动验证流程，可在 MVP 计划中更新。
- `docs/architecture/notes/`：若纵向切片发现 EPUB/PDF、source anchor、dictionary import 或 sync 边界的新风险，应新增或更新架构备忘录。
- `docs/review/README.md` 和 `docs/review/INDEX.md`：本任务涉及 Data schema、AI、TTS 和三端入口，应触发专项文档影响检查，并记录是否需要 review round。

## 16. 严格方案自审核记录

审核日期：2026-06-01

审核方式：主会话自审核。

审核轮次：双轮合并执行；2026-06-01 按用户要求根据 `docs/plans/README.md` 追加补充自审；2026-06-01 按用户要求追加真实 AI / TTS 开发范围复审。

2026-06-01 追加：按用户提出的早期开发阶段重构原则、基础设施完整建设原则和 dev docs 控制面原则再次复审。

未使用隔离审查的原因：当前用户要求立即创建 active plan 文档，且本轮不进入生产代码实现；主会话按 `docs/plans/plan-review-protocol.md` 的两轮维度完成写回。

### 第一轮：系统架构师审查

发现摘要：

- P1：如果把本任务写成完整阅读 MVP，会过早触碰完整资料库、词典导入、同步、导出和全文 AI / 批量 TTS，范围过大。
  - 写回修改：本方案定位为基础设施优先的 feature 纵向切片，只做 Reading domain 基础 schema、一级入口 shell、selection AI 和 sentence TTS，不做完整阅读 MVP。
  - 是否阻塞实现：已修正；进入完整 MVP 前仍需新方案。
- P1：阅读作为一级学习场景和现有三 Tab 存在导航张力。
  - 写回修改：初版曾不修改 `PhoneRootTab`；本次追加复审后改为用户批准实施时同步更新产品 / 导航规范 / `PhoneRootTab`，避免隐藏入口成为长期债务。
  - 是否阻塞实现：阻塞任何未获用户批准的生产代码改动；不阻塞继续完善方案。
- P1：词典和 source anchor 容易与未来正式主数据混淆。
  - 写回修改：reading document / source anchor 进入最小正式模型；词典 lookup 仍保留验证性质，不创建正式词典 repository。
  - 是否阻塞实现：不阻塞纵向切片。
- P2：VMark 参考不能变成跨栈复制。
  - 写回修改：方案只吸收 format registry、pre-read gate、document state unit、command intent 等思想，不复制代码。
  - 是否阻塞实现：不阻塞。

### 第二轮：测试、安全和落地性审查

发现摘要：

- P1：原研究文档的 TDD 落点是方向性清单，缺少先失败测试名和失败原因。
  - 写回修改：第 11、12 节列出具体测试文件、测试名、命令和预期失败原因。
  - 是否阻塞实现：已修正。
- P1：阅读文本和词典内容容易进入日志或 fixture。
  - 写回修改：约束中明确只使用合成文本，日志不记录完整正文、selection 或词典解释。
  - 是否阻塞实现：实施时必须复查。
- P2：真实 AI/TTS 和 Data migration 范围下，完整验证必须成为硬门禁。
  - 写回修改：第 11.14 和 14 节要求 Core / Data / AI / Speech / UI package 验证和 `scripts/verify.sh`。
  - 是否阻塞实现：已修正。
- P2：文档影响可能被误解为只更新 Prompt Registry 和 evidence。
  - 写回修改：第 15 节明确实施本方案时必须更新产品主参考、导航规范、页面清单、Reading spec、AI / Data / TTS spec，并评估 review round。
  - 是否阻塞实现：已修正。

### 追加自审：按 `docs/plans/README.md` 必填项和 evidence 要求复核

发现摘要：

- P1：导入 preflight 用例未覆盖 `.txt` / `.md` 显式格式边界和编码失败，和本方案目标“编码失败、size gate”不完全一致。
  - 证据：第 4 节目标包含 `.txt` / `.md` 和编码失败；原第 11.2 只覆盖 pasted text、long text、byte limit。
  - 影响：实施者可能只做 metadata gate，无法为阅读 MVP 判断真实导入失败路径。
  - 写回修改：第 11.2 增加 supported extension 和 invalid bytes 测试，实施要点增加 `decodeTextData`、UTF-8 / UTF-16 best-effort 和 `.encodingFailed`。
  - 是否阻塞实现：已修正；实施时必须先写这些失败测试。
- P1：早期 UI 计划只验证三端 layout，不验证 selection 触发 inspector 的状态流。
  - 证据：原第 11.6 只检查 `primaryColumnCount` 和 `inspectorPresentation`。
  - 影响：无法证明 iPhone bottom sheet / iPad inspector 的核心交互能通过 presentation state 表达。
  - 写回修改：第 11.6 增加 `ReadingPresentationState` 和 selection opens inspector 测试。
  - 是否阻塞实现：已修正。
- P1：Source anchor stale 判定只测试 revision changed，没有测试 selected text hash changed。
  - 证据：原第 11.5 只有 current 和 revision changed 用例。
  - 影响：文本同 revision 下重新分段或 selection hash 变化时可能静默误指。
  - 写回修改：第 11.5 增加 selected text hash changed 测试。
  - 是否阻塞实现：已修正。
- P2：`docs/plans/README.md` 要求 spike / probe / fixture / evidence 写清敏感内容、验证方式、保留期限和清理条件；原方案只说明合成 fixture，不够可审计。
  - 证据：`docs/plans/README.md` 第 5 节要求高风险任务说明 spike / probe / fixture / evidence。
  - 影响：后续可能把真实文本或词典样本留在 evidence 目录。
  - 写回修改：新增第 7.6 节，补充 evidence 文档必须记录 fixture 文件边界和清理条件。
  - 是否阻塞实现：已修正。
- P2：文档影响检查未显式判断 review round。
  - 证据：`docs/plans/plan-review-protocol.md` 第二轮要求文档影响检查判断 review round。
  - 影响：若实施中越界改 Data / navigation / AI / TTS，可能漏掉专项审查。
  - 写回修改：第 15 节新增 `docs/review/README.md` 和 `docs/review/INDEX.md` 检查项。
  - 是否阻塞实现：已修正。

### 追加自审：真实 AI / TTS 范围复核

发现摘要：

- P0：原方案明确“不接真实 AI / TTS”，与用户新要求冲突。
  - 证据：原 Architecture 和“本任务不做”包含“不接真实 AI explanation / TTS playback”。
  - 影响：按原方案实施会产出无法验证真实 Provider 链路的伪 spike，不能满足当前开发要求。
  - 写回修改：将类型从 `research` 改为 `feature`，目标改为阅读 AI/TTS 纵向切片，加入 Data、AI、TTS、UI 和 App assembly 阶段。
  - 是否阻塞实现：已修正；后续实施必须按 feature 级门禁执行。
- P1：接真实 AI 后必须补 Prompt Registry 和请求预览 / 日志边界。
  - 证据：`docs/workflows/add-ai-provider.md` 和 `docs/prompts/README.md` 要求新增 AI 能力登记 Prompt、说明发送内容、日志允许字段和失败路径。
  - 影响：如果只写 service，不登记 Prompt，后续隐私审查和输出契约不可追踪。
  - 写回修改：新增 `docs/prompts/reading/selection-explanation.md`、`ReadingSelectionExplanationServiceTests` 和 AI operation summary 要求。
  - 是否阻塞实现：已修正。
- P1：接真实 TTS 后不能复用 learning material source。
  - 证据：`TTSSentenceSource` 当前只有 entry、learningMaterialSentence、temporary；调研文档要求 reading source 不与 Entry / LearningMaterial 混淆。
  - 影响：若复用现有 source，media artifact cache、删除、导出和诊断会错误归属。
  - 写回修改：新增 `readingDocumentSentence(documentID:sentenceID:)` source、Core key 测试和 Data source columns round-trip。
  - 是否阻塞实现：已修正。
- P1：真实 AI/TTS 纵向切片需要正式 Reading domain 主数据，否则 source anchor 和 TTS artifact owner 缺少稳定 source id。
  - 证据：source anchor、TTS source 和 AI operation summary 都需要 document id / sentence id。
  - 影响：如果继续纯内存，TTS artifact key、operation summary 和后续 stale 判断无法稳定复现。
  - 写回修改：允许新增 Reading domain 基础 GRDB migration 和 `GRDBReadingRepository`，但仍不做完整资料库、词典导入、同步和导出。
  - 是否阻塞实现：已修正。
- P2：真实 Data / AI / TTS / assembly 变更后，完整验证不能再是条件性。
  - 证据：`docs/workflows/add-ai-provider.md`、`docs/workflows/add-tts-provider.md` 和 `docs/plans/README.md` 对高风险动作要求聚焦测试和完整验证。
  - 影响：只跑 Core / UI 测试会漏 Data migration、AI service、Speech / media artifact 和 App assembly 问题。
  - 写回修改：验证命令扩展到 Core / Data / AI / Speech / UI，并要求运行 `scripts/verify.sh`。
  - 是否阻塞实现：已修正。

### 追加自审：早期重构、基础设施和 dev docs 控制面复核

发现摘要：

- P0：原方案把“不修改 `PhoneRootTab` / 不更新导航规范”作为硬边界，实质上让一个已被研究确认的一级学习场景继续服从旧三 Tab 临时设计。
  - 证据：`docs/spec/002-navigation-and-routing.md` 当前固定 `记录 / 练习 / 记忆`；调研文档已建议长期 `记录 / 阅读 / 练习 / 记忆`；用户明确要求早期阶段发现落后应用级设计可主动推倒重来。
  - 影响：如果继续只做隐藏入口，会形成新的信息架构债务，后续仍要重写 Tab、页面清单和路由测试。
  - 写回修改：第 4、5、7.1、8、11.1、11.11、13、15、18 节改为“用户批准实施后同步更新产品 / 导航 / 页面清单并新增正式 reading route”，不再把旧导航作为不可触碰边界。
  - 是否阻塞实现：已修正；但仍需用户批准本 feature 实施和导航升级范围。
- P1：原 “最小 reading schema” 偏纵向 demo，不足以作为基础设施首版。
  - 证据：`docs/spec/007-data-storage-migration-export-and-attachments.md` 明确真实数据基础设施不得只实现单对象临时版本；阅读 AI/TTS source anchor 需要稳定 document / structure / anchor / operation 主数据。
  - 影响：后续做阅读资料库、记忆回链、练习回链、删除、导出或同步时会补 schema，造成迁移和 repository 返工。
  - 写回修改：第 7.3 和 11.8 将 migration 提升为 Reading domain 基础 schema，新增 `reading_structure_blocks`、`reading_source_anchors`、`reading_import_operations`，并要求 CHECK、唯一索引、device scoped position 和 operation id 幂等。
  - 是否阻塞实现：已修正。
- P1：原文档影响检查把产品主参考、导航规范、Data / AI / TTS spec 放到“后续或可选”，与 dev docs 作为开发控制面的原则冲突。
  - 证据：入口文档要求形成新结论时写回对应事实源，research / active plan 不能替代长期 spec。
  - 影响：后续 AI 会话会从旧 spec 读取错误事实，继续生成三 Tab 或无 Reading domain 的实现。
  - 写回修改：第 7.8、8、10、11.1、15 节新增 `docs/spec/012-reading-learning-domain.md`，并把产品、导航、页面清单、AI、Data、TTS spec 更新列为实施步骤和完成标准。
  - 是否阻塞实现：已修正。
- P2：Reading route 上升为一级入口后，测试不能只检查 presentation model。
  - 证据：原 UI 测试只覆盖 layout model 和 selection inspector。
  - 影响：可能出现阅读功能存在但入口隐藏、Tab 顺序回退或进入阅读页即触发外部请求。
  - 写回修改：第 11.11 和 13 节新增 `PhoneRootTab` 顺序、reading tab 进入不触发 AI/TTS、源码 convergence 测试要求。
  - 是否阻塞实现：已修正。

仍需用户确认的问题：

- 是否批准按本方案进入 feature 纵向切片实施。
- 是否批准本轮同时升级 iPhone 顶层导航为 `记录 / 阅读 / 练习 / 记忆`，并同步修订产品主参考、导航规范和页面清单。
- 纵向切片完成后，是优先进入完整阅读资料库 / 文档管理，还是优先进入词典导入与词状态。

是否允许进入实现：否。当前状态为 `Draft`，需要用户明确确认后才能开始实现。

## 17. 实施记录

- 2026-06-01：创建本 active plan，最初依据阅读整合调研收敛为 research spike；完成主会话自审核并写回范围、TDD、验证命令和文档影响检查。
- 2026-06-01：按用户要求根据 `docs/plans/README.md` 追加自审并修订方案：补齐格式识别、编码失败、selection range、selection -> inspector、hash mismatch stale、fixture / evidence 边界和 review round 判断。
- 2026-06-01：按用户要求将方案从纯 research spike 调整为 feature 级阅读 AI/TTS 纵向切片：接入真实 AI selection explanation、真实 reading sentence TTS、最小 GRDB reading schema、Prompt Registry、TTS source key、App assembly 和完整验证门禁。
- 2026-06-01：按用户追加的早期重构、基础设施完整建设和 dev docs 控制面原则复审并修订：取消“不改导航 / 不改规范”的硬限制，将阅读正式一级入口、产品 / 导航 / 页面清单 / Reading spec 更新、Reading domain 基础 schema 和四 Tab 测试纳入本方案；方案仍为 Draft，尚未进入生产代码实现。

## 18. 完成标准

本任务完成时必须满足：

- 本方案状态更新为 `Implemented` 或移动到 `done/` 后更新为 `Verified` / `Done`。
- Core reading 测试全部通过。
- Data reading migration / repository 测试全部通过。
- AI reading selection explanation 测试全部通过。
- TTS reading source / media artifact 测试全部通过。
- UI reading presentation 和 AI/TTS action seam 测试全部通过。
- Evidence 文档存在且记录实际命令和结果。
- `PhoneRootTab.swift`、`docs/spec/002-navigation-and-routing.md`、`docs/product-main-reference.md` 和 `docs/platform-page-inventory.md` 已一致表达阅读一级入口。
- `docs/spec/012-reading-learning-domain.md` 已存在并记录 Reading domain 长期规则。
- `AppDatabase.swift` 只包含本方案允许的 Reading domain 基础 migration。
- 未提交真实用户文本、版权词典或大体积 fixture。
- Prompt Registry 已登记 reading selection explanation Prompt。
- `scripts/verify.sh` 通过，或失败项有明确环境原因和替代验证记录。
- 文档验证通过。
- 剩余风险和下一步 feature plan 建议已写回。

## 19. 剩余风险

- SwiftUI presentation model 测试不能完全替代真实设备上的文本选择、VoiceOver、Dynamic Type 和滚动体验；后续 MVP 前仍需要模拟器或真机人工验证。
- 纯内存 100k lookup 只能证明索引思路，不等于 GRDB normalized index 性能结论；正式词典导入仍需 Data package migration 和 benchmark。
- 本纵向切片会验证真实 AI explanation，但不验证全文总结、全文翻译、历史记忆摘要、附件摘要或多 Provider 高级兼容。
- 本纵向切片会验证真实 reading sentence TTS source，但不验证全文朗读、批量预生成、后台播放、锁屏控制或音频同步。
- 本纵向切片不验证导出、备份、同步和删除传播；这些必须在 reading document infrastructure 和 sync 任务中重新建模。
- 本纵向切片会更新产品主参考和导航规范，但只交付最小阅读闭环；完整资料库、词典导入、词状态、导出、同步和阅读统计仍需后续 active plan 收口。
