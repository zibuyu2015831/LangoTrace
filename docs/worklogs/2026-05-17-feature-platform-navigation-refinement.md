# 工作记录：平台导航入口优化

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/guidelines/002-navigation-and-routing.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/worklogs/2026-05-17-feature-collapsible-side-panels.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`

关联提交：

- 未提交

## 1. 背景

当前 iPad 主体页顶部全局条包含：

- 左侧时间线切换。
- 当前语言空间：`中文 -> 英语 · B1`。
- 搜索。
- 本地优先 / 未配置 AI 状态。
- 右侧学习面板切换。
- 设置按钮。

用户指出：从页面设计上看，语言空间栏是否更适合放到左侧 Sidebar 底部，并和设置按钮放在同一行，类似 Obsidian 左侧栏底部的库 / 设置区域。用户同时提出：

- 该调整涉及 iPad 和 Mac。
- iPhone 希望支持左右滑动切换 Tab。

这次 worklog 用于记录平台导航入口优化的方案，避免直接改动导致导航结构、平台交互和长期文档不一致。

## 2. 目标

本次完成后，应达到以下可验证结果：

- iPad 顶部全局条更聚焦当前任务，不再把语言空间作为高优先级顶部按钮。
- iPad 左侧 Sidebar 底部承载当前语言空间、设置入口和本地 / AI 状态。
- Mac Sidebar 底部承载当前语言空间和设置入口，符合桌面工具的资料库上下文心智。
- iPhone 保留底部 Tab，同时支持在一级 Tab 根页面左右滑动切换 Tab。
- 三端仍共享同一个语言空间上下文，不引入 Project、“我的”或多用户概念。
- 语言空间切换入口保持可发现，但不抢占记录、搜索、学习和练习主流程。
- 明确“语言空间是全局学习上下文，不是高频主导航”：它应稳定可见或可召回，但不应压过当前任务入口。
- 本次仍保持 Mock / App Shell 阶段边界，不实现真实语言空间列表、真实设置页、真实路由持久化或数据库写入。

## 3. 范围

本次会处理：

- iPad：
  - 从顶部全局条移除语言空间胶囊。
  - 在左侧 Sidebar 底部增加轻量空间 / 设置区域。
  - 将当前语言空间、设置图标、本地优先 / AI 未配置状态合并为低干扰底部工具区。
  - 保留顶部左侧时间线切换、搜索、本地状态摘要、右侧学习面板切换。
- Mac：
  - 将语言空间和设置入口固定在 Sidebar 底部。
  - 保留主区内 Sidebar / Inspector 显示隐藏按钮。
  - 不提前实现 macOS 菜单栏 Commands 或快捷键。
- iPhone：
  - 保留 `今日 / 记录 / 练习 / 记忆 / 设置` 底部 Tab。
  - 为一级 Tab 根页面增加左右滑动切换 Tab 的增强手势。
  - 让底部 Tab 始终反映当前选中页面。
- 文档：
  - 如果实现后长期规则变化，需要同步 `docs/guidelines/002-navigation-and-routing.md` 和 `docs/guidelines/003-ui-design-system.md`。
  - 更新本 worklog 的实施记录和验证结果。

## 4. 不做什么

本次不处理：

- 真实语言空间切换列表。
- 语言空间创建、删除、重命名或排序。
- 多语言空间数据持久化。
- 真实设置页面、偏好设置或 `Cmd+,`。
- macOS 菜单栏 View Commands、Command Palette 或快捷键体系。
- iPad 自动根据窗口宽度移动语言空间入口。
- iPhone 详情页、编辑页、录音页、文本选择区、横向控件区的全局左右滑切 Tab。
- 替换底部 Tab 为自定义导航。
- 真实路由、深链、数据库、同步、AI、TTS、OCR、StoreKit 或权限流程。

## 5. 分析

### 5.1 语言空间是否应留在顶部

语言空间是重要上下文，但不是高频操作。它告诉用户“当前正在学习哪门目标语言、以什么水平生成材料”，但用户进入学习桌面后，主要动作是：

- 搜索记录或词句。
- 写作和阅读当前记录。
- 打开或收起时间线。
- 打开或收起学习面板。
- 进行听、读、跟读和回译。

因此语言空间不应长期占据顶部全局条的第二高优先级位置。顶部更适合放与当前任务直接相关的操作：面板切换、搜索、隐私状态和学习面板切换。

### 5.2 为什么适合放到 Sidebar 底部

左侧 Sidebar 承载时间线、记录库、筛选和资料库上下文。语言空间本质上是这些内容的容器，把它放到 Sidebar 底部更符合用户心理：

- 顶部：处理当前任务。
- 左侧：组织当前资料库。
- 底部：空间 / 设置 / 状态等低频系统入口。

Obsidian 的底部库 / 设置结构值得借鉴，但语迹不应照搬。语迹的底部区域需要强调当前语言空间和本地优先状态，而不是插件、帮助和复杂库管理。

这个设计应遵守一条长期原则：语言空间是当前所有记录、练习、记忆和 AI 生成材料的上下文容器，而不是与“记录 / 练习 / 记忆”并列的主导航。它应该可被用户确认和召回，但不应成为每次进入主界面时最显眼的操作。

### 5.3 iPad 与 Mac 的差异

iPad：

- 左侧 Sidebar 可能被收起。
- 语言空间放到底部后，在 Sidebar 收起时暂时不可见。
- 这是可以接受的，因为语言空间切换不是高频操作。
- 顶部左侧 Sidebar 按钮始终可见，用户可以召回该入口。
- 当前阶段“稳定可达”不等于“始终占据顶部”。只要 Sidebar 展开按钮稳定可见，语言空间和设置入口就可以跟随 Sidebar 隐藏。

Mac：

- Sidebar 是桌面工具的资料库入口。
- 语言空间和设置放在 Sidebar 底部更符合 Mac 工具类 App 心智。
- 后续可以通过菜单栏和快捷键补充设置入口，但本次不提前做。
- 当前阶段可以先通过 Sidebar 底部满足设置入口稳定可达；后续 `Settings...`、`Cmd+,` 和菜单栏属于 Mac 产品级导航增强。

### 5.4 iPhone 左右滑切 Tab 的必要性

iPhone 底部 Tab 是标准主导航，必须保留。左右滑切 Tab 可以作为高级但自然的增强：

- 用户在记录、练习、记忆之间切换时，横向手势比反复点底部 Tab 更顺。
- 它符合许多 iOS 内容型 App 的页面切换习惯。
- 但它不能抢占文本选择、横向滚动、录音控制或详情页返回手势。

因此 iPhone 首期只应在一级 Tab 根页面支持左右滑切换，不应在深层详情页强行全局响应。

### 5.5 对现有实现的影响

当前实现中：

- `PadWorkspaceBar` 负责 iPad 顶部全局条。
- `PadMainView` 负责 iPad Sidebar、写作区和学习面板。
- `MacMainView` 负责 Mac Sidebar、主区和 Inspector。
- `PhoneMainView` 当前使用未绑定 selection 的 `TabView`。

本次需要把平台导航入口从“视觉位置调整”落实为状态结构调整：

- iPad 顶部条不再需要 `languageSpace` 作为主要展示内容，但仍可能用于状态文案。
- iPad Sidebar 底部需要新的轻量 `LanguageSpaceFooter` 或等价组件，表达当前空间、设置入口和隐私状态。
- Mac Sidebar 底部需要类似组件，但视觉密度应更适合桌面，避免变成大卡片。
- iPhone `TabView` 需要引入 `@State selectedTab` 和有边界的 swipe gesture。

## 6. 方案

推荐采用“语言空间下沉到 Sidebar 底部，iPhone 增加根级 Tab 滑动”的方案。

### 6.1 iPad 方案

iPad 顶部全局条调整为：

```text
[时间线切换] [搜索记录、词句、相似生活片段] [本地优先 · 未配置 AI] [学习面板切换]
```

iPad 左侧 Sidebar 底部调整为：

```text
英语空间 · B1        [设置]
中文 -> 英语
本地优先 · AI 未配置
```

设计规则：

- 底部区域不要做成大型卡片，避免视觉重量过高。
- 设置使用齿轮图标按钮，点击区域不少于 44pt。
- 语言空间区域可点击，但当前阶段只作为 Mock 入口。
- 左侧 Sidebar 收起时，该区域跟随收起。
- Sidebar 收起时，顶部不额外补一个语言空间按钮或设置按钮；用户通过时间线 / Sidebar 按钮召回这些低频入口。
- 顶部仍显示本地优先 / 未配置 AI 的轻量状态，避免隐私状态完全消失。
- 点击语言空间和设置入口在本阶段不得写入数据、不得创建真实路由，可以保持无副作用 Mock 行为。

### 6.2 Mac 方案

Mac Sidebar 保持：

```text
顶部：语迹 / LangoTrace
中部：当前空间内的主入口
底部：语言空间 · 设置
```

底部区域建议：

```text
英语空间 · B1        [设置]
中文 -> 英语
```

设计规则：

- Mac Sidebar 底部可比 iPad 更紧凑。
- 设置仍可作为普通按钮或 icon button，不抢占主区。
- 主区顶部不放语言空间切换。
- Sidebar 收起时，语言空间和设置入口跟随隐藏；主区保留 Sidebar 显示按钮，作为召回路径。
- 后续如果实现 `Settings...`、`Cmd+,` 或菜单栏入口，需要另开 worklog 或在 Mac UI 质量优化中处理。

### 6.3 iPhone 方案

iPhone `TabView` 引入明确 selection：

```text
今日 -> 记录 -> 练习 -> 记忆 -> 设置
```

手势规则：

- 左滑进入下一个 Tab。
- 右滑进入上一个 Tab。
- 到边界时不循环，例如 `今日` 右滑不跳到 `设置`。
- 只在一级 Tab 根页面生效。
- 底部 Tab 继续保留，并和手势后的当前页保持一致。
- 避免在文本输入、横向滚动和详情页中抢手势。
- 手势需要有明确阈值：水平位移应明显大于垂直位移，建议水平位移超过 60pt 后才触发。
- 纵向滚动时不能误触发 Tab 切换；如果后续页面存在横向卡片、文本编辑或录音控制，应在对应区域禁用该增强手势。

### 6.4 替代方案

方案 A：语言空间继续留在顶部。

- 优点：上下文最明显。
- 缺点：顶部太拥挤，语言空间高于搜索和当前任务，长期使用显得不够安静。

方案 B：语言空间移入设置页。

- 优点：顶部最简洁。
- 缺点：语言空间是当前资料库上下文，不应被藏到设置深处。

方案 C：语言空间下沉到 Sidebar 底部，设置同组展示。

- 优点：符合低频但重要上下文的位置；iPad/Mac 心智统一；顶部更聚焦任务。
- 缺点：Sidebar 收起时入口暂时不可见。

推荐方案 C。

## 7. 风险与边界

- 风险：Sidebar 收起后用户找不到语言空间入口。
  - 缓解：顶部 Sidebar 切换按钮始终可见；语言空间不是高频操作，当前阶段可接受。
- 风险：把设置下沉后违背“设置稳定可达”的长期规则。
  - 缓解：当前阶段把 Sidebar 展开按钮视为稳定召回路径；Mac 菜单栏和快捷键入口后续单独设计。
- 风险：底部区域过重，像新的卡片堆叠。
  - 缓解：使用低高度、低对比度、轻量分隔的底部工具区，不使用大卡片。
- 风险：iPhone 左右滑切 Tab 与系统返回、文本选择或横向滚动冲突。
  - 缓解：只在一级 Tab 根页面支持，手势阈值足够明确，不在详情页、编辑区、文本选择区、横向控件区或录音控制区全局响应。
- 风险：Mac 顶部不显示语言空间后上下文不明显。
  - 缓解：Sidebar 顶部保留产品名，底部保留当前语言空间；后续 Mac Toolbar 质量优化再决定是否补充轻量状态。
- 风险：当前仍是 Mock，用户误以为设置或语言空间切换可用。
  - 缓解：保持 Mock 入口为无副作用按钮，不引入真实数据写入。

## 8. 测试与验证

完成前至少执行：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
swiftlint --no-cache
swiftformat --lint . --cache ignore
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS' build
git diff --check
```

手动验证：

- iPad Pro 13-inch Simulator：
  - 顶部不再显示语言空间胶囊。
  - 顶部不再显示设置齿轮；设置入口下沉到 Sidebar 底部。
  - 左侧 Sidebar 底部显示语言空间、设置入口和本地 / AI 状态。
  - 收起 Sidebar 后语言空间区域隐藏；再次展开后恢复。
  - 收起 Sidebar 后，用户仍可通过顶部时间线 / Sidebar 按钮召回语言空间和设置入口。
  - 顶部搜索、本地状态和学习面板切换仍然清晰。
- Mac：
  - Sidebar 底部显示语言空间和设置入口。
  - 主区顶部不显示语言空间。
  - Sidebar 收起后，语言空间和设置入口隐藏；主区仍保留 Sidebar 显示按钮。
  - Sidebar 收起 / 展开后主区仍可读，不出现标题竖排或内容挤压。
- iPhone 17 Simulator：
  - 底部 Tab 正常显示。
  - 左滑切换到下一个 Tab。
  - 右滑切换到上一个 Tab。
  - 边界 Tab 不循环。
  - 纵向滚动不会误触发左右切换。
  - 底部 Tab 选中状态和滑动后的页面一致。

## 9. 用户确认记录

状态已从 `Draft` 进入实施。

```text
2026-05-17：用户确认本方案，可以开始实现。
```

## 10. 实施记录

- 新增 `PhoneRootTab` 纯 Swift 类型，固化 iPhone 一级 Tab 顺序、边界切换和横滑阈值。
- 新增 `PhoneTabNavigationTests`，用测试覆盖 Tab 顺序、边界不循环、左右切换和纵向滚动防误触发。
- 新增 `LanguageSpaceFooter`，作为 iPad / macOS Sidebar 底部语言空间与设置入口的共享语义组件。
- iPad 顶部 `PadWorkspaceBar` 移除语言空间胶囊和设置齿轮，仅保留时间线切换、搜索、本地 / AI 状态和学习面板切换。
- iPad Sidebar 底部改为 `LanguageSpaceFooter`，承载当前语言空间、设置入口和本地 / AI 状态。
- macOS Sidebar 将语言空间和设置入口下沉到底部，主区顶部不显示语言空间。
- iPhone `TabView` 引入 `selectedTab`，并接入根级横滑切换增强手势。

## 11. 验证结果

自动验证：

```text
2026-05-17：
- xcodegen generate：通过。
- swift test --package-path Packages/LangoTraceCore：通过，8 个 Swift Testing 测试通过。
- swiftformat --lint . --cache ignore：通过，0 个文件需要格式化。
- swiftlint --no-cache：通过，0 violations。
- xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build：通过。
- xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build：通过。
- xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS' build：通过。
- git diff --check：通过。
```

人工验收：

```text
2026-05-17：
- iPhone 17 Simulator：创建语言空间后进入主体页面；从“记忆”左滑进入“设置”，右滑回到“记忆”；纵向拖动未触发 Tab 切换。
- iPad Pro 13-inch (M5) Simulator：顶部不再显示语言空间胶囊和设置齿轮；左侧 Sidebar 底部显示当前语言空间、设置入口和“本地优先，AI 未配置”；收起 Sidebar 后这些入口隐藏，再次展开后恢复。
- macOS Debug App：Sidebar 底部显示当前语言空间和设置入口；主区顶部不显示语言空间；收起 Sidebar 后语言空间和设置入口隐藏，主区仍可读，并保留 Sidebar 显示按钮。
```
