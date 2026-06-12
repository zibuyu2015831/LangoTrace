# 2026-06-11 Mac 待验证清单

状态：Open
创建日期：2026-06-11
来源：`docs/plans/active/2026-06-11-chore-code-review-and-dev-plan-series.md`（全量代码审查修复，commits `71bfc01`…`a2b1be3`）；2026-06-11 追加 `fix/ai-provider-language-support` 分支合并（multimodal TTS adapter、TTS-only probe、probe 诊断事件）相关验证项。

本次审查与修复在 Linux 环境完成，无 Swift 工具链，所有 Swift 改动仅经过静态审查（全文阅读、调用点 grep、括号配平、xcstrings JSON 校验），**未经编译与测试运行**。切换到 Mac 后按本清单逐项验证；全部通过后在本文件记录结果，并将母方案移入 `docs/plans/done/`。

## 1. 必跑命令（按顺序）

```bash
# 1. 重新生成工程（project.yml 改动：移除 AppIntents 依赖、版本号变量、删除 iOS 空 test scheme）
xcodegen generate
xcodebuild -list -project LangoTrace.xcodeproj

# 2. 各 Package 聚焦测试（每个包都有新增/更新测试）
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceSync
swift test --package-path Packages/LangoTraceUI

# 3. App 级测试（含新 AppSessionStateTests、entitlement 守护测试、临时目录 bootstrap）
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests

# 4. Lint / Format（verify.sh 已修复 --no-cache / --cache ignore）
swiftlint --no-cache
swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache ignore

# 5. 三端构建
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
```

修复后的 `scripts/verify.sh` 本身也需要完整跑通一次（验证失败传播逻辑：可临时制造一个编译错误确认脚本会以非零退出，再还原）。

## 2. 编译风险重点核对

静态修复中以下 API 用法未经本地编译核对，若编译失败优先检查：

- GRDB API：`DatabaseQueue.writeWithoutTransaction`、`Database.changesCount`、`DatabaseError.resultCode == .SQLITE_CONSTRAINT`（DATA-02/03/10）。
- `@ScaledMetric(relativeTo: .largeTitle)` 在 WelcomeView 的接入（UIV-18）。
- Speech 包 `AVAudioSession` 接入仅 `#if os(iOS)`（APP-10），macOS 测试 target 不应触碰。
- Core `SentenceAudioRequestSummary` 新增 `sentenceSource` 字段后 UI seam 的编译兼容（CORE-02）。
- `bootstrap(databaseURL:)` 新参数与 `SharedAppDatabaseFactory` internal 化（TEST-01）。
- 新增本地化键的 xcstrings 由脚本写入，Xcode 打开后可能重排键序（预期，无需处理）。

2026-06-11 合并 `fix/ai-provider-language-support` 后追加的编译/行为风险点：

- `TTSProviderAdapter` 协议新增 `decodeAudio(from:)` / `decodedAudioFormat(for:)`（带默认实现），新增 multimodal / custom adapter 与 PCM16->WAV 包装，需确认 AI 包编译与既有 adapter 测试通过。
- `TTSConfigurationProbeService` 构造参数新增 `diagnosticLogger`，所有调用点（App 装配 + 测试）已更新，注意遗漏点。
- `AIProviderConfigurationService.loadDefaultPlayableTTSConfiguration` 的 adapter 守卫由两种扩为五种（merge 时修正），与 `SentenceTTSGenerationService.adapter(for:)` 必须保持一致。
- 语言支持 validator 下限放宽为 15 可见字符 / 10 词（合并取舍：采纳分支下限、保留"不设上限"语义），相关阈值测试需通过。
- multimodal 解码路径下 `SentenceTTSGenerationResult.mimeType` 仍回落原始 `httpResponse.contentType`（可能是 `text/event-stream`），如造成回放或缓存元数据异常，需另立修复项。

## 3. 数据迁移验证

- 新增 migration `v15_reset_reading_explanation_cache_for_unix_epoch`（DATA-06）：用包含旧版数据库的模拟器升级启动，确认迁移通过、解释缓存被清空后可重新生成。
- v10 migration 删除了两条事务内 no-op `PRAGMA foreign_keys`（DATA-03）：跑既有 legacy v7/v9 迁移测试回归。
- 带 providerParameters 的既有 TTS 缓存键会一次性失效并重新生成一次音频（CORE-01 的必然代价）。
- 阅读解释 Prompt 升级 v3→v4（AI-17）：缓存键不含 promptVersion，旧缓存仍会返回 v3 时期结果（已记录在 Prompt Registry；如需强制失效另立任务）。

## 4. 真机 / 模拟器人工验证

| # | 验证项 | 来源 |
| --- | --- | --- |
| 1 | iPhone 打开静音拨片，逐句"听"应有声 | APP-10 |
| 2 | 录一段约 3 秒跟读，GRDB practice_recording 元数据 durationSeconds 非 0 且接近真实时长 | APP-01 |
| 3 | 录音 → 停止 → 回放录音 → 再播 TTS，全程音频会话正常 | APP-10/APP-01 |
| 4 | 详情页快速连点两句"听"，无叠音 | SPEECH-07 |
| 5 | 设置页连续多次点 TTS 试听，无叠音、无累积内存 | SPEECH-03/04 |
| 6 | 签名 macOS 构建执行 AI Provider 配置测试，能正常出网 | APP-03 |
| 7 | 把数据库文件设为不可读后启动，Welcome 底部出现错误面板；恢复权限后点"重试"可继续 | APP-02 |
| 8 | 详情页连续双击"生成学习材料"，第一次结果正常落地；完成后点取消不出现"已取消"假状态 | UIS-01 |
| 9 | 播放句子音频后切换语言空间，用 Memory Graph 确认旧 LearningContentStore 释放 | UIS-02 |
| 10 | 修改 AI Provider 配置 → 保存失败 → 点"测试请求"，测试的是屏幕上的草稿而非旧存档 | UIS-03 |
| 11 | 阅读页快速连续选中两个句子触发解释，第二个请求的加载指示不闪断 | UIS-04 |
| 12 | 阅读库搜索框用中文输入法连续打字，组字不被打断；停止输入后列表刷新一次 | UIV-04 |
| 13 | iPad 创建 20+ 条记录，侧栏可滚动且底部状态栏固定 | UIV-01 |
| 14 | 编辑语言空间把母语改成与目标语言相同，目标语言自动切换且无法保存同语言组合 | UIV-02 |
| 15 | 模拟仓库写失败（如只读数据库）时，新建记录浮层显示错误且草稿保留；阅读导入失败时 sheet 不关闭 | UIV-06 |
| 16 | Mac 编辑浮层输入正文后点击浮层外部不关闭；清空内容后点击外部可关闭 | UIV-30 |
| 17 | 界面语言切英文：iPad/macOS 侧栏状态图标 tooltip 与 VoiceOver 全部英文，且不出现"请求预览"承诺 | UIV-03/CORE-07 |
| 18 | 界面语言为日语/俄语时 hero 副标题语序自然 | UIV-10 |
| 19 | 系统语言设为 zh-CN（不带 script），界面回落简体中文而非英文 | CORE-23a |
| 20 | 开 AX5 大字号查看练习卡片不截断；VoiceOver 朗读完整"标题、状态、x/y 句" | UIV-14 |
| 21 | 系统开启"减弱动态效果"后，阅读选句滚动与底部面板无滑入动画 | UIV-26 |
| 22 | 未配置 TTS 时句子"听"按钮显示带感叹号图标并提示去设置 | UIV-19 |
| 23 | CRLF（Windows 来源）`.txt`/`.md` 导入后正常分段、标题列表正确渲染 | CORE-03 |
| 24 | 重新保存 AI Provider 设置后，逐句"听"仍可重新生成缓存（不再撞唯一索引） | DATA-01 |
| 25 | 点击生成后立即取消，详情页不出现新材料 | DATA-07 |
| 26 | 跑两遍 LangoTraceAppTests 后检查 `~/Library/Application Support/LangoTrace/LangoTrace.sqlite` 不再新增 "Bootstrap Practice Test" 空间 | TEST-01 |
| 27 | 配置 o-series / gpt-5 等 reasoning 模型，配置测试与真实生成行为一致 | AI-05 |
| 28 | AppIntents metadata extractor warning 是否复现（若复现且不可接受，可恢复依赖并在方案中记录） | PROJ-01 |
| 29 | 构建产物 Info.plist 版本号显示 0.1.0 | PROJ-02 |
| 30 | 深/浅色模式下阅读选中高亮与下划线颜色与品牌强调色一致 | UIV-27 |
| 31 | iOS 模拟器开启 VoiceOver，在阅读正文选中文本：VoiceOver 仍能朗读选中内容，学习面板元素可被聚焦与朗读；系统编辑菜单保持不出现 | 归档阅读缺陷方案自审核 P1-A（最终实现为 `ReadingNonMenuTextView.canPerformAction` 全量返回 false，正是当时标记可能影响 VoiceOver 的方案，回归优先级应高于普通项） |
| 32 | OpenRouter 预设新建 TTS 配置（默认 multimodal adapter + `openai/gpt-audio-mini`）：配置 probe 转 Succeeded，且记录详情逐句"听"能生成并播放（WAV 包装的 PCM16） | 分支合并：multimodal 解码 + playable 配置 adapter 集合扩展 |
| 33 | 仅启用语音合成（不启用文本生成）的 Provider 配置可发起"测试请求"，错误 API Key 时 TTS 测试显示鉴权失败而非"未启用" | 分支合并：TTS-only probe readiness + 静默 catch 修复 |
| 34 | 自定义 OpenAI 兼容预设启用 TTS 后保存，逐句"听"可生成播放 | 分支合并：customOpenAICompatibleAudioSpeech 默认 adapter |

## 5. 归档方案遗留的人工验证项

来自 `docs/archive/plans/`（2026-06-11 整体归档）：

> 注意：2026-06-11 审查波次 APP-04 已将 console 诊断恢复为 spec 008 默认关闭，`ConsoleDiagnosticLogger` 仅在 `LANGOTRACE_DIAGNOSTICS=1` 时挂载（`LangoTraceApp/AppEnvironment.swift` 的 `makeDiagnosticLogger`）。本节两项验证必须以 `LANGOTRACE_DIAGNOSTICS=1` 启动 App（必要时配合 `LANGOTRACE_LOG_LEVEL=warning`），否则 `scripts/capture-runtime-log` 采不到任何诊断事件，会被误判为修复回归。归档方案中"无需环境变量即可出现 warning 日志"的描述对当前代码已不成立。

- `2026-05-26-bug-ai-provider-language-support-diagnostics.md`：iPad 模拟器运行 AI Provider 测试，语言支持行失败时用 `scripts/capture-runtime-log --last 30m` 确认日志能区分失败阶段。期望日志行：`ai_provider_configuration.probe_partial` 或 `probe_failed` 且带 `language_support_failure_reason=<unsupported_language_code | missing_sample_json | sample_too_short | script_mismatch | natural_language_mismatch>`。
- `2026-05-26-bug-mac-ai-provider-key-retention.md`：macOS 本机验证 Keychain 静默读取（无弹窗）与诊断事件；签名约束跟踪在 `docs/architecture/notes/2026-06-05-macos-ai-provider-credential-signing-notes.md`。期望日志行：`ai_provider_settings.credential_resolve_failed failed failure_phase=credential_reveal error_category=<稳定分类>`；同一轮中确认设置页加载与显式 reveal 均无登录钥匙串弹窗。

## 6. 验证结果记录

逐项完成后在此追加：日期、命令/项目、结果、发现的问题与处置。

---

### 2026-06-12 自动化验证（第 1 节命令，部分完成）

**执行环境**：Mac Darwin 25.4.0 / arm64，由 Claude Code 执行。

#### 1-1. xcodegen generate + xcodebuild -list ✅

- `xcodegen generate` 成功生成 `LangoTrace.xcodeproj`。
- scheme 列表：`LangoTrace-iOS`、`LangoTrace-macOS`、`LangoTraceAI`、`LangoTraceCore`、`LangoTraceData`、`LangoTraceSpeech`、`LangoTraceSync`、`LangoTraceUI`（共 8 个）。
- Target：`LangoTrace-iOS`、`LangoTrace-macOS`、`LangoTraceAppTests`（无多余 iOS 空 test scheme，符合预期）。

#### 1-2. swift test — 各 Package ⚠️（部分完成，有 bug 修复）

| Package | 结果 | 备注 |
|---|---|---|
| LangoTraceCore | ✅ 151 tests 全通过 | 无问题 |
| LangoTraceData | ✅ 138 tests 全通过（修复后） | 修复 `ReadingExplanationCacheRepositoryTests.swift:25` 并发捕获错误：`var entry` 在 `databaseQueue.read` 闭包中被捕获，在闭包外提前绑定 `let entryID = entry.id` 解决 |
| LangoTraceAI | ✅ 132 tests 全通过（修复后） | 修复 `AIProviderConfigurationServiceTests.swift` 第 368、405 行两处 `TTSConfigurationProbeService` 初始化遗漏 `diagnosticLogger: DisabledDiagnosticLogger()` 参数（命中清单第 2 节预警） |
| LangoTraceSpeech | ✅ 24 tests 全通过 | 无问题 |
| LangoTraceSync | ✅ 1 test 全通过 | 无问题 |
| LangoTraceUI | ⏸ 未完成 | 首次运行发现 `PremiumUIBehaviorTests.swift:197` 引用已删除文件 `PhoneMainModels.swift`（该文件在 commit `c1b7947` 中删除，内容迁入 `PhoneMainSections.swift` / `PhoneMainSupportingViews.swift`），已更新测试；重新编译耗时过长，会话超时前未获得最终结果，待下次继续 |

**修复文件汇总（本次 bug fix）：**

- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingExplanationCacheRepositoryTests.swift`：并发捕获 var 修复。
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationServiceTests.swift`：两处 `TTSConfigurationProbeService` init 补齐 `diagnosticLogger` 参数。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`：`stageThreeUnavailablePagesKeepMigratedChromeLocalized` 测试将 `PhoneMainModels.swift` 替换为 `PhoneMainSections.swift` 和 `PhoneMainSupportingViews.swift`。

**已知 warning（非阻塞）：**

- `LangoTraceUI/Tests` 中 `LaunchRecoveryPresentationTests.swift`：`#ActorIsolatedCall` warning，因同步上下文中调用 `@MainActor` 方法，测试仍可通过，无需立即修复。
- `LangoTraceUITests/LearningContentStoreOperationOwnershipTests.swift`：`WeakMutability` warning，`weak var weakStore` 可改为 `weak let`，非阻塞。

#### 待完成（下次继续）

- [ ] `swift test --package-path Packages/LangoTraceUI`（确认修复后全通过）
- [ ] `xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests`
- [ ] `swiftlint --no-cache`
- [ ] `swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache ignore`
- [ ] 三端构建（iOS iPhone / iPad / macOS）
- [ ] 第 4 节人工验证项（需真机/模拟器手动操作）
