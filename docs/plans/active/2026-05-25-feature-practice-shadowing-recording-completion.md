# 任务方案：练习模块跟读录音完成闭环

状态：Draft
类型：feature
创建日期：2026-05-25
最后更新日期：2026-05-26

## 用户确认记录

2026-05-25：用户提出接下来三大方向：练习模块、词典、语伴。用户确认词典和语伴先创建文档记录，练习模块深入思考后创建 active plan。
2026-05-26：用户基于 iOS 练习 Tab 截图提出交互调整：去掉顶部“从生活进入练习”，练习 Tab 改为记录卡片列表；点击记录进入句子练习列表；点击单句进入单句跟读、录音、完成页面，并希望单句页可查看翻译 / 语法分析、标记单词或短语进单词本。经复审后采纳推荐边界：第一阶段只展示已有 LearningMaterial 里的翻译 / 说明，不新增 AI 语法分析请求；单词 / 短语标记作为扩展入口和数据预留，不并入本次录音闭环实现。
2026-05-26：用户补充 iOS 练习 Tab 的记录卡片需要有高度要求，长文本必须自动省略显示，页面开发必须参考和遵循现有规范。方案补充卡片高度、行数、省略、Dynamic Type 和既有 UI / SwiftUI / Apple 交互规范约束。

当前确认范围只覆盖创建方案，不代表已经批准实施代码。状态保持 `Draft`，正式实现前需要用户确认本方案范围。

## 1. 需求或 bug 描述

当前练习页面仍停留在原型阶段，`PracticeSessionView` 只展示本地 step 切换，不录音、不持久化练习结果，也不形成真实完成闭环。

本任务目标是把第一阶段练习模块收敛为可运行、可测试、边界清楚的三步闭环：

1. 跟读：用户听目标语言示范并准备跟读。
2. 录音：用户录下自己的朗读，并可立即回放作为自我对比。
3. 完成：用户标记本次练习完成，可选择标记问题句或保留复习线索。

本阶段不做专业发音评分，不做 Speech Recognition 转写，不做听写和回译，不做 AI 自动纠错。重点是让用户围绕自己的生活记录完成一次真实本地练习。

2026-05-26 iOS 交互复审后，本任务的练习信息架构调整为三层：

1. 练习 Tab：只展示可练习的记录卡片列表，不展示“从生活进入练习”这类说明型标题，不按“跟读 / 反向翻译 / 听写”等任务类型混排。
2. 记录练习页：点击记录后进入该记录的句子练习列表，按 LearningMaterial 句子顺序展示每一句的练习状态。
3. 单句练习页：点击句子后进入单句跟读录音完成页面，围绕一个句子完成听示范、录音、回放、标记完成和问题标记。

## 2. 现状描述

当前代码和文档事实：

- `PracticeSessionState` 位于 `Packages/LangoTraceData/Sources/LangoTraceData/PracticeSessionState.swift`，当前只有 `prepare`、`shadow`、`compare`、`completed` 四个本地 UI step。
- `PracticeSessionView` 位于 `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`，当前只在 UI 内使用 `@State currentStep` 切换步骤。
- `PracticeControlBar` 位于 `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`，当前负责本地步骤按钮和下一步按钮。
- `PracticeView` 当前位于 `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`，在练习 Tab 顶部显示 `phone.practice.fromLife.title` section header，并按 `PracticeItem.Kind` 展开“听 / 跟读 / 听写 / 回译”等任务行；这与第一阶段“记录 -> 句子 -> 单句练习”的 iOS 练习心智不一致。
- `PhoneMainView` 当前只有 `.practice(entry.id)` 路由，点击练习 Tab 或记录详情的练习入口都进入 Entry 级 `PracticeSessionView`；还没有“记录练习句子列表”和“单句练习页”两个明确层级。
- 逐句 `听` 已通过 `SentenceAudioPlaybackActions`、`LearningContentStore` 和 `SentenceAudioPlaybackCoordinator` 接入真实 TTS 生成、artifact cache 和播放。
- `docs/platform-page-inventory.md` 明确记录练习会话当前状态为 Local Mock，真实语音能力接入前需要单独权限和语音边界方案。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已规定录音 / 跟读使用 Microphone，默认数据边界为本地音频片段和练习结果，触发条件为用户点选录音或跟读，诊断日志不得记录音频正文或波形原始数据。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 已规定练习结果属于主数据，音频文件必须通过附件或媒体资产边界管理，不能散落在临时目录。
- `docs/spec/011-tts-provider-configuration-and-playback.md` 不覆盖录音、跟读评分、听写和 ASR；逐句 TTS 播放只能作为听示范能力，不应被扩展成录音评分。

## 3. 目标

本任务完成后应达到：

- 练习会话第一阶段有清晰三步模型：跟读、录音、完成。
- 用户可从记录详情或练习 Tab 进入练习会话。
- iOS 练习 Tab 以记录卡片为主，不再显示“从生活进入练习”标题，不再把练习任务类型列表作为首层信息架构。
- 用户点击记录后进入句子练习列表，按顺序查看该记录可练习的单句、完成状态和问题标记。
- 用户点击单句后进入单句练习页；单句页可以展示已有翻译、说明或语法提示，但第一阶段不新增 AI 语法分析请求。
- 跟读步骤可复用现有逐句 TTS 播放能力听示范。
- 录音步骤在用户显式点击后请求麦克风权限并录制用户朗读。
- 录音结果写入 App 管理目录，并通过 GRDB metadata 与 Entry / LearningMaterial / sentence 归属关联。
- 用户可回放本次录音，作为自我对比。
- 用户可标记本次练习完成，并可标记当前句为问题句或复习线索。
- 练习状态在重启后仍可读取最近完成状态和录音 metadata。
- iPhone、iPad、macOS 共享同一练习业务状态；平台只改变布局和入口承载。
- 日志、诊断和错误状态不泄露音频内容、原文、完整句子或文件绝对路径。

## 4. 范围

本任务预计修改：

- Core：新增或提升练习会话、录音、完成状态、错误分类和 reducer / state machine contract。
- Data：新增 GRDB schema、repository、migration 和测试，用于 practice session、practice recording metadata 和 completion state。
- Speech：新增本地录音 service 和回放 source 边界，处理麦克风权限、录制、停止、失败和文件校验。
- UI：改造 `PracticeSessionView`、`PracticeControlBar` 和练习入口，让三端共享真实状态和 action。
- App Shell：装配 Data repository、Speech recording service、Practice action 和权限边界。
- 文档：同步 `platform-page-inventory.md`、相关 spec 或 architecture 事实。

## 5. 不做什么

本任务明确不做：

- 发音评分。
- Speech Recognition / ASR 转写。
- 听写。
- 回译。
- AI 自动纠错。
- 新增 AI 语法分析请求。
- 独立语法分析生成链路。
- 语伴对话。
- 词典查询。
- 单词本完整实现。
- 单词 / 短语的持久收藏、复习调度和词典解释生成。
- 后台录音。
- 流式录音上传。
- 云端同步练习录音。
- 导出练习录音。
- 录音转文字。
- 声纹、音色分析或情绪分析。
- 自动把练习录音发送给任何 AI Provider。

## 6. 证据与决策依据

代码证据：

- `Packages/LangoTraceData/Sources/LangoTraceData/PracticeSessionState.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentenceAudioPlaybackActions.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift`

2026-05-25 严格复审补充证据：

- 当前 `SentencePairView` 的逐句 `练` 按钮只把 `onPractice` 回调提升到 Entry 级 route，`PhoneMainView` / `PadMainSections` / `MacWorkspaceContentView` 当前都进入 `.practice(entry.id)`。如果本任务要让用户练“当前句”，必须在路由、presentation state 和 repository contract 中显式携带 sentence identity；否则 `practice_sessions.sentence_id` 会成为没有入口保证的孤立字段。
- 当前 `media_artifacts` schema 已包含 `shadowingRecording` 和 `dictationRecording` artifact type，`MediaArtifactOwner` 也已包含 `practiceSession(id:)`，但 `MediaArtifactDerivationKind` 只有 `ttsAudio`，`GRDBMediaArtifactRepository` / `LocalMediaArtifactStore` / `LocalMediaArtifactStoring` 的 public contract 仍是 TTS audio 专用。练习录音不得硬塞进 `TTSAudioArtifactKey` 或 `tts_audio_artifacts`，必须新增 practice recording 专属 key / commit / lookup / resolver contract，或把媒体资产 repository 抽象提升为真正通用的 artifact commit contract。
- 当前 `Info-iOS.plist` 和 `Info-macOS.plist` 没有 `NSMicrophoneUsageDescription`；`project.yml` 也没有 macOS audio input entitlement。只要本任务接入真实录音，这些不是“可能需要”，而是实施前必须补齐并测试的权限 / entitlement 落点。
- 当前 `PracticeControlBar` 位于 `ScrollView` 内容流内，并且 step button 最小高度为 36pt；真实 iPhone 录音流程的开始 / 停止 / 完成主操作应进入底部可达控制区并满足至少 44pt 触控目标，不能继续沿用当前 mock 控制条形态。
- `TTSAudioPlaybackService` 已使用 `AVAudioPlayer` 管理播放生命周期；录音服务需要单独处理录音与播放的互斥、Audio Session 类别切换、开始录音前停止或暂停示范播放、以及快速重复点击导致的并发状态。

2026-05-26 iOS 交互复审补充证据：

- 当前 `PracticeView` 在练习 Tab 首层显示 `SectionHeader(titleKey: "phone.practice.fromLife.title")`，截图中对应“从生活进入练习”。该标题解释性强但信息增量低，占用首屏空间，应删除。
- 当前练习 Tab 使用 `ForEach(items)` 展示 `PracticeItem.Kind`，用户看到的是“反向翻译练习 / 跟读练习”等功能项；第一阶段目标是跟读录音闭环，应把首层改为记录卡片，避免尚未实现的听写 / 回译等练习类型继续出现在主路径。
- `RenderingSentence` 已有 `id`、`translation`、`targetText`、`note`；第一阶段单句页可以展示这些已有内容作为翻译 / 说明来源，不需要新增 AI 请求。

文档证据：

- `docs/product-main-reference.md` 的朗读与跟读章节建议支持逐句播放、跟读录音、跟读对比，并说明未来可以加入发音评分但第一阶段不应变成纯发音训练工具。
- `docs/technical-framework-roadmap.md` 的录音与跟读章节建议第一版闭环为听示范、跟读录音、回放、文本对照、收藏问题句。
- `docs/platform-page-inventory.md` 当前记录练习会话为 Local Mock，不录音、不评分。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 规定录音 / 跟读权限和日志边界。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 规定练习结果、附件和媒体资产的数据边界。
- `docs/spec/011-tts-provider-configuration-and-playback.md` 明确 TTS 规范不覆盖录音、跟读评分、听写和 ASR。
- `docs/spec/003-ui-design-system.md` 规定卡片只用于重复 item、modal / sheet 内容、工具面板或确实需要框定的局部；不得卡片套卡片，页面不能临时定义自己的卡片、按钮、badge 和颜色。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md` 规定 iPhone 触控目标不得小于 44pt，长英文 / 德文 / 俄文、中文、日文、韩文和 Dynamic Type 不能导致主操作不可见、按钮文字溢出或内容互相遮挡。
- `docs/spec/004-swiftui-architecture.md` 规定练习流程等 Feature state 应通过 feature store / presentation model 管理，View 不应直接承载长期业务状态；共享组件应独立拆分，避免继续把页面堆在大文件中。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md` 和 `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` 提醒后续录音、同步、导出和 playback source 需要独立决策。

应引用 workflow：

- `docs/workflows/add-storage-migration.md`：新增 practice session / recording metadata 表和 migration。
- `docs/workflows/add-platform-screen.md`：练习会话是三端页面能力。
- `docs/workflows/add-tts-provider.md`：只作为听示范能力的边界参考，不新增 TTS Provider。

高风险或研究性任务补充：

```text
是否需要 spike / probe / fixture / evidence：需要。麦克风权限、AVAudioRecorder / AVAudioEngine 录制文件格式、macOS sandbox entitlement 和模拟器录音行为需要单独记录 evidence。
需要时的落点：docs/reference/research/spikes/2026-05-25-practice-recording-platform-spike.md 或任务实施记录中的 evidence 小节。
是否包含真实用户敏感内容：实现和测试不得使用真实用户录音；fixture 使用生成的短静音或测试音频。
如何验证和清理：spike 只记录平台行为、错误码和路径分类，不保留真实音频；临时文件写入系统临时目录或 App 测试目录，验证后删除。
```

## 7. 涉及的代码文件路径

预计新增或修改：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeRecording.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSessionReducer.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/PracticeSessionReducerTests.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/PracticeRepository.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBPracticeRepositoryTests.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/PracticeRecordingService.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/PracticeRecordingPlaybackService.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/PracticeRecordingServiceTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhonePracticeRows.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeSessionViewModelTests.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceAppTests/AppEnvironmentBootstrapTests.swift`
- `project.yml`、`LangoTraceApp/Supporting/Info-iOS.plist`、`LangoTraceApp/Supporting/Info-macOS.plist` 和必要的 macOS entitlements 文件，用于补齐麦克风权限说明、audio input entitlement 和 App test 装配。

实际实施时如果发现更小的文件拆分更符合现有代码，应在实施记录中说明。

## 8. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlayback.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackCoordinatorTests.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LocalMediaArtifactStore.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/TTSAudioPlaybackService.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentenceAudioPlaybackActions.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreSentenceAudioCoordinatorTests.swift`

## 9. 涉及的文档路径

预计修改或同步检查：

- `docs/platform-page-inventory.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/testing/README.md`
- `docs/architecture/002-system-map.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.1 阶段一：状态模型和数据边界

1. 在 Core 中定义真实练习领域模型，避免继续把长期练习业务状态放在 Data 的 preview state 中。
2. 明确第一阶段 session 粒度：
   - 记录详情逐句 `练` 入口创建或恢复“单句跟读 session”，必须携带 `entryID`、`learningMaterialID`、稳定 `sentenceID` 或 sentence index、目标语言句子文本 hash 和目标语言 code。
   - 练习 Tab 的首层入口按 Entry / LearningMaterial 聚合展示；点击记录后进入句子练习列表，用户再选择具体句子进入 session。第一阶段不在练习 Tab 首层直接跳到某个隐式句子，避免“继续练习”选择不透明。
   - `practice_sessions.sentence_id` 不得只作为可空字段存在；若采用 sentence index，应在 plan 实施记录中说明它如何跟 `learning_materials` 的 current material 和重新分析后的 sentence list 保持一致。
3. 将第一阶段 UI 步骤收敛为三步：
   - `shadowing`：展示目标语言句子，允许用户听示范。
   - `recording`：录制用户朗读，并显示录制 / 停止 / 失败状态。
   - `completion`：回放录音、标记完成、标记问题句。
4. 保留 `prepare` 的语义作为 `shadowing` 内部说明，不再作为独立业务完成步骤，避免用户看到四步但产品说三步。
5. 定义 `PracticeSessionReducer`，覆盖进入步骤、开始示范播放、示范播放状态更新、开始录音、停止录音、取消录音、录音完成、录音失败、重录、回放开始、回放停止、标记完成和标记问题句。
6. Reducer 必须显式建模互斥状态：TTS 示范播放中不能直接开始录音；录音中不能开始示范播放或录音回放；同一 session 的 `startRecording` / `stopRecording` / `complete` 必须具备幂等或稳定拒绝结果，避免快速重复点击造成两个 ready recording 或一个完成态指向失败文件。
7. 先写 Core reducer 单元测试，再实现 reducer。

### 11.2 阶段二：GRDB schema 和 repository

1. 新增 practice session / recording metadata migration。
2. 推荐最小表结构：
   - `practice_sessions`：id、language_space_id、entry_id、learning_material_id、sentence_id 或 sentence_index、target_text_hash、target_language_code、status、problem_marked、completed_at、created_at、updated_at、soft_deleted_at。
   - `practice_recordings`：id、session_id、language_space_id、media_artifact_id、attempt_number、status、duration、byte_size、content_hash、created_at、invalidated_at。录音文件路径只通过 media artifact resolver 间接解析，不在 UI 或练习 repository 中暴露绝对路径。
3. `practice_recordings` 必须允许同一 session 多次重录，并能稳定查询 latest ready recording；失败、取消或被新录音替代的 attempt 不得被完成态引用。
4. 如果复用 `media_artifacts`，必须把用户练习录音与 TTS 音频区分为不同 artifact type / owner / policy，并补齐当前缺口：
   - 新增 `MediaArtifactDerivationKind`，例如 `practiceRecording`，并同步更新 DB CHECK constraint、Core enum、repository mapper 和测试 fixture。
   - 新增 practice recording artifact key，key 至少包含 session id、attempt number、recording format、target text hash 和 created-at bucket 或 recording id，避免与 TTS derivation key 复用。
   - 新增 practice recording commit / lookup / playback resolver contract；不得使用 `TTSAudioArtifactKey`、`commitTTSAudioArtifact` 或 `tts_audio_artifacts` 表承载用户录音。
5. 用户练习录音默认 local-only、excluded from system backup、excluded from default export；未来同步或导出需单独方案。
6. 写 repository 测试覆盖创建 session、绑定 recording、重录 attempt 排序、latest ready recording 查询、完成态只能引用 ready recording、标记完成、标记问题句、按 Entry 查询最近状态、按具体句子恢复 session、软删除 Entry 后 active 查询不返回悬空练习。

### 11.3 阶段三：Speech 录音和回放服务

1. 新增 `PracticeRecordingService`，只负责录音生命周期，不负责练习业务状态。
2. 录音必须由用户显式点击开始触发。
3. 处理麦克风权限：not determined、authorized、denied、restricted / unavailable。
4. 录音文件写入 App 管理 staging 位置，停止并校验后提交到 repository 认可的位置。
5. 失败、取消或权限拒绝时清理 staging 文件，不写入 ready recording。
6. 回放服务只能播放 repository / resolver 返回的受限 source，不接受 UI 传入任意绝对路径。
7. 录音开始前必须停止或暂停当前示范 TTS；录音中禁用示范播放和录音回放；回放用户录音时禁用开始录音或给出稳定拒绝状态。
8. 录音服务需要独立于 TTS playback service 的错误分类，至少覆盖权限拒绝、权限受限、设备不可用、启动失败、停止失败、文件缺失、文件过大、解码 / 时长校验失败、取消和未知错误。
9. 单元测试使用 fake recorder、fake clock、fake file store 和生成音频 fixture，不依赖真实麦克风。

### 11.4 阶段四：UI 和三端入口

1. iPhone 练习 Tab 改为记录卡片列表：
   - 删除顶部 `phone.practice.fromLife.title` 对应的“从生活进入练习”标题。
   - 不再按 `PracticeItem.Kind` 展示“反向翻译练习 / 跟读练习 / 听写”等任务类型。
   - 每张记录卡片展示记录标题、1-2 行目标语言预览、句子总数、完成数量、问题句数量和最近练习状态；没有 LearningMaterial 的记录可显示轻量不可练状态或不进入练习列表，但不得引导发起 AI 请求。
   - 记录卡片必须有稳定高度约束，推荐常规字体下保持约 112-132pt 的可扫描高度；Dynamic Type 较大时允许增高，但不得因为用户原文或学习文本过长无限撑开。
   - 卡片文本必须使用明确行数限制和省略策略：标题最多 1 行，目标语言预览最多 2 行，元信息 / 进度最多 1 行；长文本使用尾部省略，不在卡片内显示全文。
   - 卡片内不要展示原文长段落；如果需要上下文，只显示短摘要或目标语言首句，完整内容放到记录练习页的折叠概览或记录详情。
   - 卡片布局必须遵循 `docs/spec/003-ui-design-system.md`、`docs/spec/004-swiftui-architecture.md` 和 `docs/spec/010-apple-platform-interaction-and-accessibility.md`，复用现有 `LangoTraceDesign` token、`langoPanel` / row 语义和本地化工具，不新增临时颜色、阴影、卡片半径或硬编码文案。
   - 卡片整体可点击，触控目标不小于 44pt，支持 VoiceOver 读出标题、目标语言、进度和状态。
2. 新增或改造 iPhone 记录练习页：
   - 点击记录卡片进入该记录的句子列表，按 `LearningRendering.sentences` 顺序显示。
   - 每个句子 row 显示序号、目标语言句子、已有翻译的短预览、完成 / 未完成 / 问题标记状态。
   - 默认不展示完整长文；顶部可提供折叠的“原文 / 学习文本概览”，用于恢复上下文，但不能压过句子队列。
   - 如果记录没有 current LearningMaterial 或句子列表为空，显示面向用户的空状态，引导回记录详情生成学习材料；本任务不在练习页自动触发 AI 生成。
3. 改造单句 `PracticeSessionView`：
   - 从本地 `@State currentStep` 迁移到可测试 presentation model 或 store action。
   - 单句页顶部显示返回路径、句子序号、练习状态和问题标记，不显示开发阶段能力说明。
   - 单句目标语言是页面主体；翻译、已有说明 / note、语法提示作为可展开辅助区域。第一阶段只读取已有 `RenderingSentence.translation` 和 `RenderingSentence.note`，不新增 AI 语法分析请求。
   - 单词 / 短语标记作为界面扩展点：可以设计长按、选择文本或辅助按钮的入口，但本任务不实现持久单词本、复习调度或词典解释。若当前 SwiftUI text selection 不足以稳定支持词级选择，应先隐藏入口或以 disabled affordance 记录，不做半成品。
4. `PracticeControlBar` 显示三步进度，不展示评分或 AI 纠错。
5. 跟读步骤复用现有 `听` action seam 或等价 wrapper，不复制 TTS 请求逻辑。
6. 录音步骤显示开始、录制中、停止、权限拒绝、失败和已录制状态。
7. 完成步骤显示回放、自我对比提示、标记问题句、完成按钮，并提供“上一句 / 下一句”导航；完成当前句后可以进入下一句，但不能自动开始录音或播放。
8. iPhone 使用单列流程，录音开始 / 停止 / 完成主操作应放在底部 `safeAreaInset` 或等价 sticky control 区，所有主按钮触控目标不小于 44pt；步骤切换可以是状态指示，不应鼓励用户跳过录音直接完成。
9. iPad 在 regular width 中保持记录列表 / 句子列表 / 单句练习之间的层级，但可用侧栏和主区并列承载；支持 Split View / Stage Manager resize 不丢失录音状态；compact width 回退为 iPhone 类单列。
10. macOS 需要提供 toolbar 或 command/menu 入口承载开始录音、停止录音、播放 / 暂停、上一句 / 下一句和完成，至少为高频命令预留 keyboard shortcut 设计；不能只把 iPhone 底部控制条放大到桌面。
11. 三端的业务 action 和状态必须共享；平台差异只在 layout、toolbar、keyboard shortcut、inspector 和辅助说明。
12. 所有新 UI 文案进入 `Localizable.xcstrings`，不得硬编码中文或英文句子。

### 11.5 阶段五：App 装配和权限配置

1. App Shell 装配 practice repository、recording service、playback service 和 UI action。
2. 必须通过 `project.yml` / plist 写入 iOS 和 macOS 的 `NSMicrophoneUsageDescription`，并补齐 macOS App Sandbox audio input entitlement；当前仓库还没有这些配置。
3. 权限说明文案必须面向用户，说明录音只用于本地跟读练习，不自动发送给 AI Provider。
4. App test 覆盖 production assembly 可以构造 practice action，且不会回退到 disabled recording service。
5. 权限、entitlement 和录音 service 装配完成后，需要至少记录一次 iOS Simulator、macOS 本机和一台真实 iPhone 或明确不可用原因的手动验证结果；模拟器不能替代真实设备麦克风验证。

### 11.6 阶段六：文档和验证收口

1. 更新 `docs/platform-page-inventory.md`：练习会话从 Local Mock 更新为真实本地练习录音闭环。
2. 更新 `docs/spec/007-data-storage-migration-export-and-attachments.md`：若新增 practice recording metadata 或用户录音 policy。
3. 更新 `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：若新增具体权限文案、失败状态或日志字段。
4. 更新 `docs/architecture/002-system-map.md`：如果练习录音成为当前真实能力。
5. 完成后将本方案移入 `docs/plans/done/`，记录验证命令和提交信息。

## 12. 复查方法

复查时必须确认：

- 练习会话真实状态不是纯 SwiftUI 本地 step。
- 用户录音必须由显式点击触发。
- 未授权麦克风时不会创建录音文件或完成记录。
- 取消或失败不会留下 ready metadata 指向不存在文件。
- 日志不包含音频内容、完整句子、Entry 正文、绝对路径或 API Key。
- TTS 听示范仍走现有逐句播放边界，不新增重复 TTS 请求路径。
- 当前逐句 `练` 入口已经携带稳定 sentence identity；如果仍只有 Entry 级 route，则不得声称实现了“当前句”练习闭环。
- iOS 练习 Tab 首层已经改为记录卡片列表，且不再展示“从生活进入练习”标题或未实现的任务类型混排。
- iOS 练习 Tab 记录卡片有稳定高度、明确 line limit 和尾部省略；长文本不会把卡片无限撑高，也不会遮挡底部 Tab 或主操作。
- 练习 Tab 和记录 / 单句页面复用了现有设计系统、SwiftUI 架构和 Apple 交互规范，没有新增临时卡片样式、硬编码颜色或未本地化文案。
- 记录练习页已经提供句子队列、句子状态和空状态；单句页从队列进入，而不是从 Entry 级页面隐式选句。
- 单句页的翻译 / 说明只来自已有 LearningMaterial；未新增 AI 语法分析请求。
- 单词 / 短语标记若出现，只能作为明确的扩展入口或 disabled affordance，不得写成单词本已完成。
- 练习录音没有复用 TTS 专属 artifact key、TTS 专属 repository method 或 `tts_audio_artifacts` 表。
- 用户录音不会自动发送给 AI Provider。
- 完成标记可以重启后读取。
- iPhone、iPad、macOS 不复制三套练习业务逻辑。
- iPhone 主录音控制符合底部可达与 44pt 触控目标；iPad / macOS 不退化成放大的 iPhone 控制条。

高风险故障与恢复路径：

- 麦克风权限拒绝：显示权限说明，不写录音。
- 录音启动失败：显示稳定错误分类，清理 staging。
- 录音停止失败：清理半成品或标记 failed，不写 ready recording。
- 快速重复点击开始 / 停止 / 完成：不会创建重复 ready recording，不会把完成态指向失败或被替换的 attempt。
- 示范播放与录音冲突：开始录音前停止或暂停 TTS，录音中禁用播放，恢复时状态可解释。
- 文件提交失败：保留 UI 失败状态，不标记完成。
- 回放失败：允许重新录制或重新尝试回放，不删除完成状态。
- GRDB 写入失败：不显示完成成功，不丢失当前可恢复 UI 状态。
- Entry 或 LearningMaterial 已删除：练习入口不可用，已有 session active 查询不返回悬空对象。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests
```

完整验证：

```bash
scripts/verify.sh
```

文档检查：

```bash
find docs -maxdepth 3 -type f | sort
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如果真实麦克风、模拟器录音或 macOS entitlement 需要人工验证，应在实施记录中写明设备、系统版本、App build、权限状态和结果。

## 14. 文档影响检查

本任务会改变练习模块当前事实，完成后必须检查：

- `docs/README.md` 当前状态是否需要更新。
- `docs/platform-page-inventory.md` 练习 Tab 和练习会话状态。
- `docs/architecture/002-system-map.md` 当前真实能力和故障恢复矩阵。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 对练习录音和 practice session 的主数据 / 媒体资产分类。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 对麦克风权限和日志字段的描述。
- `docs/testing/README.md` 是否需要新增手动麦克风验证说明。
- `docs/review/INDEX.md` 是否需要触发专项文档影响审查。

## 15. 实施记录

2026-05-25：创建 Draft active plan。尚未实施代码。
2026-05-25：按系统架构和 Apple 三端交互角度完成严格复审，并补充句子级 session 粒度、媒体资产非 TTS 专属扩展、录音 / 播放互斥、权限配置和三端 UI 控制边界。尚未实施代码。
2026-05-26：采纳用户对 iOS 练习 Tab 的三层交互方向，并完成 Apple 交互复审：练习 Tab 改为记录卡片列表，记录练习页承载句子队列，单句页承载跟读录音完成；第一阶段只展示已有翻译 / note，不新增 AI 语法分析请求；单词 / 短语标记仅作为扩展点。尚未实施代码。
2026-05-26：补充 iOS 练习 Tab 记录卡片高度、长文本省略和规范遵循要求：卡片常规高度保持可扫描，长文本通过 line limit 和尾部省略处理，开发必须遵循 UI 设计系统、SwiftUI 架构和 Apple 交互 / 可访问性规范。尚未实施代码。

## 16. 完成标准

本任务可以从 `active/` 移入 `done/` 的条件：

- 用户已确认方案进入实现。
- Core / Data / Speech / UI / App Shell 相关实现完成。
- 练习会话三步闭环可从真实 Entry / LearningMaterial 进入。
- 录音、回放、标记完成和问题句状态通过单元测试覆盖。
- GRDB migration 和 repository 测试通过。
- 文档已同步当前事实，不把评分、ASR、听写、回译、语伴或词典写成已完成。
- 聚焦验证和 `scripts/verify.sh` 通过，或记录明确环境阻塞和剩余风险。
- 实施记录写明实际改动、验证命令、结果和 commit。

## 17. 剩余风险

- 模拟器和真实设备的麦克风权限、录音格式和音频路由行为可能不同，需要人工验证补充。
- macOS sandbox、麦克风权限说明和 App Store 隐私标签会被该能力影响，后续发布前必须复查。
- 用户练习录音是否属于可恢复备份或导出内容需要独立设计，本任务默认不进入同步和默认导出。
- 如果后续加入 ASR 或发音评分，需要新增方案，并重新评估是否发送录音或转写给 Provider。
- 如果练习会话未来扩展到听写、回译和语伴，对当前 practice session schema 可能需要增加 exercise type 和 attempt model。
- 当前计划采用“单句跟读 session”作为第一阶段推荐粒度；如果用户更希望一次 session 覆盖整篇 Entry 的多句队列，需要在实施前调整 schema、route 和 UI，不宜在开发中临时混用两种语义。
- iOS 句子页是否展示全文应保持折叠上下文，不应默认占据练习主视图；如果人工测试发现用户频繁迷失上下文，再考虑提高概览可见性。
- 词级选择和短语标记在 SwiftUI 文本中可能涉及 selection、range mapping、本地化分词和目标语言脚本差异，必须单独设计，不能在录音闭环中临时实现。
