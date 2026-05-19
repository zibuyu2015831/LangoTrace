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
| Onboarding | iPhone / iPad / macOS | 选择母语、目标语言和水平，创建第一个语言空间 | Welcome 完成后或缺少语言空间 | Implemented | `OnboardingView.swift`、`LangoTraceRootView.swift` | 当前创建内存语言空间预览，未持久化 | 后续真实持久化后检查启动恢复、错误状态和无障碍 |
| Platform Main 分发 | iPhone / iPad / macOS | 按设备进入专属主界面 | `phase == .main` 且存在语言空间 | Shell | `LangoTraceRootView.swift` | iOS 通过 `UIDevice.current.userInterfaceIdiom` 区分 iPhone / iPad；macOS 走 Mac 主界面 | 分平台 UI 不应退化为同一套放大布局 |

## 3. iPhone 页面清单

iPhone 的顶层结构是 `记录 / 练习 / 记忆` 三个 Tab，设置通过顶部 gear 和二级 route 稳定可达。当前代码事实源是 `PhoneMainView.swift`、`PhoneMainSections.swift`、`PhoneMainSupportingViews.swift`、`PhonePhotoWritingPreviewView.swift`、`LocalListeningPreviewView.swift` 和 `PhonePracticeRows.swift`。

| 页面 | 用户目的 | 入口 | 当前状态 | 主要代码路径 | 能力边界 | 审查关注点 |
| --- | --- | --- | --- | --- | --- | --- |
| iPhone Main Shell | 承载三 Tab、NavigationStack、sheet 和语言空间上下文 | Root 进入 iPhone main | Shell | `PhoneMainView.swift` | `contentStore.ensureSeeded()` 使用本地种子数据 | Tab 数量保持克制；sheet 不应抢占主流程 |
| 记录 Tab | 随手创建生活记录，查看最近记录 | 底部 `记录` Tab | Implemented | `PhoneRecordWorkspaceView` in `PhoneMainSections.swift` | 最近记录来自本地 repository / mock seed | 首屏应突出写一句和照片写作，避免说明卡堆叠 |
| 记录 Hero | 提供高频记录入口 | 记录 Tab 顶部 | Implemented | `HeroActionCard` in `PhoneMainSupportingViews.swift` | `写一句` 打开文本编辑；`用照片开始` 打开本地照片写作预览 | 不恢复旧的 `听` 首屏入口；按钮文案不能溢出 |
| 文本记录编辑 | 输入标题和正文，保存为本地记录 | `写一句`、iPad 新建、部分 Mac 复用路径 | Implemented | `EntryEditorView` in `PhoneMainSupportingViews.swift` | 保存到内存 repository；不触发 AI、同步或导出 | 隐私说明保持短；后续真实存储后检查失败恢复 |
| 照片写作预览 | 用模拟照片展示未来照片写作体验 | 记录 Hero 的 `用照片开始` | Local Mock | `PhonePhotoWritingPreviewView.swift`、`LearningContentStore.createMockPhotoWritingEntry()` | 不打开 PhotosUI、不调用 OCR/AI、不上传照片 | 视觉应像真实流程，不显示内部接入计划 |
| 最近记录列表 | 浏览本地生活记录并进入详情 | 记录 Tab 下方列表 | Implemented | `EntryCard` in `PhoneMainSupportingViews.swift` | 展示 seed 和用户本地创建记录 | 卡片密度、目标语言内容和状态 badge 需保持清晰 |
| 空记录状态 | 没有记录时给出创建入口 | 记录 Tab 无 entries | Implemented | `EmptyEntryPanel` in `PhoneMainSupportingViews.swift` | 只引导创建，不写入数据 | 空状态不能像错误或开发提示 |
| 记录详情 | 阅读母语记录、目标语言文本、逐句练习入口和练习条目 | 最近记录、保存后、照片写作创建后 | Implemented / Local Mock | `EntryDetailView`、`EntryDetailHeader.swift`、`SentencePairView` | rendering 可为本地 mock；未 rendering 时允许显式生成本地预览 | 默认 iPhone 流程不显示持久请求预览卡；避免开发标记 |
| 听一句预览 | 针对单句进行本地听读练习展示 | 记录详情每句的 `听` | Local Mock | `LocalListeningPreviewView.swift`、`SentencePairView` | 播放按钮只切换本地状态；不接 TTS、不录音、不保存成绩 | 不得回退到 `听力播放规划中`、`待配置` 等工程文案 |
| 逐句练习入口 | 从单句进入完整练习会话 | 记录详情每句的 `练` | Local Mock | `SentencePairView`、`PracticeSessionView` | 练习状态来自本地 mock session | `听` 与 `练` 的职责需清晰，避免重复入口 |
| 练习 Tab | 从生活记录继续听、读、跟读、回译 | 底部 `练习` Tab | Local Mock | `PracticeView` in `PhoneMainSections.swift`、`PhonePracticeRows.swift` | 练习任务来自本地 rendering 和 practice items | 作为 `听` 的高频承载，不应暴露 TTS 接入计划 |
| 练习会话 | 展示准备、跟读、对照、完成步骤 | 练习 Tab、记录详情 `练` | Local Mock | `PracticeSessionView`、`PracticeControlBar.swift` | step 切换为本地 UI 状态，不录音、不评分 | 后续真实语音能力接入前，需要单独权限和语音边界方案 |
| 记忆 Tab | 查看从生活记录中沉淀的短语和句子 | 底部 `记忆` Tab | Local Mock | `MemoryView` in `PhoneMainSections.swift` | iPhone 当前隐藏技术性三层记忆基础设施 | 不展示向量索引、embedding 等工程概念 |
| iPhone 设置列表 | 查看语言空间、AI、同步、隐私、导出、界面语言等能力边界 | 顶部 gear | Implemented | `SettingsView` in `PhoneMainSections.swift` | 设置项多数为只读边界说明；界面语言可切换 preference | 设置不能成为一级 Tab；文案要面向用户而非工程排期 |
| 设置详情 | 查看单项能力的当前状态、下一步和副作用边界 | 设置列表 row | Implemented / Unavailable | `SettingsCapabilityDetailView.swift` | 除界面语言外，不保存真实 provider、sync、export 配置 | 后续真实 Keychain、同步、导出接入后逐项复查 |
| 语言空间摘要 sheet | 查看当前空间、母语到目标语言、水平和本地优先边界 | 顶部语言空间胶囊或设置入口 | Implemented | `LanguageSpaceSummaryView.swift` | 不支持多空间切换、删除或持久化恢复 | 后续语言空间 lifecycle 落地后更新入口和状态 |
| iPhone 页面 chrome | 为记录、练习、记忆、设置提供顶部语言空间和设置入口 | 三个 Tab 和设置列表内部 | Implemented | `PhonePage`、`PhoneContextHeader.swift` | 语言空间入口打开摘要；设置入口进入设置列表 | 所有主 Tab 都应保留当前语言空间可见性，gear 不应变成底部 Tab |
| Unavailable sheet | 搜索等未接入能力的临时承载 | `PhoneSheet.unavailable` 或共享组件调用 | Unavailable | `UnavailableCapabilityView.swift`、`PhoneMainView.swift` | 只解释边界，不执行真实副作用 | 不应用于主学习高频体验；能 mock 的能力优先做真实级 local mock |

## 4. iPad 页面清单

iPad 的顶层结构是工作台：顶部工具条、左侧时间线 / 筛选、中央写作与详情主区、右侧学习面板。当前代码事实源是 `PadMainView.swift`、`PadMainSections.swift`、`PadMainModels.swift`、`PadWorkspaceBar.swift`、`PadSidebarControls.swift` 和共享详情 / 练习组件。

| 页面 | 用户目的 | 入口 | 当前状态 | 主要代码路径 | 能力边界 | 审查关注点 |
| --- | --- | --- | --- | --- | --- | --- |
| iPad Main Workspace | 承载三栏工作台和可收起面板 | Root 进入 iPad main | Shell | `PadMainView.swift` | 使用本地 seed；面板展开状态是 transient UI state | Split View、Stage Manager 和窄宽度下主内容优先 |
| 顶部工作台工具条 | 切换左右面板、搜索、设置、新建记录 | iPad main 顶部 | Implemented / Unavailable | `PadWorkspaceBar.swift` | 搜索打开 unavailable；新建打开编辑 sheet | 图标按钮需保持 44pt 触控和动态辅助标签 |
| 左侧时间线 | 浏览记录并选择当前 entry | 左侧面板 | Implemented | `PadSidebarView`、`EntryTimelineRow` | 使用本地 entries | 收起后不留空白；选择 entry 后主区进入详情 |
| 左侧筛选 | 按全部、照片写作、待练习、已记忆筛选 | 左侧面板 | Local Mock | `PadFilter` in `PadMainModels.swift`、`FilterPill` | 基于本地 mock 数据和 memory items 推导 | 筛选语义后续要随真实数据模型复查 |
| 左侧页面入口 | 进入记忆、导入导出、设置 | 左侧面板 | Implemented / Unavailable | `PadSidebarView`、`PadWorkspaceRoute` | 导入导出为 unavailable；设置为只读能力页 | 不把低频配置放到顶部挤压工作台 |
| iPad 语言空间底部区 | 显示当前空间、AI、同步、设置入口 | 左侧面板底部 | Implemented | `LanguageSpaceFooter.swift` | AI / Sync 为状态说明，不自动发送或同步 | 图标不能只靠颜色表达状态 |
| 工作台概览 / 写作主区 | 展示当前记录、双语正文、音频面板和句子列表 | 默认 route `.workspace` | Local Mock | `PadWorkspaceContentView.workspaceOverview` | `AudioPanel` 是本地 mock UI；句子来自 rendering | 中央主区是视觉焦点；避免卡片套卡片 |
| iPad 空工作台状态 | 没有选中记录时给出安静的主区占位 | 默认 route 且无 selected entry，或目标 entry 缺失 | Implemented | `EmptyWorkspacePanel` in `PadSidebarControls.swift` | 不创建记录、不生成内容 | 不能显示裸文本或错误式空状态；后续真实空数据需保留创建入口 |
| 记录详情 | 在主区完整查看单条记录 | 时间线选择或 route `.entryDetail` | Implemented / Local Mock | `EntryDetailView` reused in `PadWorkspaceContentView` | 与 iPhone 共享详情组件 | 共享组件改动需同时复查 iPhone 和 iPad |
| 听一句预览 | 从句子列表打开本地听读预览 | 句子 `听` | Local Mock | `SentencePairView`、`LocalListeningPreviewView.swift` | 不触发真实 TTS 或录音 | sheet 尺寸和 iPad 阅读宽度需单独检查 |
| 练习详情 | 在主区进行步骤式练习 | 句子 `练` 或学习面板练习入口 | Local Mock | `PracticeSessionView`、`PracticeControlBar.swift` | 本地 step 状态；无真实语音服务 | 后续语音能力不能直接塞入小 sheet |
| 设置列表 | 在主区查看能力列表 | 顶部 gear、左侧设置、底部设置 | Implemented | `PadWorkspaceContentView.settingsList` | 多数设置为只读说明，界面语言可切换 | iPad 设置应服务当前空间，不变成后台管理 |
| 设置详情 | 查看单项能力边界 | 设置列表 row、底部 AI / Sync | Implemented / Unavailable | `SettingsCapabilityDetailView.swift` | 无真实 provider key、sync、export 写入 | 与 iPhone 设置详情共享，改动需三端复查 |
| 记忆页 | 查看记忆摘要、记忆项和向量索引边界 | 左侧 `记忆` | Local Mock / Unavailable | `PadWorkspaceContentView.memoryPage`、`MemoryLayerSummaryView` | 向量索引为 unavailable；memory items 来自本地 mock | iPad 可展示较多结构，但不能压过学习主线 |
| 导入导出页 | 说明导入导出尚未接入 | 左侧 `导入导出` | Unavailable | `PadWorkspaceContentView.importExportPage`、`UnavailableCapabilityView` | 不打开文件、不读写导出包 | 后续真实文件访问需权限和存储方案 |
| 语言空间摘要页 | 查看当前语言空间摘要 | 底部语言空间入口 | Implemented | `PadWorkspaceContentView.languageSpaceSummaryPage`、`LanguageSpaceSummaryView.swift` | 不支持多空间 lifecycle | 后续多空间选择不应破坏当前 workspace context |
| 右侧学习面板 | 展示当前句子、记忆提取、练习入口、空间设置、请求预览 | 右侧面板 | Local Mock | `PadLearningPanelView` | `RequestPreviewCard` 是本地 / 显式请求边界展示；不发送数据 | iPad 可以保留请求预览上下文，但视觉占比要克制 |
| 右侧学习面板空状态 | 未选中记录时说明学习面板等待内容 | 右侧学习面板无 selected entry | Implemented | `PadLearningPanelView`、`LocalizedTextPanel` | 只展示说明，不触发生成或练习 | 空状态应低干扰，不能要求用户先配置工程能力 |
| 搜索 unavailable sheet | 表达搜索尚未接入 | 顶部搜索 | Unavailable | `PadSheet.unavailableSearch`、`UnavailableCapabilityView(.search)` | 不执行真实搜索或索引查询 | 后续搜索接入时需定义跨空间范围 |
| 新建记录 sheet | 创建文本记录 | 顶部新建 | Implemented | `EntryEditorView` reused by `PadMainView` | 内存 repository；不持久化 | 后续 iPad 可考虑平台专属编辑体验 |

## 5. macOS 页面清单

macOS 的顶层结构是桌面工作台：左侧 Sidebar、中央主区、右侧 Inspector、Toolbar、菜单命令和原生 Settings scene。当前代码事实源是 `MacMainView.swift`、`MacMainModels.swift`、`MacWorkspaceContentView.swift`、`MacInspectorContent.swift`、`MacEntryEditorSheet.swift`、`LangoTraceSettingsSceneView.swift` 和 `LangoTraceApp.swift`。

| 页面 | 用户目的 | 入口 | 当前状态 | 主要代码路径 | 能力边界 | 审查关注点 |
| --- | --- | --- | --- | --- | --- | --- |
| Mac Main Workspace | 承载 Sidebar、主区、Inspector 和 toolbar | Root 进入 macOS main | Shell | `MacMainView.swift` | 使用本地 seed；Sidebar / Inspector 展开状态为 transient UI state | 最小窗口宽度、菜单命令和键盘路径需持续复查 |
| Mac Sidebar | 在 Today、Entries、Practice、Memory、Import / Export、Settings 间切换 | 左侧 Sidebar | Implemented | `MacWorkspaceSection`、`MacSidebarItem` | 只是 section selection，不创建业务数据 | 不使用移动端 Tab；hover、focus、context menu 需保留 |
| Mac Toolbar | 切换 Sidebar / Inspector、搜索、新建记录 | 窗口 toolbar | Implemented / Unavailable | `MacMainView.toolbar` | 搜索 route 为 unavailable；新建打开 overlay | 桌面命令需与菜单栏保持一致 |
| Today 主区 | 展示当前 entry 详情和搜索 / 批量导入入口 | Sidebar `Today` | Local Mock | `MacWorkspaceContentView.todayContent` | 搜索、批量导入为 unavailable；entry 为本地 mock | 不能像后台 dashboard，主内容应围绕当前记录 |
| Entries 资料库 | 浏览所有记录并选择详情 | Sidebar `Entries` | Implemented | `MacWorkspaceContentView.entriesContent` | 使用本地 entries | 后续批量管理、排序、搜索接入后更新 |
| Entry Detail | 查看选中记录详情 | Entries row、Today 选中、保存后 | Implemented / Local Mock | `EntryDetailView` reused in `MacWorkspaceContentView` | 共享移动端详情组件；rendering 可能为 mock | macOS 可能需要更桌面化详情布局，避免移动布局直接放大 |
| New Entry Overlay | 桌面化创建记录 | Toolbar plus、菜单 New Entry | Implemented | `MacEntryEditorOverlay`、`MacEntryEditorSheet.swift` | 保存到内存 repository；不持久化 | overlay 点击背景取消、键盘取消和输入体验需保持 |
| Practice section | 查看所有 entry 的练习任务 | Sidebar `Practice` | Local Mock | `MacWorkspaceContentView.practiceContent` | 有 rendering 的记录显示 mock practice items | 后续真实音频 / 录音应有桌面控制面 |
| Practice route | 执行某条记录的练习会话 | Practice item 或 entry detail | Local Mock | `PracticeSessionView` reused in `MacWorkspaceContentView.practice` | 本地 step 状态；无录音或 TTS | macOS 练习可能需要键盘快捷键和更高密度布局 |
| Memory section | 查看记忆摘要、记忆项和向量索引边界 | Sidebar `Memory` | Local Mock / Unavailable | `MacWorkspaceContentView.memoryContent`、`MemoryLayerSummaryView` | 向量索引为 unavailable | macOS 可展示更多资料库信息，但不能泄露工程术语给普通用户 |
| Import / Export section | 说明导入导出尚未接入 | Sidebar `Import / Export` 或 bulk import action | Unavailable | `MacUnavailableContent("import-export")`、`UnavailableCapabilityView` | 不打开文件、不导入、不导出 | 后续真实能力需文件访问、附件、导出格式方案 |
| Settings section | 查看能力设置列表 | Sidebar `Settings` 或 `Cmd+,` 通知后选中 settings | Implemented | `MacWorkspaceContentView.settingsContent` | 多数能力只读；界面语言可切换 | Settings section 和原生 Settings scene 的职责不能冲突 |
| Settings detail route | 查看单项能力详情 | Settings row、Sidebar footer AI / Sync | Implemented / Unavailable | `SettingsCapabilityDetailView.swift` | 无真实密钥、同步、导出配置写入 | Keychain / Sync / StoreKit 接入时逐项复查 |
| Language Space summary route | 查看当前语言空间摘要 | Sidebar footer 语言空间 | Implemented | `LanguageSpaceSummaryView.swift` | 不支持多空间创建、切换、删除 | 多窗口 / 多语言空间设计前必须更新 |
| Search unavailable route | 表达搜索尚未接入 | Toolbar search、菜单 search | Unavailable | `MacUnavailableContent("search")`、`UnavailableCapabilityView` | 不查询 FTS、向量索引或外部服务 | 后续搜索需要 Command Palette / 全局搜索边界 |
| Missing route fallback | 当前 route 指向缺失 entry、practice 或 setting 时给出可读反馈 | 深层 route 找不到对象 | Implemented | `MacWorkspaceContentView.entryDetail`、`practice`、`settingDetail`、`LocalizedCompactPanel` | 不自动恢复、创建或删除数据 | 后续真实持久化后需要明确 missing object 恢复策略 |
| Inspector Overview | 根据当前 section 展示上下文说明 | 右侧 Inspector，route `.overview` | Implemented | `MacInspectorContent.overviewInspector` | 说明性上下文，不写入数据 | Inspector 文字不能替代主区可用性 |
| Inspector Entry | 展示 entry metadata、请求预览、记忆候选、隐私边界 | route `.entryDetail` | Local Mock | `MacInspectorContent`、`RequestPreviewCard` | Request preview 仍是本地 / 显式请求边界展示 | macOS 可承载请求预览，但必须避免暗示自动发送 |
| Inspector Practice | 展示练习状态和后续能力说明 | route `.practice` | Local Mock | `MacInspectorContent` | 不录音、不评分 | 真实练习接入后更新状态来源 |
| Inspector Settings | 展示设置说明和下一步 | route `.settings` | Implemented / Unavailable | `MacInspectorContent` | 读取 setting capability 文案 | 避免三块式工程说明过重 |
| macOS Settings scene | 系统级设置窗口，展示能力状态列表 | App Settings / `Cmd+,` | Implemented | `LangoTraceApp.swift` Settings scene、`LangoTraceSettingsSceneView.swift` | 读取当前环境的 settings capabilities；列表 row 当前为只读 `action: nil`，不打开详情、不保存真实配置 | 原生 Settings 和工作台 Settings section 需要保持语义一致；后续真实偏好写入要单独设计 |
| macOS Commands | 菜单触发 New Entry、Search、Toggle Sidebar、Toggle Inspector、Settings | 菜单栏 / 快捷键 | Implemented / Unavailable | `LangoTraceApp.swift`、`LangoTraceAppCommand.swift` | Search 打开 unavailable，不执行真实搜索 | 菜单项必须有可见结果，不能空 action |

## 6. 共享页面与组件清单

这些组件不是独立平台入口，但它们承载多个页面的核心体验。修改时必须按影响平台复查。

| 组件 / 页面 | 使用平台 | 当前状态 | 主要代码路径 | 影响范围 |
| --- | --- | --- | --- | --- |
| `EntryDetailView` | iPhone / iPad / macOS | Implemented / Local Mock | `PhoneMainSupportingViews.swift` | 三端记录详情、逐句练习、未 rendering 状态 |
| `SentencePairView` | iPhone / iPad / macOS | Local Mock | `LearningContentComponents.swift` | 单句听读预览和练习入口 |
| `LocalListeningPreviewView` | iPhone / iPad / macOS | Local Mock | `LocalListeningPreviewView.swift` | 逐句听力 sheet；不接真实 TTS |
| `PracticeSessionView` | iPhone / iPad / macOS | Local Mock | `PhoneMainSupportingViews.swift`、`PracticeControlBar.swift` | 准备、跟读、对照、完成步骤 |
| `SettingsCapabilityDetailView` | iPhone / iPad / macOS | Implemented / Unavailable | `SettingsCapabilityDetailView.swift` | AI、同步、隐私、导出、本地数据、语言空间、界面语言 |
| `LanguageSpaceSummaryView` | iPhone / iPad / macOS | Implemented | `LanguageSpaceSummaryView.swift` | 当前语言空间摘要 |
| `UnavailableCapabilityView` | iPhone / iPad / macOS | Unavailable | `UnavailableCapabilityView.swift` | 搜索、导入导出、向量索引和通用未接入能力 |
| `RequestPreviewCard` | iPad / macOS | Local Mock / Explicit request boundary | `LearningContentComponents.swift`、`PremiumUILayoutRules.swift` | iPad 学习面板、macOS Inspector |
| `MemoryLayerSummaryView` | iPad / macOS | Local Mock / Unavailable mix | `LearningContentComponents.swift` | 记忆摘要和向量索引边界 |
| `LanguageSpaceFooter` | iPad / macOS | Implemented | `LanguageSpaceFooter.swift` | Sidebar 底部空间、AI、同步、设置入口 |
| `CapabilityStatusRow` | iPhone / iPad / macOS | Implemented | `LearningContentComponents.swift` | 能力状态、设置列表、unavailable / local mock 入口 |
| `PhonePage` / `PhoneContextHeader` | iPhone | Implemented | `PhoneMainSections.swift`、`PhoneContextHeader.swift` | iPhone 主 Tab 的页面外壳、语言空间入口和设置入口 |
| `EntryTimelineRow` | iPad / macOS | Implemented | `LearningContentComponents.swift` | iPad 时间线、macOS entries library 的记录选择行 |
| `AudioPanel` | iPad | Local Mock | `ContentUtilityComponents.swift` | iPad 工作台概览中的本地音频视觉占位，不播放真实音频 |
| `EmptyWorkspacePanel` / `LocalizedCompactPanel` / `LocalizedTextPanel` | iPad / macOS | Implemented | `PadSidebarControls.swift`、`ContentUtilityComponents.swift`、`LocalizedTextPanel.swift` | 空状态、缺失对象状态和说明型面板 |
| `LangoTraceSettingsSceneView` | macOS | Implemented | `LangoTraceSettingsSceneView.swift` | 原生 Settings scene 的只读能力列表 |

## 7. 页面覆盖自检

截至 2026-05-19，本文档已按以下代码事实逐项覆盖：

- Root phase：`LangoTraceAppPhase.welcome`、`onboarding`、`main`。
- iPhone route：`PhoneRoute.entryDetail`、`practice`、`settings`、`settingsList`。
- iPhone sheet：`PhoneSheet.entryEditor`、`photoWritingPreview`、`unavailable`、`languageSpaceSummary`。
- iPad route：`PadWorkspaceRoute.workspace`、`entryDetail`、`practice`、`settingsList`、`settings`、`memory`、`importExport`、`languageSpaceSummary`。
- iPad sheet：`PadSheet.entryEditor`、`unavailableSearch`。
- macOS section：`MacWorkspaceSection.today`、`entries`、`practice`、`memory`、`importExport`、`settings`。
- macOS route：`MacWorkspaceRoute.overview`、`entryDetail`、`practice`、`settings`、`languageSpaceSummary`、`unavailable`。
- macOS command：`newEntry`、`search`、`toggleSidebar`、`toggleInspector`、`showSettings`。
- macOS scene：main `WindowGroup` 和原生 `Settings` scene。

## 8. 当前不应出现的页面表现

以下表现如果重新出现，应视为 UI 质量或文档一致性问题：

- iPhone 顶层恢复五 Tab 或把设置作为底部 Tab。
- iPhone 记录 Hero 恢复 `听` 作为首屏高频入口。
- iPhone 记录详情默认显示持久 `RequestPreviewCard`。
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
7. 是否需要同步更新 `docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md` 或 `docs/review/INDEX.md`？

完成页面相关任务前，至少检查：

```bash
rg "struct .*View|enum .*Route|enum .*Sheet|NavigationStack|TabView|sheet\\(|navigationDestination|Settings" Packages/LangoTraceUI/Sources/LangoTraceUI LangoTraceApp -n
rg "规划中|待配置|当前页面只展示入口边界|不播放真实 TTS|onListen|UnavailableCapabilityView\\(content: \\.listenOne\\)" Packages/LangoTraceUI/Sources Packages/LangoTraceUI/Tests
```

如果页面清单和代码不一致，以代码为当前事实，并在同一任务中修正文档或明确记录偏差。

## 10. 变更记录

- 2026-05-19：创建第一版三端页面清单。依据当前 SwiftUI 代码记录 Root、iPhone、iPad、macOS、共享组件、unavailable / local mock 页面和维护规则。
- 2026-05-19：补充页面覆盖自检、iPhone 页面 chrome、iPad 空状态、macOS missing route fallback、macOS Settings scene 只读边界和共享承载组件。原因：复查 SwiftUI `View` / `Route` / `Sheet` / `Settings` 后，需要把非主 route 但会影响页面完整性的承载层写清楚。
