# macOS Sidebar 点击命中修复方案

状态：Verified
类型：bug
创建日期：2026-05-18
最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户提供 macOS 左侧栏目截图，指出红框区域内各菜单项存在点击失效问题，要求深入排查。
- 当前状态：已完成只读排查、方案复查、代码修复和验证收口。
- 2026-05-18：按系统架构师和资深 Mac 交互设计师视角复查方案，补充组件边界、Mac 交互要求、测试边界和人工验证标准。
- 2026-05-18：用户确认根据本方案立即实施优化和修复。

## Bug 描述

macOS 主界面左侧栏目中的 `今日`、`记录库`、`练习`、`记忆`、`导入导出` 菜单项视觉上占据了侧栏宽度，但在实际点击时容易出现点击不生效。截图中红框区域暴露的问题是：用户会自然点击菜单项行内空白区域，而不是精确点击文字本身；当前实现没有把完整行区域稳定声明为命中区域。

## 复现方式

1. 启动 macOS 版本并进入主工作台。
2. 保持左侧 Sidebar 显示。
3. 在 `记录库`、`练习`、`记忆` 或 `导入导出` 行内，点击文字右侧或行内边距区域。
4. 观察主区标题、内容、Inspector 是否切换。

## 预期行为

- 每个侧栏菜单项的整行视觉区域都可点击。
- 鼠标悬停时有明确反馈，用户能判断该区域可交互。
- 键盘焦点和辅助功能能识别这些菜单项。
- 右键菜单或等效上下文能力至少不弱于当前 iPad 侧栏控件标准。

## 实际行为

- `MacMainView.sidebar` 中每个菜单项是 `Button`，但按钮 label 的可命中区域依赖 `SideItem` 内部内容。
- `SideItem` 对未选中状态使用 `Color.clear` 背景，且没有 `.contentShape(Rectangle())`。
- Mac 侧栏菜单项没有 `.focusable()`、`.onHover` 或 `.contextMenu`，交互线索弱于 iPad 侧栏。
- 当前选中状态只通过 `accessibilityValue` 表达，没有显式 `.accessibilityAddTraits(.isSelected)` 或等价选中语义。
- 视觉上整行像可点击项，但实际可点击区域容易收缩到文字和非透明绘制区域附近。

## 根因分析

根因是 Mac 侧栏菜单项的视觉区域和 SwiftUI 命中区域没有显式对齐。

涉及实现：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift:184` 到 `201`：`ForEach(MacWorkspaceSection.allCases)` 渲染侧栏按钮。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift:69` 到 `91`：`SideItem` 负责菜单项视觉样式。

当前 `SideItem` 使用 `.frame(maxWidth: .infinity)` 和 `.padding(12)` 制造整行视觉布局，但没有 `.contentShape(Rectangle())`。在 SwiftUI 中，透明区域不应被默认当作可靠命中区域依赖；未选中状态下 `.background(Color.clear)` 也不会提供清晰的交互反馈。由此造成“看起来是一整行按钮，实际点击空白处不稳定”的体验。

置信度：90%

## 置信度依据

- 截图红框标注的是菜单项整行区域，而非底部工具区或主内容区。
- `MacMainView` 已经把这些菜单项包装为 `Button`，说明不是 action 完全缺失。
- `selectSection(_:)` 会同步更新 `selectedSection` 并重置 `route = .overview`，主内容分发在 `MacWorkspaceContentView` 中存在完整路径。
- `SideItem` 没有显式 hit shape，也没有 hover/focus/context 交互增强。
- `SideItem` 当前只在 `MacMainView` 中被使用，因此将其替换或收敛为 Mac 专用组件不会影响 iPhone / iPad 共享内容组件。
- iPad 侧栏的 `FilterPill` 和 `EntryTimelineRow` 已经具备 hover、focus 和 context 线索，Mac 侧栏没有达到同等交互标准。

## 备选原因

- 透明 overlay 截获事件：当前排查未发现 Mac sidebar 上方有覆盖红框区域的 overlay 或 zIndex 内容。
- 路由切换后内容差异不明显：确实可能加重“点击没反应”的感知，但不是主要根因；`selectedSection` 绑定和内容分发都存在。
- 底部 `LanguageSpaceFooter` 的 popover 截获事件：截图红框在顶部菜单区，且 popover 只在底部工具区触发后出现，不符合常态复现路径。

## 现状描述

macOS 工作台采用自定义 `HStack` 三栏布局，而不是系统 `NavigationSplitView` 的 List selection。该选择本身符合当前早期 App Shell 和自定义视觉方向，但自定义 Sidebar 必须自行承担完整命中区域、hover、focus、辅助功能和回归测试。

当前测试只覆盖了 `MacFooterAction` 路由是否映射到可见内容，没有覆盖 Mac sidebar 菜单项的命中区域和交互 affordance。

## 目标

- 修复 Mac 侧栏菜单项整行点击命中。
- 增加 hover/focus/context 交互线索，使其符合 macOS 桌面控件预期。
- 补充选中态语义，使 VoiceOver、键盘焦点和视觉选中状态一致。
- 保持现有 `MacWorkspaceSection`、`MacWorkspaceRoute` 和三栏布局，不引入新的持久化状态。
- 增加轻量回归测试，防止后续移除 `.contentShape(Rectangle())` 或 Mac 侧栏交互能力。

## 范围

包含：

- `SideItem` 或新增 Mac 专用 sidebar item 组件的点击命中修复。
- `MacMainView.sidebar` 的最小接线调整。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/` 下新增或扩展源码级回归测试。
- 人工验证 macOS 运行时点击、hover、键盘焦点和 VoiceOver 语义。

不包含：

- 不改成 `NavigationSplitView`。
- 不重做 macOS 信息架构。
- 不新增真实导入导出、搜索、AI Provider、同步或数据库能力。
- 不改变语言空间、设置和底部状态图标的产品决策。
- 不把 sidebar section 选择持久化到语言空间、数据库、同步 manifest 或用户偏好。

## 证据与决策依据

- `docs/spec/002-navigation-and-routing.md` 要求 macOS 使用 Sidebar selection、主工作区和 Inspector，且 Sidebar 底部承载当前语言空间、设置、AI Provider 和同步状态。
- `docs/spec/003-ui-design-system.md` 要求可点击区域清晰、状态图标支持点击或键盘触发说明，macOS 可更紧凑但不能牺牲可用性。
- `docs/spec/004-swiftui-architecture.md` 要求页面闭环阶段区分平台外壳和共享内容，Mac 外壳负责 Sidebar section、route、toolbar、Inspector 和 feature store 注入。
- SwiftUI 任务参考要求优先使用 `Button`，当前代码已经使用 `Button`，问题集中在命中区域和交互反馈没有显式声明。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/MacSidebarHitTestingTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadSidebarControls.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceFooter.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

## 涉及的文档路径

- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/plans/done/2026-05-18-bug-mac-sidebar-hit-testing.md`

## 实施方案

1. 给 Mac 侧栏菜单项增加可测试的交互约束。
   - 在 `MacSidebarHitTestingTests` 中读取最终承载 Mac 侧栏组件的源文件。
   - 断言 Mac sidebar item 组件包含 `.contentShape(Rectangle())`、`.focusable()`、`.onHover`、`.contextMenu` 和显式选中态辅助语义。
   - 断言 `MacMainView.sidebar` 仍通过 `selectSection(section)` 统一处理左侧一级 section，避免每个按钮分散写路由逻辑。

2. 修复侧栏菜单项组件。
   - 优先拆出 `MacSidebarItem`，参数为 `title`、`subtitle`、`active` 和 `action`，让 Mac 专用交互留在 Mac 组件内。
   - 如果保留 `SideItem` 名称，必须先确认它仍只由 Mac 侧栏使用；若未来被 iPad 或共享内容复用，应立即改名并隔离平台职责。
   - 在 label 内部完整视觉区域后追加 `.contentShape(Rectangle())`。
   - 给菜单项设置稳定高度或最小高度，建议不低于 56pt；视觉紧凑可以保留，但命中区域不能小于当前文字块加内边距。
   - 未选中项在 hover 时使用轻量 `elevatedPaper` 或 `surfaceRaised` 背景，选中项继续保持 `surfaceRaised` 与 accent 描边。
   - Button 保持 `.buttonStyle(.plain)`，不改变现有视觉层级。

3. 补齐 Mac 侧栏按钮行为。
   - 在 Mac 专用按钮组件中给每个 Button 增加 `.focusable()`。
   - 增加 `.onHover` 所需状态时，封装到组件内部，避免 `MacMainView` 持有一组 hover 状态。
   - 增加 `contextMenu`，至少提供切换到对应 section 的同名命令；如果后续发现该菜单没有实际增益，可在实施记录中说明并保留更关键的 full-row hit、hover 和 focus。
   - 增加 `.accessibilityAddTraits(.isSelected)` 或等价实现，使选中项不是只靠文字 value 表达。
   - 如使用 `.help(...)`，内容应是 section 名称或简短用途，不加入未实现能力承诺。

4. 验证路由没有被破坏。
   - 运行 `swift test --package-path Packages/LangoTraceUI`。
   - 修复涉及 macOS UI 外壳，完整收口必须运行 `scripts/verify.sh`；如果环境导致无法完成，需要记录失败命令、失败原因和剩余风险。

## 回归测试方案

- 增加源码级测试，确认 Mac 侧栏 item 显式声明完整命中区域和基础桌面交互 affordance。
- 增加源码级测试，确认 Mac 侧栏 section 按钮由单一组件承载，并且 `selectSection(section)` 仍是统一入口。
- 继续保留 `PageClosureStateTests.macFooterActionsRouteToVisibleWorkspaceContent`，避免底部工具区路由回归。
- 源码级测试不能替代真实坐标点击。若本轮不引入 UI 自动化，必须执行人工运行时复查；如果后续引入 UI 自动化，再补充真实点击菜单项空白区域的端到端测试。

## 复查方法

人工复查：

1. 启动 macOS App。
2. 点击每个菜单项文字右侧空白区域。
3. 确认主区标题分别切换到 `今日`、`记录库`、`练习`、`记忆`、`导入导出`。
4. 鼠标悬停时确认未选中项有可见反馈。
5. 用键盘焦点导航确认菜单项可获得焦点。
6. 使用 VoiceOver 或 Accessibility Inspector 检查选中项有 selected 语义。
7. 点击当前已选中的菜单项，确认不会进入错误 route 或丢失当前语言空间上下文。

代码复查：

1. 检查 `SideItem` 或 Mac 专用组件是否有 `.contentShape(Rectangle())`，且该 modifier 作用在完整视觉矩形上。
2. 检查 `MacMainView.sidebar` 是否仍通过 `selectSection(_:)` 统一路由。
3. 检查没有把 sidebar section 状态写入语言空间、数据库或同步模型。
4. 检查没有把 hover state 提升到全局 store、language space 或 repository。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
git diff --check
git status --short
```

完整收口时运行：

```bash
scripts/verify.sh
```

## 文档影响检查

本修复属于 macOS 侧栏交互细节，不改变导航规范、UI 规范、SwiftUI 架构规范或 ADR。完成后只需要更新本任务方案的实施记录、验证结果和状态；无需新增 ADR。

如果实施过程中决定从自定义 Sidebar 改为 `NavigationSplitView` / `List(selection:)`，则不再属于本方案的最小 bug 修复范围，必须先回到本方案记录架构取舍，并重新评估 `docs/spec/002-navigation-and-routing.md` 与 `docs/spec/004-swiftui-architecture.md` 是否需要更新。

## 实施记录

- 2026-05-18：完成只读排查。根因定位为 Mac 侧栏菜单项视觉区域与命中区域未显式对齐，尚未修改代码。
- 2026-05-18：完成方案复查。结论：方案方向可行，但需要优先拆出 Mac 专用 sidebar item，补充选中态辅助语义、最小命中高度、源码级回归和人工运行时验证。
- 2026-05-18：完成 TDD 红灯验证。在 `PremiumUIBehaviorTests` 临时加入 Mac sidebar 约束后，`swift test --package-path Packages/LangoTraceUI` 失败，失败点为缺少 `MacSidebarItem`、`.contentShape(Rectangle())`、`.focusable()`、`.onHover`、`.contextMenu` 和 selected accessibility trait。
- 2026-05-18：完成代码修复。`MacMainView` 使用 Mac 专用 `MacSidebarItem` 承载 section 按钮；组件内部封装 hover state，设置 `minHeight: 56`、完整 `.contentShape(Rectangle())`、hover 背景、focus、context menu、help、accessibility value 和 selected trait；`selectSection(section)` 仍是统一入口。
- 2026-05-18：移除已无调用方的共享 `SideItem`，避免 Mac 专用交互继续留在共享学习内容组件中。
- 2026-05-18：将回归测试收敛为独立 `MacSidebarHitTestingTests`，避免继续扩大 `PremiumUIBehaviorTests`。

## 验证结果

已运行：

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
```

结果：

- `swift test --package-path Packages/LangoTraceUI` 通过；当前 UI package 共 39 个测试，7 个 suite。
- `scripts/verify.sh` 退出码 0；已完成 XcodeGen、工程列表、Core/Data/UI package 测试、iPhone/iPad/macOS 构建、SwiftLint、SwiftFormat、文档占位符扫描和 `git status --short`。
- `git diff --check` 退出码 0。
- 文档占位符扫描退出码 1，表示未匹配到占位符。
- SwiftLint 输出 3 个非 serious warning：`PremiumUIBehaviorTests.swift` 既有 line length / type body length 警告，以及 `LearningContentComponents.swift` file length 警告；脚本策略允许 warning，未阻断验证。

未完成：

- 未执行真实 macOS 坐标点击自动化或人工 VoiceOver 检查。本轮用源码级回归和完整构建验证覆盖结构性回归；真实运行时点击空白区域仍建议在下次手动 UI 走查时确认。

## 完成标准

- Mac 侧栏每个菜单项整行可点击。
- 菜单项有 hover、focus 和上下文入口。
- 选中项有明确视觉状态和辅助功能 selected 语义。
- `swift test --package-path Packages/LangoTraceUI` 通过。
- `scripts/verify.sh` 通过；若无法运行完整脚本，实施记录必须解释原因并列出已完成的替代验证。
- `git diff --check` 通过。
- 本方案更新实施记录和验证结果。

## 剩余风险

- 源码级测试只能防止实现结构回退，不能证明所有 macOS 运行时点击坐标都有效；真实 UI 点击仍需要人工或 UI 自动化复查。
- 如果后续改用系统 `NavigationSplitView` 或 `List(selection:)`，本方案中的自定义组件约束需要重新评估。
