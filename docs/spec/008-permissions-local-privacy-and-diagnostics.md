# 008：权限、本地隐私与诊断日志规范

状态：Accepted

适用阶段：照片、相机、麦克风、Speech、OCR、TTS、AI Provider、Keychain、日志诊断和发布隐私材料。

## 1. 适用范围

本文档规定语迹在 Apple 三端上的系统权限、本地隐私、密钥、日志和诊断边界。AI Provider 请求仍以 `005-ai-provider-prompt-and-privacy.md` 为主；本文档补齐 Photos、Speech、OCR、录音、TTS、系统权限弹窗、Keychain、本地加密和诊断日志的统一执行规则。

## 2. 当前结论

LangoTrace 的信任基础是本地优先。权限和隐私说明不能只在 AI 请求前出现；从用户选择照片、录音、语音识别、OCR、TTS、导出或发送诊断开始，就必须说明数据使用范围和不会发生的副作用。

当前阶段可以保留 unavailable 或 local mock 页面，但不得把未接入权限、Keychain、网络或真实数据库的功能写成可用能力。

2026-05-26 起，练习模块的单句跟读录音已经接入真实麦克风权限和本地录音保存路径。该能力只覆盖用户显式点击后的前台录音、App 管理媒体资产目录和本地 GRDB metadata；不代表 Speech Recognition、后台录音、发音评分、录音上传、录音同步、默认导出或可恢复备份已经完成。

## 3. 强制规则

- 权限请求必须由用户动作触发，不在首次启动或页面展示时批量弹出。
- 每个权限请求前，App 自有 UI 必须用当前界面语言说明用途和数据边界。
- Photos、相机、麦克风、Speech、OCR 和文件访问不得因为用户打开页面而自动读取敏感内容。
- TTS 播放目标语言文本不需要系统权限。本地 TTS 不上传内容；外部 TTS Provider 必须遵守 `011-tts-provider-configuration-and-playback.md`：设置页完成配置、测试和披露后，用户在学习页面显式点击单句播放可以直接发送该句目标语言文本，不再逐次弹出请求预览。页面展示、滚动、保存记录、进入详情、批量预生成、照片、音频、OCR、历史记忆或多条 Entry 上下文不得复用该低摩擦边界。
- 单句跟读录音必须由用户点击开始录音或再录一次触发。进入练习页、查看句子列表、播放 TTS 示范、回放页面状态或已练过状态投影不得自动请求麦克风权限。
- 跟读录音默认只保存到 App 管理的本地媒体资产目录和 practice metadata。不得自动发送给 AI Provider，不进入默认导出包、同步目录、诊断日志或对象存储。
- iOS 和 macOS 的 `NSMicrophoneUsageDescription` 必须通过 `project.yml` 作为 XcodeGen 事实源维护；macOS App Sandbox 必须启用 audio input entitlement。purpose string 需要说明录音仅用于本地跟读练习，不自动上传或发送给 AI。
- OCR、Speech 或图片理解若调用外部 Provider，必须同时遵守 `005` 的请求预览和同意级别。
- API Key 和外部服务 token 必须存入 Keychain，默认不进入数据库、日志、导出包或同步目录。
- 诊断日志默认不得包含完整日记、完整 OCR 文本、完整音频转写、照片内容、API Key、请求头或对象存储密钥。
- 本地加密、导出加密和同步加密若尚未实现，不得在 UI 或发布材料中暗示已经启用。
- 权限被拒绝时，UI 应解释影响和恢复路径，不应把拒绝状态显示为错误或阻断无关功能。
- App Store 隐私标签、权限 purpose strings 和 App 内隐私说明必须保持一致。

## 4. 权限矩阵

| 能力 | 系统权限 | 默认数据边界 | 触发条件 | 诊断日志 |
| --- | --- | --- | --- | --- |
| 选择照片写作 | Photos 或 PhotosPicker | 用户选择的照片或受限选择结果 | 用户点选照片入口并确认 | 记录能力类型和结果，不记录图片内容 |
| 拍照记录 | Camera | 本地附件或 OCR 输入 | 用户点选相机入口 | 记录授权状态和错误码 |
| 录音 / 跟读 | Microphone | 本地音频片段和练习结果 | 用户点选录音或跟读 | 不记录音频正文或波形原始数据 |
| Speech 识别 | Speech Recognition | 本地或系统识别文本 | 用户点选听写或转写 | 不记录完整转写 |
| OCR | Vision / Photos | 本地识别文本 | 用户点选 OCR 或照片分析 | 不记录完整 OCR 文本 |
| TTS | 通常无系统权限 | 本地朗读文本 | 用户点选播放 | 外部 Provider 时记录 provider 元数据 |
| AI 生成 | 网络 / Provider 配置 | 请求预览中列明的内容 | 用户确认 AI 动作 | 不记录完整请求体 |
| 导出 | Files / Share Sheet | 用户选择的导出包 | 用户点选导出并确认 | 记录导出类型和结果 |

## 4.1 Keychain 与敏感配置边界

AI Provider API Key、外部服务 token、自定义敏感请求头、对象存储密钥和加密密钥默认属于本机安全存储数据，不进入普通数据库、日志、同步目录或导出包。

当前 AI Provider 配置保存采用以下边界：

- Keychain 使用 Generic Password item 保存真实 secret，默认 `ThisDeviceOnly`、不同步。
- SQLite / GRDB 只保存非敏感配置、credential metadata、Keychain service / account 引用、最近观测到的 secret presence、cleanup state 和 validation event 摘要。
- Keychain account 是生命周期引用，日志和 UI 不应展示完整值；如需诊断，只能展示错误分类、provider、endpoint purpose、模型名和脱敏后的状态。
- App 启动、普通设置列表刷新、非 Provider 配置页和 Provider 配置页加载阶段不得解密 API Key。Provider 配置页只能加载非敏感 profile、endpoint 和 credential metadata；已有密钥以 `已保存到本机 Keychain` placeholder 表达。用户点击 API Key 字段右侧显示 / 隐藏按钮、触发本地配置验证、文本模型合成测试或未来真实 AI 请求时，才允许由服务层读取 Keychain。上述读取不得进入数据库、日志、同步、请求预览或测试输出。
- 当前文本模型合成测试沿用同一边界：未保存 draft 的明文 API Key 只允许在 UI draft、AppEnvironment 映射和 AI package transient probe input 中短生命周期存在，不写 Keychain、SQLite、validation event 或 diagnostic attributes；已保存 profile 的测试由服务层重新解析 Keychain，不依赖 UI 回填明文。
- 数据库恢复到新设备或 Keychain item 丢失时，应进入密钥缺失状态，引导用户重新输入；不得尝试从导出包、同步目录或日志恢复密钥。
- Keychain 与 SQLite 没有共同事务。保存敏感配置时必须先写 Keychain，再提交数据库 metadata；数据库失败时必须补偿删除新建 Keychain item，清理失败只能记录非敏感错误状态。

## 5. 诊断与日志

可以记录：

- 能力类型、平台、App 版本、错误码、耗时和成功 / 失败状态。
- Provider 类型、模型名、Prompt Preset ID、请求元数据摘要。
- 权限状态枚举，例如 authorized、limited、denied、restricted。
- AI Provider 配置合成测试的 operation id、endpoint purpose、adapter kind、probe capability、probe capability status、duration、validation status 和 error category。
- Practice recording 的 operation id、platform、exercise type、permission status、duration bucket、byte size bucket、failure category 和完成状态。

默认不记录：

- 完整日记、完整照片 OCR 结果、完整音频转写、完整 AI 请求体和响应体。
- 练习录音文件内容、音频 bytes、波形、绝对文件路径、完整句子快照或 Entry 正文。
- API Key、Keychain item、请求头、cookie、对象存储密钥和同步 token。
- 用户文件原始路径中可能包含的真实姓名或敏感目录结构。

如果后续提供“发送诊断包”，必须先展示内容摘要，并允许用户取消。

当前诊断日志基础设施采用以下边界：

- Core 只定义类型安全事件名、domain、level、outcome、operation id、allowlisted attributes 和 non-throwing `DiagnosticLogging` 协议，不提供任意 key / value 日志入口。
- Data 只实现本地 `diagnostic_events` ring buffer repository 和保留策略。诊断表是本地可裁剪诊断数据源，不是同步对象、学习内容、审计账本或请求日志。
- AI Provider 配置合成测试只允许写入类型安全 diagnostic event，例如 started、succeeded、partial、failed、unsupported 和 cancelled；分能力状态只能使用 allowlisted attributes 表达，不得把请求体、响应体、Authorization header、API Key、完整 Keychain account 或 Base URL query 写入日志。
- 已保存 profile 的合成测试可另写 `synthetic_test` validation event；未保存 draft 和 cancelled 测试不得写 validation event，也不得更新 profile 最近验证摘要。
- App Shell 负责决定是否启用 console、store 或 composite logger。默认产品运行使用 disabled logger；开发期开关可通过 App 层环境变量或未来调试设置装配。
- UI、AI、Data 和 Core package 不直接读取进程环境变量，也不自行决定产品期是否开启持久诊断。
- 本地诊断写入失败必须静默降级或仅在开发期 console 记录；不得导致保存配置、验证配置、权限请求、导出、同步或 AI 请求失败。
- `diagnostic_events` 只保存非敏感枚举和值，例如 operation id、endpoint purpose、endpoint count、duration、failure phase、error category 和 diagnostics mode。不得保存用户输入内容、API Key、完整 Keychain account、请求头、请求体、响应体、照片、音频、OCR 全文或转写全文。
- Practice recording 失败诊断使用 typed event `practice_recording.failed` 和 domain `practice_recording`，仅记录 operation id、platform、failure phase 和 error category。当前允许的 failure phase 为录音停止、artifact commit 和 session reload 等链路边界；不得记录完整句子、Entry 正文、音频 bytes、波形、绝对文件路径或用户目录。
- 诊断数据默认不进入导出包、同步目录或对象存储。未来若提供诊断导出或发送，必须先显示摘要、允许取消，并在导出前执行敏感字段扫描。

## 6. 验证要求

- 权限入口手动验证：允许、拒绝、受限、再次进入设置。
- 本地 mock 验证：未接入真实权限的入口必须显示 unavailable 或 local mock，不触发系统弹窗。
- 日志扫描：测试或调试日志中不得出现 API Key、完整日记、完整 OCR 文本或完整请求体。
- 本地化验证：权限说明、隐私说明、请求预览和 unavailable 文案纳入界面语言检查。
- 发布前验证：InfoPlist purpose strings、App Store 隐私标签、隐私政策和 App 内说明一致。
- AI Provider 或权限相关任务必须扫描日志、诊断事件和测试输出，确认未出现 API Key、Bearer token、完整请求头、完整请求 / 响应体、Keychain account、照片内容、音频内容、OCR 全文、转写全文或生活记录全文。
- 练习录音任务必须额外验证：拒绝麦克风权限不会创建 ready recording；录音失败或提交失败不会留下指向不存在文件的 ready metadata；测试输出不包含音频 bytes、绝对路径、完整句子或 Entry 正文。

## 7. AI 开发提示

实现任何权限或诊断相关功能前先回答：

- 触发权限的是哪个用户动作？
- App 自有说明和系统弹窗之间是否一致？
- 数据是否只保存在本地，还是会进入外部 Provider？
- 日志、导出和同步是否会带出敏感内容？
- 权限拒绝后，哪些功能仍可用？

练习录音实现前还必须回答：

- 录音开始前如何停止或拒绝当前 TTS 示范播放？
- staging 文件、metadata reservation 和 ready 标记失败时如何补偿？
- completed practice recording 是否会被普通 cache cleanup 选中？
- 录音是否会进入导出、同步、备份或诊断；如果不会，代码和文档是否一致？

## 8. 变更记录

- 2026-05-23：修订外部 TTS Provider 请求预览边界。原因：TTS Provider 配置与测试方案要求设置页完成披露和真实 probe 后，学习页单句点击播放可直接调用已配置 TTS Provider；旧规则“外部 TTS Provider 必须进入 Provider 请求预览”过宽，会阻断逐句播放交互。影响范围：TTS 设置、逐句播放、隐私披露、诊断日志和发布隐私说明。是否需要 ADR：否，沿用 ADR-005；照片、音频、OCR、历史记忆、多条 Entry 上下文和批量预生成仍需单独授权边界。
- 2026-05-26：补充练习跟读录音权限和本地隐私边界。原因：单句练习已接入真实麦克风权限、App 管理媒体资产和 practice recording metadata，需要把显式触发、purpose string、macOS audio input entitlement、日志字段和导出 / 同步排除规则写入长期规范。影响范围：LangoTraceApp、Speech、Data、UI、Testing 和 Release。是否需要 ADR：否，沿用 ADR-005；录音同步、默认导出或可恢复备份需要独立方案。
- 2026-05-26：补充练习录音失败诊断事件边界。原因：单句练习录音完成后回放按钮不刷新需要定位 stop、artifact commit 和 session reload 的实际断点，诊断必须可用但不能泄露句子、音频或路径。影响范围：LangoTraceCore、LangoTraceApp、UI 状态和测试。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-18：创建权限、本地隐私与诊断日志规范。原因：spec 深审确认 AI 隐私规范已有，但跨 Photos、Speech、OCR、录音、TTS、Keychain、日志和系统权限弹窗缺少统一执行源。影响范围：AI、Speech、Data、UI、Testing、Release 和发布隐私材料。是否需要 ADR：否，沿用本地优先和用户自带 Provider 决策。
- 2026-05-20：补充 Keychain 与敏感配置边界。原因：AI Provider 配置存储已落地，需要把 ThisDeviceOnly、默认不同步、数据库恢复缺密钥、非敏感 validation event 和 SQLite / Keychain 非原子补偿规则沉淀为长期隐私规范。影响范围：AI Provider、Data、AI、UI、Testing 和后续导出 / 同步。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-27：收紧 Provider 配置页已保存密钥读取边界。原因：macOS 登录钥匙串在设置页加载阶段可能弹出认证，且已确认通过当前 API Key 字段的小眼睛按钮进行显式查看；配置页加载不再读取 Keychain，用户点击显示按钮、配置测试或真实请求才解析密钥。影响范围：AI Provider 设置、Keychain、UI draft、隐私验证。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-20：调整 Provider 配置页已保存密钥读取边界。原因：用户再次打开 Provider 配置页时需要查看和编辑本机保存的 API Key；允许通过服务边界读取 Keychain 并回填短生命周期 UI draft，但仍禁止进入数据库、日志、同步、请求预览或测试输出。影响范围：AI Provider 设置、Keychain、UI draft、隐私验证。是否需要 ADR：否，沿用 ADR-005；该边界已于 2026-05-27 收紧为用户显式查看后才读取。
- 2026-05-20：补充诊断日志基础设施边界。原因：本地 `diagnostic_events` ring buffer、typed diagnostic events 和 App Shell logger 装配已落地，需要明确默认关闭、非敏感 allowlist、包边界、导出 / 同步排除和失败降级规则。影响范围：Core、Data、AI、UI、App Shell、Testing 和后续诊断导出。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-21：补充 Provider 配置合成测试诊断边界。原因：文本模型测试请求已接入真实 Provider 层，需要明确 draft secret 生命周期、`synthetic_test` validation event、分能力 diagnostic attributes 和敏感字段禁入规则。影响范围：AI Provider 设置、LangoTraceAI、LangoTraceData、LangoTraceUI、诊断日志和测试验证。是否需要 ADR：否，沿用 ADR-005。
