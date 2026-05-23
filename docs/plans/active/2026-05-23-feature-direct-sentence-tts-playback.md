# 任务方案：逐句分析直接播放 TTS 音频

状态：Draft
类型：feature
创建日期：2026-05-23
最后更新日期：2026-05-23

审核状态：Needs Changes

## 用户确认记录

- 2026-05-23：用户提出在 iPhone `记录详情` 页面 `逐句练习 / 逐句分析` 区域，点击句子播放按钮时不再弹出 `听一句` sheet，而是直接播放对应音频。
- 2026-05-23：用户确认当前 `听一句` sheet 中的意思、听力重点、练习方式和本地练习说明均不重要，可以删除。
- 2026-05-23：用户确认播放功能未来需要调用文本转语音 API 进行配音，用户会先在设置界面完成 TTS API 配置和测试；点击播放时不再设计逐次确认环节。
- 2026-05-23：用户确认本方案有实施前提：必须先完成文本转语音功能的 API 配置和测试，前提完成后再实施本方案。
- 2026-05-23：系统架构复审确认，本方案交互方向成立，但当前不具备实施条件。原因：现有代码只有 AI Provider 设置页中的可选 speech endpoint 保存能力和 probe 结果占位，没有可用 TTS probe、TTS 生成服务、音频播放服务、音频缓存模型、跨句播放协调器或隐私规范修订。本方案必须等待这些前置能力完成并验证后才能进入 `User Approved` 或 `In Progress`。
- 2026-05-23：人工测试发现旧 `听一句` sheet 仍会弹出。作为真实 TTS 前置 UI 清理，已允许先删除旧解释型 sheet 路径，改为原位轻量播放 / 暂停反馈；这不等于真实 TTS 直播放能力已完成。
- 2026-05-23：用户要求先把实际使用时配音后音频如何存储的问题详尽记录到本方案中；后续实施本方案前，再围绕音频缓存、附件、清理、同步和导出边界进行专门讨论和确认。
- 2026-05-23：用户补充早期开发原则：发现错误或落后框架可以推倒重来，不背历史包袱；基础设施应在首次实现时采用最优完整方案；规范文档可随更优设计演进；后续扩展但暂不实现的架构问题应进入对应开发备忘录。基于该原则，本方案采纳“本地媒体派生资产基础设施”推荐：逐句 TTS 音频不是临时 UI 缓存，而是本地优先、隐私敏感、可重建的派生媒体资产，真实逐句播放必须先建设通用媒体资产 metadata、文件存储、失效、清理和播放协调边界。
- 2026-05-23：`docs/plans/done/2026-05-23-feature-tts-provider-configuration-test.md` 已完整落地。TTS Provider 配置、真实语音模型测试、当前语言空间目标语言测试文本、voice profile、配置 fingerprint、短生命周期 preview audio、Speech bytes-based 音频校验 seam 和可播放配置读取接口已满足；本方案剩余硬性前置曾是本地媒体派生资产基础设施和逐句播放协调 / UI 接入边界，后续已由本地媒体派生资产方案完成其中基础设施部分。
- 2026-05-23：`docs/plans/done/2026-05-23-feature-local-media-artifact-store-and-tts-audio-cache.md` 已落地。Core media artifact / TTS artifact key、GRDB metadata、`LocalMediaArtifactFileStore`、`LocalMediaArtifactStore` facade、Speech 持久 TTS 文件校验、命中 / 失效 / 清理测试均已具备；本方案剩余硬性前置收窄为真实 TTS generation service、正式 playback service、跨句播放 coordinator 和 UI 接入。

## 1. 需求描述

此前 iPhone `记录详情` 页面中，逐句分析卡片右上角的听一句按钮会打开 `LocalListeningPreviewView` sheet，sheet 内重复展示目标句、播放示例、意思、听力重点、练习方式和本地隐私说明。该旧 sheet 路径已在 2026-05-23 的 UI 前置清理中删除，当前点击只在原位切换轻量播放 / 暂停反馈；真实 TTS 生成和音频播放仍等待前置服务能力。

该交互与用户点击喇叭按钮的直接意图不一致。播放按钮应承担即时播放职责，而不是打开一个阅读型 sheet。后续在本地媒体派生资产基础设施和播放协调能力完成后，应保持旧 sheet 路径删除状态，并将句子播放按钮改为：

1. 已有配音音频时，直接播放对应句子的本地音频。
2. 尚未配音时，调用已配置并已测试通过的 TTS Provider 生成该句音频，生成完成后自动播放。
3. 播放、生成、失败、未配置等状态在原句子卡片内反馈，不再弹出阻断式 sheet 或逐次确认。

## 2. 实施前提

本方案不得先于 TTS Provider 配置测试和本地媒体派生资产基础设施实施。当前 TTS Provider 配置测试和本地媒体派生资产基础设施前置已经完成；本方案仍不得进入真实播放实施，直到真实 TTS generation service、正式 playback service 和跨句播放协调边界完成并验证。

已满足前置：

1. 设置界面已经提供 TTS Provider 配置入口，覆盖 Provider / Base URL / model / voice / format / speed / instructions / API Key 引用方式和当前语言空间目标语言上下文。
2. TTS Provider 敏感凭证已经进入 Keychain 或等价安全存储，普通 SQLite / GRDB 配置只保存非敏感字段。
3. 设置界面已经提供真实 TTS 配置测试能力，使用当前语言空间目标语言对应的低敏固定测试文本验证 endpoint、凭证、模型 / voice、请求路径、鉴权头、响应 Content-Type、音频字节可解码性和错误分类。
4. TTS 配置测试通过后，App 可以明确区分 `未配置`、`配置草稿未测试`、`配置已测试可用`、`上次测试失败` 和 `配置已变更需重测`。
5. TTS 配置界面已经承担授权说明：用户点击句子播放时，会把该句目标语言文本发送给用户选择的 TTS Provider 生成音频；播放按钮不会在每次点击时再次弹出确认。
6. `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已接受“设置页完成配置、测试和披露后，学习页面显式点击单句播放可直接发起 TTS 请求”的边界；本方案实施时必须继续遵守该边界，页面展示、滚动、进入详情、保存记录、批量预生成、照片、音频、OCR、历史记忆或多条 Entry 上下文不得自动发送文本。
7. TTS 请求日志和诊断事件只能记录非敏感元数据，例如 provider id、voice id hash 或分类、文本长度分桶、duration、失败阶段和错误分类，不得记录完整句子文本、API Key、Authorization header、完整请求体、完整响应体或 audio bytes。

已满足的本地媒体派生资产前置：

1. 已生成音频的本地媒体派生资产基础设施已经实现并验证，包含 GRDB metadata、App 管理的 `MediaArtifacts` 文件目录、staging 写入、原子移动、文件 hash / size 校验、失效、清理和 policy 边界，能避免同一句同配置下重复调用 API。
2. TTS audio artifact key 已由 Core 定义并测试，包含稳定句子来源、文本内容 hash、目标语言 code、provider profile id、endpoint id、voice profile id、adapter kind / version、model / voice hash、format、语速或 style 参数 hash、provider parameters hash 和配置 fingerprint；文本、voice、模型、adapter 或配置变化时不得复用旧音频。
3. `Packages/LangoTraceData` 已提供 media artifact metadata repository、migration、file store、facade 和 cleanup；文件存储只保存相对路径，完整句子文本、请求体、响应体、API Key、Authorization header 和 audio bytes 不进入 metadata 或 validation event。
4. `Packages/LangoTraceSpeech` 已提供持久 TTS 文件校验 seam；设置页短生命周期 preview playback 仍不能直接替代逐句正式 playback service。

仍未满足的硬性前置：

1. 必须提供跨平台播放服务和句子播放协调边界，能在 iPhone / iPad / macOS 上完成播放、暂停、停止、切换句子时取消或降级上一句、生成完成后的 active key 校验、App 进入后台 / 页面销毁时释放播放资源。
2. 必须提供真实 TTS generation service，把已测试可用的 TTS Provider 配置、目标句文本和 `LocalMediaArtifactStore` 串联起来；本地媒体派生资产基础设施本身不发起 Provider 请求。
3. `Packages/LangoTraceUI` 不得直接依赖网络、Keychain、文件系统细节、SQLite / GRDB 或 AVFoundation 具体实现；UI 只能调用由 App Shell 注入的 action / service 协议。

若上述任一条件未满足，本方案保持 Draft，不进入实现。

## 3. 现状描述

当前代码事实：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift` 中的 `SentencePairView` 不再持有 `isListeningPreviewPresented`，也不再通过 `.sheet` 展示听力说明。
- `SentencePairView` 当前持有临时 `@State private var isLocalPlaybackActive = false`，点击听一句只在原位切换播放 / 暂停视觉反馈；这只是避免旧 sheet 回归的 UI 前置清理，不是最终 TTS 播放状态模型。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalListeningPreviewView.swift` 已删除，`Localizable.xcstrings` 中的 `listeningPreview.*` 专用文案已清理。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentencePairActionControls.swift` 中的听一句按钮仍是 44pt 圆形图标按钮，具备直接播放动作的视觉基础，并能根据 `isListening` 切换 `speaker.wave.2` / `pause.fill` 图标。
- AI Provider 设置页已经具备 TTS 配置、voice / format / speed / instructions 字段、真实 TTS probe、当前语言空间目标语言测试文本、结果面板短生命周期试听入口和可播放配置读取接口。
- `Packages/LangoTraceAI` 已提供 OpenAI / OpenRouter Audio Speech adapter、TTS response validator 和 TTS configuration probe service；AI package 不直接依赖 `LangoTraceSpeech`，音频校验通过 Core 协议注入。
- `Packages/LangoTraceData` 已能同事务保存 profile endpoint、endpoint 级 TTS settings 和 language code 级 voice profile，并记录 TTS probe 结果；同时已提供 `media_artifacts` / `tts_audio_artifacts`、`GRDBMediaArtifactRepository`、`LocalMediaArtifactFileStore`、`LocalMediaArtifactStore` facade 和 cleanup。
- `Packages/LangoTraceSpeech` 已提供 bytes-based `DefaultTTSAudioValidationService`、短生命周期 preview store / preview playback service、持久文件级 `TTSAudioFileValidator` 和 `LangoTraceSpeechTests`；但尚未提供正式音频 playback coordinator。
- `LangoTraceApp/AppEnvironment.swift` 已能为设置页 TTS probe / preview 装配 Speech seam；但尚未装配逐句播放所需的 TTS generation + playback coordinator。
- 当前已完成 TTS 真实配置测试、短生命周期 preview audio、语音 Provider 验证结果持久化、可播放配置读取和本地媒体派生资产基础设施；尚未完成真实逐句播放、正式音频播放服务和跨句播放协调器。

当前文档事实：

- `docs/product-main-reference.md` 将“听说：生成目标语言音频，用户可以朗读、跟读、影子跟读、模仿和背诵”定义为核心学习闭环的一环。
- `docs/product-main-reference.md` 第 9.5 节建议支持全文朗读、逐句播放、单句循环、慢速播放、原速播放和跟读录音。
- `docs/technical-framework-roadmap.md` 将 `TTSProvider` 列为 Provider 抽象之一，并说明高质量拟真语音、音频文件生成和跨设备音频应通过 TTSProvider 接入外部服务。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已修订外部 TTS Provider 请求预览边界：设置页完成配置、测试和披露后，学习页单句显式点击播放可以直接调用已配置 TTS Provider；页面展示、滚动、保存记录、进入详情、批量预生成、照片、音频、OCR、历史记忆或多条 Entry 上下文不得复用该低摩擦边界。

## 4. 目标

本任务完成后，应达到以下目标：

1. 逐句分析卡片中的听一句按钮不再打开 sheet。
2. 当前 `LocalListeningPreviewView` 及其专用本地化文案从真实播放路径中删除；如果没有其他引用，应删除该 view。
3. 听一句按钮成为原位状态控件，支持 `idle`、`generating`、`playing`、`paused`、`failed` 和 `requiresConfiguration` 状态。
4. 已配音句子点击后直接播放本地音频。
5. 未配音句子点击后调用已测试通过的 TTS Provider 生成音频，成功后自动播放并缓存。
6. TTS 未配置或配置不可用时，不弹出旧 sheet；在原位展示轻量提示，并提供进入 TTS 设置的路径或明确说明需要先完成配置。
7. 点击播放是唯一触发外部 TTS 请求的学习页面动作；页面展示、滚动、进入记录详情、生成学习材料完成和切换句子都不得自动发起 TTS 请求。
8. 同一时间只允许播放一句；切换句子时停止上一句。
9. VoiceOver 文案能区分“播放第 N 句目标语言音频”“暂停第 N 句目标语言音频”“正在生成第 N 句音频”和“需要先配置 TTS”。

## 5. 范围

本任务范围：

- iPhone / iPad / macOS 复用的 `SentencePairView` 和逐句播放控件状态模型。
- iPhone `记录详情` 页面中的逐句分析听一句交互。
- 删除或退出 `LocalListeningPreviewView` 作为播放 sheet 的路径。
- 接入前置 TTS 服务暴露的“生成并播放单句音频”能力。
- 对已完成配音的本地音频进行直接播放。
- 针对未配置、生成中、失败、播放中和暂停状态补充 UI 测试或源码约束测试。

## 6. 不做什么

本任务不实现以下内容：

- 不实现 TTS Provider 配置页、凭证保存、配置测试或配置授权说明；这些属于实施前提。
- 不设计每次点击播放前的请求确认、请求预览 sheet 或阻断弹窗。
- 不实现批量预生成整篇学习材料音频。
- 不在页面进入、滚动、预览或学习材料生成完成时自动请求 TTS。
- 不实现录音、跟读评分、听写结果、Speech 识别或后台音频播放。
- 不改变 `Entry`、`LearningMaterial`、逐句分析文本或 Prompt 输出结构。
- 不实现音频跨设备同步；音频同步策略需后续同步 / 附件方案单独决策。

## 7. 证据与决策依据

产品依据：

- 语迹的核心闭环包含“听说”，逐句播放是从生活记录进入听读和跟读的高频动作。
- 播放按钮的用户意图是即时听音频，而不是查看解释型内容。
- `听一句` sheet 中的信息与记录详情的逐句分析上下文重复，且会遮挡当前句子和练习入口。

交互依据：

- iOS 高频播放操作应尽量使用原位反馈，避免每次打开 sheet 造成上下文丢失。
- 当前句子卡片已有 44pt 听一句按钮，符合触控目标要求，可以承载直接播放 / 暂停状态。
- 生成中、失败和未配置属于播放控件状态，不应升级为阻断性导航层级。

隐私和 Provider 边界依据：

- 用户已明确要求 TTS API 配置和测试在设置界面完成，学习页面点击播放时不再逐次确认。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已接受“设置页授权说明 + 单句显式点击播放免逐次请求预览”的边界；本方案必须继续把该边界限制在用户显式点击的单句目标语言 TTS。
- 低摩擦播放只适用于用户显式点击的单句 TTS 请求，不扩展到自动预生成、批量生成、照片、音频、OCR、历史记忆或多条 Entry 上下文。

## 8. 涉及的代码文件路径

预计修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentencePairActionControls.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`

可能修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AppearanceSettingsTests.swift`

已完成前置删除，真实实施时必须保持删除状态：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalListeningPreviewView.swift`
- `Localizable.xcstrings` 中仅供 `LocalListeningPreviewView` 使用的 `listeningPreview.*` 文案。

依赖前置任务提供的代码边界：

- TTS Provider 配置状态读取接口。
- 单句 TTS 生成接口。
- 本地媒体派生资产查询、写入、失效和清理接口。
- 播放 / 暂停 / 停止音频的服务接口。
- TTS 诊断事件记录接口。
- 跨句播放协调接口：保证同一 entry 或同一页面内同时只有一个句子处于 generating / playing 主状态；新句子开始播放时必须取消或停止上一句。
- 生命周期接口：页面销毁、Entry 切换、语言空间切换、App 进入后台或音频服务失效时，UI 能收到状态回收或失败事件。

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentencePairActionControls.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalListeningPreviewView.swift`，已删除；保留在参考列表中用于防止旧 sheet 路径回归。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/SpeechBoundary.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`

## 10. 涉及的文档路径

本方案创建：

- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md`

已完成前置：

- `docs/plans/done/2026-05-23-feature-tts-provider-configuration-test.md`

仍待完成前置：

- `docs/plans/done/2026-05-23-feature-local-media-artifact-store-and-tts-audio-cache.md`

本方案实施前必须继续确认：

- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/platform-page-inventory.md`

本任务实施时按影响更新：

- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/review/INDEX.md` 或专项审查记录，若 TTS / Provider / 隐私规则发生实际变更。

## 11. 实施方案

### 11.1 实施前检查

实施前必须执行：

```bash
rg -n "TTS|文本转语音|TTSProvider|语音生成|听一句|LocalListeningPreviewView|request preview|请求预览" docs Packages
git status --short
```

必须人工确认：

- TTS 配置与测试任务已经完成并验证通过；当前依据为 `docs/plans/done/2026-05-23-feature-tts-provider-configuration-test.md`。
- TTS 设置页已经承担播放授权说明，并且 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已不再要求用户每次点击单句播放都进入请求预览。
- `docs/plans/done/2026-05-23-feature-local-media-artifact-store-and-tts-audio-cache.md` 已完成并移入 done，且提供可调用的本地媒体派生资产查询 / 写入 / 失效 / 清理接口。
- 前置任务或本任务新增 coordinator 已给出可调用的 TTS 配置状态、单句生成和播放 / 暂停 / 停止接口。

### 11.2 测试先行

在 `Packages/LangoTraceUI/Tests/LangoTraceUITests/` 中新增或更新聚焦测试，固定以下行为：

- `SentencePairView` 不再包含 `LocalListeningPreviewView`、`.sheet(isPresented: $isListeningPreviewPresented)` 或 `isListeningPreviewPresented`。
- `SentencePairActionRow` 的听一句动作进入直接播放状态模型，而不是打开 sheet。
- 听一句按钮保留 44pt 最小触控目标。
- 未配置 TTS 时显示非阻断原位状态，不显示旧 sheet 文案。
- 播放中状态的无障碍文案与待播放状态不同。
- `PhoneIOSConvergenceTests` 和 `PremiumUIBehaviorTests.stageFourVisibleInteractionAndAccessibilityGapsStayClosed` 已迁移为禁止旧 sheet、禁止 `LocalListeningPreviewView` 回归，并要求逐句播放保持原位反馈。
- `AppearanceSettingsTests` 已移除 `LocalListeningPreviewView.swift` 的 filled primary action token 扫描项，避免删除旧 view 后测试读取不存在文件。

聚焦验证命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
swift test --package-path Packages/LangoTraceUI --filter PremiumUIBehaviorTests
```

### 11.3 UI 状态模型接入

根据前置 TTS 任务暴露的接口，在 UI 层引入轻量 presentation state。推荐状态语义：

```text
idle
generating
playing
paused
failed(message)
requiresConfiguration
```

状态模型只承载 UI 展示，不持久化到语言空间、Entry、LearningMaterial 或同步 manifest。

该状态不能只放在每个 `SentencePairView` 的私有 `@State` 中。原因：

- 当前页面会同时渲染多条 `SentencePairView`，私有状态无法保证同一时间只播放一句。
- 句子 A 生成中时用户点击句子 B，需要取消或忽略句子 A 的生成 / 自动播放结果，避免异步回调覆盖当前播放状态。
- Entry 切换、语言空间切换或页面销毁时，需要统一停止播放并释放资源。

推荐由前置 TTS service 或本任务新增的 UI action coordinator 提供按 sentence key 查询的状态，例如：

```text
SentenceAudioKey(entryID, materialID, sentenceIndex, textHash, targetLanguageCode, ttsConfigurationVersion)
```

UI 只订阅当前句子的 presentation state，并把点击事件交给 coordinator；coordinator 负责串行化生成、取消旧任务、播放排他和状态广播。

### 11.4 删除 sheet 路径

修改 `SentencePairView`：

- 删除 `isListeningPreviewPresented`。
- 删除 `.sheet` 和 `LocalListeningPreviewView` 调用。
- 将 `onListen` 改为调用播放 view model 或 store action。
- 保留 `onPractice` 进入练习路径。

如果 `LocalListeningPreviewView` 没有其他引用，删除该文件，并清理对应 `listeningPreview.*` 本地化文案和相关源码约束测试。

### 11.5 接入 TTS 生成与播放

点击听一句时按以下顺序处理：

1. 计算 `SentenceAudioKey`，并确认该 key 对应的 TTS 配置仍是已测试可用状态。
2. 查询该句在当前 TTS 配置下是否已有本地音频。
3. 有本地音频：停止其他句子播放，播放当前句音频。
4. 无本地音频且 TTS 配置已测试可用：取消当前其他句子的生成 / 播放任务，进入 `generating`，调用 TTS Provider 生成音频，写入本地媒体派生资产存储，成功后确认当前 active key 仍未变化，再播放。
5. 无本地音频且 TTS 未配置、未测试或配置已变更需重测：进入 `requiresConfiguration`，提供进入设置的轻量路径或状态说明。
6. 生成失败：进入 `failed(message)`，不记录完整句子文本到日志。
7. 用户再次点击当前播放句：暂停或恢复播放；用户点击另一句：停止当前句并切换 active key。

必须显式处理：

- 重复点击同一句导致的重复 TTS 请求。
- 生成请求完成时用户已经切换到另一句。
- Entry 被删除、LearningMaterial 重新生成、learning text 被编辑导致旧句子音频失效。
- 网络超时、Provider 返回非音频、音频文件写入失败、播放解码失败。
- App 进入后台、音频中断和路由变化。第一版如果不支持后台播放，必须在方案和 UI 状态中明确只做前台播放。

### 11.6 本地媒体派生资产基础设施

本方案采纳以下架构结论：逐句 TTS 音频不是临时 UI 缓存，也不是 Entry 正文这类用户主数据；它是本地优先、隐私敏感、可重建的派生媒体资产。真实逐句播放不得把音频文件写入临时目录、SwiftUI 私有状态、不可索引的 ad hoc 文件名，或只为 TTS 单点能力临时创建一套无法复用的缓存逻辑。

进入真实逐句播放实施前，应先建设或专门规划通用 `LocalMediaArtifactStore`，TTS 逐句音频作为第一类落地对象。该基础设施后续还应能承载全文朗读音频、用户跟读录音、听写录音、OCR 中间文件、导出包临时产物，以及未来可同步附件或派生媒体。因此第一版 schema、repository、文件目录和清理策略必须按可扩展基础设施设计，而不是只满足当前一个按钮。

推荐链路：

```text
SentencePairView
-> SentenceAudioPlaybackActions / SentenceAudioPlaybackCoordinator
-> SpeechService / TTSAudioPlaybackService
-> TTSAudioGenerationService
-> LocalMediaArtifactStore
   -> GRDB media artifact metadata repository
   -> Application Support media artifact file store
   -> invalidation / cleanup policy
```

模块边界：

- `LangoTraceCore`：定义 media artifact id、artifact type、owner reference、derivation key、TTS artifact key、播放 presentation state、领域错误和服务协议。
- `LangoTraceData`：实现 GRDB metadata repository、migration、索引、清理查询和文件相对路径引用，不直接播放音频。
- `LangoTraceAI`：负责 TTS Provider request builder、HTTP 请求、Provider 错误映射和非敏感 diagnostic event，不持有长期播放状态。
- `LangoTraceSpeech`：负责音频解码验证、播放、暂停、停止、AudioSession / AVFoundation 生命周期和跨句播放协调，不读取 Provider secret、不拼 Provider HTTP request。
- `LangoTraceUI`：只渲染状态和发送播放意图，不读取 SQLite、Keychain、文件路径、Provider request 或 AVFoundation。
- `LangoTraceApp`：通过 `AppEnvironment` 装配 Data / AI / Speech 的真实实现和测试替身。

#### 11.6.1 产品边界

已采纳：

- 配音音频第一版定义为“可重建的本地媒体派生资产”，不是普通系统缓存，也不是不可丢失的用户主资产。
- 已生成音频应支持离线播放；未生成过的句子离线点击时显示需要联网生成。
- 外部 TTS Provider 可能收费，因此命中同一 artifact key 时必须复用本地音频，避免重复扣费。
- 用户应能在设置中查看并清理 TTS / 媒体派生资产占用。
- 第一阶段不把 TTS 音频纳入跨设备同步、可恢复备份或默认导出；但 metadata 必须预留 `sync_policy`、`backup_policy` 和 `export_policy`，避免后续改造 schema。
- 多设备复用音频、批量预生成、全文朗读、跟读录音、听写录音和音频同步属于后续扩展；当前任务不提前实现，但必须通过架构开发备忘录或后续 active plan 保留边界。

#### 11.6.2 存储位置

已采纳：

- 真实逐句 TTS 音频应存放在 App container 的 `Application Support/LangoTrace/MediaArtifacts/` 或等价 App 管理目录下。
- 该目录默认设置 excluded from backup，除非后续备份 / 同步 / 导出方案明确改变该策略。
- 文件名使用 artifact id、content hash 或派生 key hash，不得包含原文、Entry 标题、用户输入短语、voice 明文、Provider secret 或其他可读敏感信息。
- `Caches` 不作为第一阶段主位置；系统可能随时清理，无法稳定支持离线复用和避免重复扣费。
- 临时目录只适合设置页测试试听、未完成写入或短生命周期 preview，不适合真实逐句播放缓存。
- 未来附件目录如果承载音频同步或导出，必须通过单独方案定义 manifest、加密、冲突处理、删除传播和用户可见说明。

#### 11.6.3 Metadata 与索引

进入真实实施前，必须新增 GRDB / SQLite metadata 表或等价 repository 能力。推荐模型为通用表加 TTS 专属字段；可用一张表落地第一版，但字段语义必须按通用媒体资产设计。

通用 media artifact metadata 至少包含：

- artifact id。
- language space id。
- owner type。
- owner id。
- artifact type。
- derivation kind。
- derivation key hash。
- relative file path。
- mime type。
- byte size。
- duration seconds。
- content hash。
- created at。
- last accessed at。
- invalidated at。
- delete after。
- backup policy。
- sync policy。
- export policy。

TTS 专属 metadata 至少包含：

- sentence source type。
- entry id。
- learning material id。
- sentence index 或等价稳定句子定位。
- sentence text hash，不保存完整句子文本作为 key、metadata 或日志字段。
- target language code。
- provider profile id。
- tts endpoint id。
- adapter kind。
- adapter version。
- model name。
- voice id hash，除非 Provider 风险评估允许明文。
- output format。
- sample rate。
- speed、pitch、volume。
- instructions / style prompt hash。
- provider parameters hash。
- configuration fingerprint。

失败生成不应长期写成 media artifact 主记录。生成失败属于 operation / diagnostic event，第一版只保存非敏感错误分类、阶段、duration、byte size bucket 等诊断元数据。

#### 11.6.4 Artifact Key

TTS artifact key 必须绑定所有会影响音频内容、合规性或可用性的字段，至少包括：

- 稳定句子来源。
- 句子文本 hash。
- 目标语言 code。
- provider profile id。
- tts endpoint id。
- adapter kind。
- adapter version。
- model name。
- voice id 或 voice hash。
- output format。
- sample rate。
- speed、pitch、volume。
- instructions / style prompt hash。
- provider parameters hash。
- configuration fingerprint。

不得只用 `entryID + sentenceIndex` 作为 key。否则当句子文本、语言空间、voice、模型、format、style、provider 参数或配置 fingerprint 变化时，可能播放过期或错误音频。

第一阶段不跨 Entry 全局复用同一句文本音频。原因：稳定来源纳入 key 后，删除、失效、隐私预期和诊断更清晰。若未来需要全局去重，应在不泄露文本内容的前提下单独设计 dedup index。

#### 11.6.5 写入与一致性规则

实现必须满足：

- 生成完成后先写临时文件，解码验证成功后再原子移动到正式 media artifact 目录。
- metadata 与文件写入必须有明确顺序；任一步失败都要清理半成品文件或回滚 metadata。
- App 崩溃、用户取消、页面关闭或语言空间切换时，半成品文件不得被当作 ready artifact。
- artifact 命中必须同时满足 metadata 存在、文件存在、文件可读、content hash / size 合法、configuration fingerprint 匹配。
- metadata 存在但文件丢失时，应清理 metadata 并按 miss 处理。
- 文件存在但 metadata 丢失时，第一版建议删除孤立文件，不做复杂修复。
- 同一个 artifact key 同时被多次请求时，必须复用 in-flight task 或串行化，不能并发请求 Provider 并写同一路径。
- 文件 IO、解码验证、Provider 请求和 metadata 写入不得阻塞主线程。
- metadata 的 ready 记录和文件正式路径应在服务层形成可测试的提交边界；SwiftUI View 不参与文件提交。

#### 11.6.6 失效与清理规则

以下情况至少应导致旧音频不可作为当前配置下的命中：

- 句子文本 hash 变化。
- target language code 变化。
- voice、model、format、sample rate、speed、pitch、volume、instructions、style prompt 或 provider parameters 变化。
- TTS configuration fingerprint 与最近成功测试 fingerprint 不一致。
- adapter version 或 request builder schema version 变化。
- Entry 删除、LearningMaterial 删除或重新生成。
- 用户删除语言空间。
- 用户删除 Provider profile、TTS endpoint 或当前 language code 的 voice profile。
- 缓存文件损坏、不可解码或格式不匹配。

清理策略第一阶段应具备：

- 设置页手动清理入口。
- 按 artifact type 和 language space 清理。
- 总大小上限或可配置清理阈值。
- 基于 last accessed at 的 LRU 清理。
- 启动或维护任务中的孤立文件 / 孤立 metadata 清理。
- 低磁盘空间或文件被系统 / 用户外部删除后的 cache miss 恢复路径。

#### 11.6.7 隐私、同步、备份与导出边界

音频虽然不包含可读原文字符串，但可以泄露用户学习内容和生活记录语义，因此必须按敏感本地媒体处理。

强制规则：

- 音频文件、audio bytes、完整句子文本、请求体、响应体和 Provider secret 不得进入日志、diagnostic event 或 validation event。
- 文件名和目录名不得包含原文、Entry 标题、用户输入短语、可读 Provider secret 或完整 Keychain account。
- 第一阶段 `sync_policy` 默认为 `localOnly`。
- 第一阶段 `export_policy` 默认为 `excludedByDefault`。
- 第一阶段 `backup_policy` 默认为 `excludedFromSystemBackup`。
- 诊断事件只能记录 cache hit / miss、byte size bucket、duration、error category、operation id、artifact type、provider preset id、endpoint purpose 等非敏感元数据。
- 若未来将音频纳入附件、同步、备份或导出，必须单独定义 manifest、加密、冲突处理、删除传播、恢复策略、导出选项和用户可见说明。

#### 11.6.8 用户交互结果

真实逐句播放必须呈现以下行为：

- 第二次点击已生成且 artifact key 命中的句子时，直接播放本地音频，不再次请求 TTS Provider。
- 当前句正在播放时再次点击，应暂停或恢复播放，不重新生成。
- 当前句正在生成时重复点击，应复用当前 in-flight 状态，不发起第二个相同 TTS 请求。
- 用户切换到另一句时，应停止当前播放；旧生成任务若已完成，可以入库为 ready artifact，但如果 active key 已变化，不得自动抢回播放。
- 缓存文件丢失或损坏时，应清理无效 metadata，回到生成流程或失败状态，并给出轻量提示。
- TTS 配置变更后，旧音频即使文件存在，也不得作为当前配置下的命中。
- 离线时已生成音频可播放；未生成音频进入轻量失败状态，提示需要联网生成。

#### 11.6.9 实施前必须形成的确认产物

进入真实逐句播放实施前，必须形成以下确认产物：

- 已完成前置方案：`docs/plans/done/2026-05-23-feature-local-media-artifact-store-and-tts-audio-cache.md`，已定义并实现本地媒体派生资产、TTS audio artifact、metadata schema、迁移、文件目录、清理、失效和测试。本方案真实实施前仍必须补齐 TTS generation service、正式 playback service 和跨句 playback coordinator。
- 更新 `docs/spec/007-data-storage-migration-export-and-attachments.md`，把 media artifact / derived media asset 作为数据与附件规范的一等规则，而不是留在单个 TTS 方案中。
- 更新 `docs/spec/011-tts-provider-configuration-and-playback.md`，把 TTS 音频存储从可演进部分提升为逐句播放前置基础设施。
- 已创建 `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`，覆盖全文朗读、跟读录音、听写录音、音频同步、音频导出和批量预生成的扩展提醒。后续任务若采纳其中内容，必须提升到 active plan、正式 spec、architecture 文档或 ADR。
- 如最终设计改变 ADR-005 的本地优先、用户自带 Provider 或敏感内容默认本地边界，必须新增或更新 ADR。

### 11.7 可访问性和反馈

听一句按钮必须保持：

- 最小 44pt 触控区域。
- 播放中、生成中和未配置状态的不同图标或进度反馈。
- VoiceOver label / hint 表达当前动作和句子序号。
- Dynamic Type 下不挤压句子正文或练习按钮。

## 12. 复查方法

代码复查重点：

- 是否彻底移除播放按钮打开 sheet 的路径。
- 是否没有在页面展示、滚动或进入详情时自动触发 TTS 请求。
- 是否只在用户显式点击听一句时触发单句生成或播放。
- 是否没有把 TTS 请求、生成中、播放中、失败提示等短生命周期状态写入 Core 主模型、同步 manifest 或非 media artifact 的持久表；允许且必须通过 media artifact metadata 记录 ready 音频的非敏感索引。
- 是否没有在日志、测试输出、诊断事件中记录完整句子文本、API Key、Authorization header、请求体或响应体。
- 是否没有把 TTS 配置未完成状态伪装成可用播放能力。
- 是否没有绕过 `LocalMediaArtifactStore`，把音频文件直接写入 UI、临时目录或不可索引路径。

文档复查重点：

- 前置 TTS 方案是否已经更新 Provider 请求预览规则。
- 本地媒体派生资产基础设施的 active plan、`007`、`011` 和架构备忘录是否保持一致。
- 本方案是否仍然只覆盖逐句直接播放，不扩展到批量生成、录音、听写或跟读评分。
- 页面清单和 UI flow 是否不再把 `听一句` sheet 当作当前交互事实。

## 13. 验证命令

本地媒体派生资产基础设施和播放协调前置完成后，本任务实施时至少运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
swift test --package-path Packages/LangoTraceUI --filter PremiumUIBehaviorTests
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

如果涉及 TTS Provider、媒体派生资产存储或诊断服务，还应追加前置任务定义的 Core / Data / AI / Speech package 聚焦测试。

## 14. 文档影响检查

本任务涉及 TTS、Provider、隐私边界、记录详情交互和页面路由层级，属于必须做文档影响检查的任务。

实施完成后至少检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

若删除 `LocalListeningPreviewView` 或改变 TTS 请求确认边界，必须同步检查：

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/platform-page-inventory.md`

## 15. 实施记录

- 2026-05-23：创建方案。当前仅记录交互决策和实施前提，不实施代码。实施必须等待 TTS API 配置、测试、授权说明、规范边界和音频生成 / 缓存 / 播放接口完成。
- 2026-05-23：按人工测试反馈先完成旧 sheet 路径清理：`SentencePairView` 删除 `isListeningPreviewPresented` 和 `.sheet`，删除 `LocalListeningPreviewView.swift`，清理 `listeningPreview.*` 本地化文案，并把源码约束测试改为禁止旧 sheet。当前只提供原位播放 / 暂停视觉反馈，不触发 TTS 请求，也不代表本方案真实播放链路已完成。
- 2026-05-23：根据用户要求补充“音频存储问题记录”。本次只详尽记录后续真实逐句播放实施前必须确认的缓存位置、metadata、cache key、写入一致性、失效清理、隐私、同步、导出和用户交互边界，不直接确定最终存储方案；进入真实实施前必须单独讨论并确认。
- 2026-05-23：根据用户补充的早期开发和基础设施原则，采纳“本地媒体派生资产基础设施”作为逐句 TTS 音频存储方向；重写 11.6，将音频从临时缓存提升为可重建、隐私敏感、App 管理的派生媒体资产，并要求真实逐句播放前先形成 LocalMediaArtifactStore / TTS audio artifact 的前置 active plan、spec 更新和架构开发备忘录。
- 2026-05-23：TTS Provider 配置测试方案已完成并移入 `docs/plans/done/`。本方案更新实施前提：TTS 配置、真实 probe、语言测试文本、voice profile、短生命周期 preview audio 和可播放配置读取接口已满足；剩余阻塞项是本地媒体派生资产基础设施、持久音频播放服务和跨句播放协调器。

## 16. 完成标准

本任务完成时必须同时满足：

- 用户点击逐句分析中的听一句按钮不再弹出 sheet。
- 旧 `听一句` sheet UI 不再作为播放路径存在。
- 前置本地媒体派生资产基础设施已经实现并验证，包含 metadata、文件原子写入、解码验证、失效、清理、policy 默认值和非敏感诊断边界。
- 已生成音频可以直接播放。
- 未生成音频可以在 TTS 配置已测试可用时生成并自动播放。
- 未配置或配置不可用时使用原位轻量反馈，不弹阻断确认。
- 同一时间只播放一句，切换句子会停止上一句。
- TTS 请求只由用户显式点击触发。
- 测试覆盖直接播放路径、未配置路径、artifact hit / miss / invalidated、重复点击 in-flight 复用、旧 sheet 删除和可访问性文案。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。
- 文档影响检查完成，相关事实源不再描述旧 sheet 为当前交互。

## 17. 剩余风险

- TTS Provider 配置任务已经定义“设置页授权说明替代逐次请求预览”的规范边界；后续实现必须保持该边界只适用于用户显式点击的单句 TTS，不得扩展到自动预生成或多条上下文。
- 不做逐次确认会降低摩擦，但仍要求设置页文案持续清楚，否则用户可能低估单句文本会发送给外部 TTS Provider。
- 外部 TTS 费用、速率限制和失败重试策略如果在播放 coordinator 中没有继续收口，直接播放体验可能出现不可解释的等待或失败。
- TTS artifact key 若没有包含文本、目标语言、voice、模型、语速、Provider 参数、adapter 版本和配置 fingerprint，可能播放过期或错误音频。
- 批量预生成音频不在本方案范围内；未来若加入，必须单独设计授权、费用提示、队列、失败恢复和取消机制。
- 如果只在 UI package 内实现播放状态，会违反 `docs/spec/004-swiftui-architecture.md` 中“AI、TTS、OCR、Speech、Sync 必须通过协议或服务层进入 UI”的边界。
- 当前 AI Provider 设置页已有真实 TTS probe 和可用性状态；实施者仍不得只看 speech endpoint 是否存在，必须以前置 TTS 测试通过且 fingerprint 与当前配置一致作为播放前置。

## 18. 系统架构复审结论

状态：Needs Changes，不具备立即实施条件。

当前结论更新：TTS Provider 配置与测试前置、本地媒体派生资产基础设施均已满足；本方案仍不具备立即实施条件，因为真实 TTS generation service、持久音频播放服务和跨句播放协调器尚未完成。

### 18.1 代码现状准确性

准确：

- 原审查时，`SentencePairView` 确实通过 `isListeningPreviewPresented` 打开 `LocalListeningPreviewView` sheet。
- 2026-05-23 UI 前置清理后，旧 sheet 路径和 `LocalListeningPreviewView.swift` 已删除；当前只剩原位轻量播放 / 暂停反馈，不接真实 TTS。
- `SentencePairActionButton` 当前有 `minWidth: 44, minHeight: 44`，可作为直接播放按钮的触控基础。
- `Localizable.xcstrings` 中原有 `listeningPreview.*` 文案已随旧 sheet 删除同步清理。

需要补强：

- AI Provider 设置页已经不再只是 speech endpoint 保存路径；当前已有 TTS 配置测试、音频响应解码校验和短生命周期 preview 试听。但这些能力只服务配置页测试，不等同于逐句播放的持久缓存与播放协调。
- `LangoTraceSpeech` 已具备 bytes-based TTS audio validation 和 preview playback seam；但尚未具备逐句播放需要的持久文件 validator、正式音频播放 coordinator、跨句互斥状态和 media artifact 文件生命周期。
- 原有测试中有多处显式要求 `LocalListeningPreviewView` 存在；2026-05-23 UI 前置清理已迁移为禁止旧 sheet 的源码约束测试。

### 18.2 架构可行性

交互方向可行：删除 sheet、点击即播放或生成并播放，符合逐句听读的高频动作语义。

系统实现当前仍不可行：TTS 可用性状态、配置测试和本地媒体派生资产基础设施已经具备，但仍缺少真实 TTS generation service、正式音频播放服务和跨句协调器。若强行先改 UI，只能得到一个没有真实生成 / 播放行为的按钮，或者把 Provider / 播放细节塞进 SwiftUI，都会破坏当前模块边界。

推荐架构顺序：

1. 已完成：TTS Provider 配置测试和规范修订。
2. 已完成：`LocalMediaArtifactStore` / TTS audio artifact 的 metadata、文件存储、失效、清理和诊断基础设施。
3. 下一步：完成 TTS generation service、正式 audio playback service / playback coordinator contract。
4. 再实施本方案的 UI 直接播放接入；旧 sheet 删除已经作为 UI 前置清理完成，后续必须保持不回归。

### 18.3 四维切片

并发 / 性能边界：

- 必须防止重复点击同一句产生重复 TTS 请求。
- 必须保证同一时间只播放一句，且生成完成后的自动播放不能覆盖用户后来选择的另一句。
- 本地媒体派生资产命中必须避免重复网络请求；音频文件写入和解码不能阻塞主线程。
- 第一版应明确前台播放，不承诺后台播放、锁屏控制或批量生成。

异常边界：

- 必须区分未配置、未测试、配置变更需重测、网络失败、鉴权失败、非音频响应、media artifact 写入失败、解码验证失败和播放失败。
- 失败提示应在原位或轻量 toast 中呈现，不弹回旧 sheet。
- 诊断事件不得记录完整句子、请求体、响应体或 secret。

状态同步：

- 播放状态不应是每个 `SentencePairView` 独立私有状态；需要 page-level 或 service-level active sentence state。
- Entry 切换、LearningMaterial 重新生成、learning text 编辑、语言空间切换和页面销毁都要让旧状态失效。
- TTS 配置保存后如果没有重新测试，播放入口应回到 `requiresConfiguration` 或 `requiresRetest`。

数据一致性：

- TTS artifact key 必须绑定文本 hash、语言、voice / model、provider endpoint、adapter 版本和配置 fingerprint。
- 如果原 learning text 编辑导致 sentence text 变化，旧音频不得继续作为当前句音频。
- 音频文件第一阶段按本地媒体派生资产处理，默认 local only、excluded from backup、excluded by default from export；如果后续进入附件存储、同步或可恢复备份范围，必须另行定义 manifest、加密、清理、导出、删除传播和同步边界。

### 18.4 实施条件

当前不具备实施条件。进入实施前必须拿到以下可验证证据：

- 已满足：TTS 设置页能保存并测试 speech endpoint，测试结果覆盖真实音频响应。
- 已满足：`docs/spec/008-permissions-local-privacy-and-diagnostics.md` 和 `docs/spec/005-ai-provider-prompt-and-privacy.md` 已接受“设置页授权说明 + 单句显式点击播放免逐次确认”的边界。
- 已满足：`LocalMediaArtifactStore` / TTS audio artifact 已有可测试的 metadata、文件存储、失效、清理和诊断协议。
- 待满足：`LangoTraceSpeech` 或等价服务层已有可测试的生成、播放和跨句协调协议；当前只具备持久文件校验 seam，不具备正式 playback coordinator。
- UI 测试已先改为禁止旧 sheet，并覆盖直接播放状态。
- 已满足：前置 TTS 配置方案已经定义配置 fingerprint、失败分类、诊断字段和配置变更重测规则；本地媒体派生资产方案已经补齐 artifact key、持久文件 metadata、命中校验、失效和 cleanup 规则。

### 18.5 更优设计

更优设计不是在 `SentencePairView` 内新增更多 `@State`，而是新增一个可注入的句子音频 action / coordinator：

```text
SentenceAudioPlaybackActions
  state(for: SentenceAudioKey) -> SentenceAudioPresentationState
  togglePlayback(for: SentenceAudioRequest) async
  stopActivePlayback() async
```

`SentencePairView` 只负责渲染按钮状态和发送点击意图；coordinator / service 编排 TTS 可用性检查、AI Provider 生成、Data media artifact 写入、Speech 播放和非敏感诊断。这能保持 SwiftUI 视图轻量，也能自然处理跨句互斥、取消和配置失效。
