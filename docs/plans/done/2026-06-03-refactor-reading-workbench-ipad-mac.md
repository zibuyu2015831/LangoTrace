# Reading Workbench iPad Mac Redesign

状态：Verified
自审核状态：Reviewed
类型：refactor
创建日期：2026-06-03
最后更新日期：2026-06-03

## 用户确认记录

- 2026-06-03：用户要求从专业 UI 设计师角度检查 iPad 端和 Mac 的阅读页面，并在保持风格一致性的前提下优化。
- 2026-06-03：已与用户确认本轮不是只做视觉统一，而是以“信息结构和交互也一起重整”为主。
- 2026-06-03：已向用户提出 `工作台重整` 方向，并获得“好，立即进行”的实现授权。

## 需求描述

当前 iPhone `阅读` 页已经重构为“资料库首页 + 独立阅读详情”，但 iPad 和 macOS 仍共用较早的工作台实现。现状虽然已有多栏，但左栏、正文区和 inspector 的职责边界仍不够清楚，导入 / 搜索 / 筛选 / 解释反馈在多个区域之间层级失衡，空状态和大屏工具区也没有和 iPhone 新阅读语言完成统一。本任务需要在保留大屏工作台优势的前提下，重整 iPad 和 macOS 的信息结构、交互承载和视觉节奏。

## 当前现状

- `ReadingLibraryView` 在 `platform == .pad` 和 `platform == .mac` 时共用 `desktopLibraryAndReader`，仅通过 `ReadingLayoutModel.primaryColumnCount` 区分是否显示 inspector。
- 左栏 `ReadingLibraryPane` 仍沿用偏表单式结构：标题、搜索、导入按钮、筛选器、列表和删除恢复纵向直排，资料库首页感较弱。
- 中栏阅读区缺少明确的阅读画布容器与空状态分层，未选中文档时只显示简单空状态。
- inspector 仍然偏“结果容器”，对 idle / loading / failed / selected 等状态的承载不够像大屏学习面板。
- iPad 和 macOS 虽然都有大屏 route，但没有形成“iPad 双主栏 + 轻 inspector”和“macOS 三栏工作台”的差异化表达。

## 目标

1. 保留大屏多栏阅读工作台，而不是回退为放大的 iPhone 详情页。
2. 明确三栏职责：资料库、正文、学习反馈互不争抢主焦点。
3. 让 iPad 更像“主内容优先 + 可收束 inspector”的学习桌面，让 macOS 更像真正的三栏阅读工作台。
4. 统一和 iPhone 新阅读页的产品语言：导入主路径、空状态质量、文档列表层级、解释反馈状态与整体安静感保持一致。
5. 在不改变 Reading domain、AI 请求边界和 TTS 边界的前提下完成这次 UI / 交互重整。

## 范围

- iPad / macOS 阅读工作台的信息结构和布局承载优化。
- 资料库侧栏、阅读画布、inspector 空状态和交互状态优化。
- 必要的 presentation model 补充和 UI package 单元测试更新。
- 页面清单事实源更新。

## 不做什么

- 不改变 iPhone 阅读首页和独立详情结构。
- 不引入新的 EPUB / PDF / HTML 导入能力。
- 不新增键盘快捷键、menu command 或 command palette；macOS 只做当前工作台内结构重整。
- 不实现新的阅读位置持久化、真实文本选择引擎、词典 UI 或后台全文朗读。
- 不改动 Reading repository、GRDB schema、解释请求契约或 TTS artifact 行为。

## 证据与决策依据

- `docs/spec/003-ui-design-system.md`：iPad / macOS 不应只是放大的 iPhone，辅助面板应是低干扰上下文，不是永久抢主视觉的大列。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`：iPad regular width 优先多栏，macOS 应使用 sidebar / toolbar / inspector 的桌面语义，并且状态必须通过文案与布局表达，而不只是颜色。
- `docs/platform-page-inventory.md`：iPad 和 macOS 阅读页已经进入真实 Reading AI / TTS 闭环，但文档中仍标注后续应强化 side inspector、三栏工作台和长文验收。
- 本轮 UI 审核结论：当前大屏问题不是缺少功能，而是资料库、阅读和反馈在一个工作台里仍未形成足够清晰的主次关系。

## 涉及代码路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`

## 涉及文档路径

- `docs/platform-page-inventory.md`
- `docs/plans/done/2026-06-03-refactor-reading-workbench-ipad-mac.md`

## 实施方案

1. 先补大屏阅读 presentation tests：
   - iPad layout 应表达“资料库 + 正文”为主，inspector 仍为 side panel，但不强制三主列同权。
   - macOS layout 应表达完整三栏工作台。
   - inspector 在无选择时应有明确 idle workspace 语义，而不是只显示弱占位。
2. 为 `ReadingLayoutModel` 补充更明确的工作台语义字段，避免只靠 `primaryColumnCount` 决定 UI。
3. 重构 `ReadingLibraryView` 的大屏分支：
   - iPad 使用更偏双主栏的结构，正文成为中心视觉焦点，inspector 保持次级宽度与外侧 gutter。
   - macOS 保持三栏，但加强 side surfaces、工具区和内容边界。
4. 重做 `ReadingLibraryPane` 大屏表达：
   - 把资料库标题、导入动作、搜索和筛选组合成更稳定的 library header。
   - 保持文档列表层级与 iPhone 一致，但让其更适合 sidebar / library 承载。
5. 强化阅读画布与 inspector：
   - 阅读区增加更明确的 header / canvas / empty state 分层。
   - inspector 对 idle / loading / failed / explained 状态做更完整表达。
   - 选中操作条保持靠近正文，不把解释结果重新塞回正文流。
6. 更新 `docs/platform-page-inventory.md` 中 iPad / macOS 阅读页事实，记录新的工作台承载方式。

## TDD 落点

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
  - 新增 iPad / macOS 工作台语义测试，覆盖 column emphasis、inspector presentation 和 layout intent。

## 复查方法

- 代码复查：确认 iPad / macOS 不再只是同一个大屏结构的轻微宽度差异。
- 结构复查：确认左栏只承担资料库职责，中栏只承担阅读职责，右栏只承担学习反馈职责。
- 交互复查：确认解释状态不再和正文空状态混杂，导入 / 搜索 / 筛选在大屏上有稳定层级。

## 验证命令

聚焦：

```bash
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
```

完整：

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

## 文档影响检查

- 需要更新 `docs/platform-page-inventory.md` 中 iPad 与 macOS 阅读页的当前承载事实。
- 若最终实现没有偏离现有 `docs/spec/003-ui-design-system.md` 和 `docs/spec/010-apple-platform-interaction-and-accessibility.md`，则无需修改 spec。

## 严格方案自审核记录

审核日期：2026-06-03
审核方式：主会话自审核
审核轮次：双轮
未使用隔离审查的原因：当前任务范围集中在同一组 Reading UI 文件内，且需要在同一上下文中连续完成大屏审查、TDD 落点和实现。
发现摘要：

- P0：如果继续只靠 `primaryColumnCount` 切换列数，iPad 与 macOS 的工作台差异仍会停留在视觉层，无法形成清楚的结构语义。已纳入实施方案第 2、3 步。
- P1：左栏当前仍偏表单和功能堆叠，不像稳定的阅读资料库侧栏。已纳入实施方案第 4 步。
- P1：inspector 对 idle / loading / failed 的承载过弱，会继续让大屏反馈区显得像临时结果盒。已纳入实施方案第 5 步。
- P1：需要先补工作台语义测试，再改生产代码。已纳入 TDD 落点。

写回修改：

- 明确本轮采用 `工作台重整`，而不是跨平台彻底同构。
- 明确 iPad 与 macOS 的分歧发生在工作台承载层，不触碰 Reading domain 和请求边界。
- 将页面清单更新列为必做收口项。

仍需用户确认的问题：无。用户已明确要求立即实现。
是否允许进入实现：允许。

## 实施记录

- 2026-06-03：创建 active plan，记录大屏阅读工作台重整方向、TDD 落点与验证命令。
- 2026-06-03：先补 `ReadingPresentationTests`，新增 iPad focused canvas 和 macOS balanced workbench 语义测试，确认大屏工作台重整前先出现失败。
- 2026-06-03：为 `ReadingLayoutModel` 增加 `workspaceStyle` 与 `showsPersistentInspector`，并按该语义重构 `ReadingLibraryView` 的大屏分支。
- 2026-06-03：重整大屏资料库侧栏、阅读画布和 inspector，统一导入 / 搜索 / 筛选头部层级，强化中栏阅读卡与右栏解释反馈状态。
- 2026-06-03：更新 `docs/platform-page-inventory.md` 中 iPad / macOS 阅读工作台事实；运行 `swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests`、`swift test --package-path Packages/LangoTraceUI` 与 `scripts/verify.sh`，全部通过。`scripts/verify.sh` 仍报告仓库既有 SwiftLint warning，但无 serious violation，`swiftformat --lint`、`check-docs` 与 `git diff --check` 均通过。

## 完成标准

- iPad 阅读页形成“资料库 + 阅读正文”为主、inspector 为次级学习反馈的工作台结构。
- macOS 阅读页形成清晰的三栏工作台，而不是放大的 iPad 或 iPhone 布局。
- 大屏资料库、阅读画布和 inspector 的空状态、解释反馈和工具区层级与 iPhone 新阅读页保持同一产品语言。
- 受影响 UI package 测试通过。
- 页面清单与代码事实一致。

## 剩余风险

- 本次任务不包含自动截图测试；iPad regular / compact 与 macOS 窄窗口仍需后续人工验收。
- macOS 菜单命令和更深的键盘交互不在本轮范围内，后续若强化桌面体验需要单独任务。
