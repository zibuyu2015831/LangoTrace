# 测试文档

本目录用于记录自动化测试策略、手动测试流程、模拟器验证、真机验证和回归检查清单。

语迹是长期付费 App，测试文档需要重点覆盖：

- 数据迁移。
- 本地存储。
- AI 请求隐私边界。
- 权限流程。
- 练习闭环。
- 同步冲突。
- StoreKit 购买和恢复购买。

## 自动化测试组织原则

可执行单元测试默认放在所属 Swift Package 的 `Tests` 目录，而不是根目录 `Tests/`。根目录 `Tests/` 作为项目级测试索引、未来跨包集成测试、UI 自动化、共享 fixtures 和测试 runbook 的入口。

当前单元测试落点：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/`：领域模型、路由、隐私状态、诊断事件、练习状态机、前台音频协调和核心枚举。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/`：SQLite / GRDB repository、migration、local state、practice session / recording metadata、media artifact cleanup 和非敏感诊断持久化。
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/`：AI Provider 配置服务、Keychain 引用、网络 probe 和错误映射。
- `Packages/LangoTraceSpeech/Tests/LangoTraceSpeechTests/`：音频格式校验、TTS preview / playback seam、系统播放前置和练习录音 service 生命周期。
- `Packages/LangoTraceSync/Tests/LangoTraceSyncTests/`：同步包边界、disabled sync service 和后续 Sync domain contract。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/`：SwiftUI 状态、presentation model、本地化 key、source-boundary、practice route seed / view model 和页面 helper。
- `Tests/Tooling/`：项目级开发脚本的 Python 单元测试；这些测试不替代 package XCTest，只覆盖宿主机诊断工具。

同一功能有多个测试文件或预计继续扩展时，应在对应 package test target 内创建功能子目录，例如 `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/`。这样既保持 SwiftPM / XcodeGen 的测试发现机制，也避免测试文件在单一目录下平铺失控。

## Fixture 与 Probe 规则

- 自动化测试依赖的长期 fixture 优先靠近对应 package test target，例如 `Packages/LangoTraceAI/Tests/LangoTraceAITests/` 或 `Packages/LangoTraceData/Tests/LangoTraceDataTests/`。
- 项目级宿主机工具 fixture 或诊断脚本测试可放在 `Tests/Tooling/`。
- 外部格式样本、参考项目研究样本或不直接参与测试发现的研究材料，可放入 `docs/reference/research/`，并在被采纳后提升到测试、spec、architecture 或任务方案。
- fixture 不得包含真实用户敏感内容、API Key、Authorization header、请求体、响应体、照片、音频或转写全文。
- 临时 probe 通过后默认删除或归档为 historical-only 过程证据；若保留为长期开发工具，必须写明运行命令、输入边界、跳过条件和失败含义。

## TDD 要求

新功能、bug 修复、架构调整和可观察行为变化默认采用测试驱动开发：

1. 先写或更新能失败的单元测试，明确当前缺口或目标行为。
2. 再实施最小生产代码变更。
3. 先运行聚焦 package 测试，例如 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`。
4. Swift 工程行为、包边界、资源、本地化或构建配置发生变化时，继续运行 `scripts/verify.sh`。

无法自动化的视觉、真机、权限弹窗或真实 Provider 账号路径，应在任务方案中写明手动验证方法、未自动化原因和剩余风险。

Python 开发脚本应优先用标准库 `unittest` 做聚焦测试，避免为了诊断工具引入额外依赖。当前可运行：

```bash
python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py
```

## 运行时日志采集

运行期问题、模拟器人工验证失败或 AI 辅助排查需要最新 App 日志时，使用宿主机脚本采集 OSLog / unified log 到项目根目录 `logs/`：

```bash
scripts/capture-runtime-log --last 30m
```

常用命令：

```bash
scripts/capture-runtime-log --last 10m
scripts/capture-runtime-log --stream
scripts/capture-runtime-log --last 30m --category ai-provider
scripts/capture-runtime-log --macos --last 15m
```

采集结果：

- 默认写入 `logs/runtime-YYYYMMDD-HHMMSS.log`。
- 默认同步更新 `logs/latest.log`。
- `logs/` 已在 `.gitignore` 中排除，不进入 Git。

架构边界：

- App 不直接写仓库 `logs/` 目录。
- App 仍通过 `OSLog` / `ConsoleDiagnosticLogger` / 非敏感诊断事件产生运行期信息。
- 采集脚本只在宿主机开发环境运行，负责把模拟器或 macOS unified log 导出到本地文件。
- 日志不得包含 API Key、Authorization header、请求体、响应体、用户正文、照片、音频或转写全文。

如果需要更细的 App 诊断事件，可在开发运行环境中启用：

```text
LANGOTRACE_DIAGNOSTICS=1
LANGOTRACE_LOG_LEVEL=debug
```

## OpenAI-compatible Provider 外部连通性诊断

当 App 内 AI Provider 测试失败，且需要判断问题来自 App 代码、API Key、Base URL、模型名还是 Provider 兼容层时，先用宿主机脚本对同一配置发送固定合成请求：

```bash
OPENAI_API_KEY='...' scripts/probe_openai_compatible_api.py \
  --base-url 'https://api.example.com' \
  --model 'model-name' \
  --mode chat
```

可选模式：

```bash
scripts/probe_openai_compatible_api.py
scripts/probe_openai_compatible_api.py --mode responses ...
scripts/probe_openai_compatible_api.py --mode embeddings ...
scripts/probe_openai_compatible_api.py --mode both ...
scripts/probe_openai_compatible_api.py --json ...
```

Embedding / 向量化 opt-in smoke 示例：

```bash
OPENAI_API_KEY='...' OPENAI_BASE_URL='https://api.openai.com/v1' OPENAI_EMBEDDING_MODEL='text-embedding-3-small' \
  scripts/probe_openai_compatible_api.py --mode embeddings --json
```

边界：

- 脚本只用于开发期宿主机诊断，不属于 App 运行链路。
- 不携带任何参数时，脚本进入交互模式，依次要求输入 Base URL、API Key 和 Model；API Key 在终端输入时可见，但脚本输出仍会脱敏。
- 文本请求内容固定为 `Reply with exactly OK.`；embedding 请求内容固定为 `LangoTrace embedding configuration test.`；两者都不发送生活记录、照片、音频、历史记忆、Prompt Preset 或用户正文。
- 输出不会打印 API Key、请求体、响应体或 embedding vector；embedding mode 只输出 vector length。
- 如果脚本返回 `authentication_failed`，应优先检查 API Key、Provider 账号权限和兼容层认证方式；如果脚本通过但 App 失败，再回到 App 日志和 Provider probe 实现排查。

## 模拟器截图验证

涉及 iPhone、iPad、macOS 页面结构、设计系统、导航和主要用户路径的改动，除自动化测试外，应保留一轮模拟器或本机截图验证记录。

Apple 三端交互、Dynamic Type、VoiceOver、键盘、指针、菜单命令和 Reduce Motion 的长期规则见 `docs/spec/010-apple-platform-interaction-and-accessibility.md`。本节只记录验证入口和清单，不重复定义平台交互规范。

最低截图覆盖：

- iPhone：welcome、onboarding、主 Tab、关键二级页。
- iPad：三栏默认状态、左栏收起、右栏收起、关键详情页。
- macOS：默认窗口、Sidebar 收起、Inspector 收起。

截图验证重点：

- 页面是否完整可操作，主行动入口是否可见。
- 文案、按钮、状态标签和面板是否溢出或互相遮挡。
- 触控目标是否过小。
- 空状态、不可用状态、请求预览和错误状态是否清楚。
- Mock、Disabled、未配置 AI Provider、同步未启用是否不会被误读成真实能力。
- 深色模式或 Reduce Motion 若被声明支持，必须有对应验证。

## MVP UI 手动验证清单

设置与练习状态闭环阶段至少覆盖：

- iPhone 设置：进入设置后，语言空间进入真实管理页，AI Provider、同步、本地数据、隐私边界和导出每一项都能进入二级说明页或对应配置页。
- iPhone 设置二级页：每页必须显示当前状态、当前边界、后续接入条件和“不会发生”的副作用说明。
- iPhone 练习：练习 Tab 中以记录卡片列表进入句子练习列表；首层不显示“从生活进入练习”标题，不混排听写 / 回译等未完成任务类型。
- iPhone 练习会话：单句页可创建或恢复 shadowing session；听示范按钮只在用户显式点击时复用逐句 TTS 播放；显式点击后请求麦克风录音，停止后写入本地 practice recording metadata；ready recording 可在单句页回放；录音成功后由最近一次 ready recording 派生“已练过”，主按钮显示 `再录一次` 并允许继续录音；文件缺失或 hash mismatch 时保留本地 recording metadata 但显示不可播放；未授权、失败或无 ready recording 时不能回放录音。
- iPhone 记录详情：逐句练习入口携带 sentence identity 和 snapshot 进入同一单句练习闭环，而不是 Entry 级隐式练习。
- 不可用状态：无 rendering 的记录应显示不可用说明，而不是空白或误导性按钮。
- 隐私表达：AI Provider 未配置、同步未启用、导出未实现时，不得出现“已连接”“已同步”“已生成真实结果”等文案。

## 外观浅色 / 深色验证清单

外观基础设施落地后，自动化测试至少覆盖：

- Core：`AppearancePreference` 的 `system / light / dark` 稳定存储值、未知值 fallback 和 `UserDefaultsAppearancePreferenceStore` 读写 / reset。
- Data：`SettingsCapability.Kind.appearance` 存在、顺序稳定、文案 key 完整，且不依赖语言空间写入。
- UI：外观详情页包含 `跟随系统 / 浅色 / 深色` 三个选项，选中态有 checkmark、accessibility value 和 selected trait，且无当前语言空间时仍可进入。
- UI 源码约束：`LangoTraceDesign` 提供 light / dark palette，页面不新增散落 `Color(red:)`。
- App：`AppearancePreference.system` 映射为 `preferredColorScheme(nil)`，浅色和深色分别映射为 `.light` 与 `.dark`。

人工验证至少覆盖：

- iPhone：设置 > 外观可进入；切换浅色、深色、跟随系统后，记录、练习、记忆、设置列表和外观详情主区域可读，触控目标不小于 44pt。
- iPad：Sidebar 设置 > 外观可进入；切换后 Sidebar、主区、学习面板和设置详情都随当前外观更新；Stage Manager 或窄窗口下选项仍可读可点。
- macOS 工作台：Settings section > Appearance 可切换，Sidebar、主区和 Inspector 不出现明显低对比或文字遮挡。
- macOS Settings scene：`Cmd+,` 打开后无当前语言空间也可进入 Appearance；切换后主窗口下一次渲染显示同一选择。
- Accessibility：外观选项不能只靠颜色表达选中状态；VoiceOver 可读出选项名称和 selected / unselected。

剩余边界：

- 当前 light / dark palette 已有对比度基准，但发布级视觉质量仍需要截图或人工验收记录。
- 该设置只代表系统浅深色外观，不代表多品牌主题、字体主题、交互样式切换或每个语言空间独立主题已经完成。

## 三端页面闭环验证清单

三端页面补全阶段完成后，除自动化测试外，需要执行一轮 iPhone、iPad 和 macOS 的页面闭环验证。

自动化最低要求：

- `swift test --package-path Packages/LangoTraceUI` 通过。
- route、filter、panel gesture 或其他可纯函数化的页面状态 helper 有单元测试覆盖。
- `scripts/verify.sh` 通过，除非当前环境缺少明确工具；跳过时必须记录原因和剩余风险。

iPhone 手动验证：

- `记录 / 练习 / 记忆` 三个 Tab 均可进入；设置通过顶部 gear 或二级 route 稳定可达，不作为底部 Tab。
- `写一句` 打开本地记录编辑 sheet，保存后进入记录详情；文本 Entry、LearningMaterial、句子分析、practice candidate 和 memory candidate 经 GRDB learning content repository 持久化，完整时间线、照片 / 音频附件、FTS、导出和同步仍未接入。
- `用照片开始` 打开照片写作本地预览，不访问 Photos、Camera、OCR、AI Provider、网络、同步服务或导出文件。
- 记录详情的 `听` 不会在页面展示、滚动或进入详情时自动触发；用户点击单句后，通过已配置且测试可用的 TTS Provider、local artifact cache、Speech playback seam 和 playback coordinator 执行逐句生成 / 播放，并应验证未配置、失败、取消和缓存命中状态。
- 记录详情和练习 Tab 可进入单句跟读录音会话；录音必须由用户显式点击触发，不得自动发送给 AI Provider。
- 语言空间设置入口已访问本地 SQLite / GRDB repository，用于新增、切换、重命名和删除语言空间。
- AI Provider 设置页可保存非敏感配置到 SQLite / GRDB、保存 API Key 到 Keychain，并通过用户主动触发的配置合成测试显示文本回复、JSON 输出、语言支持和可选内置图片理解结果；不得发送生活记录、用户照片、音频、历史记忆或 Prompt Preset 内容。
- 同步、本地数据、隐私和导入导出等未完成真实能力的设置项应显示当前边界、本地 mock 或 unavailable 状态，不能写成真实同步、导出或外部请求已经完成。
- iPhone 17 和较窄宽度下文案、按钮和状态标签不溢出。

iPad 手动验证：

- regular width 默认工作台可显示时间线、主内容和学习面板。
- 时间线和学习面板可独立收起与展开，Reduce Motion 下不依赖动效理解状态。
- 记录选择会更新主内容和学习面板。
- 新建记录打开 sheet，保存后选中新记录并进入详情。
- 筛选按钮可切换全部记录、照片写作、待练习和已入记忆；选中态有可访问状态，不只靠颜色表达。
- 练习句子列表、单句跟读录音会话、设置详情和请求预览可从当前记录或面板进入；当前记录有可练习句子时，学习面板练习入口显示可用状态而不是 mock 状态。
- Split View、Slide Over 或 Stage Manager 窄窗口下，主内容仍可读，辅助面板不把主内容挤压到不可用。

macOS 手动验证：

- 默认窗口显示 Sidebar、主工作区和 Inspector。
- Sidebar section 可切换今日、记录库、练习、词句记忆、导入导出和设置；Practice section 中有可练习句子的记录显示可用状态，而不是 mock 状态。
- 新建记录打开 mock 编辑 sheet，保存后进入对应记录详情。
- Inspector 内容随记录详情、练习、设置、导入导出或 overview 变化。
- Sidebar 和 Inspector 可独立隐藏，窗口缩放后主内容仍可操作。
- 导入导出、向量索引、同步、练习录音导出 / 同步和快捷键未实现时，页面明确显示 unavailable 或 Local Mock，不写成真实能力；练习句子列表和单句页不应出现外层工作台滚动与页面内滚动叠加。

## 练习录音验证清单

录音完成后回放按钮不刷新、录音只停留在 staging、metadata 没有 ready 或 SQLite schema 约束漂移时，先按 [练习录音回放故障排查 Runbook](practice-recording-troubleshooting.md) 分层定位。

自动化最低要求：

- Core：`PracticeSessionReducerTests` 覆盖三步状态、ready recording、完成态和失败事件；`PracticeAudioCoordinationTests` 覆盖示范播放、录音和回放互斥边界。
- Data：`AppDatabaseTests` 覆盖 practice session / recording / typed artifact migration；`GRDBPracticeRepositoryTests` 覆盖句子快照、session 恢复、ready recording、完成态引用和完成态不漂移；`MediaArtifactRepositoryTests` 覆盖 practice recording artifact lookup / cleanup exclusion。
- Speech：`PracticeRecordingServiceTests` 覆盖 start / stop、权限拒绝、文件大小或停止失败边界；测试使用 fake recorder，不依赖真实麦克风。
- UI：`PracticeRouteSeedTests` 覆盖 route seed 必须包含 sentence identity、同一篇记录内 sibling context、上一句 / 下一句 seed 生成、底部导航条中间句序 presentation 和无 context 安全退化；`PracticeSessionViewModelTests` 覆盖 create / listen demo / record / playback recording、录音播放互斥、操作区 action projection，以及重复录音后回放最近 ready recording；`ThreePlatformPresentationCopyTests` 覆盖练习句间导航和重录 key 在 `en` / `zh-Hans` 均存在；`PhoneIOSConvergenceTests` 覆盖练习 Tab 不展示未实现任务类型，并锁定 iPad / macOS 练习入口 ready 状态和 macOS 练习 route dedicated scrolling。
- App：`PracticeRecordingConfigurationTests` 覆盖 iOS / macOS purpose string 和 macOS audio input entitlement；`AppEnvironmentPracticeBootstrapTests` 覆盖 production assembly 未回退到 disabled practice seam，并暴露录音回放失败而非静默 no-op；`SentenceAudioPlaybackAssemblyTests` 覆盖示范 TTS 播放 action seam。

聚焦命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter 'SentenceAudioPlaybackCoordinatorTests|PracticeSessionReducerTests|PracticeAudioCoordinationTests'
swift test --package-path Packages/LangoTraceData --filter 'GRDBPracticeRepositoryTests|MediaArtifactPlaybackSourceResolverTests|MediaArtifactRepositoryTests'
swift test --package-path Packages/LangoTraceSpeech --filter PracticeRecordingServiceTests
swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|PracticeRouteSeedTests|ThreePlatformPresentationCopyTests|LearningContentStoreSentenceAudioCoordinatorTests|PhoneIOSConvergenceTests'
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests/PracticeRecordingConfigurationTests -only-testing:LangoTraceAppTests/AppEnvironmentPracticeBootstrapTests -only-testing:LangoTraceAppTests/SentenceAudioPlaybackAssemblyTests
```

手动验证至少覆盖：

- iOS Simulator：进入练习 Tab -> 记录卡片 -> 句子列表 -> 单句页；确认单句页没有重复 header、不可点击阶段 pill、常驻指导文案、缺少录音提示卡或底部 step card；从第一句 / 中间句 / 最后一句分别检查底部导航条左侧 `上一句`、中间 `第 n / m 句`、右侧 `下一句`，不显示 `这是第一句` / `这是最后一句`；点击上一句 / 下一句后系统返回仍回到句子列表或记录详情，不按每句逐级倒退；点击听示范不会自动开始录音；拒绝 / 允许麦克风权限；开始 / 停止录音；录音停止后 `回放录音` 可用且主按钮显示 `再录一次`；重复录音后回放最近一次录音；录音中不能切换句子；回放录音中不能切换句子；返回再进入可继续看到最近 ready recording 并允许继续重录。
- 真实 iPhone：重复 iOS Simulator 主路径，确认系统麦克风弹窗、录音文件生成、停止时长、示范播放与录音互斥、录音回放音量 / 路由和前后台切换行为；模拟器不能替代真实设备验收。
- macOS：首次录音弹出麦克风授权；拒绝后不创建 ready recording；允许后可听示范、录音、回放并继续重录单句 session；App Sandbox audio input entitlement 生效。
- 隐私扫描：日志、测试输出和诊断事件不得包含完整句子、Entry 正文、音频 bytes、波形、绝对路径、API Key 或 Provider 请求体。
- 未接线菜单、Command Palette、多窗口和快捷键不作为已完成项验收。

## 界面国际化基础验证清单

国际化基础落地阶段至少覆盖：

- Core 测试：界面语言偏好支持 `system / en / zh-Hans` 稳定存储值。
- Core 测试：跟随系统时，支持的系统语言解析为对应界面语言，不支持时回退英文。
- Core 测试：修改界面语言偏好不会改变 `LanguageSpacePreview` 的母语、目标语言或水平。
- Data 测试：设置能力列表包含“界面语言”入口，并明确它不改变用户母语、目标语言或已生成内容。
- UI 测试：新增设置能力项后，iPad 和 macOS footer 的 AI Provider、同步和设置路由仍指向正确页面；同名 enum case 必须使用显式类型避免误解析。

后续进入 String Catalog 和真实设置页时，还需要补充：

- 英文和简体中文截图，覆盖 Welcome、Onboarding、iPhone Tab、iPad workspace、macOS workspace 和 Settings。
- Dynamic Type、较窄 iPhone、iPad Split View / Stage Manager、macOS 窄窗口下的长文本检查。
- 至少一轮 RTL 或伪本地化 smoke，确认没有明显 left / right 硬编码导致布局方向错误。
- 权限 purpose strings、隐私说明、请求预览、unavailable 页面和 App Store 元数据的本地化检查。

## String Catalog 与界面语言设置验证清单

本清单用于验证 `LangoTraceUI` String Catalog、App 内界面语言设置和三端页面 chrome 本地化。实现完成后必须补齐实际截图或问题链接。

## 主流界面语言扩展验证清单

首批主流界面语言扩展覆盖 `en / zh-Hans / es / ja / fr / de / ko / ru`。该清单只验证 App 自有 SwiftUI chrome 的界面语言能力，不代表目标学习语言、TTS、OCR、Speech、AI Provider 输出、App Store 元数据或权限弹窗已经完成对应语言支持。

自动化最低要求：

- Core 测试：`InterfaceLanguagePreference` 的 `system / en / zh-Hans / es / ja / fr / de / ko / ru` 稳定存储值和 `supportedLanguageCodes` 顺序。
- Core 测试：`System` 模式对 `es-* / ja-* / fr-* / de-* / ko-* / ru-* / zh-Hans-*` 解析到对应支持语言，`zh-Hant-*` 和未支持语言回退英文。
- Core 测试：UserDefaults 可以持久化第一批显式语言偏好，未知值回到 `system`。
- UI 测试：界面语言设置列表包含 `System` 加 8 个候选界面语言，且 title key 稳定。
- String Catalog 检查：`Localizable.xcstrings` 的所有核心 chrome key 都包含 `en / zh-Hans / es / ja / fr / de / ko / ru`，`sourceLanguage` 保持 `en`。
- App target 配置检查：`project.yml` 中 iOS 和 macOS target 的 `CFBundleLocalizations` 包含同一 8 语言清单，且 `xcodegen generate` 后不会丢失。
- 完整收口：`scripts/verify.sh` 通过，除非当前环境缺少明确工具；跳过时必须记录原因和剩余风险。

手动验证分层：

- 常规回归：`en`、`zh-Hans`、`de`、`ru`，覆盖 Welcome、Onboarding、Settings 和 Interface Language detail。
- 字体和断行 smoke：`ja`、`ko`，重点检查系统字体、行高、断行、按钮和设置列表行。
- 发布前完整验证：`en / zh-Hans / es / ja / fr / de / ko / ru` 三端覆盖 Welcome、Onboarding、iPhone main tabs、iPad workspace、macOS workspace、Settings、Interface Language detail、Request Preview 和 unavailable capability page。

发布前附加门槛：

- 新增语言翻译需要人工审校或至少人工抽检核心路径。
- 权限 purpose strings、隐私说明、App Store 元数据、截图和客服材料需要分别完成本地化检查。
- 对外文案只能宣称界面语言支持，不能写成“支持西班牙语学习 / 支持日语学习”等学习能力承诺。

| 平台 | 界面语言 | 覆盖页面 | 结果 |
| --- | --- | --- | --- |
| iPhone 17 | English | Welcome + Onboarding + Settings | 通过，Onboarding 截图：`/private/tmp/langotrace-ui-review/iphone17-en.png`；Settings 路由和 Picker key 由 `LangoTraceUITests` 覆盖。 |
| iPhone 17 | 简体中文 | Welcome + Onboarding + Settings | 通过，Onboarding 截图：`/private/tmp/langotrace-ui-review/iphone17-zh-Hans.png`；Settings 路由和 Picker key 由 `LangoTraceUITests` 覆盖。 |
| iPad Pro 13-inch (M5) | English | sidebar + workspace + settings | 通过，Onboarding 截图：`/private/tmp/langotrace-ui-review/ipad-pro-13-m5-en.png`；Settings 路由和 Picker key 由 `LangoTraceUITests` 覆盖。 |
| iPad Pro 13-inch (M5) | 简体中文 | sidebar + workspace + settings | 通过，Onboarding 截图：`/private/tmp/langotrace-ui-review/ipad-pro-13-m5-zh-Hans.png`；Settings 路由和 Picker key 由 `LangoTraceUITests` 覆盖。 |
| macOS arm64 | English | sidebar + toolbar + inspector | 通过，Computer Use 读取窗口确认 Welcome / Onboarding 英文 chrome、主窗口和 Settings 可见；`screencapture` 在当前环境返回 `could not create image from display`，未生成文件截图。 |
| macOS arm64 | 简体中文 | sidebar + toolbar + inspector | 通过，Computer Use 读取窗口确认 Welcome / Onboarding 简体中文 chrome、主窗口和 Settings 可见；`screencapture` 在当前环境返回 `could not create image from display`，未生成文件截图。 |

补充记录：

- 2026-05-18 回归：用户截图发现 English 设置下 Settings detail 仍混入中文，且 iPhone 二级页标题重叠。本轮修复后，设置列表和设置详情中 `SettingsCapability` 驱动的 title / summary / detail / next requirement / no side effects chrome 均改由 UI 层 String Catalog 渲染；`SettingsCapabilityDetailView` 在 iOS 上固定 inline navigation title。`PageClosureStateTests` 已覆盖每个设置能力的 detail key 映射，`scripts/verify.sh` 通过且 SwiftLint 0 warning。
- iPhone / iPad 模拟器 tab bar 的子元素在 Computer Use accessibility tree 中没有稳定暴露，未保留 Settings 页截图；Settings 可达性通过 `PageClosureStateTests` 的 route 断言和 settings capability localization key 断言覆盖。
- 2026-05-20 语言空间数据基础设施后，iPhone 人工回归应覆盖：首次 onboarding 创建空间、终止并重启后恢复当前空间、设置 -> 语言空间新增同目标语言空间、同名提示、切换、重命名、删除非当前空间、删除当前空间 fallback、删除最后空间回到 onboarding 或无空间恢复路径。
- macOS Settings 页面复查时发现 settings row 的 accessibility label 曾暴露本地化 key；已改为使用 `Text` 组合本地化标题和状态，避免 VoiceOver 读出 catalog key。

检查标准：

- `System / English / 简体中文` 三个选项在设置详情页可见。
- 选择 English 或 简体中文后，语迹自有 SwiftUI chrome 文案刷新。
- 当前语言空间、选中记录、练习步骤和 mock 内容不被界面语言设置重写。
- 系统弹窗、StoreKit、文件选择器和第三方 UI 不作为 App 内语言设置的即时覆盖范围。
