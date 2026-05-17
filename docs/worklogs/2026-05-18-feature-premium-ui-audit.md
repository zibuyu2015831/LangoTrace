# 工作记录：三端付费级 UI 全面审查与优化方案

类型：feature

状态：Reviewed

日期：2026-05-18

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/guidelines/002-navigation-and-routing.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/guidelines/004-swiftui-architecture.md`
- `docs/guidelines/005-ai-provider-prompt-and-privacy.md`
- `docs/guidelines/006-interface-localization-and-language-boundaries.md`
- `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`
- `docs/worklogs/2026-05-18-chore-premium-ui-principles-review-plan.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 未提交

## 1. 审查背景和目标

当前 LangoTrace 已经完成 Welcome / Onboarding / Main 启动路由、iPhone Tab、iPad 学习桌面、macOS 工作台、Mock 学习内容、隐私状态图标、设置能力说明和 iPad 边缘手势。三端已经能展示产品骨架，但仍处于真实数据、真实 AI、真实语音、真实同步和 StoreKit 之前的早期阶段。

本轮目标不是直接美化页面，也不是修改 SwiftUI 代码，而是站在系统架构师和专业 iOS / iPadOS / macOS 交互设计师角度，把“付费级 UI”拆成有代码和文档证据的问题清单、设计系统补强建议、样板页面选择和分阶段优化方案。

付费级 UI 的判断基准来自产品定位：LangoTrace 是“用生活记录学习语言”的本地优先 Apple 三端原生 App。优秀 UI 应强化个人语言资料库、生活记录到学习闭环、隐私可信状态和平台原生体验，而不是通过装饰性渐变、阴影、卡片堆叠或营销式文案制造高级感。

## 2. 审查范围

### 2.1 指定文档

已按项目入口要求阅读或复核：

- `AGENTS.md`，确认重要功能、UI 审查和架构判断需要进入 `docs/worklogs/`。
- `docs/product-main-reference.md`，确认核心定位、学习闭环、语言空间、买断制和本地优先方向。
- `docs/guidelines/002-navigation-and-routing.md`，确认 iPhone / iPad / macOS 导航、语言空间上下文、设置入口和 mock/unavailable 路由边界。
- `docs/guidelines/003-ui-design-system.md`，确认设计气质、状态表达、组件方向、触控尺寸和本地化约束。
- `docs/guidelines/004-swiftui-architecture.md`，确认平台外壳、共享内容视图、App-level / Feature-level / transient UI state 和 View 副作用边界。
- `docs/guidelines/005-ai-provider-prompt-and-privacy.md`，确认 AI Provider、请求预览、隐私发送边界和日志边界。
- `docs/guidelines/006-interface-localization-and-language-boundaries.md`，确认界面语言、母语、目标学习语言、Prompt 输出语言和内容语言分层。
- `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`，确认本轮审查维度、问题记录格式、严重度和分阶段优化结构。

### 2.2 代码目录

本轮检查范围：

- `LangoTraceApp/`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/` 中与页面状态、语言空间、Tab、隐私状态相关的模型。
- `Packages/LangoTraceData/Sources/LangoTraceData/` 中与 preview、mock 内容、设置能力和练习状态相关的模型。

### 2.3 重点文件

- `LangoTraceApp/LangoTraceApp.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadSidebarControls.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadWorkspaceBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceFooter.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/UnavailableCapabilityView.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/PracticeSessionState.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SeedLearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`

## 3. 总体判断

当前三端页面的优点是：核心导航形态基本符合文档，iPhone 使用 `Today / Entries / Practice / Memory / Settings` Tab，iPad 保持三栏工作台并支持左右面板收起，macOS 使用 Sidebar / main / Inspector，语言空间、AI Provider 和同步状态已经下沉到 iPad / macOS Sidebar 底部，设置能力和 unavailable 页面也明确写出不会访问照片、麦克风、网络、Keychain、真实数据库、同步服务或导出文件。

主要差距不是“缺少装饰”，而是还没有形成可支撑付费级感知的设计系统和页面样板。当前实现大量依赖浅米色纸面、teal 强调色、圆角面板和说明文案；产品对象之间的来源关系、能力边界、状态层级、Mac 生产力工具感、iPad 主焦点和 iPhone 单任务路径仍偏早期骨架。下一阶段应先补设计系统底座，再用少数样板页面验证，不应全项目同时重写。

本轮未发现 P0。没有看到 UI 直接访问真实网络、Keychain、数据库、同步服务或具体 AI Provider；也没有看到已经真实发送隐私内容的路径。P1 问题集中在 iPhone 全局横滑 Tab 手势、设计 token 单一且难以验证、请求预览文案“即将发送”与 Local Mock 状态冲突、Mac 工作台仍像放大的 iPad 页面、Data 层承担中文 UI chrome。

## 4. iPhone 问题清单

### I-01：全局横滑 Tab 手势可能破坏 iOS 原生返回和滚动预期

- 平台：iPhone
- 页面或组件：`PhoneMainView`
- 问题类型：平台交互
- 严重度：P1
- 代码证据：`PhoneMainView` 在整个 `TabView` 上使用 `.simultaneousGesture(tabSwipeGesture)`，`tabSwipeGesture` 为本地坐标 `DragGesture(minimumDistance: 24)`，结束后直接根据水平位移切换 Tab。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`，`PhoneMainView.body`，`tabSwipeGesture`
- 问题描述：iPhone 顶层已经有标准 Tab Bar，额外在整个 Tab 内容区域挂水平拖拽会与 `NavigationStack` 系统边缘返回、ScrollView 横向误触、TextEditor 选择和未来逐句卡片横向动作产生竞争。该手势没有限定起点、没有显式避开系统返回边缘，也没有作为可发现交互呈现。
- 违反依据：`docs/guidelines/002-navigation-and-routing.md` 规定 iPhone 保持 Tab 和 `NavigationStack` 层级，不新增会干扰系统返回手势的全屏横向手势；付费级 UI 规格要求手势只是加速路径，不是唯一入口，并且不能阻断平台标准手势。
- 决策依据：这不是审美问题，而是平台交互风险。用户在 iPhone 上期待底部 Tab 和系统返回稳定；全屏横滑切 Tab 会让深层详情和编辑路径的返回心智变得不确定，尤其当后续加入 OCR 校对、句子滑动、录音控制或卡片操作时会放大冲突。
- 优化方向：第一批样板实现中应删除全局横滑 Tab，或仅在明确的顶部 segmented / pager 区域使用可见、可测试的切换控件。Tab 切换保留系统 Tab Bar；若需要快捷切换，考虑系统键盘快捷键或明确按钮，不在全屏内容上抢手势。
- 复查方法：代码检查确认 `PhoneMainView` 不再对整个 `TabView` 挂全屏水平 `DragGesture`；在 iPhone 模拟器验证 Tab、详情返回、sheet dismiss、TextEditor 输入和 ScrollView 滚动互不干扰；必要时增加 `PhoneRootTab` 纯函数测试覆盖手势 helper 删除或收敛后的逻辑。

### I-02：首页主动作同时并列三枚 ActionChip，削弱“今天记录一点生活”

- 平台：iPhone
- 页面或组件：`TodayView`，`HeroActionCard`
- 问题类型：产品路径 / 视觉系统
- 严重度：P1
- 代码证据：`TodayView` 把 `HeroActionCard` 作为首页主区；`HeroActionCard` 内部并列 `写一句`、`拍照`、`听一句` 三个同等视觉权重 ActionChip，其中拍照和听一句当前进入 unavailable。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`，`TodayView`；`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`，`HeroActionCard`
- 问题描述：产品文档明确首页主动作应围绕“今天记录一点生活”。当前三枚同权重入口让用户难以判断真正可用且最重要的动作，且其中两项是未接入能力，会让首页首屏过早暴露能力缺口。
- 违反依据：`docs/product-main-reference.md` 第 7 节强调首页主动作应尽量围绕“今天记录一点生活”；`docs/guidelines/003-ui-design-system.md` 要求首页进入可用体验，未接入能力不能抢占主流程。
- 决策依据：用户购买感来自主路径清楚和反馈可信，不是入口数量。三入口并列会把未接入的照片和听力能力放到与文本记录同等地位，降低第一屏完成度。
- 优化方向：样板页应把 `写一句` 做成唯一主 CTA；`拍照写作`、`听一句` 改为次级能力入口或渐进说明，使用 `CapabilityStatusBadge` 标明 Local Mock / 未接入，不与主按钮同权重。首页首屏优先展示当前语言空间、今日主动作、最近记录和下一次可执行练习。
- 复查方法：iPhone 小屏截图确认首屏只有一个主 CTA；VoiceOver 顺序先读当前空间和主动作，再读次级能力；手动点击未接入能力确认进入统一 unavailable sheet 且不会触发权限。

### I-03：记录详情在 iPhone 上使用双列 HStack，动态字体和小屏风险高

- 平台：iPhone
- 页面或组件：`EntryDetailView`
- 问题类型：平台交互 / 视觉系统
- 严重度：P1
- 代码证据：`EntryDetailView` 使用 `HStack` 并排显示 `TextPanel(title: "母语记录")` 和 `TextPanel(title: "目标语言")`。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`，`EntryDetailView`
- 问题描述：双语对照是核心体验，但 iPhone 单列页面在较大 Dynamic Type、长句、德语/俄语等长本地化或小屏宽度下，并排文本会造成行长过短、阅读断裂和垂直高度膨胀。iPhone 上更适合上下分组、逐句对照或可切换视图。
- 违反依据：`docs/guidelines/003-ui-design-system.md` 要求 iPhone 单列、一次聚焦一个任务；`docs/guidelines/006-interface-localization-and-language-boundaries.md` 要求不能按中文短标签和默认字号设计。
- 决策依据：这影响核心学习闭环的可读性，不是单纯布局偏好。用户需要读懂母语来源和目标语言表达，过窄双列会削弱学习价值。
- 优化方向：iPhone 记录详情样板应使用垂直结构：原始记录摘要、目标语言 rendering、逐句 `SentencePairView`。如果需要左右对照，可在 iPad / macOS 或横向宽度才使用双列；iPhone 通过逐句卡片建立来源关系。
- 复查方法：iPhone SE 宽度、默认字号和较大 Dynamic Type 截图；英文和简体中文界面切换；检查母语长段、目标语言长句不溢出、不被按钮遮挡。

### I-04：设置页承担大量能力说明，主流程完成感不足

- 平台：iPhone
- 页面或组件：`SettingsView`，`SettingsCapabilityDetailView`
- 问题类型：能力边界 / 产品路径
- 严重度：P2
- 代码证据：`SettingsView` 遍历 `settingsCapabilities`，详情页展示当前边界、后续接入条件和不会发生；能力数据来自 `InMemoryLearningContentRepository.settingsCapabilities(for:)`。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`，`SettingsView`；`Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`；`Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- 问题描述：当前设置页在能力边界上是诚实的，但列表和详情像工程说明文档。付费级 iPhone 设置应更像可理解的偏好中心：先呈现当前状态和用户可做的动作，再将未接入条件放入次级说明。
- 违反依据：UI 规格要求渐进披露优先于说明堆叠；导航规范要求配置路由可以只读，但不能抢占记录和学习主流程。
- 决策依据：用户需要知道隐私和能力边界，但不应该在移动端阅读大量工程接入条件。过重说明会降低产品完成度。
- 优化方向：建立 `CapabilityStatusBadge`、`UnavailableStateView` 和 `SettingsCapabilityRow` 三层表达。列表只显示状态和短说明；详情页把“不会发生”和“后续接入条件”折叠或放在说明区；真实可操作偏好如界面语言保持清晰可改。
- 复查方法：iPhone 设置列表截图检查每行信息层级；VoiceOver 检查标题、状态、摘要不重复；手动进入 AI Provider / 同步 / 本地数据详情确认不会误导为可配置真实能力。

## 5. iPad 问题清单

### P-01：三栏布局有骨架，但中间学习主区视觉焦点不够强

- 平台：iPad
- 页面或组件：`PadMainView`，`PadWorkspaceContentView`
- 问题类型：视觉系统 / 产品路径
- 严重度：P1
- 代码证据：`PadMainView` 使用左 `sidebar`、中 `writingDesk`、右 `learningPanel`；中间 `workspaceOverview` 内包含标题、双列 TextPanel、`AudioPanel` 和逐句列表，最大宽度为 820。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`，`PadMainView.body`；`Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`，`workspaceOverview`
- 问题描述：iPad 的目标是沉浸式学习工作台。当前左右面板、顶部搜索、新建按钮和中间多个同类面板的视觉语言接近，主记录和目标语言文本没有足够的层级差异，用户第一眼难以知道当前学习焦点是哪一条记录、哪一句目标语言、下一步练什么。
- 违反依据：`docs/guidelines/003-ui-design-system.md` 要求 iPad 中间内容为主，右侧学习面板承载解释、词句、练习入口；付费级规格要求三栏不是为了复杂，而是减少上下文切换。
- 决策依据：这影响核心体验，不是美观偏好。iPad 的付费价值应来自同时看到生活记录、目标表达、逐句学习和练习入口；如果所有区块都是同等面板，工作台像原型而非产品。
- 优化方向：iPad 样板应把中间主区改成明确的 Entry 阅读和学习画布：顶部为记录标题和来源 metadata，中部为母语/目标语言对照，逐句区域有当前句焦点，右侧学习面板跟随当前句或当前任务。左右面板使用更低对比度，主区使用更稳定行长和阅读层级。
- 复查方法：iPad Pro 默认宽度截图、左右面板分别收起截图、Stage Manager 中等宽度截图；检查第一眼主焦点、当前记录、当前句、练习入口是否可辨。

### P-02：compact width 只在 onAppear 收起学习面板，尺寸变化后的响应式状态不稳定

- 平台：iPad
- 页面或组件：`PadMainView`
- 问题类型：平台交互 / 组件状态
- 严重度：P1
- 代码证据：`shouldPreferSingleMainColumn` 基于 `horizontalSizeClass == .compact`，但只在 `.onAppear` 中将 `isLearningPanelVisible = false`。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`，`shouldPreferSingleMainColumn`，`.onAppear`
- 问题描述：iPad Split View、Slide Over 和 Stage Manager 会在运行中改变窗口宽度。当前实现只在出现时处理 compact，无法保证窗口变窄后自动保护主内容，也无法保证变宽后用户意图和系统建议之间有清晰关系。
- 违反依据：导航规范要求 iPad 在 compact width、Split View、Slide Over 或 Stage Manager 窄窗口下优先保证主内容可读；UI 规格要求多窗口和尺寸变化时选中记录、滚动位置和面板状态稳定。
- 决策依据：这是 iPadOS 原生体验问题。付费 App 需要适应 Stage Manager 和分屏，而不是只在首次出现时设置一次。
- 优化方向：设计 `PadAdaptiveLayoutState` 或纯函数 helper，根据宽度等级、用户显式面板选择和当前任务决定面板默认可见性。用户手动展开/收起属于 transient UI state，但响应式降级应有可测试规则。
- 复查方法：增加纯函数单元测试覆盖 regular -> compact -> regular 的面板策略；用 iPad 模拟器分屏或 Stage Manager 尺寸变化手动验证主内容不被挤压，选中记录和 route 不丢失。

### P-03：顶部搜索框是静态视觉元素，缺少不可用状态和后续边界

- 平台：iPad
- 页面或组件：`PadWorkspaceBar`
- 问题类型：组件状态 / 能力边界
- 严重度：P2
- 代码证据：`PadWorkspaceBar` 展示一个带放大镜和“搜索记录、词句、相似生活片段”的 HStack，但不是 `Button`、`TextField` 或 `UnavailableCapabilityView` 入口。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PadWorkspaceBar.swift`，`PadWorkspaceBar.body`
- 问题描述：搜索是高价值能力，但当前只是一个看起来可点击的静态容器。用户会把它理解成搜索输入，实际没有焦点、键盘、点击反馈或 unavailable 说明。
- 违反依据：导航规范要求明显按钮和关键二级路径要有可见结果；UI 规范要求空状态和不可用状态不能临时用裸文本堆在页面上。
- 决策依据：这是交互可信度问题。一个看起来像搜索框但不可交互的控件，会降低付费级完成度。
- 优化方向：短期改成 `Button` 触发 `UnavailableCapabilityView` 或使用明确 disabled 状态；后续真实搜索接入时再改为 `searchable` 或 Mac/iPad 适配的命令搜索。文案应说明 FTS / 向量索引未接入，不会查询真实数据库。
- 复查方法：手动点击搜索区域有反馈；VoiceOver 读出“搜索未接入”或“搜索”；代码检查不再存在仅用 HStack 伪装输入的搜索框。

### P-04：右侧学习面板存在空字符串和过弱状态表达

- 平台：iPad
- 页面或组件：`PadLearningPanelView`
- 问题类型：组件状态 / 能力边界
- 严重度：P2
- 代码证据：词句提取使用 `memoryItems.filter { $0.entryID == entry.id }.map(\.text).joined(separator: ", ")`，若当前记录没有记忆项会显示空文本；练习摘要同样拼接 practice item summary。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`，`PadLearningPanelView.selectedEntryContent`
- 问题描述：学习面板应该是 iPad 的核心价值区，但当前缺少当前句、词句候选、练习可用性和请求预览的明确状态。空字符串会让用户误以为 UI 漏渲染。
- 违反依据：UI 规范要求错误、空状态、加载状态不能用裸文本堆在页面上；规格要求状态表达必须可信。
- 决策依据：右侧面板是“生活记录 -> 学习动作”的桥梁，空文本会直接破坏闭环感。
- 优化方向：建立 `LearningPanelState` 或局部状态组件：无词句时显示“这条记录还没有提取词句，当前不会调用 AI”；无练习时显示 unavailable 行；有 mock 数据时用 `CapabilityStatusBadge` 标注 Local Mock。
- 复查方法：构造有 rendering 无 memory、有 memory、有 practice item、无 practice item 四种 preview；截图确认没有空白 TextPanel。

## 6. macOS 问题清单

### M-01：Mac 使用自定义 HStack 工作台，缺少 Toolbar / Commands / Settings scene 边界

- 平台：macOS
- 页面或组件：`MacMainView`
- 问题类型：平台交互 / 工程结构
- 严重度：P1
- 代码证据：`MacMainView` 以 `HStack` 自行组合 Sidebar、main、Inspector；顶部 header 内放侧栏/检查器按钮和 `新建记录`；当前没有使用 macOS `NavigationSplitView`、`.toolbar`、`Settings` scene、菜单命令或 `Cmd+,` 边界。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`，`MacMainView.body`，`header`
- 问题描述：当前 Mac 页面能工作，但更像自绘 iPad 工作台。付费级 Mac App 应呈现资料库和生产力工具感：Sidebar、Toolbar、Inspector、菜单栏、快捷键、Settings 和窗口行为有清楚职责。
- 违反依据：导航规范推荐 macOS 主区顶部或 Toolbar、Sidebar、Inspector、Command Palette、多窗口、菜单栏和快捷键；UI 规格要求 Mac 像原生个人语言资料库。
- 决策依据：Mac 用户期望窗口、工具栏、菜单和键盘操作稳定。自定义 header 可以作为早期骨架，但如果作为样板推广会形成平台债务。
- 优化方向：Mac 样板阶段先定义 Toolbar 命令模型和后续 Settings scene 边界，不必立即实现所有菜单。`新建记录`、Sidebar toggle、Inspector toggle、搜索入口进入 Toolbar；Sidebar 继续承载资料库 section 和底部语言空间，Inspector 专注请求预览/元数据/学习状态。
- 复查方法：macOS 构建后手动检查窗口 toolbar 区域、Sidebar/Inspector toggle、菜单或 Settings 入口候选；键盘焦点能从 Sidebar 到 main 到 Inspector；最小窗口主内容仍优先可读。

### M-02：最小窗口宽度硬编码较大，可能不符合 Mac 可缩放体验

- 平台：macOS
- 页面或组件：`MacMainView`
- 问题类型：平台尺寸 / 视觉系统
- 严重度：P1
- 代码证据：`minimumWindowWidth` 在 Sidebar 和 Inspector 都显示时为 1160，只显示一个时为 900，都隐藏时为 680；root frame 设置 `minHeight: 720`。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`，`minimumWindowWidth`，`body`
- 问题描述：Mac 用户会调整窗口和并排使用应用。硬编码较大的最小窗口容易在小屏 MacBook、分屏或 Stage Manager 下表现笨重。正确方向不是无限压缩，而是在宽度不足时优先保护主内容并收起低频面板。
- 违反依据：UI 规范要求 macOS Sidebar 和 Inspector 可手动显示/隐藏，不能固定挤压主编辑区；付费级规格要求最小窗口优先保留主内容。
- 决策依据：这是平台可用性，不是视觉偏好。窗口无法缩到用户需要的尺寸，会让 App 像固定尺寸原型。
- 优化方向：建立 Mac 窗口宽度等级和自动/建议收起策略。最小可用宽度应围绕主内容和当前任务定义；Sidebar/Inspector 的显示可以由用户控制，但当宽度不足时给出合理降级。
- 复查方法：macOS 默认窗口、半屏、较窄窗口、Sidebar/Inspector 分别收起截图；检查主记录、双语内容和设置详情不被挤压。

### M-03：Mac Today 页优先展示搜索/批量导入说明，弱化生活记录学习闭环

- 平台：macOS
- 页面或组件：`MacWorkspaceContentView.todayContent`
- 问题类型：产品路径
- 严重度：P1
- 代码证据：Mac `todayContent` 第一行展示 `搜索与筛选` 和 `批量导入` 两个 `TextPanel`，之后才展示当前记录详情。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`，`todayContent`
- 问题描述：Mac 可以更重资料库和批量能力，但当前真实数据层、导入导出和搜索都未接入。把两个未接入说明放在 Today 首位，会让首页像功能占位板，而不是个人语言资料库工作台。
- 违反依据：产品主文档要求主流程围绕记录、转换、对照、听说、输出、提取、复习和沉淀；规格要求内容路径优先于界面装饰或说明堆叠。
- 决策依据：这影响 Mac 首页定位。搜索和导入是高阶能力，不能抢过当前记录和学习闭环。
- 优化方向：Mac Today 样板应优先展示当前选中记录、目标语言版本、最近学习状态和 Inspector 请求预览。搜索/批量导入作为 Toolbar command 或 Sidebar section 的 unavailable 入口，不能作为首屏主内容。
- 复查方法：Mac Today 截图检查第一屏是否展示当前生活记录和学习动作；点击搜索/导入候选入口确认进入 unavailable 说明。

### M-04：Inspector 内容偏静态说明，尚未体现 Mac 生产力上下文

- 平台：macOS
- 页面或组件：`MacInspectorContent`
- 问题类型：平台交互 / 组件状态
- 严重度：P2
- 代码证据：Inspector 在 entry detail 时展示 `RequestPreviewCard` 和隐私边界；overview 分支多为静态 `TextPanel` 说明。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`
- 问题描述：Mac Inspector 应承载上下文 metadata、请求预览、词句提取、练习状态和可选操作。当前内容多为只读说明，缺少选中记录 metadata、来源关系、当前句、候选记忆、可用命令和错误/不可用状态。
- 违反依据：导航规范推荐 macOS Inspector 承载请求预览、词句提取、元数据和练习状态；规格要求 Mac 更重管理、搜索、批量整理和长内容编辑。
- 决策依据：Inspector 是 Mac 原生感的关键，不应只是说明文档侧栏。
- 优化方向：样板中定义 `InspectorSection`：Entry metadata、Request Preview、Memory Candidates、Practice State、Capability Boundary。没有数据时显示空状态，不显示空白或泛泛说明。
- 复查方法：Mac Entry detail、Practice、Settings、Unavailable 四类 route 截图；确认 Inspector 内容随 route 和 selected entry 变化，且不挤压主内容。

## 7. Shared 问题清单

### S-01：设计 token 偏单一色相和纸面风格，缺少状态、层级和平台密度 token

- 平台：shared
- 页面或组件：`LangoTraceDesign`
- 问题类型：视觉系统 / 工程结构
- 严重度：P1
- 代码证据：`LangoTraceDesign.ColorToken` 主要由 `paper`、`elevatedPaper`、`teal`、`paleTeal`、`gold` 组成；`langoPanel` 统一使用 18pt 圆角、纸色背景和 hairline；阴影只有 `langoSoftShadow`。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- 问题描述：当前 token 足以支撑早期骨架，但不足以表达付费级三端 UI 的状态层级。所有页面容易落入浅米色纸面 + teal badge + 圆角卡片的单一视觉。它也缺少 dark mode、高对比度、Reduce Transparency、平台密度、状态色、交互状态、选中/禁用/加载/错误/空态的语义 token。
- 违反依据：UI 规范禁止大面积单一色相堆叠和卡片套卡片，要求颜色、字体、间距和圆角逐步进入设计 token；付费级规格要求设计系统必须有代码边界。
- 决策依据：如果不先补 token，后续页面优化会继续散落临时颜色、opacity、radius 和 shadow，形成样式债务。
- 优化方向：第一阶段设计系统底座应扩展 `LangoTraceDesign`：surface 层级、content tint、selection、focus ring、disabled、local mock、unavailable、external request warning、sync off、error、success、separator、platform density、panel width、control size、animation duration。避免直接引入复杂品牌系统，先服务产品对象状态。
- 复查方法：代码扫描页面中 raw `Color(red:)`、`.opacity(...)`、固定 corner radius、padding 魔法数；截图检查状态色不只靠 teal/gold；深色模式只在 token 映射和截图验证后标记支持。

### S-02：请求预览文案使用“即将发送”，与 Local Mock 不发送外部请求冲突

- 平台：shared
- 页面或组件：`RequestPreviewCard`
- 问题类型：能力边界 / 隐私边界
- 严重度：P1
- 代码证据：`RequestPreviewCard.sentContent` 返回“即将发送：...”，同时卡片下方显示 `requestPreview.notSent` 和 `requestPreview.localMock`。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`，`RequestPreviewCard`
- 问题描述：当前阶段不会发起真实 AI 请求，但“即将发送”会让用户误以为打开详情或预览已经准备外发内容。虽然后文写 Local Mock，但同一卡片内同时出现“即将发送”和“不发送”会降低隐私可信度。
- 违反依据：AI Provider 与隐私规范要求敏感内容只有用户明确触发时才发送；请求预览应让用户理解即将发送的内容类型。付费级规格要求 Local Mock 不得使用容易被理解为真实能力完成的文案。
- 决策依据：这是隐私边界 P1。产品的本地优先信任不能通过后续小字解释来修正前面的误导词。
- 优化方向：将请求预览拆成两种状态：`localMockPreview` 显示“真实接入后会请求确认的内容范围，当前不会发送”；`externalRequestPreview` 只在用户明确触发真实 Provider 时使用“将发送”。增加 `RequestPreviewState` 或枚举，避免文案由 `rendering != nil` 隐式决定。
- 复查方法：代码检查不再在 mock 状态显示“即将发送”；手动进入 Entry detail、Practice、Mac Inspector 确认文案一致；后续真实 AI 实现时增加状态测试。

### S-03：Data 层承载大量中文 UI chrome，违反国际化和展示边界

- 平台：shared
- 页面或组件：`InMemoryLearningContentRepository`，`LearningContentModels`
- 问题类型：工程结构 / 本地化
- 严重度：P1
- 代码证据：`LearningEntry.sourceTitle` 返回中文展示名；`createEntry` 写入“新的生活记录”“今天”“练习 1 组”；`settingsCapabilities` 写入中文 summary/detail/nextRequirement；`makeMockRendering` 写入中文 promptLabel 和 note。
- 涉及路径：`Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`；`Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- 问题描述：Data package 可以提供 mock 内容和稳定业务状态，但不应成为 App chrome 的中文文案来源。当前 UI 中部分设置能力已通过 String Catalog 本地化，但 Data 层仍输出大量用户可见中文。后续扩展英文和其他界面语言时，会出现 UI 语言、用户内容语言和 mock 数据说明混杂。
- 违反依据：`docs/guidelines/006-interface-localization-and-language-boundaries.md` 强制要求 Data / Core 层可以提供稳定 kind、状态、业务语义和 mock 内容，但 UI chrome 必须由 UI 层 String Catalog 或等效本地化资源渲染。
- 决策依据：这不是翻译润色，而是架构边界问题。Data 层文案会让设置、状态、错误和 unavailable 难以本地化，也会混淆用户生成内容与界面 chrome。
- 优化方向：把 `sourceTitle` 改为稳定 `EntrySource` kind，由 UI 层映射本地化标题；`SettingsCapability` 保留 kind/status/nextRequirementKey 或 stable semantic payload；mock 用户内容可以保持特定语言，但 UI 状态说明迁到 `Localizable.xcstrings`。
- 复查方法：代码扫描 `Packages/LangoTraceData` 中用户可见中文；英文界面运行截图检查 chrome 不混入中文；Core/Data 单元测试验证 stable kind 而非展示字符串。

### S-04：通用组件大量使用同一种 `langoPanel`，卡片密度和层级缺少产品对象差异

- 平台：shared
- 页面或组件：`EntryTimelineRow`、`SentencePairView`、`CapabilityStatusRow`、`CompactPanel`、`TextPanel`
- 问题类型：视觉系统 / 组件状态
- 严重度：P2
- 代码证据：`EntryTimelineRow`、`SentencePairView`、`CapabilityStatusRow`、`TextPanel` 等都落到 `langoPanel` 或相似浅色面板；`CapabilityStatusRow` 状态色只区分 ready/mockOnly/unavailable。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`；`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- 问题描述：组件已经按产品对象命名，这是好方向；但视觉层级仍接近“所有东西都是卡片”。Entry、SentencePair、RequestPreview、Capability、Memory、Unavailable 应有不同密度和状态模型，否则页面会像素材面板集合。
- 违反依据：UI 规范不鼓励卡片套卡片，要求组件优先表达产品对象而不是抽象样式；规格要求设计系统服务产品对象。
- 决策依据：付费级感知来自信息层级和状态成熟度。统一卡片能快速闭环，但不能承载长期产品质量。
- 优化方向：为产品对象定义组件样式：Entry timeline row 更轻，SentencePair 更偏阅读和练习，RequestPreview 更偏隐私边界，CapabilityStatus 更偏设置/能力，Unavailable 更偏状态页。减少卡片嵌套，增加分组、列表、Inspector section 和 toolbar 状态。
- 复查方法：样板页截图检查每种组件的视觉职责；代码扫描是否所有组件仍无差别调用 `langoPanel`；VoiceOver 检查组件语义不重复。

### S-05：多数页面仍有硬编码中文文案，String Catalog 覆盖不完整

- 平台：shared
- 页面或组件：多数 SwiftUI view
- 问题类型：本地化 / 工程结构
- 严重度：P2
- 代码证据：`TodayView`、`PadSidebarView`、`MacMainView`、`MacWorkspaceContentView`、`MacInspectorContent`、`UnavailableCapabilityView` 中存在大量 `Text("中文")`、`Button("中文")` 和中文 accessibility label。部分 Tab 和设置详情已使用 `localizedText`。
- 涉及路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`；`PadMainSections.swift`；`MacMainView.swift`；`MacWorkspaceContentView.swift`；`MacInspectorContent.swift`；`UnavailableCapabilityView.swift`
- 问题描述：当前是 MVP 早期，但本轮目标是付费级 UI 审查。硬编码中文会阻碍英文基础发行语言和未来多语言布局验证，也难以做伪本地化与 Dynamic Type 截图。
- 违反依据：界面国际化规范要求新增或改进页面时考虑英文、简体中文和更长语言长度，UI chrome 迁入 String Catalog。
- 决策依据：语言学习 App 的目标市场和产品定位天然要求多语言意识。本地化不是发布末期附加项，会直接影响布局、按钮长度和平台质量。
- 优化方向：样板页面先完成 String Catalog 覆盖，建立术语 key 和注释；暂时保留用户 mock 内容的中文/英文混合，但所有 chrome、状态、按钮、accessibility label 迁入 UI package 资源。
- 复查方法：`rg 'Text\\(\"|Button\\(\"|Label\\(\"' Packages/LangoTraceUI/Sources/LangoTraceUI` 抽查；英文和简体中文截图；长语言或伪本地化 smoke。

### S-06：Mock 创建记录会自动生成 rendering、practice 和 memory，可能混淆真实生成边界

- 平台：shared
- 页面或组件：`InMemoryLearningContentRepository.createEntry`
- 问题类型：能力边界 / 工程结构
- 严重度：P2
- 代码证据：创建记录后立即写入 mock rendering、practice item 和 memory item，且 `practiceSummary` 为“练习 1 组”。
- 涉及路径：`Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`，`createEntry`
- 问题描述：当前页面闭环需要 mock 自动生成，这是可接受的早期资产。但付费级 UI 中必须更清楚地区分“保存原始记录”和“生成学习材料”。否则用户会以为新建记录已经完成真实 AI 转换和提取。
- 违反依据：AI Provider 规范要求 AI 输出不能直接覆盖用户原文，Prompt 与 Provider 边界要可理解；付费级规格要求 Local Mock 状态可信。
- 决策依据：这会影响用户对本地优先和 AI 请求的信任。真实能力接入前，自动 mock 生成应作为 demo 明确表达，而不是默默发生。
- 优化方向：在 UI 层把创建记录后的状态表达为“已本地保存，已生成本地示例学习材料”；后续真实实现拆分保存 Entry 和显式请求生成 Rendering 两个动作。Data 层 mock 可以保留，但 UI 必须标注 Local Mock。
- 复查方法：新建记录手动路径验证；详情页和练习页均显示 Local Mock 且不使用“已生成真实内容”语气；后续真实 AI 接入时加入 request preview 确认。

## 8. 设计系统补强建议

### 8.1 Token

第一阶段建议补强 `LangoTraceDesign`，但保持克制，不创建庞大品牌系统。

建议新增或重组：

- Surface token：`surfaceCanvas`、`surfaceSidebar`、`surfacePanel`、`surfaceInspector`、`surfacePopover`、`surfaceSelected`。
- Text token：`textPrimary`、`textSecondary`、`textTertiary`、`textOnAccent`、`textLink`。
- Border token：`separator`、`panelBorder`、`focusRing`、`selectedBorder`。
- State token：`stateReady`、`stateLocalMock`、`stateUnavailable`、`stateExternalRequest`、`stateSyncOff`、`stateWarning`、`stateError`、`stateSuccess`。
- Platform density：iPhone page padding、iPad sidebar width、iPad inspector width、Mac sidebar width、Mac inspector width、compact control height。
- Motion token：panel transition duration、micro feedback duration，并受 Reduce Motion 控制。
- Accessibility token：minimum touch target、focus outline width、高对比度 fallback。

### 8.2 组件

优先沉淀产品对象组件：

- `LanguageSpaceSwitcher`：当前可以只做单空间 unavailable，但结构应支持空间选择和当前空间状态。
- `EntryTimelineRow`：表达来源、场景、练习状态、选中态和最近活动。
- `EntryDetailHeader`：统一记录标题、来源、场景、保存状态和语言方向。
- `SentencePairView`：分 iPhone 单列、iPad/macOS 宽布局，明确当前句和练习入口。
- `PracticeControlBar`：区分 mock、真实播放、录音、听写和完成状态。
- `RequestPreviewCard`：拆分 Local Mock preview 与真实 external request preview。
- `MemoryItemRow`：显示词句、来源记录、是否已确认、复习状态。
- `PrivacyStatusPopover`：iPad 和 macOS 可使用 popover / inspector，iPhone 使用 sheet 或设置详情。
- `CapabilityStatusBadge`：统一 ready、Local Mock、未配置、未启用、不可用、需要确认。
- `UnavailableStateView`：替换通用说明堆叠，包含标题、当前边界、下一步、不会发生。

### 8.3 状态

必须形成统一状态表达：

- 空态：没有语言空间、没有记录、没有 rendering、没有可练习句子、没有记忆项。
- 不可用态：照片、录音、OCR、同步、导出、StoreKit、真实 AI 未接入。
- 未配置态：AI Provider 未配置，这是正常状态，不是错误。
- 未启用态：同步未启用，这是正常状态，不是失败。
- Local Mock：明确“不会发送外部请求，不访问 Keychain，不写真实数据库”。
- 请求预览：只有用户触发真实 Provider 时才使用“将发送”。
- 加载/运行/失败/取消：为真实 AI、TTS、OCR、Speech、Sync 预留，不在 mock 中伪装完成。

### 8.4 Local Mock、AI Provider、同步状态

- Local Mock 应使用独立 badge 和文案，不与 ready 共享绿色/成功语义。
- AI Provider 未配置使用 `sparkles`，状态为“未配置”，说明“配置前不会发送外部请求”。
- 同步未启用使用 `arrow.triangle.2.circlepath`，状态为“未启用”，说明“当前只保存在本机或内存 preview”。
- 不把 AI 和同步合并为“本地优先”一个模糊状态；它们是不同配置边界。
- 设置能力 row、请求预览、Unavailable 页面和 Inspector 使用同一状态词汇。

## 9. 第一批样板页面建议

### 9.1 iPhone：Today + Entry Detail

选择原因：

- 覆盖最高频路径“今天记录一点生活”。
- 能验证单主 CTA、记录保存、最近记录、记录详情、双语对照、逐句练习和 Local Mock 状态。
- 能暴露小屏、Dynamic Type、键盘、sheet、Tab 和 NavigationStack 返回问题。

样板目标：

- Today 首屏只有一个主动作。
- Entry Detail 使用 iPhone 单列逐句学习结构。
- Request Preview 在 mock 状态不使用“即将发送”。
- 所有 chrome 迁入 String Catalog。

### 9.2 iPad：三栏学习桌面

选择原因：

- iPad 是最能体现 LangoTrace 工作台价值的平台。
- 覆盖时间线、主记录、目标语言、逐句学习、右侧学习面板、左右面板收起和 Stage Manager 尺寸变化。
- 能验证设计 token、面板层级、边缘手势和触控/指针/键盘共存。

样板目标：

- 中间主区成为视觉焦点。
- 右侧学习面板跟随当前记录或当前句显示真实状态。
- compact / Split View / Stage Manager 有可测试降级规则。
- 搜索和导入导出等未接入能力有明确 unavailable 入口。

### 9.3 macOS：主工作台 + Inspector

选择原因：

- Mac 应体现个人语言资料库和生产力工具感，不能只是 iPad 放大版。
- 覆盖 Sidebar、Toolbar 候选、主内容、Inspector、设置能力、窗口缩放和键盘焦点。
- 能验证未来菜单栏、快捷键、Settings scene 和 Command Palette 的边界。

样板目标：

- Today 首屏聚焦当前记录和学习状态。
- Inspector 显示 Entry metadata、Request Preview、Memory Candidates、Practice State 和能力边界。
- Toolbar 承载新建、搜索、Sidebar/Inspector toggle 候选。
- 最小窗口优先保留主内容。

## 10. 分阶段优化方案

### 10.1 第一阶段：设计系统底座

工作内容：

- 补强 `LangoTraceDesign` 的 surface、state、density、motion 和 accessibility token。
- 定义 `CapabilityStatusBadge`、`UnavailableStateView`、`RequestPreviewState`、`EntryDetailHeader`、`MemoryItemRow`。
- 收敛 Local Mock、AI Provider 未配置、同步未启用、不可用、空态、错误态的文案和图标。
- 把样板页面所需 chrome 迁入 String Catalog。

验收：

- 样板页不再新增散落 raw color、opacity、radius 和 padding。
- Mock / unavailable / not configured / off 状态在三端语义一致。
- 文案支持英文和简体中文，不依赖中文短标签。

### 10.2 第二阶段：三端样板页面

工作内容：

- iPhone 重做 Today + Entry Detail 样板。
- iPad 重做三栏学习桌面样板。
- macOS 重做主工作台 + Inspector 样板。
- 每个平台只改样板路径，不全量铺开。

验收：

- 每端至少一套截图覆盖默认尺寸、窄尺寸、英文、简体中文和较大 Dynamic Type 或等效文本压力。
- 样板页面清楚表达生活记录来源、目标语言内容、练习入口、Local Mock 或请求预览状态。
- 没有真实能力误导。

### 10.3 第三阶段：页面推广

工作内容：

- 将样板组件推广到记录、练习、记忆、设置、unavailable、request preview 和 footer 状态。
- 移除重复卡片样式和临时说明面板。
- 将 Data/Core 中的 UI chrome 迁到 UI 本地化资源。

验收：

- 主要页面共享同一状态语言，但保持 iPhone / iPad / macOS 平台差异。
- `Packages/LangoTraceData` 不再输出设置能力 UI 说明文案。
- 入口、空态和 unavailable 页面都有可见结果。

### 10.4 第四阶段：质量验证

工作内容：

- 运行 `scripts/verify.sh`。
- 增加 iPhone、iPad、macOS 样板截图检查。
- 抽查 VoiceOver label、键盘焦点、Dynamic Type、Reduce Motion 和深色模式边界。
- 根据截图结果回写 worklog 和必要的 guideline。

验收：

- 构建和 package test 通过。
- 截图无明显溢出、重叠、主动作丢失或平台形态错误。
- 深色模式只有在 token 映射和截图验证完成后才写入“已支持”。

## 11. 风险清单

- 真实能力与 Mock 混淆：新建记录会自动生成 mock rendering/practice/memory，必须持续标注 Local Mock。
- 隐私边界：请求预览不能在 mock 状态使用“即将发送”；真实 Provider 接入前不能让打开页面像触发外发请求。
- 平台尺寸：iPhone 小屏、iPad Split View / Stage Manager、Mac 半屏窗口都可能暴露布局硬编码。
- 语言本地化：大量中文硬编码会阻断英文基础发行和长文本布局验证。
- 样式债务：如果不先补 token，后续页面会继续散落颜色、阴影、圆角和 padding。
- 过度重写：当前仍是早期资产，可以重写，但应按样板页面推进，避免一次性改动三端全部页面导致验证不可控。
- 平台原生感倒退：追求跨端一致视觉时，容易把 Mac 做成 iPad 放大版，或把 iPad 做成 iPhone Tab 放大版。
- 文档与代码分离：如果设计结论不及时回写 worklog / guideline，后续实现会再次回到主观“美化”。

## 12. 本轮不进入实现的内容

本轮明确不处理：

- 不修改 SwiftUI 代码。
- 不调整 `project.yml`、Swift Package、资源文件或 Xcode 工程。
- 不接入真实 SQLite / GRDB、AI Provider、Keychain、TTS、Speech、OCR、Photos、Sync、StoreKit。
- 不建立完整品牌手册。
- 不做全量视觉重写。
- 不承诺深色模式已经支持。
- 不创建新的 ADR；本轮没有改变核心产品决策，只形成 UI 审查和后续优化方案。

## 13. 文档影响检查

- `docs/guidelines/003-ui-design-system.md`：本轮发现 token、状态和组件边界需要补强，但建议在第一阶段实现计划中定向更新，不在本轮直接修改 Accepted guideline。
- `docs/guidelines/006-interface-localization-and-language-boundaries.md`：当前规范足够，问题来自代码未完全执行规范；不需要本轮修改。
- `docs/review/`：本轮是专项 UI 审查方案，不触发数据库、AI Provider、权限、同步、StoreKit、XcodeGen、包边界或 App 启动结构专项审查。
- `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`：本轮审查结果符合该规格，不需要修改规格。

## 14. 验证计划

本轮是文档审查任务，按用户要求完成后运行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

本轮不运行 `scripts/verify.sh`，因为没有修改 Swift、XcodeGen、Package 或资源文件。

## 15. 验证结果

2026-05-18 已运行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

结果：

- `find docs -maxdepth 3 -type f | sort` 已确认本 worklog 位于 `docs/worklogs/2026-05-18-feature-premium-ui-audit.md`。
- 占位词扫描无命中；`rg` 返回 exit 1，表示没有匹配项。
- `git diff --check` 通过。
- `git status --short` 显示当前仅有文档层改动：`docs/superpowers/specs/README.md` 已修改，`docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`、`docs/worklogs/2026-05-18-chore-premium-ui-principles-review-plan.md` 和本 worklog 为未跟踪文件。
- 本轮未运行 `scripts/verify.sh`，因为没有修改 Swift、XcodeGen、Package 或资源文件。
