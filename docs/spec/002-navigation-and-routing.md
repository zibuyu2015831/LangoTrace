# 002：导航与路由规范

状态：Accepted

适用阶段：工程初始化前、SwiftUI App Shell、MVP 早期开发。

## 1. 适用范围

本文档规定语迹 LangoTrace 的导航、路由、语言空间上下文、首次启动路径和三端页面组织方式。

## 2. 当前结论

语迹的导航应围绕“语言空间中的生活记录与学习闭环”展开，而不是围绕账号中心、Project 管理或后台配置展开。

当前语言空间是全局学习上下文。首次启动是状态路由。设置是低干扰系统配置入口。iPhone、iPad、macOS 应共享核心状态，但采用不同导航形态。

## 3. 强制规则

- 首次启动不默认创建语言空间。
- 首次启动必须先询问母语、目标语言和当前水平，再创建第一个语言空间。
- 首次启动不要求用户选择数据目录。
- 面向用户不使用 Project 作为核心概念。
- 一级导航不使用“我的”。
- iPhone 一级入口使用 `记录 / 阅读 / 练习 / 记忆` 四个主目的地；设置通过 toolbar gear、语言空间摘要或二级配置 route 稳定可达，不作为底部 Tab 与主学习流程并列。
- “单词”不作为一级入口，词、短语和句子统一归入“记忆”。
- 每条记录、练习、词句记忆和 AI 生成内容都必须能回到所属语言空间。
- 设置入口必须稳定可达，但不应抢占记录和学习主流程。
- 深层页面如果进入 Entry、Rendering、MemoryItem 或 PracticeSession，必须携带或恢复 `space_id` 上下文。
- 外部入口进入 App 时，如果无法确定语言空间，必须先进入语言空间选择或恢复最近使用空间，并给用户明确上下文。
- 任何会创建主数据的路由，都不能在缺少语言空间上下文时执行写入。

## 4. 默认推荐

### 4.1 首次启动

推荐路径：

1. 选择母语。
2. 选择目标语言。
3. 选择当前水平。
4. 确认并创建第一个语言空间。
5. 进入“记录一点生活”。

AI Provider、同步、词典、导出和目录选择不应成为首次启动门槛。

当前水平使用 A1-C2 作为内部和可见等级代码，但不得只裸露 `A1 / A2 / B1 / B2 / C1 / C2`。iPhone、iPad 和 macOS 的 onboarding 都应展示等级代码、自然名称和一句话说明；控件应支持滚动、动态字体和无障碍选中态。字段标题使用“当前水平”，避免让用户误以为需要完成测验。

### 4.2 iPhone

推荐导航：

```text
底部 Tab：记录 / 阅读 / 练习 / 记忆
顶部轻量上下文：英语（仅目标语言；完整母语 -> 目标语 · 等级作为无障碍 value）
Toolbar：设置 gear、必要的记录动作或语言空间摘要入口
```

定位：

- 随手记录。
- 本地阅读资料库和选区学习。
- 拍照引导写作。
- 碎片听读和跟读。
- 快速复习。

### 4.3 iPad

推荐导航：

```text
顶部全局条：辅助面板切换 / 搜索 / 学习面板切换
主体三栏：可收起时间线或筛选 / 写作与双语正文 / 可收起学习面板
左侧 Sidebar 底部：当前语言空间 / 设置 / AI Provider 状态 / 同步状态
```

定位：

- 沉浸写作。
- 双语对照。
- 分句练习。
- 图片和手写文章学习。

### 4.4 macOS

推荐导航：

```text
主区顶部或 Toolbar：Sidebar 切换 / Inspector 切换 / 命令搜索
Sidebar 底部：当前语言空间 / 设置 / AI Provider 状态 / 同步状态
主体：可隐藏 Sidebar / 主编辑区 / 可隐藏 Inspector
辅助：Command Palette、多窗口、菜单栏、快捷键
```

定位：

- 语言资料库。
- 批量导入导出。
- Prompt 管理。
- 同步和 Provider 高级配置。

macOS 应提供原生 `Settings` scene，并通过菜单命令或 `Cmd+,` 打开通用设置。New Entry、Search、Toggle Sidebar、Toggle Inspector 等高频工作台动作应有菜单或快捷键镜像；真实搜索未接入时，搜索命令只能打开明确的 unavailable / local mock 状态，不能伪装成已完成搜索能力。

### 4.5 路由类型

推荐把路由分为四类：

- 启动状态路由：首次启动、缺少语言空间、正常进入 App。
- 主流程路由：记录、阅读、练习、记忆、记录详情和阅读详情。
- 配置路由：设置、AI Provider、同步、导入导出、购买恢复。
- 临时任务路由：请求预览、权限解释、OCR 校对、听写结果、同步冲突处理。

主流程路由应优先保持当前语言空间。配置路由可以进入全局设置，但如果配置项归属于某个语言空间，需要明确显示当前空间。

MVP 早期的配置路由可以先做只读说明页。AI Provider、同步、本地数据、隐私和导出在真实实现前必须显示 mock 或 unavailable 状态，不能在没有 Keychain、网络、数据库或同步引擎接入时提供会产生真实副作用的入口。

### 4.6 Sheet、Modal 与 Inspector

推荐使用边界：

- Sheet：短流程任务，例如选择 Prompt Preset、确认请求预览、编辑标签。
- Modal：阻断性任务，例如首次启动关键步骤、同步冲突确认、不可恢复删除确认。
- Inspector：iPad 和 macOS 上承载解释、词句、请求预览、练习状态和元数据。
- Popover 或 Menu：语言空间切换、更多操作、排序筛选。

不要把长时间写作、完整练习或复杂设置塞进小型 Sheet。

Sheet 是否需要标题取决于承载职责，而不是取决于它是不是 `.sheet`：

- 任务型 sheet 需要标题：创建、编辑、重命名、配置、选择对象、权限解释、同步草稿等有明确对象或流程边界的 sheet，应使用 `NavigationStack`、`navigationTitle`、取消 / 保存或关闭操作，让用户知道正在处理哪个对象。
- 状态反馈 sheet 不使用页面式标题：保存结果、Provider 测试结果、导出结果、同步运行结果等反馈面板，应使用状态 chrome 或中性面板标题表达操作上下文，不再叠加一个导航标题。running / testing 可以使用居中状态标题；完成态不应把 succeeded / failed / partial / cancelled 这类一次性 overall status 当作顶部标题。此类 sheet 可有 handle、右上关闭按钮、结果分组和底部恢复操作。
- 说明型 unavailable sheet 可以有标题，但标题应是能力名或状态名，不应伪装成已进入真实功能页面。
- 高频操作不应为了展示状态而打开 sheet，例如逐句播放、暂停、继续、练习步骤切换等应优先在原位反馈。

如果一个 sheet 同时像任务流程又像结果反馈，应优先拆分职责：流程用标题，结果用状态面板；不要在同一顶部同时出现系统导航标题、面板内大标题和状态图标。

### 4.7 辅助面板展开状态

iPad 和 macOS 的左右辅助面板属于主工作区的可召回上下文，不属于业务路由。

推荐边界：

- iPad 左侧时间线 / 筛选和右侧学习面板必须可以手动收起或展开。
- macOS Sidebar 和 Inspector 必须可以手动显示或隐藏。
- 中间写作、双语正文和练习内容始终是主工作区，面板收起后应优先获得空间。
- iPad 右侧学习面板是当前 route 的上下文面板，不是始终绑定 selected entry 的固定面板；只有记录、练习和工作台学习上下文才展示当前句子、词句提取和请求预览。设置、记忆、导入导出和语言空间 route 应展示对应的低干扰上下文。
- 面板展开状态属于瞬时 UI 状态，不进入语言空间模型、数据库、同步 manifest 或对象存储。
- 当前阶段不持久化面板展开状态；后续若要记住用户偏好，应单独设计设备级、窗口级和语言空间级偏好边界。
- iPad 主要通过触控友好的顶部图标按钮切换。
- macOS 可以先提供顶部区域或 Toolbar 图标按钮，菜单栏命令和快捷键应在 Mac 产品级 UI 优化中确认冲突后再落地。

### 4.8 语言空间与设置入口

语言空间是当前记录、练习、记忆和 AI 生成内容的全局学习上下文，不是与“记录 / 练习 / 记忆”并列的高频主导航。

推荐边界：

- iPhone 在页面顶部以轻量控件显示当前语言空间的**目标语言**（例如 `英语`），不渲染描边 / 填充，靠低对比与下拉指示提示可点；完整 `母语 -> 目标语 · 等级`（例如 `中文 -> 英语 · B1`）作为无障碍 value 保留。一门空间只对应一门语言，目标语言已能唯一标识当前空间，等级是少变的水平自评、不进顶部控件。点击后优先打开快速切换 sheet，支持查看当前空间、切换 active 空间、添加学习语言，并提供进入完整管理页的次级入口。
- iPhone 的设置页语言空间入口已进入真实管理页：展示当前空间和 active 空间列表，支持新增、切换、重命名和删除。顶部语言空间入口不得退回只读 summary；它是当前学习上下文的轻量切换入口，不替代设置页的完整管理页。
- iPad 和 macOS 的 Sidebar footer 语言空间入口、设置列表语言空间 row，以及 macOS 原生 `Settings` scene 的语言空间 row，均应进入完整语言空间管理页，而不是只读 summary。管理页共享新增、切换、编辑、删除语义；平台外壳只负责主区、Settings scene 或桌面右键菜单等原生承载。
- 语言空间管理 UI 可通过命名和管理页结构鼓励一门学习语言使用一个空间，但新增 / 编辑表单不应为同目标语言多空间显示 warning；重复目标语言允许创建，不能在 Data 层禁止。
- iPad 默认把当前语言空间、AI Provider 状态、同步状态和设置入口放在左侧 Sidebar 底部；AI、同步、设置三个图标应在语言空间标题行右侧同组呈现，顶部全局条优先服务当前任务，不再重复放置设置齿轮。
- macOS 默认把当前语言空间、AI Provider 状态、同步状态和设置入口放在 Sidebar 底部；AI、同步、设置三个图标应在语言空间标题行右侧同组呈现，主区顶部或 Toolbar 优先服务工作台操作。
- iPad 和 macOS 的 Sidebar 收起时，语言空间和设置入口可以跟随隐藏；稳定可达由 Sidebar 显示按钮保证。
- 当前阶段不要求语言空间和设置入口始终占据顶部；iPad 顶部右侧应优先保留右侧面板切换和新建记录等工作台动作。
- macOS `Settings...` / `Cmd+,` 是通用偏好入口；Sidebar 底部 gear 是当前工作台中的低频配置入口；AI / Sync 图标表达能力状态或配置详情，不应与 gear 表现成三个等价设置按钮。

### 4.9 页面闭环阶段路由边界

页面闭环阶段的目标是让三端所有一级入口、明显按钮和关键二级路径都有可见结果。可见结果可以是真实页面、Local Mock 页面、sheet、popover、Inspector 内容或 unavailable 说明，但不能留下空 action。

推荐边界：

- iPhone 保持 `记录 / 阅读 / 练习 / 记忆` 四个主 Tab。记录 Tab 合并原“今日”和“记录”的职责，首屏主动作是记录生活，次级内容是最近记录、当前 Entry 状态和必要的本地能力边界；阅读 Tab 承载当前语言空间的本地阅读资料库、搜索、粘贴导入、打开、软删除 / 恢复、选区解释和显式句子 TTS。短说明使用 sheet，不新增会干扰系统返回手势的全屏横向手势。
- iPad 不使用放大的 iPhone Tab；regular width 保持工作台三栏，详情、练习和设置优先由中间主区或右侧学习面板承载。
- iPad 在 compact width、Split View、Slide Over 或 Stage Manager 窄窗口下，优先保证主内容可读，时间线和学习面板可以自动或手动收起。
- macOS 不使用移动端 Tab；使用 Sidebar selection、主工作区和 Inspector 承载页面状态。
- macOS 的 Settings scene、菜单命令和关键快捷键属于当前页面闭环后的基础桌面外壳；Command Palette、多窗口和批量管理仍属于后续 Mac 工作台阶段。任何未接入真实能力的命令必须打开明确 unavailable / local mock 状态。
- route、section、filter、sheet 和面板展开状态属于 transient UI state，不进入语言空间模型、数据库、同步 manifest 或启动恢复。
- 任何 Local Mock 或 unavailable 页面都必须说明当前边界、后续接入条件和不会发生的副作用。

## 5. 可演进部分

- iPad 是否使用两栏或三栏，可根据可用屏幕宽度调整。
- Mac 是否默认显示 Inspector，可根据窗口尺寸和任务场景调整。
- iPad / macOS 是否自动根据窗口宽度收起辅助面板，后续在响应式布局设计时单独明确。
- 全局搜索是否跨语言空间，可以在实现搜索功能时进一步明确。
- Share Extension、Spotlight、Shortcuts、Widget 等外部入口后续单独设计。
- 多窗口是否允许同时打开不同语言空间，后续在 macOS 实现时单独明确。

## 6. 反例

不应这样做：

- iPhone 首页先显示设置、同步或 Provider 配置。
- 把多个语言空间做成左侧堆叠卡片，导致页面像后台管理系统。
- 用“我的”承载设置、购买、词库和语言空间。
- 在没有语言空间上下文时直接创建记录。
- 让工作空间、生活空间、旅行空间成为顶层导航。

## 7. AI 开发提示

开发任何导航、页面路由、Tab、Sidebar、Toolbar、Sheet、Modal 或深链能力前，必须先读取本文档。

如果需要新增路由，先回答：

- 这个路由属于哪个语言空间？
- 它是主流程、设置流程还是临时任务？
- 在 iPhone、iPad、macOS 上是否需要不同呈现？
- 它是否会触发权限、AI 请求、同步或密钥访问？
- 它是启动状态路由、主流程路由、配置路由还是临时任务路由？
- 它是否适合 Sheet、Modal、Inspector、Popover 或完整页面？

## 8. 官方参考

以下 Apple 官方文档是本规范导航与承载约束的依据来源（链接于 2026-06-11 验证可达；若失效，以 HIG 站内检索对应主题为准）：

- [HIG · Navigation and search](https://developer.apple.com/design/human-interface-guidelines/navigation-and-search)：层级导航、平铺导航与搜索入口的组织原则。
- [HIG · Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)：Tab 数量克制、目的地命名和不把动作放入 Tab 的官方约束；对应 iPhone 四 Tab 规则。
- [HIG · Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)与[HIG · Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)：iPad / macOS 工作台的侧栏与工具栏语义。
- [HIG · Modality](https://developer.apple.com/design/human-interface-guidelines/modality)、[HIG · Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)与[HIG · Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers)：模态边界、sheet detent 和 popover 适用场景；对应本文档 4.6 节。
- [HIG · Searching](https://developer.apple.com/design/human-interface-guidelines/searching)：搜索体验组织；后续搜索能力接入时对照。
- [HIG · Settings](https://developer.apple.com/design/human-interface-guidelines/settings)：设置入口低干扰、不抢占主流程的官方原则。
- [HIG · The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)：macOS 菜单命令组织与快捷键镜像。
- [SwiftUI · NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)与[SwiftUI · NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)：当前路由实现的框架 API 入口。

## 9. 变更记录

- 2026-05-17：创建第一版导航与路由规范。
- 2026-05-17：补充路由类型、外部入口和 Sheet/Modal/Inspector 使用边界。原因：避免后续 AI 在页面承载方式上发散。影响范围：导航、路由、平台交互。是否需要 ADR：否。
- 2026-05-17：补充 iPad / macOS 辅助面板展开状态规范。原因：已落地可收起时间线、学习面板、Sidebar 和 Inspector，需要明确其属于瞬时 UI 状态而非业务路由或同步数据。影响范围：iPad、macOS 导航和布局状态。是否需要 ADR：否。
- 2026-05-19：移除 iPad 顶部重复设置入口，并明确右侧面板切换属于顶部最右侧工作台控制。原因：设置入口已在左侧语言空间底部区稳定存在，顶部齿轮会和右侧面板控制形成重复低频入口。影响范围：iPad 顶部工具栏、左侧语言空间底部区。是否需要 ADR：否。
- 2026-05-19：补充 iPad 右侧学习面板 route-aware 约束。原因：设置 route 中继续展示 entry 请求预览会造成上下文冲突。影响范围：iPad 工作台右侧面板、设置页、记忆页、导入导出页和语言空间摘要页。是否需要 ADR：否。
- 2026-05-17：调整 iPad / macOS 语言空间和设置入口默认位置。原因：语言空间是低频但重要的学习上下文，应下沉到 Sidebar 底部，顶部保留给搜索、状态和面板切换等当前任务入口。影响范围：iPad、macOS 导航和设置入口。是否需要 ADR：否，已由语言空间 ADR 支撑。
- 2026-05-17：将 AI Provider 状态和同步状态统一收敛到 iPad / macOS Sidebar 底部。原因：顶部全局条应服务当前任务，AI 与同步是两个独立配置边界，不应以顶部常驻状态文案重复展示。影响范围：iPad、macOS 顶部工具栏和 Sidebar 底部状态区。是否需要 ADR：否，属于既有语言空间底部工具区规则细化。
- 2026-05-17：将 AI Provider、同步和设置三个图标并入语言空间标题行右侧。原因：三者均为当前空间的低频配置入口，同组呈现能降低底部工具区高度并保持页面简洁。影响范围：iPad、macOS Sidebar 底部工具区。是否需要 ADR：否。
- 2026-05-17：补充配置路由只读说明页边界。原因：设置与练习状态闭环阶段新增 iPhone 设置二级路由，但真实 Keychain、网络、数据库和同步引擎尚未接入，需要防止 mock 页面被误读为真实配置能力。影响范围：iPhone 设置路由和后续配置页实现。是否需要 ADR：否。
- 2026-05-17：补充三端页面闭环阶段路由边界。原因：新增 iPad 和 macOS 页面补全计划需要明确空 action、窄窗口、Mac command surface 和 transient UI state 的边界。影响范围：iPhone、iPad、macOS 页面闭环和后续设计优化。是否需要 ADR：否。
- 2026-05-18：同步第一轮 UI 收敛后的导航事实。原因：iPhone 顶层已从五 Tab 收敛为记录、练习、记忆三主目的地，设置降级为稳定可达的配置入口；macOS 已具备 Settings scene 和基础 commands；语言空间入口第一阶段应呈现 Space summary 而不是 unavailable 死路。影响范围：iPhone IA、iPad / macOS 底部工具区语义、macOS 命令面和后续语言空间生命周期方案。是否需要 ADR：否，未改变语言空间作为核心上下文的 ADR。
- 2026-05-20：补充三端 onboarding 当前水平规则。原因：A1-C2 裸露给新用户不够直观，已收敛为“当前水平”字段和解释性等级列表；iPhone、iPad、macOS 都不应回退为裸 segmented control。影响范围：首次启动、语言空间创建、界面文案和无障碍。是否需要 ADR：否，未改变语言空间模型或 A1-C2 数据模型。
- 2026-05-20：更新 iPhone 语言空间入口事实。原因：语言空间数据基础设施已接入 iPhone 设置页管理入口，原“只展示 Space summary / lifecycle 说明”的描述已过期。影响范围：iPhone 设置导航、语言空间管理页、无空间路由保护和后续 iPad/macOS 扩展。是否需要 ADR：否，延续语言空间核心模型和三端分平台 UI 决策。
- 2026-05-20：更新 iPad / macOS 语言空间入口事实。原因：语言空间管理从 iPhone 扩展到 iPad 工作台主区、macOS 工作台 Settings route 和原生 Settings scene，iPad / macOS 不再使用 summary-only route 作为管理入口。影响范围：iPad / macOS route、Sidebar footer、设置列表、macOS Settings scene 和 App Shell action 注入。是否需要 ADR：否，未改变语言空间核心模型或三端分平台 UI 决策。
- 2026-05-21：更新 iPhone 顶部语言空间入口事实。原因：顶部语言空间 pill 已从只读 summary sheet 调整为快速切换 sheet，支持切换 active 空间、添加学习语言和进入完整管理页。影响范围：iPhone 顶部语言空间入口、`PhoneSheet`、语言空间管理路径和页面清单。是否需要 ADR：否，未改变语言空间核心模型或多空间数据策略。
- 2026-05-23：补充 sheet 标题分类规则。原因：AI Provider 测试结果面板暴露了规范缺口，反馈型 sheet 不应误套任务型 sheet 的导航标题结构。影响范围：iPhone sheet、AI Provider 测试结果、保存 / 导出 / 同步结果面板和后续状态反馈。是否需要 ADR：否。
- 2026-05-24：补充状态反馈 sheet 完成态标题规则。原因：AI Provider 测试完成后将 `测试成功` 作为顶部标题不够稳重；完成态应以中性标题维持面板上下文，并把结果状态交给分项结果和可用操作表达。影响范围：AI Provider 测试结果、保存 / 导出 / 同步结果面板和后续状态反馈。是否需要 ADR：否。
- 2026-06-01：将阅读提升为一级学习入口。原因：Reading domain 已落地本地资料库、Markdown / 纯文本阅读、用户显式选区 AI 解释和 reading sentence TTS 纵向切片，三端导航需要把阅读作为正式学习场景而非隐藏入口。影响范围：PhoneRootTab、iPhone Tab、iPad workspace route、macOS workspace section、页面清单和 Reading spec。是否需要 ADR：否，未改变本地优先、语言空间或 SwiftUI Multiplatform 核心决策。
- 2026-06-11：新增官方参考小节。原因：导航、Tab、sheet、popover 和菜单约束需要可直接对照的 Apple 官方文档入口，降低后续开发检索成本；全部链接经可达性验证。影响范围：规范使用方式，不改变任何既有约束。是否需要 ADR：否。
- 2026-06-20：iPhone 顶部语言控件收敛为仅目标语言。原因：去边框克制化后用户反馈左右仍不够协调；一门空间只对应一门语言（核心决策 #4），目标语言已能唯一标识当前空间，等级是少变自评，顶部控件只显示 `英语` 即可，完整 `母语 -> 目标语 · 等级` 降为无障碍 value。§54 / §157 原写「例如 英语 · B1」为举例，去等级在示例范围内，已同步措辞。影响范围：iPhone 四 root tab 顶部语言 chip、`PhoneRootContextChrome.compactContext`、无障碍 value 与页面清单。是否需要 ADR：否，未改变语言空间核心模型或 A1-C2 数据模型。
