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

## 1. 需求描述

此前 iPhone `记录详情` 页面中，逐句分析卡片右上角的听一句按钮会打开 `LocalListeningPreviewView` sheet，sheet 内重复展示目标句、播放示例、意思、听力重点、练习方式和本地隐私说明。该旧 sheet 路径已在 2026-05-23 的 UI 前置清理中删除，当前点击只在原位切换轻量播放 / 暂停反馈；真实 TTS 生成和音频播放仍等待前置服务能力。

该交互与用户点击喇叭按钮的直接意图不一致。播放按钮应承担即时播放职责，而不是打开一个阅读型 sheet。后续在 TTS Provider 能力完成后，应删除该 sheet 路径，将句子播放按钮改为：

1. 已有配音音频时，直接播放对应句子的本地音频。
2. 尚未配音时，调用已配置并已测试通过的 TTS Provider 生成该句音频，生成完成后自动播放。
3. 播放、生成、失败、未配置等状态在原句子卡片内反馈，不再弹出阻断式 sheet 或逐次确认。

## 2. 实施前提

本方案不得先于 TTS API 配置与测试功能实施。实施前必须满足以下全部条件：

1. 设置界面已经提供 TTS Provider 配置入口，至少覆盖 Provider 类型、Base URL、模型或 voice、API Key / token、安全存储和当前语言空间的目标语言上下文。
2. TTS Provider 敏感凭证已经进入 Keychain 或等价安全存储，普通 SQLite / GRDB 配置只保存非敏感字段。
3. 设置界面已经提供 TTS 配置测试能力，用户可以用低敏合成文本验证 endpoint、凭证、模型 / voice、请求路径、鉴权头、响应 Content-Type、音频字节可解码性和错误分类。
4. TTS 配置测试通过后，App 可以明确区分 `未配置`、`配置草稿未测试`、`配置已测试可用`、`上次测试失败` 和 `配置已变更需重测`。
5. TTS 配置界面已经清楚说明：用户点击句子播放时，会把该句目标语言文本发送给用户选择的 TTS Provider 生成音频；播放按钮不会在每次点击时再次弹出确认。
6. `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 当前写有“若使用外部 TTS Provider，必须进入 Provider 请求预览”。TTS 配置前置任务必须先修正或细化该规范：设置页完成配置、测试和授权说明后，用户在学习页面显式点击播放可以直接发起单句 TTS 请求，不需要逐次请求预览；页面展示、滚动、进入详情或批量预生成仍不得自动发送文本。
7. TTS 请求日志和诊断事件只能记录非敏感元数据，例如 provider id、voice id、文本长度分桶、duration、失败阶段和错误分类，不得记录完整句子文本、API Key、Authorization header、完整请求体或完整响应体。
8. 已生成音频的本地缓存、附件存储或临时文件策略已经明确，至少能避免同一句同配置下重复调用 API。
9. TTS 前置任务已经明确音频缓存 key，至少包含稳定句子来源、文本内容 hash、目标语言 code、provider profile id、endpoint id、model / voice、语速或 style 参数、adapter 版本和配置版本；文本、voice 或配置变化时不得复用旧音频。
10. TTS 前置任务已经提供跨平台播放服务边界，能在 iPhone / iPad / macOS 上完成播放、暂停、停止、切换句子时取消上一句、App 进入后台 / 页面销毁时释放播放资源。
11. `Packages/LangoTraceSpeech` 不再只有 `SpeechService` / `DisabledSpeechService` 空边界，或本任务的前置实现已经在合适模块提供等价的 TTS generation / playback service，并通过 `LangoTraceApp/AppEnvironment.swift` 注入到 UI。
12. `Packages/LangoTraceUI` 不直接依赖网络、Keychain、文件系统细节或 AVFoundation 具体实现；UI 只能调用由 App Shell 注入的 action / service 协议。

若上述任一条件未满足，本方案保持 Draft，不进入实现。

## 3. 现状描述

当前代码事实：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift` 中的 `SentencePairView` 不再持有 `isListeningPreviewPresented`，也不再通过 `.sheet` 展示听力说明。
- `SentencePairView` 当前持有临时 `@State private var isLocalPlaybackActive = false`，点击听一句只在原位切换播放 / 暂停视觉反馈；这只是避免旧 sheet 回归的 UI 前置清理，不是最终 TTS 播放状态模型。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalListeningPreviewView.swift` 已删除，`Localizable.xcstrings` 中的 `listeningPreview.*` 专用文案已清理。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentencePairActionControls.swift` 中的听一句按钮仍是 44pt 圆形图标按钮，具备直接播放动作的视觉基础，并能根据 `isListening` 切换 `speaker.wave.2` / `pause.fill` 图标。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 当前已经展示可选 `speechModel` 分组，`AIProviderDraftConfiguration` 能在启用后把 `.tts` purpose endpoint 保存到 AI Provider profile。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift` 的配置 probe 只把 `.speechSynthesis` 作为 includePlaceholders 时的占位能力；真实 probe 当前聚焦文本回复、JSON、语言支持和可选图片理解。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift` 在缺失凭证结果中将 `.speechSynthesis` 标记为 `.notEnabled`，不是可用 TTS 测试结果。
- `Packages/LangoTraceSpeech/Sources/LangoTraceSpeech/SpeechBoundary.swift` 当前只有空协议 `SpeechService` 和 `DisabledSpeechService`，没有 TTS 生成、音频播放或缓存接口。
- `LangoTraceApp/AppEnvironment.swift` 当前注入 `DisabledSpeechService()`，没有把可用 TTS service 注入 UI。
- 当前 TTS 真实配置测试、真实音频生成、真实音频播放、音频缓存、语音 Provider 验证结果持久化和真实逐句播放服务尚未完成。

当前文档事实：

- `docs/product-main-reference.md` 将“听说：生成目标语言音频，用户可以朗读、跟读、影子跟读、模仿和背诵”定义为核心学习闭环的一环。
- `docs/product-main-reference.md` 第 9.5 节建议支持全文朗读、逐句播放、单句循环、慢速播放、原速播放和跟读录音。
- `docs/technical-framework-roadmap.md` 将 `TTSProvider` 列为 Provider 抽象之一，并说明高质量拟真语音、音频文件生成和跨设备音频应通过 TTSProvider 接入外部服务。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 要求外部 TTS Provider 进入请求预览；该规则需要在 TTS 配置前置任务中按用户确认的新交互边界修正。

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
- 该决策要求前置 TTS 配置任务在设置页完成授权说明，并修正 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 中“外部 TTS Provider 必须进入请求预览”的当前规则。
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

预计删除：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalListeningPreviewView.swift`
- `Localizable.xcstrings` 中仅供 `LocalListeningPreviewView` 使用的 `listeningPreview.*` 文案。

依赖前置任务提供的代码边界：

- TTS Provider 配置状态读取接口。
- 单句 TTS 生成接口。
- 本地音频缓存查询和写入接口。
- 播放 / 暂停 / 停止音频的服务接口。
- TTS 诊断事件记录接口。
- 跨句播放协调接口：保证同一 entry 或同一页面内同时只有一个句子处于 generating / playing 主状态；新句子开始播放时必须取消或停止上一句。
- 生命周期接口：页面销毁、Entry 切换、语言空间切换、App 进入后台或音频服务失效时，UI 能收到状态回收或失败事件。

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentencePairActionControls.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalListeningPreviewView.swift`
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

前置 TTS 配置任务必须更新或确认：

- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
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

- TTS 配置与测试任务已经完成并验证通过。
- TTS 设置页已经承担播放授权说明。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 已不再要求用户每次点击单句播放都进入请求预览。
- 前置任务已经给出可调用的 TTS 配置状态、单句生成、缓存和播放接口。

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
4. 无本地音频且 TTS 配置已测试可用：取消当前其他句子的生成 / 播放任务，进入 `generating`，调用 TTS Provider 生成音频，写入本地缓存，成功后确认当前 active key 仍未变化，再播放。
5. 无本地音频且 TTS 未配置、未测试或配置已变更需重测：进入 `requiresConfiguration`，提供进入设置的轻量路径或状态说明。
6. 生成失败：进入 `failed(message)`，不记录完整句子文本到日志。
7. 用户再次点击当前播放句：暂停或恢复播放；用户点击另一句：停止当前句并切换 active key。

必须显式处理：

- 重复点击同一句导致的重复 TTS 请求。
- 生成请求完成时用户已经切换到另一句。
- Entry 被删除、LearningMaterial 重新生成、learning text 被编辑导致旧句子音频失效。
- 网络超时、Provider 返回非音频、音频文件写入失败、播放解码失败。
- App 进入后台、音频中断和路由变化。第一版如果不支持后台播放，必须在方案和 UI 状态中明确只做前台播放。

### 11.6 可访问性和反馈

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
- 是否没有把 TTS 请求状态写入 Core 模型、SQLite 持久表或同步 manifest。
- 是否没有在日志、测试输出、诊断事件中记录完整句子文本、API Key、Authorization header、请求体或响应体。
- 是否没有把 TTS 配置未完成状态伪装成可用播放能力。

文档复查重点：

- 前置 TTS 方案是否已经更新 Provider 请求预览规则。
- 本方案是否仍然只覆盖逐句直接播放，不扩展到批量生成、录音、听写或跟读评分。
- 页面清单和 UI flow 是否不再把 `听一句` sheet 当作当前交互事实。

## 13. 验证命令

前置 TTS 任务完成后，本任务实施时至少运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
swift test --package-path Packages/LangoTraceUI --filter PremiumUIBehaviorTests
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

如果涉及 TTS Provider、缓存或诊断服务，还应追加前置任务定义的 Core / Data / AI package 聚焦测试。

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

## 16. 完成标准

本任务完成时必须同时满足：

- 用户点击逐句分析中的听一句按钮不再弹出 sheet。
- 旧 `听一句` sheet UI 不再作为播放路径存在。
- 已生成音频可以直接播放。
- 未生成音频可以在 TTS 配置已测试可用时生成并自动播放。
- 未配置或配置不可用时使用原位轻量反馈，不弹阻断确认。
- 同一时间只播放一句，切换句子会停止上一句。
- TTS 请求只由用户显式点击触发。
- 测试覆盖直接播放路径、未配置路径、旧 sheet 删除和可访问性文案。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。
- 文档影响检查完成，相关事实源不再描述旧 sheet 为当前交互。

## 17. 剩余风险

- TTS Provider 配置任务若未明确定义“设置页授权说明替代逐次请求预览”的规范边界，本方案会与现有隐私规范冲突。
- 不做逐次确认会降低摩擦，但也要求设置页文案足够清楚，否则用户可能低估单句文本会发送给外部 TTS Provider。
- 外部 TTS 费用、速率限制和失败重试策略如果在前置任务中没有定义，直接播放体验可能出现不可解释的等待或失败。
- 音频缓存 key 若没有包含文本、目标语言、voice、模型、语速和 Provider 配置版本，可能播放过期或错误音频。
- 批量预生成音频不在本方案范围内；未来若加入，必须单独设计授权、费用提示、队列、失败恢复和取消机制。
- 如果只在 UI package 内实现播放状态，会违反 `docs/spec/004-swiftui-architecture.md` 中“AI、TTS、OCR、Speech、Sync 必须通过协议或服务层进入 UI”的边界。
- 当前 AI Provider 设置页已有 speech endpoint 保存 UI，但没有 TTS probe 和可用性状态；实施者可能误把“已保存 speech endpoint”当成“已测试可用 TTS”。必须以前置 TTS 测试通过状态作为播放前置，而不是只看 endpoint 是否存在。

## 18. 系统架构复审结论

状态：Needs Changes，不具备立即实施条件。

### 18.1 代码现状准确性

准确：

- 原审查时，`SentencePairView` 确实通过 `isListeningPreviewPresented` 打开 `LocalListeningPreviewView` sheet。
- 2026-05-23 UI 前置清理后，旧 sheet 路径和 `LocalListeningPreviewView.swift` 已删除；当前只剩原位轻量播放 / 暂停反馈，不接真实 TTS。
- `SentencePairActionButton` 当前有 `minWidth: 44, minHeight: 44`，可作为直接播放按钮的触控基础。
- `Localizable.xcstrings` 中原有 `listeningPreview.*` 文案已随旧 sheet 删除同步清理。

需要补强：

- AI Provider 设置页不是完全没有语音配置入口。当前已有可选 speech endpoint UI 和 `.tts` endpoint 保存路径，但只有配置保存能力，没有 TTS 配置测试、音频生成、音频解码或播放能力。
- `LangoTraceSpeech` 当前是空服务边界，`AppEnvironment` 注入的是 `DisabledSpeechService`。因此本方案不能只改 UI，必须等待 Speech / TTS 服务边界先完成。
- 原有测试中有多处显式要求 `LocalListeningPreviewView` 存在；2026-05-23 UI 前置清理已迁移为禁止旧 sheet 的源码约束测试。

### 18.2 架构可行性

交互方向可行：删除 sheet、点击即播放或生成并播放，符合逐句听读的高频动作语义。

系统实现当前不可行：缺少 TTS 可用性状态、生成服务、音频缓存、播放服务和跨句协调器。若强行先改 UI，只能得到一个没有真实行为的按钮，或者把网络 / 文件 / 播放细节塞进 SwiftUI，都会破坏当前模块边界。

推荐架构顺序：

1. 先完成 TTS Provider 配置测试和规范修订。
2. 再完成 `LangoTraceSpeech` 或等价服务层的 TTS generation / audio playback / cache contract。
3. 再实施本方案的 UI 删除 sheet 和直接播放接入。

### 18.3 四维切片

并发 / 性能边界：

- 必须防止重复点击同一句产生重复 TTS 请求。
- 必须保证同一时间只播放一句，且生成完成后的自动播放不能覆盖用户后来选择的另一句。
- 音频缓存必须避免重复网络请求；音频文件写入和解码不能阻塞主线程。
- 第一版应明确前台播放，不承诺后台播放、锁屏控制或批量生成。

异常边界：

- 必须区分未配置、未测试、配置变更需重测、网络失败、鉴权失败、非音频响应、写缓存失败和播放失败。
- 失败提示应在原位或轻量 toast 中呈现，不弹回旧 sheet。
- 诊断事件不得记录完整句子、请求体、响应体或 secret。

状态同步：

- 播放状态不应是每个 `SentencePairView` 独立私有状态；需要 page-level 或 service-level active sentence state。
- Entry 切换、LearningMaterial 重新生成、learning text 编辑、语言空间切换和页面销毁都要让旧状态失效。
- TTS 配置保存后如果没有重新测试，播放入口应回到 `requiresConfiguration` 或 `requiresRetest`。

数据一致性：

- 音频缓存 key 必须绑定文本 hash、语言、voice / model、provider endpoint 和配置版本。
- 如果原 learning text 编辑导致 sentence text 变化，旧音频不得继续作为当前句音频。
- 音频文件如果后续进入附件存储或同步范围，必须另行定义 manifest、清理、导出和同步边界；本方案只允许本地缓存或明确的非同步附件策略。

### 18.4 实施条件

当前不具备实施条件。进入实施前必须拿到以下可验证证据：

- TTS 设置页能保存并测试 speech endpoint，测试结果覆盖真实音频响应。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 和 `docs/spec/005-ai-provider-prompt-and-privacy.md` 已接受“设置页授权说明 + 单句显式点击播放免逐次确认”的边界。
- `LangoTraceSpeech` 或等价服务层已有可测试的生成、缓存和播放协议。
- UI 测试已先改为禁止旧 sheet，并覆盖直接播放状态。
- 前置 TTS 方案已经定义缓存 key、失败分类、诊断字段和配置变更失效规则。

### 18.5 更优设计

更优设计不是在 `SentencePairView` 内新增更多 `@State`，而是新增一个可注入的句子音频 action / coordinator：

```text
SentenceAudioPlaybackActions
  state(for: SentenceAudioKey) -> SentenceAudioPresentationState
  togglePlayback(for: SentenceAudioRequest) async
  stopActivePlayback() async
```

`SentencePairView` 只负责渲染按钮状态和发送点击意图；App Shell 或 Speech service 负责读取 TTS 配置、解析 Keychain、生成音频、缓存、播放和诊断。这能保持 SwiftUI 视图轻量，也能自然处理跨句互斥、取消和配置失效。
