# Reading Library UI Redesign

状态：Verified
自审核状态：Reviewed
类型：refactor
创建日期：2026-06-03
最后更新日期：2026-06-03

## 用户确认记录

- 2026-06-03：用户要求对当前已实现的 `阅读` 界面进行重新设计，并先完成一次专业 UI 审核。
- 2026-06-03：基于审核结果，用户确认采用 `资料库首页型` 方向，并要求一次性完整实现本次 UI 优化整改任务。

## 需求描述

当前 iPhone `阅读` Tab 已接入真实资料库、Markdown / 纯文本阅读、显式 AI 解释和显式 TTS，但首屏将资料库、正文和 inspector 纵向堆叠，界面更像纵向切片验证页而不是正式产品页面。本任务需要将 iPhone 阅读页重构为“资料库首页 + 独立阅读详情”的正式结构，并同步优化空状态、导入主路径、筛选器、文档列表和阅读详情中的解释 / 听操作承载方式。

## 当前现状

- `ReadingLibraryView` 在 `platform == .phone` 时直接承载资料库、正文和 inspector，同一页面内通过 `ViewThatFits` 落成纵向堆叠结构。
- 未选中文档时，正文区域会显示英文 Markdown 占位内容，和资料库空状态重复表达同一事实。
- iPhone 没有独立的阅读详情 route；用户在阅读 Tab 内同时看到管理控件、正文和解释承载区。
- `ReadingPresentationModels` 将 iPhone inspector 语义定义为 `bottomSheet`，但当前视图实现没有真正使用 sheet。

## 目标

1. 将 iPhone `阅读` Tab 改为正式资料库首页，而不是资料库 / 正文 / inspector 三段纵向拼接页。
2. 在 iPhone 上引入独立阅读详情 route，打开文档后进入单独详情，而不是继续在 Tab 首页内联阅读。
3. 清理重复空状态和中英混杂占位内容，保证界面 chrome 完全遵守当前界面语言。
4. 收敛导入主路径：首屏只保留清晰的资料库 hero、搜索、筛选和文档列表。
5. 让解释 / 听操作在阅读详情内承载，iPhone 使用 bottom sheet 作为解释结果容器，符合现有 layout model。

## 范围

- iPhone 阅读首页信息结构重做。
- iPhone 阅读详情路由与详情界面。
- 阅读空状态、文档列表、筛选器、导入按钮和解释 bottom sheet 的 UI 优化。
- 必要的本地化文案补充和页面清单更新。
- 对应 UI package 单元测试更新。

## 不做什么

- 不改变 Reading domain 的数据模型、AI 请求边界、TTS 边界、导入 adapter 或 GRDB schema。
- 不新增 EPUB / PDF / HTML 导入能力。
- 不为 iPad / macOS 引入新的信息架构；大屏仍保留资料库 + 正文 + inspector 的工作台式布局。
- 不实现新的阅读位置持久化、最近阅读排序策略或批量管理能力。

## 证据与决策依据

- `docs/spec/003-ui-design-system.md`：iPhone 一次聚焦一个任务，空状态不能裸文本堆叠，不做卡片套卡片，不混淆界面语言。
- `docs/spec/002-navigation-and-routing.md`：阅读属于 iPhone 一级主目的地，阅读详情属于主流程路由；iPhone inspector 适合用 sheet / bottom sheet 承载短流程学习反馈。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`：iPhone UI 不能把高频内容和低频管理混在同一拥挤长页；高频操作应优先原位反馈或轻量 sheet。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：界面 chrome 必须遵守当前界面语言，不能用英文占位内容补空状态。
- UI 审核结论：当前页面的核心问题是信息结构错位，而不是局部视觉 token 不足。

## 涉及代码路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingLibraryStoreTests.swift`

## 涉及文档路径

- `docs/platform-page-inventory.md`
- `docs/plans/done/2026-06-03-refactor-reading-library-ui-redesign.md`

## 实施方案

1. 先用 TDD 为这次重构补充 UI presentation / route 级测试：
   - iPhone 阅读首页只承载资料库首页结构，不再要求同屏正文和 inspector。
   - iPhone 阅读详情需要独立 route，并与 `ReadingLayoutModel.phone` 的 `bottomSheet` inspector 语义对齐。
2. 将 `ReadingLibraryView` 拆成平台分支：
   - `phone` 使用资料库首页视图。
   - `pad` / `mac` 继续使用多栏阅读工作台。
3. 在 `PhoneMainView` 增加阅读详情 route，并将文档打开动作改为“打开后 push 到阅读详情”。
4. 重做 iPhone 资料库首页：
   - 顶部 hero 收敛为标题、短说明、主副导入动作。
   - 搜索框和筛选器形成同一资料库工具区。
   - 空状态使用单一高质量卡片，不再叠加英文正文占位。
   - 文档列表行增强层级和点击语义。
5. 实现 iPhone 阅读详情：
   - 标题、轻量 metadata、独立阅读正文。
   - 选中文本后出现轻量操作条。
   - 解释结果改为 bottom sheet；TTS 仍为显式原位动作。
6. 更新页面清单事实源，记录 iPhone 阅读首页与阅读详情的新承载方式。

## TDD 落点

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
  - 新增 iPhone 阅读首页 / 阅读详情 presentation intent 测试。
- 如 route / helper 需要提炼为纯模型，测试应优先覆盖该模型，而不是靠截图验证结构变化。

## 复查方法

- 代码复查：确认 iPhone 阅读 Tab 不再把正文和 inspector 直接堆在首页。
- 交互复查：确认点开文档后进入独立阅读详情，解释通过 sheet 承载。
- 文案复查：确认空状态和默认界面不再混入英文占位正文。

## 验证命令

聚焦：

```bash
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
swift test --package-path Packages/LangoTraceUI --filter ReadingLibraryStoreTests
```

完整：

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

## 文档影响检查

- 需要更新 `docs/platform-page-inventory.md` 中 iPhone 阅读页的入口、当前状态、代码路径和能力边界。
- 若最终实现与 `docs/spec/002`、`003`、`010` 一致，则无需再修改 spec；若实现偏离，需要在同任务内补文档。

## 严格方案自审核记录

审核日期：2026-06-03
审核方式：主会话自审核
审核轮次：双轮
未使用隔离审查的原因：当前会话需要在同一上下文内连续完成 UI 审核、任务方案落盘与实现。
发现摘要：

- P0：当前 iPhone 阅读页缺少独立阅读详情 route，资料库首页与正文 / inspector 同屏堆叠，违背导航和 UI 规范。已纳入实施方案第 3、5 步。
- P1：空状态存在重复表达和语言边界问题，英文 Markdown 占位会和中文空状态冲突。已纳入实施方案第 4、5 步。
- P1：现有 `ReadingLayoutModel.phone` 定义 bottom sheet inspector，但视图层未兑现。已纳入实施方案第 5 步。
- P1：需要先补 UI package 测试，再改生产代码。已写入 TDD 落点和验证命令。

写回修改：

- 将用户确认的 `资料库首页型` 方案写入目标和实施方案。
- 明确 iPhone 与 iPad / macOS 的结构分叉仅发生在 UI 承载层，不触碰 Reading domain 数据边界。
- 明确页面清单需要同步更新。

仍需用户确认的问题：无。用户已明确授权一次性完整实现整改任务。
是否允许进入实现：允许。

## 实施记录

- 2026-06-03：创建 active plan，写入 UI 审核结论、用户确认和实现授权。
- 2026-06-03：先补 `ReadingPresentationTests`，为 iPhone 阅读首页与独立详情 route 建立失败测试，再新增 `ReadingPhoneNavigationState` 和 phone route 行为。
- 2026-06-03：重构 `ReadingLibraryView`，将 iPhone 改为资料库首页，拆出独立 `ReadingDocumentDetailView`，并把解释结果改为详情内 bottom sheet。
- 2026-06-03：优化文档列表、筛选菜单、空状态卡片和详情头部信息；同步更新 `docs/platform-page-inventory.md`。
- 2026-06-03：运行 `swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests`、`swift test --package-path Packages/LangoTraceUI --filter ReadingLibraryStoreTests`、`swift test --package-path Packages/LangoTraceUI` 与 `scripts/verify.sh`，全部通过；`scripts/verify.sh` 中仍存在仓库既有 SwiftLint warning，但无 serious violation，`check-docs`、`git diff --check` 与全量验证均通过。

## 完成标准

- iPhone 阅读 Tab 首屏只承载正式资料库首页结构。
- 点开阅读文档后进入独立阅读详情，不再在首页同屏显示正文和 inspector。
- iPhone 空状态不再出现重复表达或英文占位正文。
- 解释结果在 iPhone 详情中通过 bottom sheet 承载，TTS 仍保持显式点击触发。
- 受影响 UI package 测试通过。
- 页面清单与代码事实一致。

## 剩余风险

- 本次任务不包含真实截图测试自动化；iPhone 视觉细节仍需模拟器人工复查。
- iPad / macOS 仍沿用当前阅读工作台结构，本次不顺带优化其大屏信息密度。
