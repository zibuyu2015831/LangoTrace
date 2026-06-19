# 006：界面国际化与语言边界规范

状态：Accepted

适用阶段：MVP 早期开发、页面设计优化、SwiftUI 文案资源化、后续全球发行准备。

## 1. 适用范围

本文档规定语迹 LangoTrace 的 App 界面语言、用户母语、目标学习语言和 Provider / Prompt 输出语言之间的边界。它适用于后续所有 iPhone、iPad、macOS 页面设计、页面改进、设置入口、SwiftUI 文案资源、测试截图和发布材料。

本文档不直接规定某一种语言的最终翻译文案；具体翻译应在实现 String Catalog、术语表和本地化 QA 时逐步沉淀。

参考依据：

- Apple Developer Localization：国际化是面向全球用户构建 App 的基础步骤；iOS / iPadOS 支持用户为单个 App 选择偏好语言，macOS 可在系统设置的语言与地区中设置 App 语言。
- Apple Developer Localization：String Catalog 可用于翻译文本、处理复数和按设备变化文案；Xcode 可跟踪 SwiftUI 中的可本地化字符串并保持 String Catalog 同步。
- Apple Developer Localization：本地化测试应检查裁切、截断、布局重叠和从右到左格式问题；权限 purpose strings、隐私政策和 App Store 元数据也应纳入本地化范围。

## 2. 当前结论

语迹的产品愿景是支持任意语言学习，因此 App 必须从早期开始具备国际化意识。后续设计和改进页面时，不允许假设界面永远是中文，也不允许把目标学习语言当成 App 界面语言。

推荐产品原则：

> 界面语言、用户母语和目标学习语言是三条独立轴线。

推荐默认策略：

> App 默认跟随系统语言；当系统语言暂不支持时回退英文；用户可以在设置中主动覆盖为其他已支持界面语言。

英文应作为基础发行语言和 fallback 语言。简体中文应作为当前开发阶段的主要验证语言之一。第一批主流界面语言候选清单为 `en / zh-Hans / es / ja / fr / de / ko / ru`，分别对应 English、简体中文、Español、日本語、Français、Deutsch、한국어、Русский。小语种暂不进入第一批正式支持，但架构和布局不得阻断未来扩展。

产品和工程上需要区分两层能力：

- 系统级 App 语言：iOS / iPadOS / macOS 提供的 per-app language 偏好，适合控制整个 App bundle 的本地化资源和系统承载界面。
- App 内界面语言偏好：语迹自己提供的设置入口，适合控制 App 自有 SwiftUI 文案。若要做到不重启即时切换，必须单独设计 Locale 注入、系统控件边界和测试方案。

在没有完成 App 内即时切换方案前，设置页可以先表达当前语言策略，并引导用户理解系统级 App 语言和语迹内置偏好的关系，不能承诺所有系统弹窗、StoreKit sheet、权限弹窗都能被 App 内设置即时覆盖。

当前实现方向采用两者并存：

1. `System` 表示跟随系统语言或系统为语迹设置的 per-app language。
2. App 内显式选择 `English`、`简体中文` 或第一批候选语言时，只覆盖语迹自有 SwiftUI chrome。
3. App 内设置不修改系统 per-app language，不覆盖权限弹窗、StoreKit sheet、文件选择器、分享面板、系统键盘候选、第三方 SDK UI 或 Apple 服务 UI。
4. 如果系统 per-app language 在 App 运行中被修改，第一阶段只要求下次启动或重新激活后表现正确，不把监听系统设置变化作为基础能力。

实现边界补充：Swift Package 内的 `Localizable.xcstrings` 可以承载 package 自有 SwiftUI chrome，但不应被视为主 App bundle 已经完整支持对应系统级 App 语言。若产品文案声明系统 per-app language 可选择 `English / 简体中文 / Español / 日本語 / Français / Deutsch / 한국어 / Русский`，App target 也必须通过 `CFBundleLocalizations`、App target 本地化资源或等效配置声明这些语言，并在系统设置中验证。否则设置页只能说明“跟随平台当前语言偏好”，不能暗示系统设置一定会出现所有 App 内支持语言。

`System` 模式应以 Apple bundle localization 结果为准，优先使用 `Bundle.main.preferredLocalizations` 或等效结果与语迹支持语言清单求交集。显式语言模式通过 SwiftUI `locale` 环境和 UI 层本地化封装影响自有 chrome，不改变 `Bundle.main.preferredLocalizations`。

当前 UI 实现应使用显式 interface-language resolver：`System` 从 `Bundle.main.preferredLocalizations` 解析到受支持语言，显式偏好直接解析为对应 language code，并通过 SwiftUI environment 影响语迹自有 chrome。测试必须覆盖系统语言与 App 内显式语言不一致时，Tab、Settings、toolbar、unavailable 和状态组件使用显式偏好显示。

## 3. 语言概念边界

### 3.1 App 界面语言

App 界面语言用于显示导航、按钮、设置、空状态、错误状态、隐私说明、权限说明和本地功能文案。

示例：

- `Today`
- `Entries`
- `Practice`
- `Memory`
- `Settings`
- `AI Provider not configured`

界面语言不得随着用户切换语言空间而自动改变。

### 3.2 用户母语

用户母语用于记录原文、对照解释、学习讲解、语法说明和 AI 辅助理解。母语来自首次启动或后续语言偏好设置。

示例：

- 中文用户学习英语时，讲解可以使用中文。
- 英文用户学习日语时，讲解可以使用英文。

用户母语不得被界面语言覆盖。用户也可以选择界面为英文，但母语仍为中文。

### 3.3 目标学习语言

目标学习语言属于语言空间。一个语言空间对应一门目标语言，例如英语空间、日语空间或法语空间。

目标学习语言用于 AI 转换结果、TTS、跟读、听写、回译、词句记忆和练习内容。它不得决定 App 全局 UI 文案。

### 3.4 Provider / Prompt 输出语言

Provider / Prompt 输出语言是 AI 请求中的生成要求，例如：

- 目标语言文本使用英语。
- 讲解使用用户母语。
- 错误修改说明使用界面语言或用户母语。

Provider / Prompt 输出语言必须由请求构建层显式传入，不得从某个 UI 文案字符串反推。

AI Provider 配置页的 `语言支持` 合成测试也属于 Provider / Prompt 输出语言边界。该测试必须使用当前语言空间的稳定目标语言 code 作为上下文，由 AI 层 allowlist 派生 Prompt 英文语言名称、`NLLanguage` 映射和脚本规则；不得从 `LanguageSpacePreview.targetLanguage` 展示名、界面语言、本地化文案或用户母语反推 Provider 输出语言。

### 3.5 地区格式与语言

地区格式用于日期、时间、数字、货币、温度、长度单位、周起始日和日历显示。它与界面语言相关，但不能被简单等同。

示例：

- 用户界面语言是英文，但地区仍可能是中国大陆。
- 用户界面语言是简体中文，但日期、时区和货币可能跟随美国地区设置。

后续实现日期、统计、价格、StoreKit 展示、学习时长和同步时间时，应优先使用 Foundation 的格式化能力和系统 locale / region 设置，不得手写固定格式。

### 3.6 用户内容语言

用户输入、AI 生成结果、OCR 识别文本、目标语言句子、母语讲解和词句记忆是内容，不是 App chrome。它们应保留自身语言，不应因为用户切换界面语言而被翻译、重写或重新生成。

后续如果提供“重新生成为另一种讲解语言”，应作为显式 AI 动作，而不是界面语言设置的副作用。

### 3.7 静态演示内容语言

Welcome、空状态和教学型示例中的静态演示内容既不是 App chrome，也不是真实用户保存内容。它可以为了说明产品闭环而按界面语言选择一组受控示例，但必须明确自身是本地静态 demo。

Welcome 示例的语言边界：

- Section 标题、按钮、说明、badge 和导航等 chrome 继续使用当前界面语言。
- 示例中的 source note 表达用户熟悉语言里的生活线索，rewrite 表达目标学习语言中的可练习表达。
- 当前 Welcome 示例约定：简体中文界面使用中文 source note 到英文 rewrite；英文及其他第一批界面语言使用对应界面语言 source note 到中文 rewrite。
- 该约定只服务首次解释产品闭环，不代表真实默认目标语言、onboarding 默认值、语言空间目标语言或已保存用户内容。
- 切换界面语言不得重写真实 Entry、Rendering、Practice 或 Memory。只有静态演示内容可以通过 String Catalog 或明确 demo 数据模型维护多语言版本。
- 后续如果 Welcome 示例改为根据 onboarding 选择动态生成，必须先把“界面语言、用户母语、目标学习语言”三轴输入建模清楚，不能从界面语言反推目标语言。

## 4. 强制规则

- 后续新增或改进页面时，必须考虑文案在英文、简体中文和更长语言中的长度差异。
- 可见 UI 文案不得硬编码为只能服务单一界面语言的长期实现；早期 mock 文案若临时硬编码，必须在 worklog 或实现计划中明确迁移到 String Catalog 的时间点。
- 任何语言相关模型必须使用稳定 code，例如 `en`、`zh-Hans`、`ja`，不得使用展示名作为数据标识。
- 界面语言、用户母语、目标学习语言、TTS 声音语言、OCR 识别语言和 Prompt 输出语言不得共用一个字符串字段。
- 语言空间 preview 如果需要参与 Provider / Prompt 输出语言上下文，必须携带稳定 `targetLanguageCode`，展示名只能用于 UI 显示，不得作为 AI 请求事实源。
- 语言空间切换不得自动改变 App 界面语言。
- 用户修改 App 界面语言不得自动改变语言空间目标语言、用户母语或已生成学习内容。
- App 默认应跟随系统语言；系统语言未支持时回退英文。
- 设置中必须预留界面语言入口，至少能表达 `System / English / 简体中文`；进入主流语言扩展阶段后，应容纳 `Español / 日本語 / Français / Deutsch / 한국어 / Русский`，且不能使用只适合 3 项以内的横向 segmented control 作为唯一交互。
- 界面语言设置属于设备级或 App 偏好，不属于语言空间主数据；第一阶段不得写入语言空间模型、同步 manifest 或学习记录。
- iPhone、iPad、macOS 三端必须共享同一套界面语言偏好语义，但可使用各自平台合适的设置呈现方式。
- 页面设计不得依赖固定中文短标签；按钮、segmented control、tab、sidebar row 和 toolbar item 需要为长文本、截断、换行或图标辅助预留策略。
- Data / Core 层可以提供稳定 kind、状态、业务语义和 mock 内容，但不得把中文或英文展示说明当成可切换 App chrome 的唯一来源；设置能力说明、状态摘要、错误说明和不可用说明等 UI chrome 必须由 UI 层 String Catalog 或等效本地化资源渲染。
- Core 层不得提供 `ChineseUI` 这类面向单一界面语言的展示 helper。语言 code、母语和目标语言模型可以留在 Core；折叠值、自称名、辅助名和菜单项组合属于 UI 层 language display projection。
- AI 请求预览、隐私说明、权限说明和不可用能力说明必须使用当前界面语言展示，同时清楚说明会发送哪些目标语言或母语内容。
- App Store、TestFlight、权限提示和截图文案进入发布阶段时，必须与支持的界面语言清单保持一致。
- iOS / iPadOS / macOS 的系统级 App 语言设置与语迹 App 内界面语言偏好必须在设计中明确关系；不得假设 App 内一个 Picker 就能覆盖所有系统 UI、权限弹窗、StoreKit sheet 或第三方 Provider 错误。
- `System` 是偏好模式，不是一种语言；显式语言选择不得写入系统 per-app language，也不得承诺改变 bundle 级系统 UI。
- 日期、时间、数字、货币、单位和复数规则必须使用系统格式化或本地化资源能力，不得在 UI 中手写固定中文或英文格式。
- 新页面必须使用 leading / trailing、语义对齐和系统布局能力，避免把 left / right 写成不可翻转的业务含义；确有平台导航含义时，应在设计中说明。
- 即使第一阶段只支持英文和简体中文，也不得在组件结构上阻断未来从右到左语言、较长翻译文本或非拉丁文字。
- 混合语言内容需要考虑辅助功能朗读。后续显示目标语言句子、母语解释或发音内容时，应评估是否需要为可访问文本提供语言上下文，避免 VoiceOver 用错误语言朗读。
- 静态演示内容不得被真实学习内容规则误读，也不得反过来污染真实用户内容。Welcome demo 可以为了说明学习关系而跨语言展示，但真实 Entry、Rendering、Practice 和 Memory 必须保留内容自身语言，除非用户显式触发转换或生成。

## 5. 默认推荐

### 5.1 第一批语言范围

第一阶段已经完成英文和简体中文的最小国际化闭环。下一阶段建议把第一批主流界面语言候选明确为：

- 英文：基础语言和 fallback。
- 简体中文：当前开发验证语言。
- 西班牙语：主流国际市场语言，不作为小语种处理。
- 日语：重要付费 App 市场语言。
- 法语：覆盖欧洲、加拿大和多地区学习市场。
- 德语：重要欧洲市场语言，也是长文本布局压力测试语言。
- 韩语：重要移动 App 和语言学习市场语言。
- 俄语：覆盖广泛，可提前验证西里尔文字和长词断行。

这些语言进入候选清单不等于已经正式发布支持。正式开放前必须完成 String Catalog 资源、术语审校、三端布局验证、权限和发布材料检查。小语种暂不进入第一批，但新增语言时应沿用同一质量门槛。

### 5.2 设置入口

推荐设置项：

```text
Interface Language
System
English
简体中文
Español
日本語
Français
Deutsch
한국어
Русский
```

中文界面可显示为：

```text
界面语言
跟随系统
English
简体中文
Español
日本語
Français
Deutsch
한국어
Русский
```

设置说明应明确：

- 该设置只改变 App 界面。
- 不改变用户母语。
- 不改变当前语言空间的目标语言。
- 不改变已经生成或保存的学习内容。
- 系统级权限弹窗、StoreKit sheet、系统文件选择器和部分 Apple 服务 UI 可能遵循系统或 per-app language，而不是语迹自定义文案偏好。
- 如果当前版本尚未支持 App 内即时切换，应明确需要重启 App 或前往系统设置调整 App 语言。

界面语言选择页应以选择任务为主。完整边界说明属于规范、帮助或发布材料语义，不要求在选择页常驻展示；常驻 UI 可使用短脚注说明“仅影响 App 界面，不改变语言空间或已保存内容”。系统弹窗、StoreKit、文件选择器和第三方 UI 的边界不得被反向承诺，但也不应以长段落压过选择任务。

### 5.3 SwiftUI 资源策略

推荐使用 Apple String Catalog 作为 SwiftUI Multiplatform 的主本地化机制。

实现时应逐步做到：

- 当前主要 SwiftUI chrome 位于 `LangoTraceUI` package，因此首批 `Localizable.xcstrings` 放在 `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/`，并通过 Swift Package resources 打包。
- `LangoTraceUI` package 内 String Catalog 只管理 package 自有 SwiftUI chrome。App target、InfoPlist、App Intent、权限 purpose strings、StoreKit、本地通知、widget 或后续 extension 的用户可见文案，应在对应 target 或平台配置中单独本地化。
- package 内本地化查找必须显式使用 `Bundle.module` 或统一封装；`Button("...")`、`Label("...", systemImage:)`、`.navigationTitle("...")`、`.accessibilityLabel("...")` 这类便捷 API 不能直接替换为 key 后结束。
- 依赖 SwiftUI `locale` 环境即时切换的文案应优先保持为 `Text`、label builder 或其他环境感知 View。`String(localized:bundle:)` 会立即求值，只有在显式传入当前 resolved locale 或用于非即时刷新路径时才可使用。
- `project.yml` 的 `developmentLanguage` 与 String Catalog `sourceLanguage` 必须保持英文 `en`。
- 将导航、按钮、空状态、错误状态、设置项和能力说明迁入 String Catalog。
- 术语使用统一 key，不在不同页面临时翻译。
- 避免通过字符串拼接生成复杂句子；需要变量时使用本地化插值或格式化资源。
- 使用复数、设备差异、长度差异或变量格式时，优先使用 String Catalog 和 Foundation FormatStyle，而不是手写 `if count == 1` 或拼接单位。
- 需要给译者上下文的 key 应提供注释，说明文案出现在哪个页面、按钮还是状态说明中。
- 品牌名、Provider 名、模型名、语言自称名和用户生成内容应明确是否可翻译，避免被 String Catalog 或外部翻译流程误处理。
- 图片、示例截图、App Store 截图和包含文字的视觉资产进入发布阶段时也必须评估本地化，不只处理 SwiftUI `Text`。
- Preview 和截图验证至少覆盖英文与简体中文。
- 对宽度敏感控件优先使用图标、短标签、辅助 label 或响应式布局，而不是压缩字号。

### 5.4 术语表

以下术语应作为首批稳定术语管理：

| 产品对象 | 英文建议 | 中文建议 |
| --- | --- | --- |
| App 名称 | LangoTrace | 语迹 |
| 语言空间 | Language Space | 语言空间 |
| 记录 | Entry | 记录 |
| 记忆 | Memory | 记忆 |
| 练习 | Practice | 练习 |
| 目标语言 | Target Language | 目标语言 |
| 母语 | Native Language | 母语 |
| 界面语言 | Interface Language | 界面语言 |
| 跟随系统 | System | 跟随系统 |
| AI Provider | AI Provider | AI Provider |
| 同步 | Sync | 同步 |
| 本地优先 | Local-first | 本地优先 |

术语表可以在后续实现中扩展为独立文档或 String Catalog 注释，但不得让同一产品对象在不同页面随意更名。

### 5.5 布局和交互

国际化对布局的最低要求：

- Tab、Toolbar、Sidebar、Inspector 和按钮标签不能只按中文长度设计。
- iPhone 小屏和动态字体下，重要按钮允许换行或改用图标加辅助标签。
- iPad Split View、Slide Over、Stage Manager 窄窗口需要验证长文案不遮挡主内容。
- macOS Sidebar 和 Inspector 需要支持较长英文标签和未来更长语言。
- 不使用缩小字体作为主要适配手段。
- 不使用负字距或过窄按钮来容纳翻译文本。
- 不把说明性长文案塞进按钮、Tab 或紧凑 toolbar。
- iPhone 顶层 Tab 仍应保持 3 到 5 个清晰入口；当前主结构为 `Entry / Practice / Memory` 三个目的地。本地化后若标签过长，应优先优化术语或使用系统 Tab 行为，不应新增汉堡菜单。
- iPhone 主操作需要在动态字体和较长翻译下保持 44pt 以上触控目标，不能因文案变长而压缩可点击区域。
- 重要说明允许进入正文、footnote 或详情页，不应为了把所有语义塞进按钮而破坏可扫读性。
- RTL 未来支持时，时间线、Inspector、Sidebar 等平台结构需要重新评估视觉方向；当前阶段至少不能在通用组件里硬编码与语义无关的左/右边距。

### 5.6 iOS 交互边界

iPhone 上界面语言设置应尽量遵守系统心智：

- 设置入口通过 toolbar gear、语言空间摘要或配置 route 稳定可达，不作为底部 Tab 与记录、练习、记忆并列；也不应放进首次启动主路径阻断语言空间创建。
- 首次启动仍应优先询问母语、目标语言和当前水平；界面语言可以默认跟随系统，不作为创建第一个语言空间的必填问题。
- 若系统语言不受支持并回退英文，onboarding 可以在后续版本提供轻量入口让用户切换到已支持语言，但不应让用户误以为这是目标学习语言选择。
- 切换界面语言属于低频设置，不应占用今日记录、练习或记忆的主操作位置。
- iOS 上用户可能已经在系统设置中为 App 指定语言；App 内设置页需要展示或解释这种关系，避免两个入口互相打架。

### 5.7 iPadOS 交互边界

iPad 上界面语言设置应适配多窗口和多尺寸：

- regular width 下保持 sidebar / workspace / inspector 的上下文，不用全屏 modal 打断当前工作台。
- compact width、Slide Over 或窄 Stage Manager 窗口可退化为 iPhone 式纵向设置详情。
- 语言列表必须支持 pointer、键盘焦点、滚动和动态字体。
- 切换界面语言后应保留侧栏选择、当前 workspace 页面、选中记录和面板展开状态。

### 5.8 macOS 交互边界

Mac 上界面语言设置应符合桌面偏好设置心智：

- 应接入 SwiftUI `Settings` scene，并让 `Cmd+,` 打开设置。
- 当前 workspace 内 Settings 可以保留为产品内入口，但不应成为 Mac 上唯一偏好入口。
- 语言选择控件必须支持键盘导航、VoiceOver、窗口缩放和较长本地化文案。
- 菜单栏、系统 Settings scene、App target InfoPlist、App Intents 和后续本地通知等不属于 `LangoTraceUI` package catalog 自动覆盖范围。

### 5.9 测试与验证

后续进入实现阶段后，应逐步建立以下验证：

- 单元测试：界面语言偏好不会改变语言空间目标语言。
- 单元测试：语言 code 和展示名分离。
- 单元测试：显式界面语言偏好覆盖语迹自有 chrome，`System` 仍跟随 bundle preferred localizations 的解析结果。
- 单元测试：Core 语言模型不暴露单一中文 UI helper，UI display projection 负责菜单项和折叠值。
- 静态扫描：新增 UI 文件中明显硬编码文案需要人工确认是否应进入本地化资源。
- SwiftUI Preview 或截图：英文与简体中文至少覆盖 Welcome、Onboarding、iPhone Tab、iPad workspace、macOS workspace 和 Settings。
- 手动测试：切换界面语言后，当前语言空间和学习内容不被修改。
- 单元测试或静态测试：Welcome 等静态演示内容在第一批界面语言下保持清晰的 source note 到目标语言 rewrite 关系，且不把该 demo 规则扩散到真实 Entry / Rendering 数据。
- Xcode Test Plan 或等效脚本：覆盖不同 App language、region、Dynamic Type 和至少一个 RTL 方向的布局 smoke。
- 截图检查：确认没有裁切、截断、重叠、Tab 标签不可读、按钮文字挤压或 VoiceOver label 仍为旧语言。
- 权限 purpose strings、隐私说明、请求预览和 unavailable 页面需要纳入本地化检查，因为这些文案直接影响用户信任。

## 6. 可演进部分

- 第一阶段是否把界面语言偏好持久化到 `UserDefaults`，应在实现计划中结合启动恢复方案确认。
- 是否支持 App 内立即切换语言而不重启，后续可以根据 SwiftUI 环境注入成本单独评估。
- 是否以系统 per-app language 作为唯一正式语言切换机制，还是同时维护 App 内自定义语言偏好，需要在实现计划中明确。若两者并存，必须定义优先级。
- 母语讲解语言和界面语言不一致时，AI 讲解默认跟随哪一个，可以在 AI Prompt 规范扩展时进一步明确；当前推荐默认跟随用户母语。
- App Store 首批本地化语言清单应在发布计划中确认，不在本文档中一次性承诺。
- 是否需要伪本地化或更严格的字符串扫描，可以在页面设计系统进入稳定期后补充。
- RTL 语言是否进入第一批正式支持语言，需要结合市场、翻译质量、布局成本和截图 QA 单独决策。
- 目标语言内容的 VoiceOver 朗读语言、TTS 声音和辅助功能语言标注，需要在 Speech / Accessibility 规范中进一步细化。

## 7. 反例

不应这样做：

- 因为当前开发者使用中文，就把所有 UI 文案长期硬编码为中文。
- 因为英文是 fallback，就强制所有用户首次打开都看到英文。
- 用户切换到日语空间后，App 设置、导航和按钮自动变成日语。
- 把 `英语空间` 里的 `英语` 字符串拿去判断目标语言。
- 在 Prompt 中用界面展示名推断生成语言。
- 为了容纳长英文，把按钮字号压到不可读。
- 在隐私说明里混用界面语言和目标语言，导致用户看不懂将要发送什么内容。
- 把日期写成固定 `yyyy-MM-dd` 或 `2026年5月17日` 展示给所有地区用户。
- App 内 Picker 改成 English 后，仍宣称系统权限弹窗、StoreKit 和文件选择器都会立即变成英文。
- 在用户切换界面语言时重新生成或覆盖已有 AI 学习内容。
- 在通用组件里硬编码左侧表示“上一项”、右侧表示“下一项”，导致未来 RTL 或平台适配困难。

## 8. AI 开发提示

AI 在设计、改进或实现任何页面前，如果任务涉及可见文案、设置、语言选择、Prompt、TTS、OCR、AI 讲解或跨端布局，必须读取本文档。

开始页面设计前至少回答：

- 当前文案属于界面语言、用户母语、目标学习语言还是 Provider / Prompt 输出语言？
- 这个页面在英文和简体中文下是否都能正常阅读和点击？
- 这个设置是否会改变语言空间主数据？
- 这个设置是否与系统 per-app language 或系统 locale / region 设置冲突？
- 是否存在把展示文案当作数据模型的风险？
- 相关 UI 是否需要 String Catalog、术语表或截图验证？
- 是否涉及日期、数量、价格、单位、权限说明、隐私说明或 App Store 元数据？

如果只是调整布局，也必须检查新布局是否假设了固定中文长度。

## 9. 变更记录

- 2026-05-17：创建界面国际化与语言边界规范草案。原因：语迹愿景是适配任意语言学习，后续页面设计和改进必须区分 App 界面语言、用户母语和目标学习语言。影响范围：产品设计、SwiftUI 文案资源、设置入口、三端布局、测试验证。是否需要 ADR：否，当前属于既有多语言学习定位下的开发规范细化。
- 2026-05-17：补充系统级 App 语言、App 内语言偏好、地区格式、RTL、辅助功能朗读、权限隐私文案和本地化测试边界。原因：架构与 iOS 交互复查发现原草案容易低估 Apple per-app language、系统 UI、locale / region 和长文本 / RTL 的边界。影响范围：iPhone 设置体验、SwiftUI 资源策略、AI 请求预览、发布本地化和测试验证。是否需要 ADR：否，仍属于开发规范细化；若未来决定把界面语言偏好纳入同步或语言空间主数据，需要重新评估 ADR。
- 2026-05-18：将规范状态升级为 Accepted。原因：入口文档、Core 语言偏好模型、App target 本地化声明和设置体验已经按本文档边界推进，本文档应作为后续可见文案、界面语言设置和三端本地化的生效规范。影响范围：`docs/spec/README.md`、界面国际化实现和后续测试。是否需要 ADR：否，未改变核心产品或架构决策。
- 2026-05-18：同步显式 interface-language resolver 和 UI display projection 边界。原因：第一轮 UI 收敛已让显式界面语言偏好驱动 package-owned SwiftUI chrome，并将语言展示组合从 Core 单一中文 helper 移到 UI 层；iPhone 设置入口也已从底部 Tab 调整为低频配置入口。影响范围：界面语言解析、Tab / Settings / toolbar / unavailable 文案测试、语言展示 helper 和三端设置入口。是否需要 ADR：否。
- 2026-05-19：补充静态演示内容语言边界。原因：Welcome 示例已采用受控双语 demo 来解释“生活线索 -> 目标语言表达”闭环，需要区分静态示例、App chrome、真实用户内容和语言空间目标语言。影响范围：Welcome、空状态、教学示例、本地化测试和后续 demo 数据模型。是否需要 ADR：否。
- 2026-05-22：补充 AI Provider `语言支持` 合成测试的语言上下文边界。原因：Provider 配置测试新增 iOS 当前语言空间目标语言 probe，需要明确请求构建层只能使用稳定 target language code，并由 AI 层 allowlist 派生 Prompt 名称和离线校验规则，不能从 UI 展示名或界面语言反推。影响范围：LanguageSpacePreview、AI Provider 设置页、LangoTraceAI 语言校验和 Prompt Registry。是否需要 ADR：否。
- 2026-05-22：补充三端语言支持入口事实。原因：iOS 人工审核后，iPad 和 macOS 设置入口复用同一 `SettingsCapabilityDetailView` 语言上下文注入；该边界仍要求 Provider 输出语言只来自稳定 target language code，不来自界面语言或本地化展示名。影响范围：iPad / macOS 设置详情、macOS Settings scene、AI Provider 设置页和 Prompt Registry。是否需要 ADR：否。
