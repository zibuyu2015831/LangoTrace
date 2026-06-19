# iPhone 四 tab 统一导航栏上下文条（语言胶囊 + 设置齿轮）

状态：User Approved
自审核状态：Reviewed
类型：refactor
创建日期：2026-06-20
最后更新日期：2026-06-20

## 用户确认记录

- 2026-06-20：用户提供 iPhone 记录页截图，提出两个问题——(1) 顶部空白区域过多；(2) 四 tab 中除阅读外右上角都有设置齿轮，要求重新设计设置入口。
- 2026-06-20：用户经可视化方案对比后明确选择：
  - 头部方向 = **方向 B**（去掉冗余大标题，导航栏做成「语言胶囊 + 齿轮」上下文条）。
  - 设置入口范围 = **四个 tab 统一带齿轮**。
- 2026-06-20：用户查看原型后要求专业设计评审，并指出方向 B「顶部一点空间都不留，有压迫感」。已据此修订：顶部保留 20pt 呼吸、去掉竞争 hairline、胶囊用紧凑形式避免与居中标题挤压。评审与可视化证据落在 `prototypes/archive/record-header-review/`。
- 2026-06-20：用户要求 AI 创建的原型 / 文件不得放在仓库之外，已新增治理规则（`docs/README.md` §1.5 + `prototypes/README.md` 维护规则 5），并把原 `~/Desktop` 草稿迁入 `prototypes/archive/record-header-review/`。
- 2026-06-20：用户决定保留导航栏居中标题（不去除），但指出「语言胶囊 + 标题 + 齿轮」三元素不协调。经渲染三方向对比（A 降权胶囊 / B 统一描边控件 / C 文字态语言入口）后，用户采纳 **方向 B · 统一描边控件**：语言胶囊与设置齿轮统一为同一描边控件家族（同高、同 1px hairline、无阴影、同 pill 圆角），对称夹住居中标题；去掉胶囊的前导图标、压缩胶囊宽度，使标题真正居中并加重为锚点。对比证据见 `prototypes/archive/record-header-review/` 底部「导航栏三元素协调性」一节。
- 2026-06-20：用户指示「开始实现」，授权进入生产代码实现，状态推进到 `User Approved`。

## 需求描述

iPhone「记录」页（及其余主 tab）存在两个用户可感知问题：

1. 状态栏与「记录」大标题之间有一大块空白，未利用页面空间。
2. 设置齿轮出现在「记录 / 练习 / 记忆」右上角，唯独「阅读」页没有，入口不一致。

目标：在不破坏 iPad / macOS 的前提下，让 iPhone 四个主 tab 拥有一致的轻量头部（语言空间胶囊 + 设置齿轮），并回收顶部空白。

## 现状描述

事实源（已读代码确认）：

- `PhonePage`（`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift:383-409`）是共享容器，**有 4 个调用点**：记录（`:21`）、练习（`:165`）、记忆（`:221`）三个根 tab，以及**设置详情页 `SettingsView`（`:355`，传 `showsContextHeader: false` 主动抑制 in-body 头部，避免设置页再出现一个齿轮/胶囊）**。`SettingsView` 经齿轮 `.settingsList` route 推入（`PhoneMainView.swift:291-302`，`onSettingsAction: nil`），不是根 tab。
  - 根 tab 在 `ScrollView` 正文里渲染 `PhoneContextHeader`（语言胶囊 + 齿轮）。
  - 正文整体套 `.padding(20)`（含顶部 20pt）。
  - 调用 `.navigationTitle(localizedText(titleKey))`，未指定 display mode，默认 `.automatic` → 大标题模式。
- 顶部留白的真正成因是**大标题模式预留的大标题带 + 顶部 20pt padding + 正文内 `PhoneContextHeader` 行**三者叠加；并非「inline 区为空」本身。切到 `.inline` 会移除大标题带（主要回收来源），但 inline 导航栏仍保留约 44pt 标准高度。
- `PhoneContextHeader`（`PhoneContextHeader.swift:4-44`）的齿轮按 `onSettingsAction` 是否为 nil 条件渲染。
- `PhoneMainView`（`PhoneMainView.swift:29-114`）四个 tab 各自是独立 `NavigationStack`：
  - 记录（:39）、练习（:83）、记忆（:102）显式传入 `onSettingsAction: { navModel.push(.settingsList, on: <tab>) }`。
  - 阅读（:54-64）调用 `ReadingLibraryView`，该 view 根本没有 `onSettingsAction` / 语言上下文参数，所以阅读页既无齿轮也无语言胶囊。
- `ReadingPhoneLibraryHomeView`（`ReadingViews.swift:634-666`）自带 `ScrollView` + `.navigationTitle("tab.reading")` 大标题 + `.langoPageBackground()`，不走 `PhonePage`，也没有上下文头部。
- `ReadingLibraryView`（`ReadingViews.swift:5-46`）持有 `@ObservedObject store`，`store.languageSpace` 已可用 → 无需新增 `languageSpace` 参数即可拿到 `displayContext`。
- 大标题「记录 / 阅读 / 练习 / 记忆」与底部 Tab 标签语义重复。

## 目标、范围与不做什么

目标：

1. 顶部留白回收：四个 iPhone 主 tab 的导航栏从 `.automatic`（大标题）改为 `.inline`，移除大标题带；标题文本保留（inline 居中，承载页面身份与 push 页返回标签），导航栏承载「语言胶囊（leading）+ 设置齿轮（trailing）」。同时减小正文顶部 padding。
2. 设置入口一致：四个主 tab（含阅读）统一在导航栏 trailing 提供设置齿轮，入口从「逐页手搓」改为「共享修饰符」，结构上不可能再漏。
3. 三元素协调（方向 B）：语言胶囊与设置齿轮统一为同一描边控件家族（同高约 36pt、同 1px hairline、无阴影、同 pill 圆角），对称夹住居中标题；胶囊去掉前导 SF Symbol（`text.badge.star`）改为纯文本上下文、压缩宽度，居中标题加重为锚点。**可访问性标签与点击行为不变**（胶囊→语言空间快速切换 sheet，齿轮→`settingsList` route；触控目标仍 ≥44pt，视觉尺寸缩小不缩小点击热区）。

范围（仅 iPhone）：

- `PhoneMainSections.swift`（`PhonePage`）。
- `PhoneContextHeader.swift`（拆出可复用叶子视图，原 in-body header 退役）。
- `ReadingViews.swift`（`ReadingLibraryView` 新增两个可选 phone 闭包；`ReadingPhoneLibraryHomeView` 应用共享修饰符、去大标题）。
- `PhoneMainView.swift`（阅读 tab 传入 `onLanguageSpaceAction` / `onSettingsAction`，settings 推到 `.reading` path）。
- 新增共享 `View.phoneRootContextToolbar(...)` 修饰符与可测的 presentation 模型。

不做：

- 不改 iPad（`PadMainSections.swift`）与 macOS（`MacWorkspaceContentView.swift`）——`ReadingLibraryView` 新参数默认 `nil`，大屏调用点不变；大屏的语言空间 / 设置入口仍在 Sidebar 底部（spec/002 §4.5、§4.8）。
- 不改深层详情页（记录详情、阅读文档详情、练习会话）的导航栏标题策略（仍由各自入口决定，spec/003 §143 保持）。
- 不改语言空间快速切换 sheet、设置主列表、`displayContext` 文案与设置 route 结构。
- 不引入 principal toolbar 自定义标题（与 spec/003 §143 一致：用 leading / trailing item，不用 principal）。

## 证据与决策依据

- `docs/spec/002-navigation-and-routing.md:24`：iPhone 一级入口为四个主目的地，「设置通过 **toolbar gear**、语言空间摘要或二级配置 route 稳定可达，不作为底部 Tab」。→ 设置齿轮应在 toolbar，当前在正文里属于偏离。
- `docs/spec/002-navigation-and-routing.md:54-55`（iPhone）：「顶部轻量上下文：英语 · B1 / **Toolbar：设置 gear**、必要的记录动作或语言空间摘要入口」。→ 目标设计（顶部轻量语言上下文 + toolbar gear）正是 spec 已规定的形态；本方案是让代码回到 spec，而非新增方向。
- `docs/spec/002-navigation-and-routing.md:151-158`（§4.8）：语言空间是全局学习上下文、不是高频主导航；iPhone 顶部可显示轻量语言空间上下文，点击打开快速切换 sheet，且「不得退回只读 summary」。→ 胶囊保留可点击切换语义。
- `docs/spec/003-ui-design-system.md:143`：iPhone compact 详情页用系统 navigation title，「不使用自定义多行标题或 principal toolbar」。→ 根页用 leading/trailing item 承载上下文条，不用 principal，避免与该约束冲突。
- `docs/platform-page-inventory.md:38,43,49`：记录该 IA 事实源；本方案完成后需同步「记录 Tab / 阅读 Tab」头部描述。
- CLAUDE.md 核心决策 #15（导航/UI 变更前读 spec）、#16（实现前先建 active plan 并经用户确认）、§1.4 测试规则 #6/#7（轻量验证优先，非必要不跑 `verify.sh`）。
- 无需新增或反转 ADR：本方案对齐既有导航 spec，未推翻任何核心决策（核心决策 #2 三端分别设计仍满足——仅改 iPhone）。

## 约束映射与验证路径

| 约束来源 | 规则 | 本方案落地方式 | 验证 |
| --- | --- | --- | --- |
| spec/002 §24,§54-55 | 设置经 toolbar gear 稳定可达；顶部轻量语言上下文 | 齿轮入 toolbar trailing；胶囊入 toolbar leading | 四 tab 模拟器人工验收 + 截图 |
| spec/002 §4.8 | 顶部语言入口可点击切换、非只读 | 胶囊保留 `onLanguageSpaceAction` → 切换 sheet | 单元测试 chrome 模型 + 人工点击 |
| spec/003 §143 | 不用 principal toolbar 自定义标题 | 仅用 leading/trailing item，根页取消大标题 | 代码审查 + 人工验收 |
| CLAUDE.md §1.4 #6/#7 | 轻量验证优先 | 仅跑 UI package 聚焦测试 | `swift test --package-path Packages/LangoTraceUI` |

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`（`PhonePage`）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneContextHeader.swift`（拆叶子视图 + presentation 模型，退役 in-body header）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`（`ReadingLibraryView` 新参数 + `ReadingPhoneLibraryHomeView`）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`（阅读 tab 接线）
- 新增：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneRootContextToolbar.swift`（共享修饰符 + `PhoneRootContextChrome` 模型）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneMainChromeTests.swift`（迁移字符串断言到新叶子视图）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`（确认 `SettingsView` 抑制行为仍绿）

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift:183`（iPad 阅读调用点，确认不受影响）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift:50,92`（macOS 阅读调用点，确认不受影响）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`（色板 token）

## 涉及的文档路径

- `docs/platform-page-inventory.md`（更新记录 Tab / 阅读 Tab 头部事实）
- `docs/spec/002-navigation-and-routing.md`（核对 §54-55 描述与新实现一致；若需要补「胶囊为 toolbar leading item」细节则小幅更新）
- `docs/review/INDEX.md`（平台页面 / 导航结构变化触发专项审查时登记）
- `prototypes/archive/record-header-review/`（设计评审原型与证据，含 README）
- `prototypes/archive/README.md`（新增归档条目）
- `docs/README.md` §1.5 + `prototypes/README.md` 维护规则 5（工作产物落地治理规则，本任务附带新增）

## 实施方案

1. **抽取可复用叶子视图与 presentation 模型**（`PhoneContextHeader.swift` → 配合新文件 `PhoneRootContextToolbar.swift`）：
   - `PhoneLanguageSpaceChip(displayContext:action:)`：方向 B 描边控件——纯文本上下文（**去掉 `text.badge.star` 前导图标**），1px hairline 描边、无阴影、pill 圆角、视觉高度约 36pt、`lineLimit(1)` + 最大宽度防截断；保留三条可访问性属性（label/value/hint）与点击切换行为。
   - `PhoneSettingsGearButton(action:)`：方向 B 描边控件——与胶囊同一家族（同高约 36pt、同 1px hairline、无阴影、圆形），保留 `tab.settings` 可访问性 label；触控热区仍 ≥44pt。
   - 两个控件提取共享样式（如 `phoneRootControlStyle` 修饰符或常量）确保 hairline、高度、圆角一致，避免两处样式漂移。
   - `struct PhoneRootContextChrome: Equatable { let displayContext: String; let showsLanguageSwitcher: Bool; let showsSettings: Bool }` + 纯构造器 `make(languageSpace:hasSettings:)`，供修饰符与单元测试共用。
2. **新增共享修饰符** `View.phoneRootContextToolbar(titleKey:languageSpace:onLanguageSpaceAction:onSettingsAction:)`：
   - `.navigationTitle(localizedText(titleKey)).navigationBarTitleDisplayMode(.inline)`（保留 inline 标题——既给 push 页提供返回标签，又移除大标题带；记录/阅读/练习/记忆均为 2 字短标题，居中标题与 leading 胶囊宽度在 iPhone 可共存，仍需模拟器确认不挤压）。
   - `.toolbar { ToolbarItem(placement: .topBarLeading){ PhoneLanguageSpaceChip(...) }; if onSettingsAction != nil { ToolbarItem(placement: .topBarTrailing){ PhoneSettingsGearButton(...) } } }`。
   - 仅在 iOS 编译（`#if os(iOS)`），其它平台 `self`。
3. **改造 `PhonePage`**（保护共享消费者 `SettingsView`）：
   - 正文顶部 padding 由 `.padding(20)` 改为 `.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 92)`。顶部留 **20pt 呼吸**（设计评审结论：回收大标题带≠抹掉所有空间，8pt 会压迫；评审证据见 `prototypes/archive/record-header-review/`）。导航栏不加底部 hairline，避免与首个卡片顶部边框两条横线打架。
   - **保留** `showsContextHeader` 开关并以它作为门控（不删除——`SettingsView` 与 `PageClosureStateTests.swift:109` 都依赖它）：
     - `showsContextHeader == true`（三个根 tab）：移除正文内 `PhoneContextHeader`，应用 `.phoneRootContextToolbar(...)`。
     - `showsContextHeader == false`（`SettingsView`）：保持现状——沿用其自身 `.navigationTitle(titleKey)`，不注入胶囊/齿轮工具栏。
   - 因此 `PhonePage` 不再无条件设置大标题；大标题→inline 的切换只发生在 `showsContextHeader == true` 分支。
4. **改造阅读页**：
   - `ReadingLibraryView` 新增两个可选参数 `onLanguageSpaceAction: (() -> Void)? = nil`、`onSettingsAction: (() -> Void)? = nil`（init 默认 nil，向后兼容 iPad/macOS 调用点）。
   - `ReadingPhoneLibraryHomeView` 接收这两个闭包；移除 `.navigationTitle("tab.reading")` 大标题，应用 `.phoneRootContextToolbar(languageSpace: store.languageSpace, ...)`；保留原副标题 `reading.library.subtitle`（可作为正文首行说明，不再依赖大标题）。
5. **接线 `PhoneMainView`**：阅读 tab 调用 `ReadingLibraryView` 时补 `onLanguageSpaceAction: { presentedSheet = .languageSpaceSwitcher }`、`onSettingsAction: { navModel.push(.settingsList, on: .reading) }`；记录/练习/记忆改为统一通过 `PhonePage` 的修饰符（保持各自 `on: <tab>` 推送目标）。
6. **退役** `PhoneContextHeader`（in-body 版）并同步更新耦合测试：
   - 实施前先 `grep -rn "PhoneContextHeader\|onSettingsAction)\|onLanguageSpaceAction)" Packages/LangoTraceUI/Tests`，确认所有引用点。
   - `PhoneMainChromeTests.swift:16-18` 当前对 `PhoneContextHeader.swift` 做字符串断言（`Button(action: onSettingsAction)` / `accessibilityLabel("tab.settings")` / `Button(action: onLanguageSpaceAction)`）。把这些断言迁移到新文件 `PhoneRootContextToolbar.swift` / 新叶子视图（断言齿轮 action、`tab.settings` 可访问性 label、胶囊 action 仍存在），保证语义守卫不丢失。
   - 仅当 grep 确认无生产代码引用后删除旧 struct（早期资产，按 CLAUDE.md §1.1 可重写，不保留兼容）。

## 严格方案自审核记录

按 `docs/plans/plan-review-protocol.md` 执行。本轮使用隔离只读子代理（Plan agent，独立 context）对照真实代码审查架构 / 落地 / 测试 / spec 维度，主会话核验证据并写回。子代理确认 3 个 BLOCKER、2 个 IMPORTANT，并验证 5 项断言正确、3 项 MINOR。已修订项：

1. **[BLOCKER → 已修订] `PhonePage` 不止服务三个根 tab，`SettingsView` 是第 4 个消费者（`PhoneMainSections.swift:355`，`showsContextHeader: false`）。** 初版在 `PhonePage.body` 无条件应用工具栏并移除大标题，会把胶囊/齿轮泄漏到设置详情页并抹掉其标题。已改为以 `showsContextHeader` 门控（见实施步骤 3），设置页分支保持现状。
2. **[BLOCKER → 已修订] 删除 `showsContextHeader` 会破坏 `SettingsView` 与既有绿测 `PageClosureStateTests.swift:109`（`#expect(... "showsContextHeader: false")`）。** 已改为保留该开关作为门控，不删除。
3. **[BLOCKER → 已修订] `PhoneMainChromeTests.swift:16-18` 对 `PhoneContextHeader.swift` 做字符串断言；退役该 struct 会无声红测。** 实施步骤 6 增加「grep 全部测试引用 + 迁移断言到新文件」任务。
4. **[IMPORTANT → 已修订] 移除根页 `.navigationTitle` 会让 push 详情页的返回按钮丢失上下文标签（记录/练习/记忆）。** 已改为「保留标题 + `.inline` display mode」：既保留返回标签与页面身份，又移除大标题带回收空间（见实施步骤 2）。
5. **[IMPORTANT → 已修订] 顶部留白成因表述不准。** 真因是大标题带 + 顶部 padding + 正文内 header，而非「inline 区为空」。已在「现状描述」重写因果，并保留 `.padding(.top, 8)` 这一正确杠杆。
6. **[VERIFIED] 子代理核对并确认正确的断言：** (a) `ReadingLibraryView` 新增可选闭包默认 nil 不影响 iPad（`PadMainSections.swift:183`）/macOS（`MacWorkspaceContentView.swift:49,87`）；(b) `store.languageSpace`（`ReadingLibraryStore.swift:13`）与 `LanguageSpacePreview.displayContext` 可用；(c) `PhoneRootTab` 是 `public CaseIterable`（`PhoneRootTab.swift:1`），且 `tab.settings`/`languageSpace.switcher.label`/`languageSpace.switcher.hint` 均存在于 `Localizable.xcstrings`，`localizedString` 在 UI 测试 target 可调用 → TDD 落点可行；(d) spec/002 §24,§54-55、spec/003 §143 无冲突；(e) 部署目标 iOS 18，`.topBarLeading/.topBarTrailing` 可用，每 tab 各有 `NavigationStack` 提供工具栏宿主。
7. **[MINOR → 已纳入]** `ReadingViews.swift:668-672` 的 `header` 注释「大标题来自 navigationTitle」在去大标题后过期，实施时一并更新；`PhoneRootTab.providesRootContextToolbar` 断言只覆盖 4 个根 tab，不覆盖 `SettingsView`（后者由门控分支 + 专门用例守卫，见 TDD）。

剩余需用户确认项：无新增产品/隐私/数据/同步决策；仅需用户把状态推进到 `User Approved` 授权实现。

## TDD / 测试落点

先失败用例（新增文件 `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneRoot/PhoneRootContextChromeTests.swift`）：

- `test_chrome_reflectsLanguageSpaceDisplayContext`：`PhoneRootContextChrome.make(languageSpace:hasSettings:)` 的 `displayContext == languageSpace.displayContext`（类型未建时编译失败 → 红）。
- `test_chrome_showsLanguageSwitcherAndSettings_whenSettingsProvided`：`make(..., hasSettings: true)` → `showsSettings == true && showsLanguageSwitcher == true`。
- `test_chrome_hidesSettings_whenNoSettingsAction`：`make(..., hasSettings: false)` → `showsSettings == false`（保留齿轮可选语义）。
- `test_allPhoneRootTabs_provideContextToolbar`：对 `PhoneRootTab.allCases` 断言每个都声明上下文条（新增 `PhoneRootTab.providesRootContextToolbar`，含 `.reading`），作为「阅读页漏齿轮」的结构性回归守卫。
- `test_chromeAccessibilityKeys_resolve`：断言 `tab.settings`、`languageSpace.switcher.label`、`languageSpace.switcher.hint` 在本地化资源中可解析（source-boundary / 本地化 key 守卫）。

需同步更新的既有耦合测试（实施时必须改，否则红测）：

- `PhoneMainChromeTests.swift:16-18`：当前 string-match `PhoneContextHeader.swift`。迁移断言到新叶子视图 / `PhoneRootContextToolbar.swift`（齿轮 action、`tab.settings` label、胶囊 action）。
- `PageClosureStateTests.swift:103-112`：依赖 `SettingsView` 传 `showsContextHeader: false`。保留该开关后此测试应仍绿；改造后跑该用例确认 `SettingsView` 仍不渲染胶囊/齿轮，必要时补一条 `test_settingsView_suppressesRootContextToolbar` 显式守卫「设置详情页不出现上下文工具栏」。

不自动化部分（原因：SwiftUI 导航栏实际渲染需运行期）：四个 tab 的 toolbar 实际呈现、inline 标题与 leading 胶囊是否挤压、顶部留白回收、胶囊点击切换 sheet、齿轮进入设置、push 详情页返回标签——由模拟器人工验收 + 截图记录于实施记录。

## 验证命令

聚焦验证（默认，CLAUDE.md §1.4 #6/#7）：

```bash
swift test --package-path Packages/LangoTraceUI
swiftformat --lint Packages/LangoTraceUI --cache ignore
swiftlint --no-cache
```

人工验收（模拟器 iPhone 17 / iOS 26.5）：依次进入 记录 / 阅读 / 练习 / 记忆，确认 (a) 顶部无大块留白；(b) 四 tab 均有「语言胶囊 + 齿轮」；(c) 胶囊打开切换 sheet、齿轮进入设置；(d) 进入详情页后导航栏标题策略未变。

全量 `scripts/verify.sh`：默认不跑；仅在合并 `main` 前于 GitHub Actions 执行（CLAUDE.md §1.4 #8）。

## 文档影响检查

- 必更新：`docs/platform-page-inventory.md` 记录 Tab / 阅读 Tab 头部描述（齿轮入 toolbar、四 tab 一致、取消大标题）。
- 核对：`docs/spec/002-navigation-and-routing.md` §54-55 与新实现一致（预期已一致，必要时补「胶囊为 toolbar leading item」一句）。
- 触发审查：属「平台页面 / 导航结构」变化 → 按 `docs/review/README.md` 在实现后做文档影响检查，必要时在 `docs/review/INDEX.md` 登记专项审查。
- 无 ADR 变更（对齐既有 spec，未反转核心决策）。

## 实施记录

2026-06-20 实现（分支 `dev`，仅代码 + 测试，未合并 `main`）：

实际改动：

- 新增 `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneRootContextToolbar.swift`：
  - `PhoneRootContextChrome`（`Equatable` presentation 模型）+ `make(languageSpace:hasSettings:)`。
  - `PhoneRootTab.providesRootContextToolbar`（四 tab 全 `true`，结构性守卫阅读不漏）。
  - 方向 B 共享控件：`PhoneLanguageSpaceChip`（纯文本、去 SF Symbol、`lineLimit(1)`）与 `PhoneSettingsGearButton`，共用 `PhoneRootControlSurface`（34pt 视觉高度、1px `borderSubtle` 描边、`surfacePanel` 底、无阴影、Capsule 形），触控热区经 `minHeight/minWidth = minimumTouchTarget(44)` + `contentShape` 保持 ≥44pt。
  - `View.phoneRootContextToolbar(titleKey:languageSpace:onLanguageSpaceAction:onSettingsAction:)`：`#if os(iOS)` 下 `.navigationTitle + .navigationBarTitleDisplayMode(.inline) + topBarLeading 胶囊 + 可选 topBarTrailing 齿轮`，其它平台仅 `navigationTitle`。
- `PhoneMainSections.swift`：`PhonePage` 以 `showsContextHeader` 门控——`true` 走 `phoneRootContextToolbar`，`false`（SettingsView）走纯 `navigationTitle`；正文改 `.padding(.horizontal,20).padding(.top,20).padding(.bottom,92)` 保留 20pt 呼吸；移除正文内 `PhoneContextHeader`。
- `ReadingViews.swift`：`ReadingLibraryView` 新增 `onLanguageSpaceAction` / `onSettingsAction` 可选闭包（默认 nil，iPad/macOS 调用点不变）；`ReadingPhoneLibraryHomeView` 接收闭包、去 `.navigationTitle("tab.reading")` 大标题、改用 `phoneRootContextToolbar`，并把 header 注释更新为 inline 标题口径。
- `PhoneMainView.swift`：阅读 tab 传入 `onLanguageSpaceAction`（切换 sheet）/ `onSettingsAction`（push `.settingsList, on: .reading`），与记录/练习/记忆对齐。
- 删除 `PhoneContextHeader.swift`（grep 确认无生产引用后退役）。

测试（TDD）：

- 新增 `Tests/LangoTraceUITests/PhoneRoot/PhoneRootContextChromeTests.swift`（7 用例：chrome 模型 3 条、`providesRootContextToolbar` 全 tab、a11y key 解析、toolbar 源契约、PhonePage 门控守卫）。先失败（类型缺失）→ 实现后转绿。
- 迁移耦合测试：`PhoneMainChromeTests.swift` 改读 `PhoneRootContextToolbar.swift`（保留齿轮 action / `tab.settings` / 胶囊 action 断言）；`PlatformViewHardeningTests.swift` 的「Reading phone home」用例从「navigationTitle 大标题」迁移到「`phoneRootContextToolbar` + `titleKey: "tab.reading"`」（计划 grep 步骤未预见的额外耦合测试，已一并处理）。`PageClosureStateTests.swift:109` `showsContextHeader: false` 保持绿。

验证输出：

- `swift test --package-path Packages/LangoTraceUI` → `Test run with 556 tests in 83 suites passed`。
- `swiftformat --lint Packages/LangoTraceUI --cache ignore` → `0/183 files require formatting`。
- `swiftlint --no-cache` → `Found 420 violations, 0 serious`；新增文件 `PhoneRootContextToolbar.swift` / `PhoneRootContextChromeTests.swift` 无违规（420 均为既有告警）。
- 未运行 `scripts/verify.sh`（CLAUDE.md §1.4 #7：轻量验证优先，全量留 CI）。

待办：四 tab 模拟器人工验收（顶部留白回收、四 tab 头部一致、胶囊点击切换 sheet、齿轮进设置、push 详情页返回标签）尚未执行；`docs/platform-page-inventory.md` 已更新（见文档影响检查）。

## 完成标准

- 上述五个先失败用例转绿。
- `swift test --package-path Packages/LangoTraceUI`、`swiftformat --lint`、`swiftlint` 通过。
- 模拟器人工验收四 tab 头部一致、顶部留白回收、胶囊/齿轮行为正确。
- `docs/platform-page-inventory.md` 已更新；文档影响检查完成。
- 方案随完成移入 `docs/plans/done/` 并补实施记录。

## 剩余风险

- inline 居中标题（如「记录」）与 leading 宽胶囊在 iPhone 窄屏可能视觉拥挤；评审原型已验证：胶囊用紧凑形式 `中文 → 英语 · B1`（而非「英语空间 中文 → English」）+ 标题绝对居中即可避免重叠。实现时仍须模拟器确认真机 toolbar item 自动布局下的间距；若仍挤压，备选：标题留空只靠 toolbar item（牺牲返回标签）或胶囊进一步缩短为 `英语 · B1`。
- 宽语言胶囊在 toolbar leading 的截断行为需模拟器确认（长母语显示名场景）；必要时对胶囊加 `lineLimit(1)` 与最大宽度。
- `PhoneRootContextChrome` 单元测试覆盖 presentation 模型，不覆盖 SwiftUI toolbar 真实渲染与挤压判断，靠人工验收补充（已在 TDD 章节声明）。
- `SettingsView` 与三个根 tab 共用 `PhonePage`，门控逻辑必须随未来新增 `PhonePage` 调用点复查，避免再次出现「共享容器行为外溢」。
