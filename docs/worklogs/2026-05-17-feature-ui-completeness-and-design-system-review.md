# 工作记录：页面完整性与设计系统审查

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/guidelines/002-navigation-and-routing.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/superpowers/specs/mvp-ui-flow-and-design-system.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/003-use-xcodegen-for-project-generation.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 未提交

## 1. 背景

用户指出当前 SwiftUI 页面存在两个问题：

1. 页面不完整，很多交互逻辑和子页面尚未完成。
2. 已完成页面缺乏高级设计，也没有沉淀为风格规范文档。

本次工作先对现有代码实现与文档承诺做审查。用户确认实施后，继续执行第一批页面闭环与设计系统基础落地。审查使用 `ui-ux-pro-max`、`swiftui-expert-skill`、iOS / iPadOS / macOS HIG 相关 skill，重点判断两个问题是否真实存在，并把结论、优化方案、实际实施结果和验证证据沉淀为后续工作的文档依据。

## 2. 目标

本次工作的目标：

- 记录页面完整性和设计系统现状的代码级证据。
- 区分“已明确处于早期骨架阶段”和“需要作为设计/实现债务处理”的内容。
- 建立后续页面补全与设计系统升级的规格入口。
- 完成第一批可验证实现：内存学习内容模型、iPhone 记录入口和详情、iPad 时间线联动、首批组件和 token。
- 明确下一阶段不直接铺开完整 AI、完整数据库、完整同步和完整 StoreKit。

## 3. 范围

本次处理：

- 审查 `Packages/LangoTraceUI/Sources/LangoTraceUI/` 下的 Welcome、Onboarding、iPhone、iPad、macOS 主页面和基础 UI 组件。
- 审查 `LangoTraceApp/` 当前 App 状态注入与 disabled 服务边界。
- 对照产品闭环、导航规范、UI 设计系统规范和技术路线文档。
- 新增 `docs/superpowers/specs/mvp-ui-flow-and-design-system.md`，作为后续页面补全与设计系统升级规格。
- 新增 `docs/superpowers/plans/2026-05-17-mvp-ui-flow-and-design-system-implementation.md`，记录第一批实施任务和验证。
- 修改 `Packages/LangoTraceData`、`Packages/LangoTraceUI` 和 `LangoTraceApp`，落地第一批 in-memory 页面闭环。
- 复查 `docs/guidelines/003-ui-design-system.md` 和 `docs/testing/README.md`，补齐设计系统落地和模拟器截图验证要求。
- 使用 iPhone / iPad 模拟器截图验证当前实现的视觉和页面状态，截图只作为本次审查证据，不作为新 UI 验收。

## 4. 不做什么

本次不处理：

- 不接入 SQLite / GRDB、真实 AI Provider、TTS、Speech、OCR、照片、同步或 StoreKit。
- 不创建新的 ADR；本次结论没有改变核心产品或架构决策。
- 不把模拟器截图审查等同于完整视觉验收；截图只验证当前页面可运行、主路径可见、关键内容不为空。
- 不把 Mac 工作台推进为完整 MVP 主线；Mac 继续作为基础可运行和后续高级工作台方向。

## 5. 分析

### 5.1 页面不完整：成立

产品主参考文档要求核心学习闭环覆盖：

- 记录。
- AI 转换。
- 双语对照。
- 听说。
- 听写、回译、复述、自测。
- 词句提取。
- 复习。
- 长期沉淀。

现有代码只实现了可运行的体验骨架：

- `PhoneMainView` 有 `今日 / 记录 / 练习 / 记忆 / 设置` 五个 Tab，但 `PhonePage` 的语言空间切换按钮、`ActionChip` 的写一句/拍照/听一句按钮都还是空动作；`SampleEntryCard` 展示 chevron，但没有进入详情路由。
- `PadMainView` 有三栏视觉结构、可收起时间线和学习面板，但 `SideItem`、`FilterPill`、`SentenceRow`、`RequestPreviewPanel` 都是静态展示；“听 / 练”按钮没有连接播放或练习会话。
- `MacMainView` 明确显示“当前为 Mock 骨架”，新建记录、搜索、批量导入、快捷键和 Inspector 都未连接真实命令系统；Inspector 只展示静态请求预览文本。
- `LangoTraceApp/AppEnvironment.swift` 注入的是 `EmptyLanguageSpaceRepository`、`DisabledAIProvider`、`DisabledSpeechService`、`DisabledSyncService`。
- `LangoTraceData` 当前的 `LanguageSpaceRepository` 还是空协议，`LangoTraceAI`、`LangoTraceSpeech`、`LangoTraceSync` 当前只有 disabled / empty 实现。
- `AppSessionState.createLanguageSpace()` 只创建 `LanguageSpacePreview` 并进入 `.main`，没有持久化 Space，也没有启动恢复。

技术路线文档已经如实记录：当前处于 Phase 0 前半段，数据层、AI、TTS 和核心学习闭环仍需单独设计与实现。因此，“页面不完整”是事实，但它也符合当前文档声明的早期阶段。

### 5.2 已完成页面缺乏高级设计：基本成立

现有页面已经具备一些正确方向：

- 三端采用不同布局形态。
- iPhone 使用五个一级 Tab。
- iPad 具备时间线、主写作区、学习面板。
- macOS 具备 Sidebar、主区、Inspector 的工作台雏形。
- 辅助面板按钮具备可访问 label、value，并尊重 Reduce Motion。
- `LanguageSpaceFooter` 区分 AI Provider 和同步状态。

但从付费精品 App 的标准看，当前仍偏骨架：

- 视觉层级主要依赖相似的 panel、静态文案和 SF Symbols，缺少更精细的页面构图、内容密度、编辑状态和练习状态。
- `LangoTraceDesign` 只有少量固定浅色颜色、圆角、间距和通用 panel modifier，没有完整语义 token、字体层级、状态色、深色模式映射、动效 token 和组件状态规范。
- 页面中缺少真实的输入、选择、详情、编辑、保存、请求预览确认、权限解释、空状态、错误状态、加载状态和完成反馈。
- 组件命名尚未完全对齐 UI 规范建议的产品对象，例如 `SentencePairView`、`PracticeControlBar`、`EntryTimelineRow`、`MemoryItemRow` 等还没有成为稳定组件。

### 5.3 “没有沉淀为风格规范文档”：不完全成立

仓库已有 `docs/guidelines/003-ui-design-system.md`，状态为 Accepted，内容覆盖：

- 视觉气质。
- 三端信息密度。
- 组件方向。
- 状态设计。
- 可访问性底线。
- 辅助面板与专注模式。
- 语言空间底部工具区。
- 国际化与语言显示。
- design token 初始边界。

因此，“没有风格规范文档”不准确。准确问题是：现有规范仍偏原则与边界，没有升级为可直接实现的设计系统规格。后续应把它补强为 tokens、组件状态、页面模式、交互动效、深色模式和验证标准。

## 6. 方案

采用“两条线并行、分阶段落地”的方案。

第一条线：补齐最小页面闭环。

- 优先围绕 `Entry -> Rendering -> Practice -> Memory` 建立页面地图。
- 第一阶段聚焦 iPhone + iPad，不让 Mac 抢 MVP 主线。
- 在补 UI 之前先建立最小模型和内存 repository：`Space` 仍可沿用现有 preview，但需要有可测试的 `Entry`、`Rendering`、`Practice`、`Memory` mock / in-memory 边界，避免页面继续写死静态内容。
- iPhone 先完成记录创建、记录详情、请求预览、双语对照、句子练习、记忆提取和设置入口。
- iPad 先完成记录详情工作台、时间线选择、学习面板、练习入口和请求预览。
- Mac 保持基础工作台，并为后续 Toolbar、menu commands、Command Palette 和批量管理留出边界。

第二条线：补强设计系统。

- 在规格中定义 design token 分层：颜色、字体、间距、圆角、阴影、状态、动效。
- 把现有 `LangoTraceDesign` 从少量静态 token 升级为可扩展 token 与组件样式入口。
- 建立核心组件清单和状态：`EntryTimelineRow`、`SentencePairView`、`PracticeControlBar`、`RequestPreviewCard`、`PromptPresetPicker`、`MemoryItemRow`、`LanguageSpaceSwitcher`、`PrivacyStatusPopover`。
- 明确 empty / loading / error / permission denied / AI unavailable / sync conflict 等状态的 UI 模式。
- 视觉升级必须服务记录、学习和复习路径，不做装饰性大改；每个组件都应有普通、选中、禁用、不可用、加载或错误等必要状态。

第三条线：文档与实现同步。

- 本 worklog 作为封面记录。
- `docs/superpowers/specs/mvp-ui-flow-and-design-system.md` 作为设计规格。
- 代码实现前创建 `docs/superpowers/plans/2026-05-17-mvp-ui-flow-and-design-system-implementation.md`，拆成可验证任务。
- 实现后按文档审查机制检查 `docs/README.md`、产品主参考、技术路线、guidelines 和 testing 是否需要更新。

## 7. 风险与边界

- 如果先全面美化而不补交互闭环，会得到更漂亮但仍不可用的 Demo。
- 如果先接完整数据库和 AI，会把视觉与交互问题压到更晚，增加返工成本。
- 如果把 Mac 工作台同步推进到完整能力，会稀释 iPhone + iPad MVP 的主线。
- 如果 design token 过早追求完整，会拖慢页面闭环；第一版 token 应覆盖当前页面和核心组件，不做全量品牌手册。
- 所有真实 AI 请求、照片、音频、OCR、同步和 API Key 相关实现仍必须遵守本地优先和用户确认边界。

## 8. 测试与验证

本次文档创建完成前检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

后续代码实现阶段应根据实际改动运行：

```bash
scripts/verify.sh
```

如果只修改文档，不运行 Swift 构建是可接受的；最终答复需说明验证范围。

本次复查增加模拟器视觉验证：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
xcrun simctl install <device> <built-app>
xcrun simctl launch <device> com.zibuyu.LangoTrace
xcrun simctl io <device> screenshot <path>
```

截图验证只回答三个问题：

- 当前页面是否确实停留在 welcome / onboarding / mock main 骨架。
- 关键入口是否真实可见但未形成完整闭环。
- iPhone / iPad 截图是否支持“页面偏静态、设计系统仍需升级”的审查结论。

## 9. 文档影响检查

本次变更新增 worklog、规格文档和实施计划，并修改第一批 SwiftUI / in-memory 数据实现。实现仍处于真实数据库、真实 AI、真实语音和真实同步之前，没有改变核心决策或既有 ADR。

- `docs/README.md`：本次不需要更新；项目当前状态仍是产品体验骨架阶段。
- `docs/product-main-reference.md`：本次不需要更新；核心闭环和对象模型已覆盖审查依据。
- `docs/technical-framework-roadmap.md`：本次不需要更新；Phase 0 当前进度已如实记录缺口。
- `docs/guidelines/003-ui-design-system.md`：本次需要补充“可执行设计系统”边界，避免长期规范停留在原则层。
- `docs/testing/`：本次需要补充模拟器截图验证的最小要求，作为后续 UI 闭环和设计系统升级的验收入口。
- `docs/review/`：本次不改变数据库、AI Provider、权限、同步、StoreKit、XcodeGen、包边界核心决策或 ADR；按 worklog 记录文档影响检查，不触发专项审查。

## 10. 用户确认记录

2026-05-17：用户确认先按推荐步骤创建相关文档，记录本次审核结果和优化方案。

2026-05-17：用户确认“立即按照方案，开始实施”。本 worklog 进入 `In Progress`，允许按关联规格和实施计划修改代码。

## 11. 实施记录

2026-05-17：

- 新增本 worklog，记录页面完整性与设计系统审查结论。
- 新增 `docs/superpowers/specs/mvp-ui-flow-and-design-system.md`，沉淀优化规格。

2026-05-17 复查更新：

- 收紧代码事实表述，明确当前只有 `LanguageSpacePreview` 和静态 mock 页面，不夸大为真实语言空间或记录闭环。
- 补充最小模型和内存 repository 是 UI 闭环前置条件。
- 更新 UI 设计系统规范和测试入口，加入可执行设计系统与模拟器截图验证要求。
- 使用 iPhone 17 和 iPad Pro 13-inch 模拟器进行当前页面截图验证，确认主页面可见但交互仍未形成闭环。

2026-05-17 第一批实现：

- 在 `Packages/LangoTraceData` 新增 `LearningEntry`、`LearningRendering`、`PracticeItem`、`MemoryItem` 和 `InMemoryLearningContentRepository`。
- 为 `LangoTraceData` 增加测试 target，覆盖 seeded 内容、创建记录、选中记录三类行为。
- 在 `AppEnvironment` 注入学习内容 repository，并通过 `LangoTraceRootView` 传入 iPhone / iPad 主页面。
- 重写 iPhone 主 Tab：今日、记录、练习、记忆、设置改为 repository 驱动；“写一句”进入 `EntryEditorView`，保存后进入 `EntryDetailView`。
- 改造 iPad 工作台：时间线选择驱动中栏记录正文、双语句子、右栏请求预览、练习和记忆摘要。
- 扩展 `LangoTraceDesign` 语义 token，新增 `EntryTimelineRow`、`SentencePairView`、`RequestPreviewCard` 等可复用组件。
- 模拟器冒烟验证首次发现 iPhone 主界面进入后仍显示空记录；根因是普通 in-memory repository 修改后不会触发 SwiftUI 刷新。已在 `PhoneMainView` 增加轻量 `contentRevision`，确保 mock seeded 内容和新建记录后刷新。

## 12. 验证结果

2026-05-17 已执行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

结果：

- `find docs -maxdepth 3 -type f | sort` 已确认新增 worklog 和规格文档在预期目录下。
- 占位词扫描无命中。
- `git diff --check` 通过。
- `git status --short` 仅显示本次新增的两份文档。

2026-05-17 复查补充执行：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
xcrun simctl install CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C /Users/zibuyu/Library/Developer/Xcode/DerivedData/LangoTrace-hdfadqhothdwgbahopjjqiwrxhky/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C com.zibuyu.LangoTrace
xcrun simctl io CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C screenshot /private/tmp/langotrace-ui-review/iphone-main-today.png
xcrun simctl io 73045FC7-A9FB-4F41-892E-3CE9755D2ECB screenshot /private/tmp/langotrace-ui-review/ipad-main-three-column.png
```

结果：

- iOS Debug 构建通过。
- iPhone 截图显示主页面有“写一句 / 拍照 / 听一句”入口，但点击“写一句”后仍停留在当前页面，符合空动作审查结论。
- iPad 截图显示三栏结构和面板收起/展开可用，但时间线、筛选、句子练习和请求预览仍是静态 mock，符合页面未闭环结论。
- 截图文件保存在 `/private/tmp/langotrace-ui-review/`，不作为仓库内长期资产。

2026-05-17 第一批实现已执行：

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
xcrun simctl install CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C /Users/zibuyu/Library/Developer/Xcode/DerivedData/LangoTrace-hdfadqhothdwgbahopjjqiwrxhky/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C com.zibuyu.LangoTrace
xcrun simctl io CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C screenshot /private/tmp/langotrace-ui-review/2026-05-17-iphone17-main-seeded.png
```

结果：

- `swift test --package-path Packages/LangoTraceData` 通过，3 个 repository 行为测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，3 个既有 UI 行为测试通过。
- `scripts/verify.sh` 通过，覆盖 XcodeGen、Core/UI 测试、iPhone 17 构建、iPad Pro 13-inch 构建、macOS 构建、SwiftLint、SwiftFormat 和文档占位扫描。
- iPhone 17 模拟器截图验证通过：创建语言空间后主页面显示 seeded mock 记录“雨天咖啡馆”和“写给朋友的感谢”，不再停留在空状态。
- 视觉截图保存在 `/private/tmp/langotrace-ui-review/2026-05-17-iphone17-main-seeded.png`，不作为仓库内长期资产。
