# 工作记录：iPad 边缘滑动召回辅助面板

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/worklogs/2026-05-17-feature-collapsible-side-panels.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`

关联提交：

- 未提交

## 1. 背景

iPad 主界面已经形成“顶部全局条 + 左侧时间线 / 筛选 + 中间写作与双语正文 + 右侧学习面板”的工作台结构。当前左右辅助面板已经可以通过顶部图标按钮手动展开和收起，解决了专注写作、小窗口和沉浸学习时主内容被挤压的问题。

本次讨论的问题是：iPad 端是否应进一步支持通过边缘滑动手势控制辅助面板展开与折叠。

初步判断是：该能力可行，也符合 iPad 对侧栏边缘手势的使用预期，但不应替代当前顶部显式按钮。它更适合作为 iPad 工作台的辅助快捷交互，用于从边缘召回或隐藏左右面板。

这里的“边缘滑动”不是全屏左右滑切换布局，也不是记录翻页手势。它只表达一个空间管理动作：从屏幕边缘召回或隐藏当前工作台的辅助上下文。

## 2. 目标

本次需求如果进入实现，应达到以下结果：

- iPad 用户可以通过边缘滑动手势召回或隐藏左侧时间线面板。
- iPad 用户可以通过边缘滑动手势召回或隐藏右侧学习面板。
- 顶部图标按钮继续作为主要、可发现、可访问的显式入口。
- 手势不影响中间写作区的阅读、滚动、文本选择、逐句练习和未来图片 / 音频交互。
- 面板展开状态继续作为 `Transient UI state`，不进入 Core 模型、数据库、同步、语言空间或用户数据。
- iPhone 和 macOS 不因本次需求引入新的手势逻辑。
- 方案明确区分“空间管理上的左右对称”和“产品语义上的左右不对等”，避免把右侧学习面板误设计成另一组导航。

## 3. 范围

本次会处理：

- 在 iPad 主工作区增加受限的边缘滑动手势。
- 增加左右边缘窄热区或等价局部手势识别区域。
- 左边缘向右滑时显示左侧时间线面板。
- 左侧时间线已显示时，在左侧面板区域向左滑可隐藏左侧时间线。
- 右边缘向左滑时显示右侧学习面板。
- 右侧学习面板已显示时，在右侧面板区域向右滑可隐藏右侧学习面板。
- 复用现有 `isTimelineVisible` 和 `isLearningPanelVisible` 状态。
- 复用现有面板展开 / 收起动画，并继续尊重 Reduce Motion。
- 避免抢占系统边缘手势、ScrollView、文本选择和面板内部控件交互。
- 补充必要的手动验证记录。

## 4. 不做什么

本次不处理：

- 不在中间写作区做全屏横向滑动捕获。
- 不把手势作为唯一入口。
- 不移除顶部面板切换按钮。
- 不使用全屏横向滑动作为面板切换方式。
- 不使用 `defersSystemGestures(on:)` 抢占系统边缘手势。
- 不默认使用高优先级手势抢占子视图交互。
- 不引入侧栏宽度拖拽调整。
- 不持久化面板展开状态。
- 不设计自动响应式断点系统。
- 不在本次实现覆盖式浮层面板。
- 不改变 iPhone 底部 Tab 导航。
- 不改变 macOS Sidebar / Inspector 的按钮、菜单栏或快捷键方案。
- 不引入真实记录路由、数据库、AI、TTS、OCR、同步或 StoreKit 能力。

## 5. 分析

### 5.1 必要性

iPad 是语迹沉浸写作、双语对照、分句练习和图片 / 手写文章学习的重要设备。左右辅助面板可以提供时间线、筛选、句子讲解、词句提取、练习入口和请求预览，但它们不应长期挤压中间主工作区。

按钮已经满足基本可用性；边缘滑动的价值在于提升 iPad 触控体验：

- 用户专注写作时，可以从左边缘快速召回时间线。
- 用户进入学习状态时，可以从右边缘快速召回学习面板。
- 用户在 Split View 或 Stage Manager 小窗口中，可以更自然地隐藏辅助面板。
- 手势符合 iPad 对侧栏和辅助面板的空间管理心智。

因此该需求不是 MVP 功能闭环的阻塞项，但适合作为 iPad 工作台体验质量优化。

### 5.2 左右面板的产品语义

左侧时间线和右侧学习面板在空间管理上都属于可召回辅助面板，但它们在产品语义上不等价：

- 左侧时间线 / 筛选更接近记录导航、历史上下文和资料选择。
- 右侧学习面板更接近 Inspector、Learning Assistant 和当前记录的学习解释。
- 左侧帮助用户“回到其他记录或筛选当前资料库”。
- 右侧帮助用户“深入理解当前记录并进入练习”。

因此本次手势只统一它们的空间管理方式，不改变二者的信息层级。后续实现不能因为二者都支持边缘滑动，就把右侧学习面板设计成与左侧时间线等价的导航区域。

### 5.3 可行性

现有 `PadMainView` 已经使用本地 SwiftUI 状态控制左右面板：

- `isTimelineVisible`
- `isLearningPanelVisible`

顶部 `PadWorkspaceBar` 已经通过按钮触发对应状态切换。边缘滑动只需要作为新的输入方式复用这些状态，不需要改变模型、路由、存储或同步边界。

### 5.4 手势与用户心理

边缘滑动的价值来自熟练用户对 iPad 空间管理的自然预期，而不是显式教程或强提示。

设计原则：

- 不做教程弹窗。
- 不做浮层提示。
- 不把手势写成首屏说明。
- 用户只通过顶部按钮也能完成全部操作。
- 手势作为渐进发现的快捷方式存在，服务长期使用时的效率。

这与语迹“安静、清晰、长期可读”的产品气质一致，避免为了一个快捷交互增加解释负担。

### 5.5 风险

主要风险是手势冲突和误触：

- iPadOS 系统边缘手势可能与 App 内边缘手势重叠。
- 中间写作区未来会涉及文本选择、滚动、句子练习、图片浏览和音频控制。
- 全屏横向手势容易导致用户在阅读或操作内容时意外隐藏面板。
- 如果使用过高优先级抢占手势，可能破坏 ScrollView、文本输入或子视图交互。
- 外接键盘、触控板、指针和 Apple Pencil 场景下，横向拖动也可能承担选择、拖放或滚动语义。

因此手势必须限制在边缘或当前显示的面板区域，不能覆盖整个主工作区。

### 5.6 窄窗口与响应式边界

本次需求会在 iPad 横屏、竖屏、Split View 和 Stage Manager 中出现，但当前阶段不实现完整响应式断点系统。

边界如下：

- 本次仍沿用现有挤压式三栏布局。
- 窄窗口下不承诺覆盖式面板。
- 极窄宽度下如果展开面板会导致主内容不可读，应优先通过现有按钮或手势隐藏面板。
- 如果后续需要在窄窗口中使用覆盖式面板、抽屉式面板或自动断点，必须单独写方案。

也就是说，本次只增加一种辅助输入方式，不重新定义 iPad 工作台在各种窗口宽度下的布局策略。

## 6. 方案

推荐方案：边缘滑动作为辅助快捷方式，顶部按钮保持主入口。

核心原则：

- 本需求不是全屏左右滑切换布局，而是边缘区域召回 / 隐藏辅助面板。
- 左侧时间线和右侧学习面板在空间管理上对称，在产品语义上不等价。
- 实现不得抢占系统边缘手势，不使用 `defersSystemGestures(on:)`。
- 手势不得成为唯一入口，顶部按钮仍是主入口和无障碍入口。
- 窄窗口下本次不承诺完整响应式覆盖面板，相关策略后续单独设计。

交互规则：

- 左侧时间线隐藏时，从左屏幕边缘向右滑，显示左侧时间线。
- 左侧时间线显示时，在左侧面板区域向左滑，隐藏左侧时间线。
- 右侧学习面板隐藏时，从右屏幕边缘向左滑，显示右侧学习面板。
- 右侧学习面板显示时，在右侧面板区域向右滑，隐藏右侧学习面板。
- 中间写作和学习内容区域不响应全局左右滑动。

命中区域：

- 面板隐藏时，只在对应屏幕边缘的窄热区识别召回手势。
- 边缘热区建议先控制在 16-32pt，具体宽度以真机验证为准。
- 面板显示时，隐藏手势优先挂在对应面板区域。
- 热区不能遮挡顶部按钮、文本输入、滚动内容、列表项、筛选按钮或语言空间底部工具区。

触发规则：

- 横向位移必须明显大于纵向位移。
- 位移达到保守阈值后才触发。
- 手势结束时只触发一次状态变化。
- 如果当前状态已经符合目标状态，不重复切换。
- 不应在 `onChanged` 阶段实时改变布局，避免拖动过程中的抖动和误触。
- 优先使用局部普通手势；只有在真机验证证明无法满足需求时，才评估更高优先级手势。

可访问性与输入方式：

- VoiceOver 用户仍通过顶部图标按钮操作面板。
- 外接键盘用户本次不新增快捷键；如后续增加，需单独评估与 iPadOS 文本编辑和系统快捷键冲突。
- 指针和触控板用户不要求通过横向滚动或拖动触发面板，避免和滚动、选择、拖放混淆。
- 手势本身不作为唯一可访问路径，不要求单独暴露无障碍动作。

替代方案：

1. 不做手势，只保留按钮。
   - 优点：最稳定、最可发现、无手势冲突。
   - 缺点：iPad 触控体验不够自然，边缘召回面板不够顺手。

2. 全屏左右滑控制面板。
   - 优点：实现和理解都直接。
   - 缺点：误触风险高，容易干扰写作区和未来内容交互，不推荐。

3. 使用系统 `NavigationSplitView` / 标准 Sidebar 行为重构。
   - 优点：更贴近系统侧栏模型。
   - 缺点：当前页面是语迹自定义三栏学习桌面，不只是主从详情导航；为一个手势重构导航层级成本过高，不适合当前阶段。

## 7. 风险与边界

- 该能力只属于 iPad UI 层，不改变产品信息架构。
- 面板展开状态仍是瞬时 UI 状态，不进入语言空间、数据库、同步 manifest、对象存储或用户设置。
- 顶部按钮必须保留，以满足可发现性、键盘 / VoiceOver 访问和明确状态表达。
- 手势必须避免抢占中间写作区交互。
- 手势不应覆盖系统边缘手势，不使用 `defersSystemGestures(on:)`。
- 手势不应作为隐藏功能承担关键路径；不会手势的用户也必须能自然完成同一任务。
- 热区宽度、触发阈值和手势优先级必须根据真机验证调整。
- 如果真机验证发现与系统边缘手势或文本交互冲突，应优先撤回手势，保留按钮方案。
- macOS 不复制 iPad 滑动手势；macOS 继续优先按钮、菜单栏和快捷键。
- iPhone 不引入侧栏手势或抽屉导航。

后续可扩展方向：

- 响应式面板策略：宽屏挤压式，窄屏覆盖式，极窄只保留主内容。
- 设备 / 窗口级偏好：未来可记住 iPad 横屏、竖屏或 Stage Manager 的面板状态，但不能进入语言空间主数据。
- UI 层 Panel Controller：如果 iPad 和 macOS 面板行为继续增加，可抽出只属于 UI 层的状态和手势 helper；当前阶段不提前抽象。

## 8. 测试与验证

实现完成前建议运行：

```bash
xcodegen generate
xcodebuild -list -project LangoTrace.xcodeproj
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
git status --short
```

手动验证建议：

- iPad 横屏：左侧隐藏时，从左边缘右滑可以显示时间线。
- iPad 横屏：左侧显示时，在左侧面板内左滑可以隐藏时间线。
- iPad 横屏：右侧隐藏时，从右边缘左滑可以显示学习面板。
- iPad 横屏：右侧显示时，在右侧面板内右滑可以隐藏学习面板。
- iPad 横屏：左右面板都隐藏时，可以分别从左右边缘召回对应面板。
- iPad 横屏：左右面板都显示时，在各自面板内滑动隐藏，不影响中间内容滚动。
- iPad 竖屏：顶部按钮和边缘手势都可以控制面板，主内容不能被永久挤压到不可读。
- Split View 半屏：手势不应导致主内容完全不可用。
- Stage Manager 窄窗口：手势不应造成不可恢复布局，顶部按钮仍可恢复。
- 中间写作区纵向滚动不误触发面板切换。
- 中间写作区横向轻微移动不误触发面板切换。
- 中间写作区文本选择、句子练习和音频控件不被边缘手势抢占。
- 左侧列表项、筛选 pill、语言空间底部工具区的点击和滚动不被隐藏手势破坏。
- 从屏幕最边缘、靠近边缘但非最边缘、面板内部三类位置分别验证手势行为。
- 顶部按钮仍可正常控制左右面板。
- Reduce Motion 开启时，面板状态变化不使用干扰性动画。
- VoiceOver 开启时，顶部按钮仍能读出正确 label、value 和操作意图。

验证优先级：

- 真机验证优先于模拟器验证，因为系统边缘手势、Stage Manager、触控板和文本选择行为在模拟器中不完全可靠。

## 9. 用户确认记录

状态为 `Draft` 时不能开始实现。

用户确认后记录：

```text
2026-05-17：用户确认本方案，可以开始实现。
```

## 10. 实施记录

2026-05-17 已实施：

- 为 `Packages/LangoTraceUI` 增加 `LangoTraceUITests` 测试 target。
- 新增 `PadPanelGestureAction` 和 `PadPanelGestureContext`，把边缘热区、面板区域、横向位移阈值和纵向误触过滤收敛到 UI 层纯 Swift helper。
- 新增 `PadPanelGestureTests`，覆盖：
  - 左侧隐藏时只允许从左边缘右滑显示时间线。
  - 右侧隐藏时只允许从右边缘左滑显示学习面板。
  - 左右面板显示时，只允许从对应面板区域滑动隐藏。
  - 中间工作区横向拖动不会触发面板状态变化。
  - 纵向位移过大的拖动不会触发面板状态变化。
- 更新 `PadMainView`：
  - 隐藏左侧时间线时，在左侧 32pt 透明热区识别召回手势。
  - 隐藏右侧学习面板时，在右侧 32pt 透明热区识别召回手势。
  - 左侧时间线显示时，在左侧面板区域使用局部普通手势识别隐藏动作。
  - 右侧学习面板显示时，在右侧面板区域使用局部普通手势识别隐藏动作。
  - 手势只在 `onEnded` 后根据阈值应用一次状态变化，不在拖动过程中实时改变布局。
  - 顶部按钮逻辑保持不变，仍是主要可发现入口。

实现偏离说明：

- 未使用 `defersSystemGestures(on:)`。
- 未使用全屏横滑手势。
- 未引入持久化偏好、覆盖式面板或响应式断点。
- 由于 SwiftUI 手势默认使用局部坐标，右侧面板和右侧边缘热区通过 `startXOffset` 折算到工作区坐标，再交给 `PadPanelGestureAction` 判断。

## 11. 验证结果

已执行：

```bash
xcodegen generate
xcodebuild -list -project LangoTrace.xcodeproj
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
swiftformat . --cache ignore
swiftlint --no-cache
swiftformat --lint . --cache ignore
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
```

结果：

- `xcodegen generate` 成功生成工程。
- `xcodebuild -list -project LangoTrace.xcodeproj` 成功列出 `LangoTrace-iOS`、`LangoTrace-macOS` 和本地 package schemes。
- `swift test --package-path Packages/LangoTraceCore` 通过，16 个 Testing 测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，3 个 Testing 测试通过。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build` 成功，输出 `BUILD SUCCEEDED`。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build` 成功，输出 `BUILD SUCCEEDED`。
- `swiftformat . --cache ignore` 格式化 1 个文件。
- `swiftlint --no-cache` 通过，0 violations。
- `swiftformat --lint . --cache ignore` 通过，0 个文件需要格式化。
- 文档文件列表检查已执行。
- 文档占位词扫描无命中。

剩余风险：

- 尚未做 iPad 真机手势验证。系统边缘手势、Stage Manager、触控板、文本选择与模拟器行为可能不完全一致；进入真机 UI 验证阶段时，应按本 worklog 第 8 节补充手动验证。
