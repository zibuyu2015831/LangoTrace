# macOS Sidebar 焦点环与新建记录 Sheet 设计修复方案

状态：Done
类型：bug
创建日期：2026-05-18
最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户提供 macOS 端截图，指出点击右上角 `+` 后弹出的新建记录页面很丑、缺乏设计感、与整体不协调。
- 2026-05-18：用户追加两张 macOS 截图，指出左侧栏可以点击后会出现很丑的蓝色边框；新建记录页面仍未修复，并且必须点击 `取消` 才能关闭，点击页面外区域无法消除弹窗。
- 当前状态：已完成只读排查和方案创建，尚未进行代码修复。

## Bug 描述

本轮 macOS 端存在两个相邻但不同的 UI 问题：

1. 左侧 Sidebar 菜单项已可整行点击，但点击或聚焦后会出现系统默认蓝色焦点环。该焦点环横跨整行矩形，视觉上比自定义选中态更重，与 LangoTrace 当前安静、低对比的侧栏风格不协调。
2. macOS 工作台右上角 `+` 打开新建记录 sheet 后，弹出页呈现为默认 `Form` 表单样式：白色大面板、系统默认行分隔、标题与输入控件挤在顶部、正文区域大面积空白、底部按钮缺少当前产品的视觉层级。该样式与 LangoTrace 当前 macOS 工作台的米色 paper 背景、安静工具型视觉、token 化按钮和面板语言不一致。并且该弹窗只能通过 `取消` 或保存关闭，点击页面外区域不能关闭。

## 复现方式

Sidebar 焦点环：

1. 启动 macOS 版本并进入主工作台。
2. 点击左侧栏 `记忆` 等菜单项。
3. 观察菜单项外侧出现系统蓝色焦点环。

新建记录弹窗：

1. 启动 macOS 版本并进入主工作台。
2. 点击窗口右上角 `+` 按钮。
3. 观察弹出的 `写一句` / 新建记录 sheet。
4. 点击弹窗外部的灰色遮罩或主页面区域。
5. 观察弹窗是否关闭。

## 预期行为

- Sidebar 菜单项应保留键盘可达性和选中语义，但不能显示破坏视觉一致性的系统蓝色焦点环。
- Sidebar 聚焦 / 选中 / hover 状态应使用 LangoTrace 自定义背景和描边表达。
- 新建记录 sheet 应使用 LangoTrace 的 `paper` / `elevatedPaper` / `accent` / `hairline` token，而不是系统默认白色 `Form` 视觉。
- macOS sheet 应像一个紧凑、清晰、可长期使用的记录编辑器，而不是临时表单。
- 标题、语言空间上下文、标题输入、正文输入、隐私边界和操作按钮应有明确层级。
- 保存 / 取消按钮应在 macOS 上有稳定位置和合理视觉重量。
- 用户点击弹窗外部区域时，应关闭 macOS 新建记录弹窗；本轮不做未保存内容确认。
- 输入体验、禁用保存状态、辅助功能标签和本地优先隐私说明不能退化。

## 实际行为

- `MacSidebarItem` 为修复整行点击而增加了 `.focusable()`，但没有关闭系统 focus effect；SwiftUI / macOS 会绘制默认蓝色焦点环。
- `EntryEditorView` 当前位于 `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`。
- 该 View 被 iPhone、iPad 和 macOS 共用。
- 实现直接使用 `NavigationStack { Form { Section { TextField; TextEditor } ... } }`。
- macOS sheet 使用这套移动端表单结构后，与 `MacMainView`、`LangoTraceDesign` 和现有 panel/card 风格明显割裂。
- `TextEditor` 没有接入产品背景、边框、最小高度、焦点视觉或说明文本；底部 toolbar 的 `取消 / 保存` 也没有与 modal 内容形成一个完整底栏。
- `MacMainView` 使用系统 `.sheet(isPresented:)` 展示 `EntryEditorView`。在 macOS 上，系统 sheet 默认不提供“点击页面外区域关闭”的行为。

## 根因分析

根因分为两部分：

1. Sidebar 蓝色边框是上一次修复整行点击时引入 `.focusable()` 后的系统默认 focus effect。`.focusable()` 本身是正确的键盘可访问性补充，但当前没有配套 `.focusEffectDisabled()` 和自定义焦点视觉，导致系统蓝色描边压过产品自定义选中态。
2. 新建记录编辑器没有按平台拆分呈现层。`EntryEditorView` 作为三端共享入口是合理的，但其内部视觉实现不应在 macOS 继续使用移动端 `Form`。同时，若产品要求点击外部关闭，则 macOS 端不能继续完全依赖系统 `.sheet`，需要改为 Mac 专用的自定义 modal overlay 或等价可外部点击关闭的呈现层。

涉及实现：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`：`MacSidebarItem` 当前包含 `.focusable()`，未包含 `.focusEffectDisabled()`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`：`EntryEditorView` 当前直接承载所有平台表单 UI。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`：右上角 `+` 设置 `isEntryEditorPresented = true`，并以 `.sheet` 展示 `EntryEditorView`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift` 和 `PhoneMainView.swift`：同样使用 `EntryEditorView`，因此修复必须避免破坏移动端现有 sheet。

置信度：95%

## 置信度依据

- 截图中 Sidebar 蓝框形态与 macOS/SwiftUI 默认 focus ring 一致，且对应代码刚加入 `.focusable()`。
- SwiftUI focus 参考明确说明 `.focusEffectDisabled()` 可在提供自定义焦点视觉时关闭系统 focus ring。
- 截图中可见系统默认 `Form` 的白色背景、分隔线和 toolbar 按钮。
- 代码中 `EntryEditorView` 没有任何 macOS 分支或 LangoTrace modal 专用布局。
- 代码中 `MacMainView` 使用系统 `.sheet`，不具备点击页面外部关闭的自定义控制层。
- 当前设计系统要求 macOS 可更紧凑，但不能牺牲可读性和视觉一致性；modal / sheet 内容可以使用卡片或局部框定工具面板。
- `LangoTraceDesign` 已经提供 `paper`、`elevatedPaper`、`surfaceRaised`、`accent`、`hairline`、`sheet` radius 等 token，本问题不需要新增架构能力即可修复。
- 当前工程目标为 iOS 18 / macOS 15，`.focusEffectDisabled()`、`@FocusState`、`NavigationStack` 和现有 SwiftUI 修饰符均在目标平台范围内，不需要新增兼容分支。

## 架构与 Mac 交互复查结论

本方案在系统架构和 macOS 交互层面可执行，但实施时必须遵守以下补充约束：

1. macOS 端从系统 `.sheet` 改为自定义 overlay 后，不能继续依赖 `@Environment(\.dismiss)` 关闭弹窗。`@Environment(\.dismiss)` 只适合系统 presentation 或 navigation context；自定义 overlay 必须显式传入 `onCancel` / `onClose`，或由 `MacEntryEditorOverlay` 统一持有关闭逻辑。
2. `EntryEditorView(languageSpace:onSave:)` 可以保留为 iPhone / iPad 的公共入口，但 macOS overlay 更适合直接承载 `MacEntryEditorSheet(languageSpace:onCancel:onSave:)`。如果仍让 `EntryEditorView` 根据平台分支渲染 Mac 组件，则 Mac 分支也必须获得显式关闭 closure，不能只调用 `dismiss()`。
3. 点击外部关闭应由背景遮罩层单独处理，而不是把 `.onTapGesture` 加在整个 overlay 父容器上。推荐结构是 `ZStack { dimLayer; sheet }`，只有 dim layer 接收关闭点击，sheet 本体不需要依赖不稳定的“阻止冒泡”技巧。
4. macOS 弹窗应支持 Escape / cancel action 关闭。外部点击是用户明确要求；Escape 是 Mac 用户对临时弹窗的自然预期。二者都只 dismiss，不写入。
5. 保存按钮的禁用规则应抽成 `private var canSave: Bool` 或等价局部计算，避免测试只能搜索一段很长的 trimming 表达式，也让 Mac 和移动端共享同一语义。
6. 自定义 overlay 不应把新建记录升级为业务路由、独立窗口或持久状态；`isEntryEditorPresented` 仍是 transient UI state，符合导航与 SwiftUI 架构规范。
7. 源码级字符串测试只能防止明显结构回退，不能证明视觉质量；本方案必须保留真实 macOS 截图复查作为完成标准。

## 备选原因

- 侧栏蓝框是自定义 overlay：当前代码 overlay stroke 使用 accent/hairline，颜色和截图中的系统蓝不一致；且蓝框在点击后出现，更符合 focus ring。
- 取消 `.focusable()` 即可去掉蓝框：可以去掉症状，但会牺牲键盘可达性，不作为推荐方案。
- sheet 尺寸过大：确实加重了空洞感，但主要问题是内部内容仍是默认 `Form`。
- macOS 系统表单风格天然偏白：不是不可避免问题；当前项目已有自定义背景、面板和按钮 token，可用于 modal。
- 顶层工作台变灰导致视觉失真：sheet 背景 dim 是系统行为，问题集中在 sheet 内容自身缺少产品化设计。
- 系统 sheet 可以通过配置直接支持外部点击关闭：当前 SwiftUI `.sheet` 没有提供稳定的 macOS 外部遮罩点击关闭入口，推荐使用 Mac 专用 overlay 来显式实现。

## 现状描述

`MacSidebarItem` 当前已经是 Mac 专用组件，但焦点视觉还停留在系统默认状态。其结构如下：

```swift
Button(action: action) { ... }
    .buttonStyle(.plain)
    .focusable()
```

`EntryEditorView` 目前更像 iPhone 表单页：

```swift
NavigationStack {
    Form {
        Section { ... }
        Section { ... }
    }
    .navigationTitle(localizedText("entryEditor.title"))
    .toolbar { cancellationAction; confirmationAction }
}
```

这对 iPhone 的系统 sheet 是可接受的，但 macOS 工作台已经采用自定义三栏布局、sidebar item、inspector card 和 token 化状态组件。继续复用 `Form` 会造成同一窗口内出现两套完全不同的视觉语言。

## 目标

- 为 macOS 新建记录 sheet 提供专用视觉结构。
- 修复 Mac Sidebar 菜单项默认蓝色焦点环，使其使用产品自定义焦点 / 选中视觉。
- 为 macOS 新建记录弹窗提供点击外部区域关闭能力。
- 保留 `EntryEditorView(languageSpace:onSave:)` 的公共调用接口，避免改动三端调用方。
- 保留 iPhone / iPad 当前表单行为，除非实现中发现必须共享小型逻辑。
- 使用现有 `LangoTraceDesign` token，不新增独立主题。
- 增加源码级回归测试，防止 macOS 分支重新退回默认 `Form`。

## 范围

包含：

- `MacSidebarItem` 的 focus effect 修复。
- `MacMainView` macOS 新建记录呈现方式，从系统 `.sheet` 改为 Mac 专用 modal overlay 或等价可点击外部关闭的呈现层。
- `EntryEditorView` 内部平台分支或组件拆分。
- macOS 专用 `MacEntryEditorSheet` 或等价私有组件。
- macOS sheet 的标题区、输入区、隐私说明和底部操作区设计。
- 必要的本地化 key 补充。
- 源码级回归测试。

不包含：

- 不接入真实数据库、AI、TTS、OCR、同步或导出。
- 不改变 Entry 保存语义；保存仍只创建用户原始记录。
- 不把新建记录改为主窗口页面、popover 或独立 window。
- 不重做 iPhone / iPad 新建记录视觉。
- 不新增复杂标签、照片、录音、Prompt preset 或 AI 请求预览。
- 不为点击外部关闭增加未保存内容确认。本轮按用户要求点击外部直接关闭。

## 证据与决策依据

- `docs/spec/002-navigation-and-routing.md` 规定 Sheet 适合短流程任务，但不要把长时间写作、完整练习或复杂设置塞进小型 Sheet。本轮保留短记录编辑 sheet，但使其在 macOS 上具备明确层级。
- `docs/spec/003-ui-design-system.md` 要求 UI 高级、现代、简洁、长期可读；卡片可用于 modal / sheet 内容；不要让不同页面临时定义自己的按钮、badge、卡片和颜色。
- `docs/spec/004-swiftui-architecture.md` 要求共享内容视图和平台外壳分离，平台差异不能大量堆在单个巨型 View 中。
- SwiftUI focus 参考要求保留 `.focusable()` 以支持键盘焦点；在提供自定义焦点视觉时可使用 `.focusEffectDisabled()` suppress 系统 focus ring。
- SwiftUI 最新 API 参考要求优先使用现代 `navigationTitle`、专用 accessibility modifier 和 `Button`，避免退回 deprecated API。
- macOS HIG 要求 Mac app 支持键盘、菜单、窗口和原生桌面交互；modal 应有清晰动作层级和焦点体验。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/MacSidebarHitTestingTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/MacEntryEditorSheetTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ContentUtilityComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/UnavailableCapabilityView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`

## 涉及的文档路径

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/plans/active/2026-05-18-bug-mac-sidebar-focus-and-entry-sheet.md`

## 实施方案

1. 扩展 Sidebar 焦点视觉回归测试。
   - 更新 `MacSidebarHitTestingTests`。
   - 断言 `MacSidebarItem` 仍包含 `.focusable()`，避免为去掉蓝框牺牲键盘可达性。
   - 断言 `MacSidebarItem` 包含 `.focusEffectDisabled()`。
   - 断言 `MacSidebarItem` 仍包含 `.contentShape(Rectangle())`、`.onHover`、`.contextMenu` 和 selected accessibility trait。

2. 增加新建记录弹窗回归测试。
   - 新建 `Packages/LangoTraceUI/Tests/LangoTraceUITests/MacEntryEditorSheetTests.swift`。
   - 读取 `PhoneMainSupportingViews.swift` 源码。
   - 断言存在 `MacEntryEditorSheet` 或等价 macOS 专用组件。
   - 断言存在 `MacEntryEditorOverlay` 或等价 macOS 专用呈现层，避免把关闭逻辑混在系统 `.sheet` 中。
   - 断言 macOS 分支使用 `#if os(macOS)`。
   - 断言 macOS sheet 使用 `LangoTraceDesign.ColorToken.paper` / `elevatedPaper` / `hairline` / `accent` 等 token。
   - 断言 macOS sheet 不在专用组件内使用 `Form {`。
   - 断言保存按钮仍由 `canSave` 或等价计算控制，语义为 `bodyText.trimmingCharacters(in: .whitespacesAndNewlines)` 非空。
   - 读取 `MacMainView.swift` 源码，断言 Mac 新建记录不再通过 `.sheet(isPresented: $isEntryEditorPresented)` 呈现，而是存在 `MacEntryEditorOverlay` 或等价 overlay。
   - 断言 overlay 背景层包含 `onTapGesture` 并会把 `isEntryEditorPresented = false`。
   - 断言弹窗内存在取消 closure 或 cancel keyboard shortcut，不能只依赖 `@Environment(\.dismiss)`。

3. 修复 Sidebar 焦点环。
   - 在 `MacSidebarItem` 的 button modifier 链中保留 `.focusable()`。
   - 增加 `.focusEffectDisabled()`，关闭系统蓝色 focus ring。
   - 如果需要可见键盘焦点，使用 `@Environment(\.isFocused)` 或 `@FocusState` 提供轻量自定义描边；颜色应使用 `accent.opacity(...)` 或 `hairline`，不得使用系统蓝色大外框。
   - 不移除 `.accessibilityAddTraits(active ? .isSelected : [])`。

4. 拆分 `EntryEditorView` 呈现层。
   - 保留现有 `EntryEditorView` public shape 作为 iPhone / iPad 系统 sheet 入口：
     ```swift
     struct EntryEditorView: View {
         let languageSpace: LanguageSpacePreview
         let onSave: (String, String) -> Void
     }
     ```
   - 将现有移动端 `NavigationStack + Form` 收敛到 `TouchEntryEditorSheet` 或保留在 `#else` 分支。
   - macOS overlay 不应依赖 `EntryEditorView` 内部的 `@Environment(\.dismiss)`；推荐新增 `MacEntryEditorSheet(languageSpace:onCancel:onSave:)`，由 `MacEntryEditorOverlay` 传入关闭和保存 closure。
   - 若为了复用仍在 `EntryEditorView` 内写 `#if os(macOS)` 分支，必须同步扩展内部关闭路径，确保 Mac 端 `取消`、保存后关闭、外部点击和 Escape 都会设置 `isEntryEditorPresented = false`。

5. 实现 macOS 专用弹窗视觉。
   - 外层使用固定合理宽度，建议 `frame(width: 560)` 或 `frame(minWidth: 520, idealWidth: 580, maxWidth: 620)`。
   - 根背景使用 `LangoTraceDesign.ColorToken.paper`，避免纯白。
   - 顶部标题区使用小图标、`entryEditor.title`、语言空间上下文，例如 `英语空间 · 中文 -> 英语 · B1`。
   - 标题输入和正文输入使用自定义 `VStack` field group：
     - label 使用 `.font(.caption.weight(.semibold))`。
     - field 背景使用 `surfaceRaised` 或 `elevatedPaper`。
     - 边框使用 `hairline`，焦点态可使用 `accent.opacity(0.45)`。
     - 正文 `TextEditor` 最小高度建议 220 到 260。
   - 隐私说明使用紧凑 callout：lock 图标、标题和现有 `entryEditor.privacy.localOnly` 文案。
   - 底部操作区使用 divider + HStack trailing buttons，取消为 secondary，保存为 primary；保存禁用时降低透明度或使用 disabled。
   - 弹窗容器使用 `clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.sheet, style: .continuous))`、hairline stroke 和轻量 shadow。

6. 在 MacMainView 中实现点击外部关闭。
   - macOS 端不再使用系统 `.sheet(isPresented:)` 展示新建记录。
   - 在 `MacMainView.body` 上增加 overlay：
     - 背景 dim 层覆盖全窗口。
     - dim 层 `.contentShape(Rectangle())` 并在 `.onTapGesture` 中设置 `isEntryEditorPresented = false`。
     - 中央显示 `MacEntryEditorSheet`。
     - dim 层和 sheet 层应作为同一个 `ZStack` 的兄弟节点，避免依赖父级 gesture 冒泡控制。
     - `MacEntryEditorSheet` 的取消按钮调用 `onCancel`，保存成功后调用 `onSave`，再由父层关闭 overlay。
     - 增加 `.keyboardShortcut(.cancelAction)` 或等价 Escape 关闭路径。
   - iPhone / iPad 继续使用系统 `.sheet`。

7. 保持行为边界。
   - 保存仍调用 `onSave(title, bodyText)` 后 dismiss。
   - 取消只 dismiss，不写入。
   - macOS 点击外部区域也只 dismiss，不写入。
   - 保存禁用规则不改变：正文去除空白后为空时禁用。
   - 不在 View 内访问 repository、数据库、AI、Keychain 或同步。
   - 不改变 `PadMainView`、`PhoneMainView` 的 sheet 调用方式。

8. 复查本地化。
   - 若新增 `entryEditor.subtitle`、`entryEditor.bodyPlaceholder`、`entryEditor.spaceContext` 等 key，必须写入 String Catalog。
   - 不在 Swift UI 源码中新增硬编码中文。
   - 若可以复用现有 key，应优先复用，避免无意义文案膨胀。

## 回归测试方案

- 扩展源码级测试，确保 Mac Sidebar 保留 `.focusable()` 但禁用系统 `.focusEffectDisabled()`。
- 新增源码级测试，确保 macOS entry editor 有专用组件和平台分支。
- 新增源码级测试，确保 macOS 专用组件不使用 `Form`。
- 新增源码级测试，确保 macOS 专用组件使用 LangoTrace design token。
- 新增源码级测试，确保 Mac 新建记录使用 overlay 并支持外部点击关闭。
- 新增源码级测试，确保 Mac overlay 有显式 `onCancel` / `onClose` 路径，避免在自定义 overlay 中误用 `@Environment(\.dismiss)`。
- 新增源码级测试或人工复查项，确保 Escape / cancel action 可以关闭 macOS 新建记录弹窗。
- 继续保留现有 `PremiumUIBehaviorTests.langoTraceUISwiftChromeContainsNoHardCodedHanCharacters`，防止新增硬编码中文。
- 运行 `swift test --package-path Packages/LangoTraceUI`。

## 复查方法

人工复查：

1. 运行 macOS app。
2. 点击左侧栏每个菜单项，确认不再出现系统蓝色大焦点环。
3. 使用键盘导航侧栏，确认仍可聚焦或至少可通过辅助功能识别选中项。
4. 点击右上角 `+`。
5. 检查新建记录弹窗是否使用米色 / elevated 面板视觉，而不是纯白默认 `Form`。
6. 检查标题、语言空间上下文、标题输入、正文输入、隐私说明和底部按钮是否有明确层级。
7. 点击弹窗外部区域，确认弹窗关闭。
8. 按 Escape，确认弹窗关闭。
9. 再次打开弹窗，输入正文后保存按钮可用；清空正文后保存按钮禁用。
10. 点击取消不创建记录；点击保存创建记录并进入记录详情。
11. 用键盘焦点在标题、正文、取消、保存之间移动，焦点状态清楚。

代码复查：

1. `MacSidebarItem` 没有为了去掉蓝框而移除 `.focusable()`。
2. `MacSidebarItem` 使用 `.focusEffectDisabled()` 并保留 selected accessibility trait。
3. `EntryEditorView` 调用接口未变化。
4. macOS 专用组件没有使用 `Form`。
5. macOS 专用 overlay 的外部点击只关闭弹窗，不创建记录。
6. macOS 专用 overlay 的取消和 Escape 关闭路径不依赖系统 `.sheet` 的 `dismiss()`。
7. macOS 专用组件没有访问 repository、AI、同步或 Keychain。
8. iPhone / iPad sheet 路径仍保留或只做低风险结构迁移。
9. 新增文案全部在 String Catalog。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
git diff --check
git status --short
```

完整收口时运行：

```bash
scripts/verify.sh
```

## 文档影响检查

本修复属于已有 UI 设计系统和 SwiftUI 平台适配规则下的 macOS 侧栏焦点视觉与新建记录弹窗修复，不改变导航规范、SwiftUI 架构规范、数据边界、AI Provider 边界、同步边界或 ADR。完成后只需要更新本任务方案实施记录、验证结果和状态。

如果实施过程中决定把新建记录从 sheet 改为独立窗口、主工作区页面或新的路由模型，则不再属于本方案范围，必须重新评估 `docs/spec/002-navigation-and-routing.md` 是否需要更新。

## 实施记录

- 2026-05-18：完成只读排查。根因定位为 `EntryEditorView` 三端共享但视觉实现直接使用 `NavigationStack + Form`，导致 macOS sheet 与产品视觉系统割裂。
- 2026-05-18：根据用户追加截图补充 Sidebar 蓝色焦点环和点击外部关闭弹窗问题。结论：蓝框来自 `.focusable()` 默认 focus effect；点击外部关闭需要 Mac 端从系统 `.sheet` 改为自定义 overlay 或等价呈现层。
- 2026-05-18：实施修复。`MacSidebarItem` 保留 `.focusable()` 并增加 `.focusEffectDisabled()`，避免系统蓝色焦点环压过产品自定义选中态。
- 2026-05-18：`MacMainView` 移除 macOS 新建记录的系统 `.sheet(isPresented:)`，改为 `MacEntryEditorOverlay`。overlay 使用独立 dim layer 处理外部点击关闭，并通过显式 `onCancel` / `onSave` 闭包关闭，不依赖系统 `dismiss()`。
- 2026-05-18：新增 macOS 专用 `MacEntryEditorSheet`。该组件使用 `LangoTraceDesign` token、紧凑标题区、自定义输入区、隐私说明和底部操作区；保存禁用规则抽为 `canSave`；取消按钮支持 `.keyboardShortcut(.cancelAction)`。
- 2026-05-18：保留 `EntryEditorView(languageSpace:onSave:)` 的 iPhone / iPad 系统 sheet 入口和现有 `NavigationStack + Form` 行为。为保证共享 UI package 在 iOS 目标编译，非 macOS 分支提供不进入运行路径的 `MacEntryEditorSheet` 空占位声明。
- 2026-05-18：补充回归测试。`MacSidebarHitTestingTests` 覆盖 `.focusEffectDisabled()`；新增 `MacEntryEditorSheetTests` 覆盖 Mac overlay、外部点击关闭、显式取消路径、Mac 专用组件、design token、非 `Form` 布局和 cancel action。
- 2026-05-18：复查完整验证输出后继续清理 SwiftLint warning。将 `MacEntryEditorSheet` 从 `PhoneMainSupportingViews.swift` 拆至独立文件，避免 Mac 专用呈现层继续挤在 iPhone supporting views 中；新增测试约束共享 phone supporting views 不再承载 Mac editor presentation。
- 2026-05-18：将 `PracticeControlBar` 从 `LearningContentComponents.swift` 拆至独立文件，并把 `PremiumUIBehaviorTests` 的 helper 移到 private extension，同时修复行长问题。该轮只做职责拆分和 lint 清理，不改变用户可见行为。

## 验证结果

- 2026-05-18：新增测试后先运行 `swift test --package-path Packages/LangoTraceUI`，测试按预期失败，失败点覆盖 `.focusEffectDisabled()`、Mac overlay、Mac 专用编辑器和 cancel action。
- 2026-05-18：实施后运行 `swift test --package-path Packages/LangoTraceUI`，42 个测试、8 个 suite 通过。
- 2026-05-18：运行 `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`，通过。
- 2026-05-18：首次运行 `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build` 发现共享 package 在 iOS 目标编译时找不到 `MacEntryEditorSheet`。已补充非 macOS 空占位声明。
- 2026-05-18：修复后再次运行 `swift test --package-path Packages/LangoTraceUI`，42 个测试、8 个 suite 通过。
- 2026-05-18：修复后再次运行 `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`，通过。
- 2026-05-18：首次完整运行 `scripts/verify.sh`，构建和测试均已通过，但在 `swiftformat --lint . --cache ignore` 阶段发现新增代码格式问题。已运行 `swiftformat` 修复，并重新运行 UI 包测试。
- 2026-05-18：格式修复后运行 `swiftlint --no-cache Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/MacEntryEditorSheetTests.swift`，0 violations。
- 2026-05-18：最终运行 `scripts/verify.sh`，通过。脚本完成了 XcodeGen、Core/Data/UI 测试、iPhone 17 构建、iPad Pro 13-inch 构建、macOS 构建、SwiftLint、SwiftFormat lint、文档 placeholder 扫描和 `git status --short`。SwiftLint 仍报告 4 条非 serious warning，分别是既有 `PremiumUIBehaviorTests` 行长 / 类型长度、`LearningContentComponents.swift` 文件长度，以及本次扩展后 `PhoneMainSupportingViews.swift` 文件长度；脚本退出码为 0。
- 2026-05-18：针对上述 warning 完成二次清理后，运行 `swift test --package-path Packages/LangoTraceUI`，43 个测试、8 个 suite 通过。
- 2026-05-18：二次清理后运行 `swiftlint --no-cache Packages/LangoTraceUI/Sources/LangoTraceUI/MacEntryEditorSheet.swift Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/MacEntryEditorSheetTests.swift`，0 violations。
- 2026-05-18：二次清理后再次运行 `scripts/verify.sh`，通过。全仓库 SwiftLint 结果为 0 violations、0 serious；SwiftFormat lint 结果为 0 个文件需要格式化。

## 完成标准

- macOS Sidebar 点击或聚焦菜单项时不再出现系统蓝色大焦点环。
- macOS Sidebar 保留键盘可达性、hover、context menu 和 selected accessibility trait。
- macOS 点击 `+` 后的新建记录 sheet 不再呈现默认白色 `Form` 外观。
- macOS 新建记录弹窗使用 LangoTrace design token，视觉上与工作台一致。
- macOS 点击弹窗外部区域可以关闭新建记录弹窗。
- macOS 按 Escape 或触发 cancel action 可以关闭新建记录弹窗。
- iPhone / iPad 新建记录入口不回归。
- 保存 / 取消 / 禁用保存 / 隐私说明行为不回归。
- `swift test --package-path Packages/LangoTraceUI` 通过。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 通过。
- `scripts/verify.sh` 通过；若无法运行完整脚本，实施记录必须说明原因和剩余风险。
- `git diff --check` 通过。
- 本方案更新实施记录和验证结果。

## 剩余风险

- 源码级测试只能约束结构和 token 使用，不能替代真实 macOS 截图复查。
- 点击外部关闭会丢弃未保存输入；本轮按用户要求实现，不增加确认流程。后续如果编辑器承载更长内容，应重新评估未保存变更保护。
- 如果未来新建记录流程增加照片、录音、标签或 AI 请求预览，当前紧凑 sheet 可能需要升级为更完整的编辑页面或多步骤 sheet。
