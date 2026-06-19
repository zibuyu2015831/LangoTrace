# 任务方案：练习模块跟读录音完成闭环

状态：Done
类型：feature
创建日期：2026-05-25
最后更新日期：2026-05-26

## 用户确认记录

2026-05-25：用户提出接下来三大方向：练习模块、词典、语伴。用户确认词典和语伴先创建文档记录，练习模块深入思考后创建 active plan。
2026-05-26：用户基于 iOS 练习 Tab 截图提出交互调整：去掉顶部“从生活进入练习”，练习 Tab 改为记录卡片列表；点击记录进入句子练习列表；点击单句进入单句跟读、录音、完成页面，并希望单句页可查看翻译 / 语法分析、标记单词或短语进单词本。经复审后采纳推荐边界：第一阶段只展示已有 LearningMaterial 里的翻译 / 说明，不新增 AI 语法分析请求；单词 / 短语标记作为扩展入口和数据预留，不并入本次录音闭环实现。
2026-05-26：用户补充 iOS 练习 Tab 的记录卡片需要有高度要求，长文本必须自动省略显示，页面开发必须参考和遵循现有规范。方案补充卡片高度、行数、省略、Dynamic Type 和既有 UI / SwiftUI / Apple 交互规范约束。
2026-05-26：基于系统架构师严格审查继续修订方案：第一版 practice session schema 必须包含 `exercise_type` 和完成态录音引用；媒体资产扩展方向固定为通用 `MediaArtifact` commit / resolver contract 加 typed extension metadata，不再新增 TTS 风格的临时 practice 专用 facade；新增前台音频协调边界，统一处理 TTS 示范、录音、录音回放和 Audio Session 互斥；补充三端 route identity、权限文案本地化、发布隐私影响和系统音频中断 / 磁盘空间等异常边界。
2026-05-26：根据系统架构师再次严格代码审查修订方案：补充练习句子内容快照、历史 sentence reference / FK 删除语义、完成态录音 retention / cleanup policy，以及实施前必须先完成的通用 MediaArtifact API review 阶段。明确完成态录音不是普通 LRU cache，不能被容量清理静默删除；历史练习读取不能依赖 current LearningMaterial 仍存在。
2026-05-26：用户确认本方案审核通过，要求先将状态改为 Approved，并针对本方案文档改动单独提交 commit；随后立即按方案进入开发，直至完整落地。

当前方案已完成实施并移入 done；2026-05-26 post-implementation 复审发现的单句页听示范和录音回放缺口，已通过 `docs/plans/done/2026-05-26-bug-practice-session-playback-completion-gap.md` 补齐。后续评分、ASR、听写、回译、单词本、练习录音同步 / 导出 / 可恢复备份和真实设备麦克风人工验收仍需独立任务。

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
- Practice session 从第一版起具备可扩展 exercise type；本任务只启用 `shadowing`，但 schema 和 reducer 不把 session 永久绑定为“只有跟读”。
- 完成态明确引用一次 ready recording attempt；后续重录、失败或取消不会改变已经完成的那次练习证据，除非用户显式重新完成。
- 每个单句练习 session 必须保存练习时的目标句内容快照，至少包括目标语言文本快照、目标语言文本 hash、可选翻译 / note 快照、material / analysis 来源摘要；历史完成记录不得依赖当前 `LearningMaterial`、当前句子列表或 AI 重新分析结果仍然存在。
- 被完成态引用的用户录音必须按练习证据处理，不得被普通容量 LRU、派生缓存清理或 TTS artifact cleanup 静默删除；只能由用户显式删除、session 删除级联、未来明确的存储管理操作或独立同步 / 导出 / 备份方案定义的策略处理。

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
- 后台播放或锁屏控制。
- 流式录音上传。
- 云端同步练习录音。
- 导出练习录音。
- 录音转文字。
- 声纹、音色分析或情绪分析。
- 自动把练习录音发送给任何 AI Provider。
- 用户录音进入默认导出、可恢复备份或跨设备同步。

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
- 当前 `AppEnvironment` 只装配真实 sentence TTS playback actions，`speechService` 仍为 `DisabledSpeechService()`；practice recording 不能直接塞进现有 `SpeechService` 空协议或 UI 本地状态，必须新增显式 practice actions / audio coordinator 装配并用 App test 防止回退到 disabled seam。
- 当前 `DiagnosticEventName` 已有 sentence TTS generation / playback 事件，但没有 practice recording 事件；新增录音链路时必须补 typed diagnostic event 和 allowlisted attributes，不能用自由字符串记录录音文件路径、句子正文或权限原始错误。

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
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeAudioCoordination.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeRecordingArtifact.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/MediaArtifactCommit.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/PracticeSessionReducerTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/PracticeAudioCoordinationTests.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/PracticeRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/MediaArtifactRepository.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBPracticeRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/PracticeRecordingArtifactRepositoryTests.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/PracticeRecordingService.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/PracticeRecordingPlaybackService.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/ForegroundAudioSessionCoordinator.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/PracticeRecordingServiceTests.swift`
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/ForegroundAudioSessionCoordinatorTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhonePracticeRows.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeSessionViewModelTests.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceAppTests/AppEnvironmentBootstrapTests.swift`
- `project.yml`、`LangoTraceApp/Supporting/Info-iOS.plist`、`LangoTraceApp/Supporting/Info-macOS.plist`、InfoPlist 本地化资源和必要的 macOS entitlements 文件，用于补齐麦克风权限说明、audio input entitlement、权限文案本地化和 App test 装配。

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

### 11.0 阶段零：通用 MediaArtifact API review 和练习证据边界冻结

1. 在写 practice session schema 或录音 service 前，先完成一次小型 API review，冻结通用媒体资产 contract：
   - `MediaArtifactCommitInput` / reservation / commit / ready / invalidate / resolver / cleanup 的职责边界。
   - TTS artifact 与 practice recording typed metadata 如何共用主表但保持各自 extension table。
   - completed practice recording 的 retention / purge policy 如何表达，避免被普通 LRU 或 cache cleanup 选中。
   - pending artifact recovery 如何区分可删除的 TTS cache 与被 session 引用的用户录音。
2. API review 的产出必须写回本方案实施记录，或同步到 `docs/spec/007-data-storage-migration-export-and-attachments.md` / `docs/spec/media-artifacts/impl.md`。
3. 若 review 发现现有 `MediaArtifact` / `LocalMediaArtifactStore` 命名和职责过度 TTS 化，应优先做基础设施重构，不为录音新增一套临时 facade。
4. 该阶段只允许修改方案或 spec；正式实现前仍需用户确认。

### 11.1 阶段一：状态模型和数据边界

1. 在 Core 中定义真实练习领域模型，避免继续把长期练习业务状态放在 Data 的 preview state 中。
2. 明确第一阶段 session 粒度：
   - 记录详情逐句 `练` 入口创建或恢复“单句跟读 session”，必须携带 `entryID`、`learningMaterialID`、稳定 `sentenceID` 或 sentence index、目标语言句子文本 hash 和目标语言 code。
   - 练习 Tab 的首层入口按 Entry / LearningMaterial 聚合展示；点击记录后进入句子练习列表，用户再选择具体句子进入 session。第一阶段不在练习 Tab 首层直接跳到某个隐式句子，避免“继续练习”选择不透明。
   - `practice_sessions.sentence_id` 不得只作为可空字段存在；必须明确它是 active query reference、历史 soft reference 还是强 FK。推荐：active query 使用 current material + sentence id；历史 session 使用内容快照读取；`sentence_id` 可采用 nullable soft reference 或 `ON DELETE SET NULL`，不得让 `learning_material_sentences` 删除级联导致历史练习证据丢失。
   - 推荐优先使用 `sentence_id` 作为当前句子的稳定来源，并保留 `sentence_index` 作为 display / fallback metadata；如果当前 material 重新分析导致旧 sentence 被删除，旧 session 仍通过 snapshot 作为历史记录读取，但 active query 不再把它当作当前句子练习入口。
   - route seed 必须一次性携带 `entryID`、`materialID`、`sentenceID`、`sentenceIndex`、`targetTextHash`、`targetLanguageCode` 和 `exerciseType`，避免 UI 再从 Entry 级状态隐式推断当前句。
3. 定义 `PracticeSentenceSnapshot` 或等价 Core value object，作为 session 创建时冻结的练习内容证据：
   - 必填：`targetTextSnapshot`、`targetTextHash`、`targetLanguageCode`、`entryID`、`learningMaterialID`、`sentenceID` soft reference、`sentenceIndex`、`exerciseType`、`capturedAt`。
   - 推荐可选：`translationSnapshot`、`noteSnapshot`、`materialAnalysisSourceHash`、`sourceEntryBodyHash`。
   - snapshot 不用于重建 AI 学习材料，也不作为新的可编辑 LearningMaterial；只用于历史练习展示、完成记录解释和 material 变化后的稳定回读。
   - 日志和 diagnostic event 禁止记录 snapshot 全文；snapshot 只进入 practice 主数据表或受控 repository 返回值。
4. 将第一阶段 UI 步骤收敛为三步：
   - `shadowing`：展示目标语言句子，允许用户听示范。
   - `recording`：录制用户朗读，并显示录制 / 停止 / 失败状态。
   - `completion`：回放录音、标记完成、标记问题句。
5. 保留 `prepare` 的语义作为 `shadowing` 内部说明，不再作为独立业务完成步骤，避免用户看到四步但产品说三步。
6. Practice session 从第一版起包含 `exerciseType`，本任务只允许 `.shadowing`；听写、回译、语伴等后续能力不得复用 `.shadowing` 伪装。
7. 完成态必须引用一次 ready recording attempt，例如 `completedRecordingID` 或 `completedAttemptID`；如果用户重录但未重新完成，历史完成态仍指向原 ready recording，UI 可以提示“有新录音未标记完成”。
8. 定义 `PracticeSessionReducer`，覆盖进入步骤、开始示范播放、示范播放状态更新、开始录音、停止录音、取消录音、录音完成、录音失败、重录、回放开始、回放停止、标记完成和标记问题句。
9. Reducer 必须显式建模互斥状态：TTS 示范播放中不能直接开始录音；录音中不能开始示范播放或录音回放；同一 session 的 `startRecording` / `stopRecording` / `complete` 必须具备幂等或稳定拒绝结果，避免快速重复点击造成两个 ready recording 或一个完成态指向失败文件。
10. 新增前台音频协调 contract，例如 `PracticeAudioCoordinator` 或 `ForegroundAudioSessionCoordinator`，作为 TTS 示范、用户录音、录音回放和 Audio Session 切换的唯一资源协调点。Core reducer 只表达业务转移，Speech / App coordinator 负责真实 AVFoundation 资源锁、系统中断和 route change。
11. 前台音频协调必须是跨 session / 跨页面的单一资源边界：A 句录音中切到 B 句、记录详情点击其他句 `听`、录音回放中开始示范播放，都必须被同一个 coordinator 稳定拒绝、停止或转移，不能只在单个 ViewModel 内判断。
12. 先写 Core reducer 和 audio coordination 单元测试，再实现 reducer 与 coordinator contract。

### 11.2 阶段二：GRDB schema 和 repository

1. 新增 practice session / recording metadata migration。
2. 推荐最小表结构：
   - `practice_sessions`：id、language_space_id、entry_id、learning_material_id、sentence_id、sentence_index、target_text_snapshot、translation_snapshot、note_snapshot、target_text_hash、target_language_code、source_entry_body_hash、material_analysis_source_hash、exercise_type、status、problem_marked、completed_recording_id、completed_at、created_at、updated_at、soft_deleted_at。
   - `practice_recordings`：id、session_id、language_space_id、media_artifact_id、attempt_number、status、duration、byte_size、content_hash、created_at、ready_at、invalidated_at。录音文件路径只通过 media artifact resolver 间接解析，不在 UI 或练习 repository 中暴露绝对路径。
   - `practice_sessions.completed_recording_id` 必须引用 `practice_recordings.id`；完成操作必须在同一 GRDB transaction 中校验该 recording 属于同一 session、状态为 ready、media artifact 已 ready 且未 invalidated。
   - `exercise_type` 第一阶段 CHECK 只允许 `shadowing`，但字段必须存在；后续听写、回译、语伴扩展通过 migration 增加 enum 值，而不是重解释已有 session。
   - `practice_sessions.sentence_id` 不得采用会级联删除 session 的强依赖；如果保留 FK，推荐 `ON DELETE SET NULL`。`entry_id` / `learning_material_id` 用于 active 查询和来源追踪；历史展示必须以 snapshot 为准。
3. `practice_recordings` 必须允许同一 session 多次重录，并能稳定查询 latest ready recording；失败、取消或被新录音替代的 attempt 不得被完成态引用，除非它本身仍是被 `completed_recording_id` 引用的 ready attempt。
4. 媒体资产扩展方向固定为通用 `MediaArtifact` commit / lookup / resolver contract 加 typed extension metadata，而不是新增一套 TTS 风格的 practice 专用 facade：
   - 新增或提升通用 `MediaArtifactCommitInput` / `MediaArtifactCommitReservation` / `MediaArtifactLookupKey` / `MediaArtifactPlaybackSourceResolving`，让 TTS 和 practice recording 都通过同一原子文件提交、相对路径校验、metadata ready 标记和 cleanup 规则。
   - 新增 `MediaArtifactDerivationKind.practiceRecording`，并同步更新 DB CHECK constraint、Core enum、repository mapper 和测试 fixture。
   - 新增 `practice_recording_artifacts` typed extension table 或等价 typed metadata，至少包含 artifact_id、session_id、recording_id、attempt_number、target_text_hash、target_language_code、recording_format、sample_rate、channel_count、duration、content_hash。不得把用户录音写入 `tts_audio_artifacts`。
   - Practice recording key 至少包含 session id、recording id 或 attempt number、recording format、target text hash 和 created-at bucket，避免与 TTS derivation key 复用。
   - `LocalMediaArtifactStore` 长期 public surface 不应继续只以 `ttsAudioArtifact` / `commitTTSAudioArtifact` 命名为中心；可以保留 TTS convenience wrapper，但底层应走通用 artifact commit。
5. 用户练习录音默认 local-only、excluded from system backup、excluded from default export；未来同步、默认导出或可恢复备份需单独方案和 manifest / 加密 / 删除传播设计。
6. 完成态录音的 retention 必须区别于普通可重建派生缓存：
   - 被 `completed_recording_id` 引用的 recording artifact 不得进入普通容量 LRU 或 TTS cache cleanup 候选。
   - 文件缺失或内容 hash 不匹配时，不得直接把 session 改成未完成；应保留 completed session，并把录音 source 标为 unavailable / missing，UI 显示“完成记录存在但录音不可播放”的稳定状态。
   - 用户显式删除练习 session、未来显式删除录音、或 Entry / LanguageSpace 删除策略触发时，才允许删除对应完成态录音文件和 metadata；这些删除策略必须在 repository transaction 和 file cleanup 补偿中有测试。
7. 增加失败补偿和清理规则：数据库 reservation 成功但文件 move 失败时删除 metadata 或标记 failed；文件 move 成功但 ready 标记失败时下次启动通过 cleanup / recovery 扫描处理 pending artifact；磁盘空间不足、文件大小超限和 duration 校验失败不得产生 ready metadata。
8. 写 repository 测试覆盖创建 session、绑定 snapshot、material 重新分析后历史 session 仍可读取 snapshot、`sentence_id` 置空后历史 session 不丢失、绑定 recording、重录 attempt 排序、latest ready recording 查询、完成态只能引用 ready recording、完成态引用不随后续重录自动漂移、完成态录音不被普通 cleanup 选中、完成态录音文件缺失时 session 仍保持 completed 但 playback source unavailable、标记完成、标记问题句、按 Entry 查询最近状态、按具体句子恢复 session、软删除 Entry 后 active 查询不返回悬空练习、pending artifact recovery 和 file / metadata 不一致恢复。

### 11.3 阶段三：Speech 录音和回放服务

1. 新增 `PracticeRecordingService`，只负责录音生命周期，不负责练习业务状态。
2. 录音必须由用户显式点击开始触发。
3. 处理麦克风权限：not determined、authorized、denied、restricted / unavailable。
4. 录音文件写入 App 管理 staging 位置，停止并校验后提交到 repository 认可的位置。
5. 失败、取消或权限拒绝时清理 staging 文件，不写入 ready recording。
6. 回放服务只能播放 repository / resolver 返回的受限 source，不接受 UI 传入任意绝对路径。
7. 录音开始前必须停止或暂停当前示范 TTS；录音中禁用示范播放和录音回放；回放用户录音时禁用开始录音或给出稳定拒绝状态。
8. 录音服务需要独立于 TTS playback service 的错误分类，至少覆盖权限拒绝、权限受限、设备不可用、启动失败、停止失败、文件缺失、文件过大、解码 / 时长校验失败、取消和未知错误。
9. 新增前台音频协调服务，统一处理：
   - 开始录音前停止或暂停正在播放的 sentence TTS。
   - 用户录音回放与示范 TTS 互斥。
   - 录音中禁止开始其他播放。
   - 系统音频中断、耳机 / 蓝牙 route change、App 进入后台或失去 active 时的停止 / 失败策略。
   - Audio Session category / mode / option 切换，第一阶段仅承诺前台录音和前台回放。
10. 第一阶段录音必须设置最大时长和最大文件大小；推荐单句录音默认最大 60 秒、文件上限按格式配置，超限后自动停止并进入稳定错误或 ready 状态，具体阈值写入实施记录和测试。
11. 单元测试使用 fake recorder、fake player、fake audio session、fake clock、fake file store 和生成音频 fixture，不依赖真实麦克风。

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
   - iPhone route 建议拆为 `.practiceEntry(entryID)`、`.practiceSentenceList(entryID, materialID)`、`.practiceSentence(PracticeSessionRouteSeed)`；不得继续用 `.practice(entry.id)` 同时承载记录列表和单句 session。
   - iPad / macOS 可使用各自 route enum，但必须携带同一 `PracticeSessionRouteSeed`，避免平台间 session identity 分叉。
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
13. 新增或更新 UI tests 覆盖：练习 Tab 不显示未实现任务类型、记录卡片 line limit / 固定高度 projection、句子 row 状态投影、单句页 disabled 单词 / 短语入口不写入持久数据、route seed 包含 sentence identity。

### 11.5 阶段五：App 装配和权限配置

1. App Shell 装配 practice repository、recording service、playback service 和 UI action。
2. 必须通过 `project.yml` / plist 写入 iOS 和 macOS 的 `NSMicrophoneUsageDescription`，并补齐 macOS App Sandbox audio input entitlement；当前仓库还没有这些配置。
3. 权限说明文案必须面向用户，说明录音只用于本地跟读练习，不自动发送给 AI Provider；InfoPlist 权限说明必须纳入当前界面语言 / 本地化策略，不能只在一个 plist 写英文或中文孤本文案。
4. App Shell 应暴露 `PracticeActions` 或等价 action seam，包含 load/create session、start demo playback、start recording、stop recording、cancel recording、play recording、complete session、toggle problem mark 和 observe state；SwiftUI View 不直接持有 recorder、file URL、GRDB repository 或 AVFoundation concrete。
5. App test 覆盖 production assembly 可以构造 practice action、practice repository、recording service、recording playback service 和 audio coordinator，且不会回退到 disabled recording service。
6. 补充 typed diagnostic event：practice recording permission requested / denied、recording started / stopped / failed、recording committed、recording playback started / failed、practice session completed。attributes 只能使用 operation id、language space id hash 或 bucket、exercise type、duration bucket、byte size bucket、failure category、platform 和 permission status；禁止记录用户句子、Entry 正文、音频 bytes、波形原始数据、绝对路径和 API Key。
7. 权限、entitlement 和录音 service 装配完成后，需要至少记录一次 iOS Simulator、macOS 本机和一台真实 iPhone 或明确不可用原因的手动验证结果；模拟器不能替代真实设备麦克风验证。
8. 本任务会影响 App Store 隐私标签和发布说明，完成前必须检查 `docs/release/` 是否需要新增 microphone / user audio / local processing 说明；即使不发布，也要在计划实施记录里说明处理结果。

### 11.6 阶段六：文档和验证收口

1. 更新 `docs/platform-page-inventory.md`：练习会话从 Local Mock 更新为真实本地练习录音闭环。
2. 更新 `docs/spec/007-data-storage-migration-export-and-attachments.md`：若新增 practice recording metadata 或用户录音 policy。
3. 更新 `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：若新增具体权限文案、失败状态或日志字段。
4. 更新 `docs/architecture/002-system-map.md`：如果练习录音成为当前真实能力。
5. 更新或新增 practice / media artifact 实现地图：如果通用 `MediaArtifact` commit contract 成为长期基础设施，应同步 `docs/spec/007-data-storage-migration-export-and-attachments.md` 或新增 `docs/spec/media-artifacts/impl.md`，避免后续开发继续误以为 artifact store 是 TTS 专属。
6. 如果本任务明确暂不实现同步 / 导出 / 可恢复备份录音，但 schema 和 policy 会影响这些未来能力，应在 `docs/architecture/notes/` 创建或更新录音同步 / 导出开发备忘录，记录当前 local-only 决策、提升条件和后续 manifest 风险。
7. 完成后将本方案移入 `docs/plans/done/`，记录验证命令和提交信息。

## 12. 复查方法

复查时必须确认：

- 练习会话真实状态不是纯 SwiftUI 本地 step。
- 用户录音必须由显式点击触发。
- 未授权麦克风时不会创建录音文件或完成记录。
- 取消或失败不会留下 ready metadata 指向不存在文件。
- 日志不包含音频内容、完整句子、Entry 正文、绝对路径或 API Key。
- TTS 听示范仍走现有逐句播放边界，不新增重复 TTS 请求路径。
- 当前逐句 `练` 入口已经携带稳定 sentence identity；如果仍只有 Entry 级 route，则不得声称实现了“当前句”练习闭环。
- 单句 session 创建时已经保存目标句内容快照；重新分析 LearningMaterial、删除旧 sentence 或 current material 变化后，历史练习仍能展示练习时的目标句文本、翻译 / note 快照和完成状态。
- `practice_sessions.sentence_id` 的 FK / soft reference 语义清楚，不会因为 `learning_material_sentences` 删除级联导致历史练习证据丢失。
- iOS 练习 Tab 首层已经改为记录卡片列表，且不再展示“从生活进入练习”标题或未实现的任务类型混排。
- iOS 练习 Tab 记录卡片有稳定高度、明确 line limit 和尾部省略；长文本不会把卡片无限撑高，也不会遮挡底部 Tab 或主操作。
- 练习 Tab 和记录 / 单句页面复用了现有设计系统、SwiftUI 架构和 Apple 交互规范，没有新增临时卡片样式、硬编码颜色或未本地化文案。
- 记录练习页已经提供句子队列、句子状态和空状态；单句页从队列进入，而不是从 Entry 级页面隐式选句。
- 单句页的翻译 / 说明只来自已有 LearningMaterial；未新增 AI 语法分析请求。
- 单词 / 短语标记若出现，只能作为明确的扩展入口或 disabled affordance，不得写成单词本已完成。
- 练习录音没有复用 TTS 专属 artifact key、TTS 专属 repository method 或 `tts_audio_artifacts` 表。
- 媒体资产提交已提升为通用 commit / lookup / resolver contract，或已有明确架构理由说明为何暂时保留 TTS wrapper 但底层不再 TTS 专属。
- `practice_sessions` 包含 `exercise_type` 和完成态录音引用；完成态不会因后续重录或 failed attempt 漂移。
- 被完成态引用的录音不会被普通 media artifact LRU、TTS cache cleanup 或派生缓存清理静默删除；如果文件意外缺失，session 仍保持 completed，并通过稳定 unavailable 状态告知用户录音不可播放。
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
- 系统音频中断或 App 进入后台：第一阶段进入停止 / 失败 / 可重试状态，不继续后台录音。
- 磁盘空间不足或文件超限：停止写入，清理 staging，不生成 ready recording。
- 文件 move 成功但 metadata ready 失败：通过 pending artifact recovery 或 cleanup 处理，不暴露悬空 ready 录音。

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
- `docs/release/README.md` 或相关发布隐私文档是否需要记录 microphone / user audio / local processing 影响。
- `docs/review/INDEX.md` 是否需要触发专项文档影响审查。

## 15. 实施记录

2026-05-25：创建 Draft active plan。尚未实施代码。
2026-05-25：按系统架构和 Apple 三端交互角度完成严格复审，并补充句子级 session 粒度、媒体资产非 TTS 专属扩展、录音 / 播放互斥、权限配置和三端 UI 控制边界。尚未实施代码。
2026-05-26：采纳用户对 iOS 练习 Tab 的三层交互方向，并完成 Apple 交互复审：练习 Tab 改为记录卡片列表，记录练习页承载句子队列，单句页承载跟读录音完成；第一阶段只展示已有翻译 / note，不新增 AI 语法分析请求；单词 / 短语标记仅作为扩展点。尚未实施代码。
2026-05-26：补充 iOS 练习 Tab 记录卡片高度、长文本省略和规范遵循要求：卡片常规高度保持可扫描，长文本通过 line limit 和尾部省略处理，开发必须遵循 UI 设计系统、SwiftUI 架构和 Apple 交互 / 可访问性规范。尚未实施代码。
2026-05-26：根据系统架构严格审查继续修订：补充 `exercise_type`、`completed_recording_id`、通用 MediaArtifact commit / resolver contract、practice recording typed extension metadata、前台音频协调服务、route seed identity、权限文案本地化、typed diagnostics、发布隐私影响、pending artifact recovery 和系统音频中断 / 后台 / 磁盘空间异常边界。尚未实施代码。
2026-05-26：根据系统架构师再次严格代码审查修订：补充 `PracticeSentenceSnapshot` / 句子内容快照要求，明确历史 session 不依赖 current LearningMaterial；补充 `sentence_id` nullable soft reference / `ON DELETE SET NULL` 方向；补充 completed recording retention policy，禁止完成态录音被普通 LRU / cache cleanup 静默删除；新增阶段零 MediaArtifact API review。尚未实施代码。
2026-05-26：用户确认审核通过并批准进入实现；状态已从 `Draft` 改为 `Approved`。接下来先单独提交本方案文档改动，再按方案从阶段零开始实施。
2026-05-26：阶段零 MediaArtifact API review 已完成并写入 `docs/spec/media-artifacts/impl.md`。冻结结论：`media_artifacts` 是通用主表；TTS 和 practice recording 通过 typed extension metadata 分离；现有 public facade 仍偏 TTS，练习录音实现前必须提升通用 commit / lookup / resolver contract；`derivation_kind` 需新增 `practiceRecording`；被完成态引用的用户录音不得被普通 LRU / TTS cache cleanup 静默删除，文件缺失时保留 completed session 并标记 playback source unavailable。
2026-05-26：实施完成 Core 练习领域模型、`PracticeSessionReducer`、前台音频协调状态、practice recording artifact key；Data 新增 `v9_create_practice_recording_infrastructure` migration、`GRDBPracticeRepository`、practice recording typed metadata、completed recording cleanup exclusion；Speech 新增 `PracticeRecordingService`；App 新增 `PracticeActionsAssembly`、`AppPracticeRecordingEngine`、iOS / macOS microphone purpose string 和 macOS audio input entitlement；UI 将练习 Tab 改为记录卡片 -> 句子列表 -> 单句跟读录音完成闭环，三端共享 `PracticeSessionRouteSeed`、`PracticeActions` 和 `PracticeSessionViewModel`。
2026-05-26：文档同步完成。更新 `docs/README.md`、`docs/platform-page-inventory.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`、`docs/spec/media-artifacts/impl.md`、`docs/architecture/002-system-map.md`、`docs/testing/README.md`、`docs/release/README.md`，并新增 `docs/architecture/notes/2026-05-26-practice-recording-sync-export-notes.md` 记录录音同步 / 导出 / 可恢复备份的后续决策边界。
2026-05-26：聚焦验证通过：`swift test --package-path Packages/LangoTraceCore --filter 'PracticeSessionReducerTests|PracticeAudioCoordinationTests'`、`swift test --package-path Packages/LangoTraceData --filter 'GRDBPracticeRepositoryTests|MediaArtifactRepositoryTests|practiceRecordingMigrationCreatesSnapshotSessionsRecordingsAndTypedArtifactMetadata'`、`swift test --package-path Packages/LangoTraceSpeech --filter PracticeRecordingServiceTests`、`swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|PracticeRouteSeedTests|PhoneIOSConvergenceTests'`、`xcodegen generate && xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests/PracticeRecordingConfigurationTests -only-testing:LangoTraceAppTests/AppEnvironmentPracticeBootstrapTests`。
2026-05-26：完整验证通过：`scripts/verify.sh` 成功完成 XcodeGen、package tests、工具测试、iPhone / iPad / macOS build、macOS app tests、SwiftLint、SwiftFormat 和文档 placeholder 扫描。真实 iPhone 麦克风人工验证未在本自动化会话中执行，剩余风险保留在第 17 节。
2026-05-26：post-implementation 全面复审发现语义缺口：单句 `PracticeSessionView` 未在页内接入听示范 TTS，也未提供用户录音回放入口；`PracticeActions` / `PracticeSessionViewModel` 只覆盖 create / start recording / stop recording / complete。该缺口先记录到 active bug plan，随后通过 `docs/plans/done/2026-05-26-bug-practice-session-playback-completion-gap.md` 完成修复并归档。
2026-05-26：缺口修复完成并归档到 `docs/plans/done/2026-05-26-bug-practice-session-playback-completion-gap.md`。单句页现在可复用逐句 TTS action 听示范，可通过 ready recording artifact resolver 回放用户录音；开始录音前会停止当前示范播放，录音中禁用示范和回放，文件缺失或 hash mismatch 时保持 completed session 并显示不可播放失败。

## 16. 完成标准

本任务可以从 `active/` 移入 `done/` 的条件：

- 用户已确认方案进入实现。
- 实施前已完成通用 MediaArtifact API review，并在实施记录或 spec 中冻结 commit / resolver / typed metadata / retention / cleanup contract。
- Core / Data / Speech / UI / App Shell 相关实现完成。
- 练习会话三步闭环可从真实 Entry / LearningMaterial 进入。
- 三端 route 和 action seam 均携带同一 `PracticeSessionRouteSeed` 或等价 sentence identity，不再通过 Entry 级 route 隐式选句。
- Practice session 创建时保存句子内容快照；历史练习读取不依赖 current LearningMaterial 或 current sentence list 仍存在。
- Practice session schema 包含 `exercise_type` 和完成态录音引用；完成操作在事务中校验 ready recording。
- `sentence_id` 历史引用语义、删除策略和 snapshot fallback 已通过 Data 测试覆盖。
- 用户录音通过通用 MediaArtifact commit / resolver contract 和 practice typed metadata 管理，不写入 TTS 专属 extension table。
- 被完成态引用的用户录音具备 retention / cleanup 保护；文件缺失时不会抹掉 completed session。
- 前台音频协调服务已覆盖示范 TTS、录音、录音回放和系统音频中断的互斥边界。
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
- 如果通用 MediaArtifact commit contract 的抽象边界设计过窄，后续照片附件、导出产物或同步 manifest 仍可能返工；实施时应优先做一次小型 media artifact API review。
- 如果练习句子快照保存过少，后续 LearningMaterial 重新分析或删除旧句子后，历史练习可能只能显示 hash 或缺失内容；因此本任务必须优先保存必要 snapshot，而不是依赖 current material 回查。
- 如果 completed recording retention 没有和普通 TTS cache cleanup 分离，用户已完成练习的录音证据可能在容量清理时被静默删除；这是不可接受的数据一致性风险。
- 第一阶段不做后台录音；系统中断、后台切换和长时间录音只保证稳定失败 / 停止，不保证恢复到录音前毫秒级状态。
- 当前计划采用“单句跟读 session”作为第一阶段推荐粒度；如果用户更希望一次 session 覆盖整篇 Entry 的多句队列，需要在实施前调整 schema、route 和 UI，不宜在开发中临时混用两种语义。
- iOS 句子页是否展示全文应保持折叠上下文，不应默认占据练习主视图；如果人工测试发现用户频繁迷失上下文，再考虑提高概览可见性。
- 词级选择和短语标记在 SwiftUI 文本中可能涉及 selection、range mapping、本地化分词和目标语言脚本差异，必须单独设计，不能在录音闭环中临时实现。
- 单句页听示范和录音回放已补齐；真实 iPhone 和 macOS 设备上的麦克风权限、录音回放音频路由、系统中断和前后台切换仍需要人工验收。
