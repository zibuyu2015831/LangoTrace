# 三端页面清单

状态：Accepted

适用阶段：SwiftUI App Shell、MVP 早期页面闭环、三端 UI 审查和后续页面新增。

本文档是语迹 LangoTrace 当前页面覆盖的长期事实源，用于避免后续开发、审查和设计迭代遗漏 iPhone、iPad 或 macOS 页面。它记录当前 App 已有页面、入口、能力状态、主要代码路径和后续审查关注点。

本文档不替代：

- `docs/spec/002-navigation-and-routing.md`：定义导航原则、路由边界和平台 IA。
- `docs/spec/003-ui-design-system.md`：定义视觉、组件、状态和可访问性原则。
- `docs/review/`：记录一次性审查轮次和当时证据。
- `docs/plans/`：记录单项任务执行过程。

后续新增、删除、合并或改名页面时，必须同步更新本文档。

## 1. 状态定义

- `Implemented`：已有可交互页面或平台承载，页面可作为当前体验的一部分使用。
- `Local Mock`：使用本地模拟数据或本地状态展示真实级页面，不触发真实外部能力。
- `Unavailable`：能力尚未接入，页面只解释当前边界、后续接入条件和不会发生的副作用。
- `Shell`：外壳或结构页面已存在，但核心业务闭环仍依赖子页面或模拟数据。
- `Planned`：当前没有真实页面或入口，只在路线中存在。本文档不应大量记录 Planned 页面，除非它会影响当前 IA。

## 2. Root 与共享启动页面

| 页面 | 平台 | 用户目的 | 入口 | 当前状态 | 主要代码路径 | 能力边界 | 审查关注点 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| App Root phase | iPhone / iPad / macOS | 根据启动状态进入 Welcome、Onboarding 或 Main | `LangoTraceRootView` 的 `phase` 和 `LaunchRoute` | Shell | `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift` | 缺少语言空间时强制回到 onboarding，不直接创建数据 | 首次启动恢复、语言空间持久化落地后必须复查 |
| Welcome | iPhone / iPad / macOS | 首次解释产品定位并进入设置流程 | App 初次启动或 `phase == .welcome` | Implemented | `WelcomeView.swift`、`WelcomeView+Layout.swift`、`WelcomeTracePreviewCarousel.swift`、`WelcomeCapsuleLabel.swift` | 使用静态示例和本地 UI，不创建语言空间 | 首屏不能营销化；三端布局不能压缩、溢出或遮挡 |
| Onboarding | iPhone / iPad / macOS | 选择母语、目标语言和水平，创建第一个语言空间 | Welcome 完成后或缺少语言空间 | Implemented | `OnboardingView.swift`、`LangoTraceRootView.swift`、`LangoTraceApp/AppEnvironment.swift` | 通过 App Shell action 调用 `LanguageSpaceRepository` 创建真实语言空间；当前默认装配 SQLite / GRDB 语言空间 repository 并支持启动恢复。compact 宽度使用底部 sticky CTA，iPad / macOS 宽屏使用内容流内 CTA 和下移的页面 stage；创建按钮按主操作宽度居中约束，不铺满宽屏 | 后续应继续检查创建失败恢复、删除最后空间回到 onboarding、动态字体和无障碍 |
| Platform Main 分发 | iPhone / iPad / macOS | 按设备进入专属主界面 | `phase == .main` 且存在语言空间 | Shell | `LangoTraceRootView.swift` | iOS 通过 `UIDevice.current.userInterfaceIdiom` 区分 iPhone / iPad；macOS 走 Mac 主界面 | 分平台 UI 不应退化为同一套放大布局 |

## 3. iPhone 页面清单

iPhone 的顶层结构是 `记录 / 练习 / 记忆` 三个 Tab，设置通过顶部 gear 和二级 route 稳定可达。当前代码事实源是 `PhoneMainView.swift`、`PhoneMainSections.swift`、`PhoneMainSupportingViews.swift`、`PhonePhotoWritingPreviewView.swift`、`LearningContentComponents.swift`、`SentencePairActionControls.swift` 和 `PhonePracticeRows.swift`。

| 页面 | 用户目的 | 入口 | 当前状态 | 主要代码路径 | 能力边界 | 审查关注点 |
| --- | --- | --- | --- | --- | --- | --- |
| iPhone Main Shell | 承载三 Tab、NavigationStack、sheet 和语言空间上下文 | Root 进入 iPhone main | Shell | `PhoneMainView.swift` | `contentStore.ensureSeeded()` 使用本地种子数据 | Tab 数量保持克制；sheet 不应抢占主流程 |
| 记录 Tab | 随手创建生活记录，查看最近记录 | 底部 `记录` Tab | Implemented | `PhoneRecordWorkspaceView` in `PhoneMainSections.swift` | 最近记录来自本地 repository / mock seed | 首屏应突出写一句和照片写作，避免说明卡堆叠 |
| 记录 Hero | 提供高频记录入口 | 记录 Tab 顶部 | Implemented | `HeroActionCard` in `PhoneMainSupportingViews.swift` | `写一句` 打开文本编辑；`用照片开始` 打开本地照片写作预览 | 不恢复旧的 `听` 首屏入口；按钮文案不能溢出 |
| 文本记录编辑 | 输入标题和正文，保存为本地记录 | `写一句`、iPad 新建、部分 Mac 复用路径 | Implemented | `EntryEditorView` in `PhoneMainSupportingViews.swift` | iOS 主路径保存到 GRDB learning content repository；保存动作不触发 AI、同步或导出 | 隐私说明保持短；iPad / Mac 创建入口仍需在后续平台接入时复查 async 保存和失败恢复 |
| 照片写作预览 | 用模拟照片展示未来照片写作体验 | 记录 Hero 的 `用照片开始` | Local Mock | `PhonePhotoWritingPreviewView.swift`、`LearningContentStore.createMockPhotoWritingEntry()` | 不打开 PhotosUI、不调用 OCR/AI、不上传照片 | 视觉应像真实流程，不显示内部接入计划 |
| 最近记录列表 | 浏览本地生活记录并进入详情 | 记录 Tab 下方列表 | Implemented | `EntryCard` in `PhoneMainSupportingViews.swift` | 展示 seed 和用户本地创建记录 | 卡片密度、目标语言内容和状态 badge 需保持清晰 |
| 空记录状态 | 没有记录时给出创建入口 | 记录 Tab 无 entries | Implemented | `EmptyEntryPanel` in `PhoneMainSupportingViews.swift` | 只引导创建，不写入数据 | 空状态不能像错误或开发提示 |
| 记录详情 | 阅读和编辑原始记录、生成学习材料、编辑 learning text、重新分析和进入练习候选 | 最近记录、保存后、照片写作创建后 | Implemented | `EntryDetailView`、`EntryDetailHeader.swift`、`SentencePairView`、`LearningMaterialGenerationActions` | iPhone / iPad / macOS 均通过共享 `EntryDetailView` 接入真实 `生成学习材料` action；无 material 时只有一个核心 AI 动作，点击后经 App Shell 发送当前文本给已配置 AI Provider 并保存 GRDB LearningMaterial；原始 Entry 正文和 learning text 均使用动态文本卡片与 sheet 编辑；原文编辑只保存本地 Entry，不自动外发，已有 material 会显示“基于旧记录”并提供显式重新生成；learning text 编辑后可 `重新分析` | 不恢复本地预览主按钮；生成动作必须披露 AI Provider 边界；iPad / macOS 仍需后续人工验收大屏布局和创建入口保存失败恢复 |
| 听一句原位反馈 | 针对单句进行本地听读入口反馈 | 记录详情每句的 `听` | Local Mock | `SentencePairView`、`SentencePairActionControls.swift` | 播放按钮只在原位切换播放 / 暂停视觉状态；不弹解释型 sheet，不接 TTS、不录音、不保存成绩 | 不得回退到 `听力播放规划中`、`待配置` 等工程文案；真实 TTS 前不得伪装成已播放真实音频 |
| 逐句练习入口 | 从单句进入完整练习会话 | 记录详情每句的 `练` | Candidate / Local Practice | `SentencePairView`、`PracticeSessionView` | 句子和 practice candidate 可来自 GRDB LearningMaterial analysis；真实听写、跟读评分和音频仍未接入 | `听` 与 `练` 的职责需清晰，避免重复入口 |
| 练习 Tab | 从生活记录继续听、读、跟读、回译 | 底部 `练习` Tab | Local Mock | `PracticeView` in `PhoneMainSections.swift`、`PhonePracticeRows.swift` | 练习任务来自本地 rendering 和 practice items | 作为 `听` 的高频承载，不应暴露 TTS 接入计划 |
| 练习会话 | 展示准备、跟读、对照、完成步骤 | 练习 Tab、记录详情 `练` | Local Mock | `PracticeSessionView`、`PracticeControlBar.swift` | step 切换为本地 UI 状态，不录音、不评分 | 后续真实语音能力接入前，需要单独权限和语音边界方案 |
| 记忆 Tab | 查看从生活记录中沉淀的短语和句子 | 底部 `记忆` Tab | Local Mock | `MemoryView` in `PhoneMainSections.swift` | iPhone 当前隐藏技术性三层记忆基础设施 | 不展示向量索引、embedding 等工程概念 |
| iPhone 设置列表 | 查看语言空间、界面语言、外观、AI、同步、本地数据、隐私、导入导出等能力边界 | 顶部 gear | Implemented | `SettingsView` in `PhoneMainSections.swift` | 设置项多数为能力边界；AI Provider 已接入本地配置保存和 Keychain；界面语言和外观可切换设备级 preference；导入导出只说明能力边界，不打开文件面板 | 设置不能成为一级 Tab；文案要面向用户而非工程排期 |
| 外观设置页 | 切换跟随系统、浅色或深色外观 | 设置列表 `外观` row | Implemented / Visual QA Pending | `SettingsCapabilityDetailView.swift`、`LangoTraceApp.swift`、`LangoTraceDesign.swift` | 偏好写入设备本地 `UserDefaults`，通过 App 层 `preferredColorScheme` 即时影响当前界面；不进入语言空间、SQLite / GRDB、Keychain、AI Provider、同步或学习数据；light / dark color token 已接入，发布级视觉仍需截图或人工验收 | 选中态不能只靠颜色表达；无当前语言空间时仍应可进入；未来多品牌主题、字体和交互样式不得直接塞入当前三选一设置 |
| AI Provider 设置页 | 配置文本模型、语音生成模型、向量模型，保存本地安全配置并执行分能力配置测试 | 设置列表 `AI Provider` row | Implemented / Configuration Synthetic Probe / TTS Probe | `AIProviderSettingsView.swift`、`AIProviderDraftConfiguration.swift`、`AIProviderSettingsModels.swift`、`AIProviderSettingsComponents.swift`、`AIProviderSettingsActions.swift`、`SettingsCapabilityDetailView.swift` | 主路径按模型用途分组；Provider 行内展示；API Key 有明确字段名和显示/隐藏按钮；文本模型必填，图片理解默认关闭；语音和向量 endpoint 可引用文本模型 API Key 或使用独立 API Key；iPad / macOS 工作台详情复用同一表单，但通过平台最大宽度保持大屏阅读栏；保存动作把非敏感配置写入 SQLite / GRDB，把 API Key 写入 Keychain；语音生成配置以“语音细节”子区显示音色、输出格式、语速和朗读风格，音色 / 格式使用带标题与说明的菜单行，语速使用统一的减 / 数值 / 加控件，“朗读风格”用于可选填写语气、节奏或朗读方式；这些字段按当前语言空间保存 language code 级 voice profile；加载已保存配置时通过服务边界解析 Keychain 并回填到短生命周期 UI draft，默认仍隐藏，同时按当前语言空间读取已保存 TTS voice profile，回填 voice、format、speed 和 instructions，避免重开设置页后被 provider 默认值覆盖；测试按钮打开分能力结果面板，当前真实请求覆盖文本回复、JSON 输出、当前语言空间上下文下的语言支持、用户显式启用图片输入后的内置图片理解 probe，以及启用且配置完整时的 OpenAI / OpenRouter TTS 固定低敏测试句 probe；TTS 结果携带 `.tts` endpoint metadata，失败不污染文本 profile 全局最近验证摘要，并在 voice profile 保留最近失败分类供可用性读取；成功结果的样例音频只通过 Speech preview store / playback seam 试听，SwiftUI 不接触 audio bytes 或文件路径；语言支持使用稳定 target language code 由 AI 层 allowlist 派生 Prompt 名称和离线校验规则，不发送目标语言正文或用户内容；iPhone / iPad / macOS 均通过共享 `SettingsCapabilityDetailView` 注入当前语言空间，不复制平台专属 AI Provider 表单；图片理解使用 App 内置白底蓝色正方形 PNG，不使用用户照片或生活记录附件；向量化仍只显示未启用、未配置或暂不支持测试；iPhone compact 使用 bottom sheet detents，iPad 常规宽度和 macOS 不强制套用移动端 detents，结果内容在大屏使用固定最大宽度避免横向拉满；测试请求不发送生活记录、用户照片、历史记忆、目标语言正文或 Prompt Preset 内容 | 真实学习材料生成已由记录详情经 `LearningMaterialGenerationActions` 接入；后续请求预览、请求日志、Prompt Preset 自定义执行和 Anthropic / Gemini 学习材料请求体仍需另开任务；Anthropic / Gemini 文本测试和图片 probe 第一阶段返回暂不支持测试，不误报为网络或 API Key 错误；真网人工复核需要可控测试 Provider / API Key；三端语言支持和 TTS 入口需持续保持共享 action seam 和同一隐私边界 |
| 同步设置页 | 预览 iCloud 推荐路径、S3 兼容对象存储高级草稿、同步范围和密钥边界 | 设置列表 `同步` row | Local Mock | `SyncSettingsView.swift`、`SyncSettingsModels.swift`、`SettingsCapabilityDetailView.swift` | 只做真实级 mock UI；iCloud 为推荐路径，S3 兼容对象存储为高级二级表单；照片和音频附件使用本地草稿 switch 开关且默认关闭；生活记录、学习材料、Prompt Preset 和 AI 生成内容作为固定纳入范围展示；向量索引本地重建；AI Key、对象存储密钥和恢复密钥不进入同步；当前不写 Keychain、不写数据库、不发 CloudKit/S3/R2/WebDAV 请求、不上传内容 | 后续真实 Sync Engine / CloudKit Adapter / S3 Adapter 接入前，必须先定义数据模型、manifest、冲突、tombstone、密钥恢复和文档审查 |
| 设置详情 | 查看单项能力的当前状态、下一步和副作用边界 | 设置列表 row | Implemented / Unavailable | `SettingsCapabilityDetailView.swift` | AI Provider 已接入本地配置保存和 Keychain；同步仍是真实级 mock 配置入口；界面语言和外观可切换设备级 preference；不保存真实导入导出配置 | 后续真实 Provider 请求、同步、导入导出接入后逐项复查 |
| 语言空间快速切换 sheet | 查看当前空间、切换 active 空间、添加学习语言，并进入完整管理页 | 顶部语言空间胶囊 | Implemented | `LanguageSpaceSwitcherSheet.swift`、`PhoneMainView.swift` | 复用 App 层语言空间 lifecycle actions；不直接持有 repository、GRDB queue 或 SQL；新增后沿用 AppSessionState 设为当前空间的语义 | 不退回只读 summary；新增流程避免未经验证的双层 modal；失败反馈受当前 action 返回值边界约束 |
| iPhone 页面 chrome | 为记录、练习、记忆、设置提供顶部语言空间和设置入口 | 三个 Tab 和设置列表内部 | Implemented | `PhonePage`、`PhoneContextHeader.swift` | 语言空间入口打开快速切换 sheet；设置入口进入设置列表 | 所有主 Tab 都应保留当前语言空间可见性，gear 不应变成底部 Tab |
| Unavailable sheet | 搜索等未接入能力的临时承载 | `PhoneSheet.unavailable` 或共享组件调用 | Unavailable | `UnavailableCapabilityView.swift`、`PhoneMainView.swift` | 只解释边界，不执行真实副作用 | 不应用于主学习高频体验；能 mock 的能力优先做真实级 local mock |

## 4. iPad 页面清单

iPad 的顶层结构是工作台：顶部工具条、左侧时间线 / 筛选、中央写作与详情主区、右侧学习面板。当前代码事实源是 `PadMainView.swift`、`PadMainSections.swift`、`PadMainModels.swift`、`PadWorkspaceBar.swift`、`PadSidebarControls.swift` 和共享详情 / 练习组件。

| 页面 | 用户目的 | 入口 | 当前状态 | 主要代码路径 | 能力边界 | 审查关注点 |
| --- | --- | --- | --- | --- | --- | --- |
| iPad Main Workspace | 承载三栏工作台和可收起面板 | Root 进入 iPad main | Shell | `PadMainView.swift` | 使用本地 seed；面板展开状态是 transient UI state | Split View、Stage Manager 和窄宽度下主内容优先 |
| 顶部工作台工具条 | 切换左右面板、搜索、新建记录 | iPad main 顶部 | Implemented / Unavailable | `PadWorkspaceBar.swift` | 搜索打开 unavailable；新建打开编辑 sheet；设置入口不在顶部重复出现 | 图标按钮需保持 44pt 触控和动态辅助标签，右侧面板切换位于顶部最右侧 |
| 左侧时间线 | 浏览记录并选择当前 entry | 左侧面板 | Implemented | `PadSidebarView`、`EntryTimelineRow` | 使用共享 learning content store；选择 entry 后主区通过共享 `EntryDetailView` 展示真实学习材料生成入口和状态 | 收起后不留空白；后续复查 iPad async 保存和平台人工验收 |
| 左侧筛选 | 按全部、照片写作、待练习、已记忆筛选 | 左侧面板 | Local Mock | `PadFilter` in `PadMainModels.swift`、`FilterPill` | 基于本地 mock 数据和 memory items 推导 | 筛选语义后续要随真实数据模型复查 |
| 左侧页面入口 | 进入记忆、导入导出、设置 | 左侧面板 | Implemented / Unavailable | `PadSidebarView`、`PadWorkspaceRoute` | 导入导出为 unavailable；设置为只读能力页 | 不把低频配置放到顶部挤压工作台 |
| iPad 语言空间底部区 | 显示当前空间、AI、同步、设置入口 | 左侧面板底部 | Implemented | `LanguageSpaceFooter.swift` | AI / Sync 为状态说明，不自动发送或同步 | 图标不能只靠颜色表达状态 |
| 工作台概览 / 写作主区 | 展示当前记录详情、学习材料生成入口、双文本卡片和句子列表 | 默认 route `.workspace` | Implemented | `PadWorkspaceContentView.workspaceOverview`、`EntryDetailView` | 默认选中记录和 route detail 共用同一详情组装，真实生成、取消、learning text 编辑和重新分析 action 均来自 `LearningContentStore` / `LearningMaterialGenerationActions`；仍不接真实 TTS / 录音 | 中央主区是视觉焦点；避免卡片套卡片；后续人工验收 iPad 常规宽度和窄宽度阅读节奏 |
| iPad 空工作台状态 | 没有选中记录时给出安静的主区占位 | 默认 route 且无 selected entry，或目标 entry 缺失 | Implemented | `EmptyWorkspacePanel` in `PadSidebarControls.swift` | 不创建记录、不生成内容 | 不能显示裸文本或错误式空状态；后续真实空数据需保留创建入口 |
| 记录详情 | 在主区完整查看单条记录 | 时间线选择或 route `.entryDetail` | Implemented | `EntryDetailView` reused in `PadWorkspaceContentView` | 与 iPhone 共享详情组件，支持动态文本卡片、原文编辑、旧记录状态展示、真实生成、取消、learning text 编辑和重新分析 | 共享组件改动需同时复查 iPhone 和 iPad；仍需平台人工验收大屏状态展示 |
| 听一句原位反馈 | 从句子列表切换单句播放入口状态 | 句子 `听` | Local Mock | `SentencePairView`、`SentencePairActionControls.swift` | 不触发真实 TTS 或录音，不打开解释型 sheet | 后续真实语音能力不能直接塞入小 sheet；必须接入 TTS 配置、测试、播放服务和跨句状态协调 |
| 练习详情 | 在主区进行步骤式练习 | 句子 `练` 或学习面板练习入口 | Local Mock | `PracticeSessionView`、`PracticeControlBar.swift` | 本地 step 状态；无真实语音服务 | 后续语音能力不能直接塞入小 sheet |
| 设置列表 | 在主区查看能力列表 | 左侧设置、底部设置 | Implemented | `PadWorkspaceContentView.settingsList` | 多数设置为只读说明，界面语言可切换 | iPad 设置应服务当前空间，不变成后台管理；顶部工具条不重复放置设置齿轮 |
| 设置详情 | 查看单项能力边界 | 设置列表 row、底部 AI / Sync | Implemented / Local Mock / Unavailable | `SettingsCapabilityDetailView.swift`、`SyncSettingsView.swift` | AI Provider 详情共享同一表单并可保存本地 Keychain 配置，配置测试会使用当前语言空间 target language code；外观和界面语言为全局设备级偏好，无语言空间时仍可展示；无真实 sync、export 写入；同步详情使用共享 Local Mock UI，iPad 常规宽度默认进入设置焦点并收起右侧学习面板，窄宽度回退单列 | 与 iPhone 设置详情共享，改动需三端复查；设置焦点是 transient UI state，不进入语言空间、数据库或同步 manifest |
| 记忆页 | 查看记忆摘要、记忆项和向量索引边界 | 左侧 `记忆` | Local Mock / Unavailable | `PadWorkspaceContentView.memoryPage`、`MemoryLayerSummaryView` | 向量索引为 unavailable；memory items 来自本地 mock | iPad 可展示较多结构，但不能压过学习主线 |
| 导入导出页 | 说明导入导出尚未接入 | 左侧 `导入导出` | Unavailable | `PadWorkspaceContentView.importExportPage`、`UnavailableCapabilityView` | 不打开文件、不读写导出包 | 后续真实文件访问需权限和存储方案 |
| 语言空间管理页 | 查看所有语言空间，新增、切换、编辑和删除空间 | 底部语言空间入口、设置列表语言空间 row | Implemented | `PadWorkspaceContentView.languageSpaceManagementPage`、`LanguageSpaceManagementView.swift`、`LanguageSpaceEditorView.swift` | 复用 App 层语言空间 lifecycle actions；不改变 Data 层同目标语言多空间策略；删除沿用 repository fallback 语义 | 管理页应保持 iPad 主区阅读宽度和触控友好操作，不应退化为 iPhone sheet 的放大版 |
| 右侧学习面板 | 随当前 route 展示上下文；记录 / 练习 route 展示当前句子、记忆提取、练习入口、空间设置、请求预览 | 右侧面板 | Local Mock | `PadMainView.learningPanel`、`PadLearningPanelView` | `RequestPreviewCard` 只出现在 entry 学习上下文；设置、记忆、导入导出和语言空间 route 显示对应低干扰上下文，不发送数据 | 右侧内容必须匹配主区 route，不能在设置页继续展示当前记录学习内容；右侧面板容器需保留外侧 gutter，内容块需保留额外 trailing inset，避免贴近屏幕边缘 |
| 右侧学习面板空状态 | 未选中记录时说明学习面板等待内容 | 右侧学习面板无 selected entry | Implemented | `PadLearningPanelView`、`LocalizedTextPanel` | 只展示说明，不触发生成或练习 | 空状态应低干扰，不能要求用户先配置工程能力 |
| 搜索 unavailable sheet | 表达搜索尚未接入 | 顶部搜索 | Unavailable | `PadSheet.unavailableSearch`、`UnavailableCapabilityView(.search)` | 不执行真实搜索或索引查询 | 后续搜索接入时需定义跨空间范围 |
| 新建记录 sheet | 创建文本记录 | 顶部新建 | Implemented / Platform Follow-up | `EntryEditorView` reused by `PadMainView` | 复用共享 store；保存后进入共享详情能力，生成学习材料 action 已接入 | 后续 iPad 可考虑平台专属编辑体验；复查创建保存状态和失败恢复 |

## 5. macOS 页面清单

macOS 的顶层结构是桌面工作台：左侧 Sidebar、中央主区、右侧 Inspector、Toolbar、菜单命令和原生 Settings scene。当前代码事实源是 `MacMainView.swift`、`MacMainModels.swift`、`MacWorkspaceContentView.swift`、`MacInspectorContent.swift`、`MacEntryEditorSheet.swift`、`LangoTraceSettingsSceneView.swift` 和 `LangoTraceApp.swift`。

| 页面 | 用户目的 | 入口 | 当前状态 | 主要代码路径 | 能力边界 | 审查关注点 |
| --- | --- | --- | --- | --- | --- | --- |
| Mac Main Workspace | 承载 Sidebar、主区、Inspector 和 toolbar | Root 进入 macOS main | Shell | `MacMainView.swift` | 使用本地 seed；Sidebar / Inspector 展开状态为 transient UI state | 最小窗口宽度、菜单命令和键盘路径需持续复查 |
| Mac Sidebar | 在 Today、Entries、Practice、Memory、Import / Export、Settings 间切换 | 左侧 Sidebar | Implemented | `MacWorkspaceSection`、`MacSidebarItem` | 只是 section selection，不创建业务数据 | 不使用移动端 Tab；hover、focus、context menu 需保留 |
| Mac Toolbar | 切换 Sidebar / Inspector、搜索、新建记录 | 窗口 toolbar | Implemented / Unavailable | `MacMainView.toolbar` | 搜索 route 为 unavailable；新建打开 overlay | 桌面命令需与菜单栏保持一致 |
| Today 主区 | 展示当前 entry 详情和搜索 / 批量导入入口 | Sidebar `Today` | Implemented / Unavailable mix | `MacWorkspaceContentView.todayContent`、`EntryDetailView` | 当前 entry 通过共享详情接入真实生成、取消、learning text 编辑和重新分析；搜索、批量导入为 unavailable | 不能像后台 dashboard，主内容应围绕当前记录；后续人工验收桌面阅读密度 |
| Entries 资料库 | 浏览所有记录并选择详情 | Sidebar `Entries` | Implemented | `MacWorkspaceContentView.entriesContent` | 使用本地 entries | 后续批量管理、排序、搜索接入后更新 |
| Entry Detail | 查看选中记录详情 | Entries row、Today 选中、保存后 | Implemented | `EntryDetailView` reused in `MacWorkspaceContentView` | 共享详情组件，支持动态文本卡片、原文编辑、旧记录状态展示、真实生成、取消、learning text 编辑和重新分析 | macOS 可能需要更桌面化详情布局，避免移动布局直接放大；后续人工验收 AI Provider 披露和右侧 Inspector 元数据 |
| New Entry Overlay | 桌面化创建记录 | Toolbar plus、菜单 New Entry | Implemented / Platform Follow-up | `MacEntryEditorOverlay`、`MacEntryEditorSheet.swift` | 复用共享 store；保存后进入共享详情能力，生成学习材料 action 已接入 | overlay 点击背景取消、键盘取消和输入体验需保持；后续复查 async 保存和失败恢复 |
| Practice section | 查看所有 entry 的练习任务 | Sidebar `Practice` | Local Mock | `MacWorkspaceContentView.practiceContent` | 有 rendering 的记录显示 mock practice items | 后续真实音频 / 录音应有桌面控制面 |
| Practice route | 执行某条记录的练习会话 | Practice item 或 entry detail | Local Mock | `PracticeSessionView` reused in `MacWorkspaceContentView.practice` | 本地 step 状态；无录音或 TTS | macOS 练习可能需要键盘快捷键和更高密度布局 |
| Memory section | 查看记忆摘要、记忆项和向量索引边界 | Sidebar `Memory` | Local Mock / Unavailable | `MacWorkspaceContentView.memoryContent`、`MemoryLayerSummaryView` | 向量索引为 unavailable | macOS 可展示更多资料库信息，但不能泄露工程术语给普通用户 |
| Import / Export section | 说明导入导出尚未接入 | Sidebar `Import / Export` 或 bulk import action | Unavailable | `MacUnavailableContent("import-export")`、`UnavailableCapabilityView` | 不打开文件、不导入、不导出 | 后续真实能力需文件访问、附件、导出格式方案 |
| Settings section | 查看能力设置列表 | Sidebar `Settings` 或 `Cmd+,` 通知后选中 settings | Implemented | `MacWorkspaceContentView.settingsContent` | 多数能力只读；界面语言和外观可切换设备级 preference | Settings section 和原生 Settings scene 的职责不能冲突 |
| Settings detail route | 查看单项能力详情 | Settings row、Sidebar footer AI / Sync | Implemented / Local Mock / Unavailable | `SettingsCapabilityDetailView.swift`、`SyncSettingsView.swift`、`MacWorkspaceContentView.swift` | AI Provider 详情共享同一表单并可保存本地 Keychain 配置，配置测试会使用当前语言空间 target language code；外观和界面语言为设备级全局偏好；无真实同步、导出配置写入；同步详情共享 Local Mock UI，并在 macOS 工作台使用 embedded presentation 避免与外层 `ScrollView` 嵌套 | 真实 Provider 请求 / Sync / StoreKit 接入时逐项复查；工作台 Settings 和原生 Settings scene 都只是设置入口，不承载学习主流程 |
| Language Space management route | 查看所有语言空间，新增、切换、编辑和删除空间 | Sidebar footer 语言空间、Settings section 语言空间 row | Implemented | `MacWorkspaceContentView.swift`、`LanguageSpaceManagementView.swift`、`LanguageSpaceEditorView.swift` | 复用 App 层语言空间 lifecycle actions；右键菜单提供编辑和删除；删除沿用 repository fallback 语义 | 多窗口 / 多语言空间设计前必须复查当前空间切换对窗口上下文的影响 |
| Search unavailable route | 表达搜索尚未接入 | Toolbar search、菜单 search | Unavailable | `MacUnavailableContent("search")`、`UnavailableCapabilityView` | 不查询 FTS、向量索引或外部服务 | 后续搜索需要 Command Palette / 全局搜索边界 |
| Missing route fallback | 当前 route 指向缺失 entry、practice 或 setting 时给出可读反馈 | 深层 route 找不到对象 | Implemented | `MacWorkspaceContentView.entryDetail`、`practice`、`settingDetail`、`LocalizedCompactPanel` | 不自动恢复、创建或删除数据 | 后续真实持久化后需要明确 missing object 恢复策略 |
| Inspector Overview | 根据当前 section 展示上下文说明 | 右侧 Inspector，route `.overview` | Implemented | `MacInspectorContent.overviewInspector` | 说明性上下文，不写入数据 | Inspector 文字不能替代主区可用性 |
| Inspector Entry | 展示 entry metadata、请求预览、记忆候选、隐私边界 | route `.entryDetail` | Local Mock | `MacInspectorContent`、`RequestPreviewCard` | Request preview 仍是本地 / 显式请求边界展示 | macOS 可承载请求预览，但必须避免暗示自动发送 |
| Inspector Practice | 展示练习状态和后续能力说明 | route `.practice` | Local Mock | `MacInspectorContent` | 不录音、不评分 | 真实练习接入后更新状态来源 |
| Inspector Settings | 展示设置说明和下一步 | route `.settings` | Implemented / Unavailable | `MacInspectorContent` | 读取 setting capability 文案 | 避免三块式工程说明过重 |
| macOS Settings scene | 系统级设置窗口，展示能力状态列表、语言空间管理和能力详情 | App Settings / `Cmd+,` | Implemented / Local Mock | `LangoTraceApp.swift` Settings scene、`LangoTraceSettingsSceneView.swift` | 读取当前环境的 settings capabilities；语言空间 row 进入完整管理页并复用 App 层 lifecycle actions；外观和界面语言无当前语言空间时仍可进入；有当前语言空间时可选择同步等能力并展示共享 `SettingsCapabilityDetailView`；无语言空间时仍可从语言空间管理页新增空间，不创建默认空间、不保存真实空间配置 | 原生 Settings 和工作台 Settings section 需要保持语义一致；无语言空间状态不能使用 `bootstrap` 能力冒充当前空间配置；外观偏好只写设备级 `UserDefaults`，后续真实同步或多主题写入要单独设计 |
| macOS Commands | 菜单触发 New Entry、Search、Toggle Sidebar、Toggle Inspector、Settings | 菜单栏 / 快捷键 | Implemented / Unavailable | `LangoTraceApp.swift`、`LangoTraceAppCommand.swift` | Search 打开 unavailable，不执行真实搜索 | 菜单项必须有可见结果，不能空 action |

## 6. 共享页面与组件清单

这些组件不是独立平台入口，但它们承载多个页面的核心体验。修改时必须按影响平台复查。

| 组件 / 页面 | 使用平台 | 当前状态 | 主要代码路径 | 影响范围 |
| --- | --- | --- | --- | --- |
| `EntryDetailView` | iPhone / iPad / macOS | Implemented | `PhoneMainSupportingViews.swift` | 三端记录详情、真实学习材料生成入口、生成中取消、learning text 编辑、重新分析、逐句练习、未 rendering 状态 |
| `SentencePairView` | iPhone / iPad / macOS | Local Mock | `LearningContentComponents.swift`、`SentencePairActionControls.swift` | 单句听读原位反馈和练习入口；当前不接真实 TTS、不打开听力解释 sheet |
| `PracticeSessionView` | iPhone / iPad / macOS | Local Mock | `PhoneMainSupportingViews.swift`、`PracticeControlBar.swift` | 准备、跟读、对照、完成步骤 |
| `SettingsCapabilityDetailView` | iPhone / iPad / macOS | Implemented / Local Mock / Unavailable | `SettingsCapabilityDetailView.swift` | AI、同步、隐私、导入导出、本地数据、语言空间、界面语言、外观；外观和界面语言支持无语言空间的 global detail，其他空间相关能力保持 no-space boundary；支持 standalone scroll 和 embedded presentation，供 macOS 工作台避免嵌套滚动 |
| `AIProviderSettingsView` | iPhone / iPad / macOS | Implemented / Configuration Synthetic Probe / TTS Probe | `AIProviderSettingsView.swift`、`AIProviderDraftConfiguration.swift`、`AIProviderSettingsActions.swift`、`AIProviderSettingsModels.swift`、`AIProviderSettingsComponents.swift` | 文本模型、语音生成模型、向量模型 endpoint；语音和向量可共享文本模型 API Key 或使用独立 API Key；语音生成模型通过“语音细节”子区显示 voice、format、speed、speaking style，并保存当前语言空间 voice profile；保存配置写 SQLite / GRDB metadata 与 Keychain secret；加载已保存配置时回填 Keychain secret 到短生命周期 UI draft，默认隐藏，并按当前 language code 读取 TTS voice profile 回填语音字段；测试按钮走共享 action seam，打开共享分能力结果内容；文本测试 readiness 与保存 readiness 分离；未保存 draft 测当前屏幕配置，已保存且无修改时由服务层重新解析 Keychain；有当前语言空间时三端都会传入 target language code 并请求 `语言支持`，启用且配置完整时也会请求固定低敏 TTS 测试；成功 TTS 结果可经 Speech preview playback seam 试听短生命周期样例音频；iPhone compact 使用 bottom sheet detents，iPad 常规宽度和 macOS 不强制套用移动端 detents；结果面板内容在大屏使用固定最大宽度；iPad / macOS 由 `SettingsCapabilityDetailView` 负责表单最大内容宽度，不分叉表单组件 |
| `SyncSettingsView` | iPhone / iPad / macOS | Local Mock | `SyncSettingsView.swift`、`SyncSettingsModels.swift`、`SyncS3DraftView.swift` | iCloud 推荐、S3-compatible 高级草稿、同步范围和密钥边界；照片和音频附件是唯一可切换草稿项并显式使用 switch；iPad / macOS 常规宽度使用自适应多栏，compact / 窄宽度回退单列；当前不连接 CloudKit、S3、R2、WebDAV、数据库或 Keychain |
| `LanguageSpaceSwitcherSheet` | iPhone | Implemented | `LanguageSpaceSwitcherSheet.swift` | iPhone 顶部语言空间快速切换、添加学习语言和完整管理入口 |
| `LanguageSpaceManagementView` / `LanguageSpaceEditorView` | iPhone / iPad / macOS | Implemented | `LanguageSpaceManagementView.swift`、`LanguageSpaceEditorView.swift` | 语言空间列表、当前态、新增、切换、编辑和删除确认；三端共享管理语义，平台外壳负责入口和承载 |
| `UnavailableCapabilityView` | iPhone / iPad / macOS | Unavailable | `UnavailableCapabilityView.swift` | 搜索、导入导出、向量索引和通用未接入能力 |
| `RequestPreviewCard` | iPad / macOS | Local Mock / Explicit request boundary | `LearningContentComponents.swift`、`PremiumUILayoutRules.swift` | iPad 学习面板、macOS Inspector |
| `MemoryLayerSummaryView` | iPad / macOS | Local Mock / Unavailable mix | `LearningContentComponents.swift` | 记忆摘要和向量索引边界 |
| `LanguageSpaceFooter` | iPad / macOS | Implemented | `LanguageSpaceFooter.swift` | Sidebar 底部空间、AI、同步、设置入口 |
| `CapabilityStatusRow` | iPhone / iPad / macOS | Implemented | `LearningContentComponents.swift` | 能力状态、设置列表、unavailable / local mock 入口 |
| `PhonePage` / `PhoneContextHeader` | iPhone | Implemented | `PhoneMainSections.swift`、`PhoneContextHeader.swift` | iPhone 主 Tab 的页面外壳、语言空间入口和设置入口 |
| `EntryTimelineRow` | iPad / macOS | Implemented | `LearningContentComponents.swift` | iPad 时间线、macOS entries library 的记录选择行 |
| `AudioPanel` | iPad | Local Mock | `ContentUtilityComponents.swift` | iPad 工作台概览中的本地音频视觉占位，不播放真实音频 |
| `EmptyWorkspacePanel` / `LocalizedCompactPanel` / `LocalizedTextPanel` | iPad / macOS | Implemented | `PadSidebarControls.swift`、`ContentUtilityComponents.swift`、`LocalizedTextPanel.swift` | 空状态、缺失对象状态和说明型面板 |
| `LangoTraceSettingsSceneView` | macOS | Implemented | `LangoTraceSettingsSceneView.swift` | 原生 Settings scene 的能力列表、语言空间管理和共享能力详情；外观与界面语言无当前语言空间时仍可进入 |

## 7. 页面覆盖自检

截至 2026-05-23，本文档已按以下代码事实逐项覆盖：

- Root phase：`LangoTraceAppPhase.welcome`、`onboarding`、`main`。
- iPhone route：`PhoneRoute.entryDetail`、`practice`、`settings`、`settingsList`。
- iPhone sheet：`PhoneSheet.entryEditor`、`photoWritingPreview`、`unavailable`、`languageSpaceSwitcher`。
- iPad route：`PadWorkspaceRoute.workspace`、`entryDetail`、`practice`、`settingsList`、`settings`、`memory`、`importExport`、`languageSpaceManagement`。
- iPad sheet：`PadSheet.entryEditor`、`unavailableSearch`。
- macOS section：`MacWorkspaceSection.today`、`entries`、`practice`、`memory`、`importExport`、`settings`。
- macOS route：`MacWorkspaceRoute.overview`、`entryDetail`、`practice`、`settings`、`languageSpaceManagement`、`unavailable`。
- macOS command：`newEntry`、`search`、`toggleSidebar`、`toggleInspector`、`showSettings`。
- macOS scene：main `WindowGroup` 和原生 `Settings` scene。
- 外观偏好：`AppearancePreference`、`SettingsCapability.Kind.appearance`、三端共享 `SettingsCapabilityDetailView` 和 App 层 `preferredColorScheme`。

## 8. 当前不应出现的页面表现

以下表现如果重新出现，应视为 UI 质量或文档一致性问题：

- iPhone 顶层恢复五 Tab 或把设置作为底部 Tab。
- iPhone 记录 Hero 恢复 `听` 作为首屏高频入口。
- iPhone 记录详情默认显示持久 `RequestPreviewCard`。
- 逐句 `听` 按钮重新打开解释型 sheet 或 `LocalListeningPreviewView`。
- iPhone 记忆页展示向量索引、embedding 或三层技术基础设施。
- 任何用户主流程显示 `规划中`、`待配置`、`当前页面只展示入口边界`、`不播放真实 TTS` 这类开发排期文案。
- 能使用本地模拟做真实级展示的能力，退回到大段 unavailable 说明。
- iPad 或 macOS 主工作区退化成放大的 iPhone Tab。
- macOS 菜单命令或 toolbar 按钮出现空 action。
- 设置页把真实密钥、同步、导出或外部请求能力伪装成已接入。

## 9. 维护规则

新增或修改页面时，开发计划必须回答：

1. 这个页面属于 iPhone、iPad、macOS 还是共享组件？
2. 它是 Root、主流程、设置流程、临时任务、Inspector、Sheet、Unavailable 还是 Local Mock？
3. 它的入口在哪里？是否有返回路径或关闭路径？
4. 它是否创建、修改、导入、导出、发送、录音、读取照片或访问文件？
5. 它的当前状态应该是 `Implemented`、`Local Mock`、`Unavailable`、`Shell` 还是 `Planned`？
6. 对应 SwiftUI 文件和测试文件是什么？
7. 是否需要同步更新 `docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md` 或 `docs/review/INDEX.md`？

完成页面相关任务前，至少检查：

```bash
rg "struct .*View|enum .*Route|enum .*Sheet|NavigationStack|TabView|sheet\\(|navigationDestination|Settings" Packages/LangoTraceUI/Sources/LangoTraceUI LangoTraceApp -n
rg "规划中|待配置|当前页面只展示入口边界|不播放真实 TTS|LocalListeningPreviewView|isListeningPreviewPresented|UnavailableCapabilityView\\(content: \\.listenOne\\)" Packages/LangoTraceUI/Sources Packages/LangoTraceUI/Tests
```

如果页面清单和代码不一致，以代码为当前事实，并在同一任务中修正文档或明确记录偏差。

## 10. 变更记录

- 2026-05-19：创建第一版三端页面清单。依据当前 SwiftUI 代码记录 Root、iPhone、iPad、macOS、共享组件、unavailable / local mock 页面和维护规则。
- 2026-05-19：补充页面覆盖自检、iPhone 页面 chrome、iPad 空状态、macOS missing route fallback、macOS Settings scene 只读边界和共享承载组件。原因：复查 SwiftUI `View` / `Route` / `Sheet` / `Settings` 后，需要把非主 route 但会影响页面完整性的承载层写清楚。
- 2026-05-19：补充 iPad / macOS AI Provider 设置页一致性记录。原因：工作台内 AI Provider 详情页三端共享同一表单，iPad / macOS 只通过平台最大宽度控制大屏阅读栏，原生 macOS Settings scene 仍保持只读能力列表。
- 2026-05-19：补充 iPad 右侧学习面板 route-aware 边界。原因：设置、记忆、导入导出和语言空间 route 不应继续展示 entry 学习内容或请求预览。
- 2026-05-19：补充 iPad 顶部工具栏去重和右侧学习面板留白边界。原因：设置入口已由左侧和底部区域稳定承载，右侧面板容器和内容块都需要避免贴近设备边缘。
- 2026-05-20：补充 iPad / macOS 同步设置 UI 适配事实。原因：同步设置从 iPhone 单列 Local Mock 扩展为三端共享内容、iPad 设置焦点、macOS 工作台 embedded presentation 和原生 Settings scene 可进入详情；无语言空间时 Settings scene 只展示全局边界。
- 2026-05-20：补充宽屏 Onboarding 和 Mac 同步范围细节修正事实。原因：Onboarding 创建按钮在 iPad / Mac 宽屏下需要受主操作宽度约束，并在宽屏使用内容流内 CTA 避免顶部贴边和按钮贴底；同步范围附件项在 macOS 上需要显式 switch 表达，而不是默认 checkbox。
- 2026-05-20：统一三端设置能力项的导入导出命名。原因：iPad / macOS 已有导入导出工作台入口，但共享设置能力仍显示为“导出”，导致 iPhone 设置页语义缺项。影响范围：SettingsCapability、三端设置列表、设置详情本地化和页面清单。是否需要 ADR：否，未改变真实导入导出能力或核心数据策略。
- 2026-05-20：补充 iPad / macOS 语言空间管理入口事实。原因：iPhone 已落地的语言空间管理能力扩展到 iPad 工作台主区、macOS 工作台 Settings route 和原生 Settings scene，原 iPad / macOS summary-only 页面事实已过期。影响范围：iPad / macOS route、Settings scene、共享语言空间管理组件和 App Shell action 注入。是否需要 ADR：否，未改变语言空间核心模型或数据策略。
- 2026-05-22：修正 Onboarding 语言空间创建事实。原因：语言空间基础设施已通过 App Shell action、`LanguageSpaceRepository` 和 SQLite / GRDB 持久化落地，页面清单不应继续写成内存预览。影响范围：Root、Onboarding、启动恢复、语言空间管理和测试清单。是否需要 ADR：否，延续语言空间核心模型和 SQLite / GRDB 主存储路线。
- 2026-05-20：更新 AI Provider 设置页实现事实。原因：Provider 设置页已从 Local Mock 推进到 SQLite / GRDB metadata、Keychain secret 保存和本地 credential validation；真实外部 Provider 合成探测仍未接入。影响范围：iPhone / iPad / macOS 设置详情、AIProviderSettingsView、AppEnvironment、Data / AI package。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-20：更新 AI Provider 已保存密钥回显事实。原因：用户再次打开配置页时需要看到并编辑已保存的本机 API Key；实现通过服务边界解析 Keychain，仅回填到短生命周期 UI draft，默认隐藏，不改变数据库、同步或真实 Provider 请求边界。影响范围：AIProviderSettingsView、AIProviderDraftConfiguration、AIProviderSettingsActions、AppEnvironment。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-21：更新 AI Provider 文本模型合成测试事实。原因：测试请求已从本地 credential validation 推进到 Provider 层固定合成文本探测，结果面板分项展示文本回复、JSON 输出、图片理解、语音生成和向量化；第一阶段只真实请求文本 endpoint，后三项只显示占位状态。影响范围：AIProviderSettingsView、AIProviderDraftConfiguration、AIProviderSettingsComponents、AIProviderSettingsActions、AppEnvironment、LangoTraceAI、LangoTraceData。是否需要 ADR：否，沿用 ADR-005；真网人工复核仍依赖可控测试 Provider / API Key。
- 2026-05-21：补充 iPad / macOS AI Provider 测试结果面板收口事实。原因：Provider 请求测试通过共享 `AIProviderSettingsView` 和 `AIProviderSettingsActions` 自然覆盖三端，但大屏结果内容需要明确最大宽度和测试锁定，避免把 iPhone compact detents 当成唯一 presentation。影响范围：AIProviderSettingsView、AIProviderSettingsProbeTests、iPad / macOS 设置详情。是否需要 ADR：否，未改变 Provider 请求、隐私或诊断边界。
- 2026-05-21：更新 AI Provider 图片理解合成测试事实。原因：图片理解不再只是占位；OpenAI Responses / OpenAI-compatible Chat 在用户显式启用图片输入时会发送内置白底蓝色正方形 PNG data URL，并严格校验 `blue square`。影响范围：AIProviderConfigurationProbeService、AIProviderProbeImageFixture、AIProviderSettingsView、Prompt Registry 和 AI Provider 隐私规范。是否需要 ADR：否，沿用 ADR-005；真实用户照片请求仍需另开方案。
- 2026-05-21：更新 AI Provider 图片理解能力边界事实。原因：OpenRouter / Custom OpenAI-compatible 的图片输入能力由具体模型决定，设置页不再用 Provider preset 静态布尔值禁用图片理解；UI 通过 Provider、adapter、endpoint purpose、模型策略和用户启用状态解析能力，`supportsImageInput` 只作为 endpoint 运行期防线和保存快照。影响范围：AIProviderSettingsModels、AIProviderDraftConfiguration、AIProviderSettingsView、AIProviderSettingsComponents、Core endpoint normalization 和 AI Provider 隐私规范。是否需要 ADR：否，沿用 ADR-005；动态模型列表和真实用户照片请求仍需另开方案。
- 2026-05-22：更新 AI Provider 语言支持合成测试首轮事实。原因：iOS Provider 设置页先新增当前语言空间上下文下的 `语言支持` probe，AI 层会让模型生成目标语言较长样例并用本机 JSON、长度、NaturalLanguage 和脚本规则校验；iPad / macOS 设置入口在后续人工审核节点后接入。影响范围：LanguageSpacePreview、AIProviderSettingsView、AIProviderDraftConfiguration、AIProviderSettingsActions、AppEnvironment、LangoTraceAI、Prompt Registry 和 AI Provider 隐私规范。是否需要 ADR：否，沿用 ADR-005；真实学习内容请求仍需单独请求预览方案。
- 2026-05-22：补充 iPad / macOS 语言支持入口事实。原因：iOS 人工审核后，iPad / macOS 工作台设置详情和 macOS 原生 Settings scene 通过共享 `SettingsCapabilityDetailView` 注入同一 target language code，不新增平台专属 AI Provider 表单。影响范围：SettingsCapabilityDetailView、AIProviderSettingsView、页面清单和 AI Provider 隐私规范。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-23：更新一键学习材料生成的 iOS 优先落地状态。原因：iPhone 记录详情已从本地预览推进到真实 AI Provider 请求、GRDB LearningMaterial 保存、learning text 编辑和重新分析；iPad / macOS UI 接入按用户确认延后到 iOS 人工测试通过后。影响范围：EntryDetailView、LearningContentStore、LearningMaterialGenerationActions、AppEnvironment、LangoTraceData、LangoTraceAI 和页面清单。是否需要 ADR：否，沿用本地优先与三端共享业务逻辑决策。
- 2026-05-23：更新记录详情双文本卡片和原文编辑状态。原因：`EntryDetailView` 已改为母语原文 / 目标语言学习文本共享动态文本卡片，原文支持 sheet 编辑并通过 `source_entry_body_hash` 推导“基于旧记录”；三端通过共享详情组件提供显式重新生成。影响范围：iPhone 记录详情、iPad route detail、macOS Entry Detail、Data learning content schema 和 Store presentation state。是否需要 ADR：否，属于本地记录闭环和派生材料状态实现细化。
- 2026-05-23：补充外观设置与浅色 / 深色基础设施事实。原因：三端设置列表新增外观能力，App 层通过设备级 `AppearancePreference` 和 `preferredColorScheme` 即时切换浅色 / 深色，`LangoTraceDesign` 已接入 light / dark token；发布级视觉仍需截图或人工验收。影响范围：iPhone / iPad / macOS 设置入口、macOS Settings scene、共享设置详情和设计 token。是否需要 ADR：否，当前只实现系统外观偏好。
- 2026-05-23：更新逐句听读入口事实。原因：`LocalListeningPreviewView` 已删除，逐句 `听` 按钮不再打开解释型 sheet，只在 `SentencePairView` 内原位切换播放 / 暂停视觉状态；真实 TTS 生成、播放和跨句协调仍等待后续 TTS Provider 配置测试与 Speech 服务边界。影响范围：iPhone / iPad / macOS 共享 `SentencePairView`、页面清单和 UI 交互规范。是否需要 ADR：否，属于当前页面事实与组件交互约束更新。
- 2026-05-23：同步 AI Provider 设置页 TTS 配置测试实施事实。原因：语音生成分组已从占位推进到 voice / format / speed / instructions 配置、language code 级 voice profile、OpenAI / OpenRouter 固定低敏 TTS probe、endpoint metadata 结果和 Speech preview playback seam。影响范围：AIProviderSettingsView、AIProviderDraftConfiguration、AIProviderSettingsComponents、AIProviderSettingsActions、AppEnvironment、LangoTraceAI / Data / Speech 和页面清单。是否需要 ADR：否，沿用 ADR-005 和 TTS 规范 011。
- 2026-05-23：补充已保存 TTS voice profile 回填事实。原因：严格代码检查发现设置页重开时若只加载 endpoint 与 Keychain secret，voice、format、speed、instructions 会回到 provider 默认值并可能在下一次保存时覆盖用户配置；当前实现已通过 `AIProviderSettingsActions.loadTTSVoiceProfile` 按当前 language code 回填。影响范围：AIProviderSettingsView、AIProviderDraftConfiguration、AIProviderSettingsActions、AppEnvironment 和 UI 回归测试。是否需要 ADR：否，属于 011 规范下的状态同步修复。
- 2026-05-23：优化 AI Provider 设置页 TTS 参数区样式事实。原因：iPhone 截图暴露音色和格式标题弱、语速 stepper 与设置页视觉不一致、“朗读指令”含义不清；当前实现改为“语音细节”子区、带说明的菜单行、统一语速控制和“朗读风格”文案。影响范围：AIProviderSettingsComponents、Localizable.xcstrings、TTSProviderSettingsTests 和页面清单。是否需要 ADR：否，属于 UI 表达修复。
- 2026-05-23：补充 iPad / macOS 一键学习材料生成接入事实。原因：iOS 人工测试通过后，iPad `workspaceOverview` / route detail 和 macOS Today / Entries detail 已复用共享 helper 注入 `LearningContentStore.generateLearningMaterial`、`cancelLearningMaterialGeneration`、`updateLearningText` 和 `analyzeCurrentLearningText`，三端记录详情均走同一真实生成 action seam。影响范围：PadMainSections、MacWorkspaceContentView、EntryDetailView、LearningContentStore、页面清单。是否需要 ADR：否，沿用三端共享业务逻辑与平台分别设计决策。
