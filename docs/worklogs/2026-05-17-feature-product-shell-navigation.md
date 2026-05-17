# 工作记录：产品体验骨架与主体导航

类型：feature

状态：User Approved

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/project-initialization.md`
- `docs/development/001-platform-development-sequence.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/guidelines/002-navigation-and-routing.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/guidelines/004-swiftui-architecture.md`
- `prototypes/langotrace-multi-device-prototype/README.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 待本次实现提交后补充

## 1. 背景

当前 SwiftUI 工程已经完成 Stage 0 App Shell 初始化，可以在 iPhone、iPad 和 macOS 构建、启动和展示占位界面。用户在 iPhone 17 Simulator 中查看后反馈：当前测试界面缺乏高端设计感，同时希望在正式填充功能前，先把大致页面开发出来，以便直观看到产品结构、三端体验和视觉方向。

用户进一步提出启动路径设想：

- 每次打开 App 后先显示欢迎页，展示 App 名称和 slogan。
- 欢迎页同时承担后台本地数据加载时间。
- 如果首次打开且没有语言空间，则进入引导界面。
- 首次引导询问母语、目标语言和水平自评，再创建对应语言空间。
- 如果不是首次打开，则进入主体页面。

本次工作不是实现完整功能，而是把语迹从工程占位推进到“可浏览、可感受、可继续迭代”的产品体验骨架。

## 2. 目标

本次完成后，应达到以下可验证结果：

- App 启动后先进入高质感欢迎页。
- 欢迎页展示 `语迹 / LangoTrace` 和固定 slogan。
- 欢迎页吸收“高级 App Shell + 首版 App Icon 方向”的视觉语言：温润纸感白 / 极浅暖灰背景，深墨黑文字，深松石绿作为主强调色，少量低饱和金色作为点缀。
- 欢迎页呈现私人日记、语言资料库和 Apple 原生精品工具的气质，不使用纯白大卡片、强装饰渐变、光球或工程占位文案。
- App 具备明确启动分流：
  - 无语言空间：进入首次引导。
  - 有语言空间：进入主体页面。
- 首次引导页面包含母语、目标语言、水平自评三个步骤或等价输入区域。
- 用户确认后基于 Mock / InMemory 状态创建第一个语言空间。
- iPhone 主体页面具备 `今日 / 记录 / 练习 / 记忆 / 设置` 五个入口。
- iPad 主体页面具备学习桌面结构，体现语言空间、时间线、写作区和学习面板。
- macOS 主体页面具备资料库工作台结构，体现 Sidebar、主区域和 Inspector。
- 页面内容使用 Mock 数据，能直观看到产品方向，但不误导为真实功能已完成。
- 整体视觉比当前白色工程占位更接近高级、现代、克制的付费 App。
- 建立首版 App icon 方向和资产占位，使 App 在 Simulator / Dock 中不再使用默认图标。

## 3. 范围

本次会处理：

- 增加产品体验级启动状态：
  - welcome / splash
  - onboarding
  - main
- 增加轻量 InMemory App State，用于模拟是否已有语言空间。
- 增加首次引导 UI：
  - 母语选择或输入。
  - 目标语言选择或输入。
  - 水平自评。
  - 创建语言空间确认。
- 增加 iPhone 主体导航骨架：
  - 今日。
  - 记录。
  - 练习。
  - 记忆。
  - 设置。
- 增加 iPad 主体学习桌面骨架。
- 增加 macOS 主体资料库工作台骨架。
- 增加基础视觉 token 或局部设计常量，避免颜色、圆角、间距散落。
- 建立本次视觉基线：
  - 背景：温润纸感白、极浅暖灰。
  - 文字：深墨黑、层级清晰。
  - 强调色：深松石绿。
  - 点缀色：低饱和金色，仅用于少量状态或品牌细节。
  - 气质：私人日记、语言资料库、Apple 原生精品工具。
  - 避免：纯白大卡片、工程占位页、营销海报、AI 紫蓝渐变、游戏化闯关感。
- 将现有工程文案 `iPhone App Shell`、`iPad App Shell`、`macOS App Shell` 替换为用户可理解的产品文案。
- 在欢迎页和空状态中使用产品级文案：
  - `今天记录一点生活`
  - `本地优先 · 未配置 AI`
  - `创建第一个语言空间`
- 使用 Mock 数据展示英语空间示例，例如 `中文 -> 英语 · B1`。
- 增加首版 App icon 资产占位：
  - 使用“生活痕迹 + 语言轨迹”的抽象符号方向。
  - 底色使用深松石或近黑青色。
  - 图形使用暖白，少量金色点缀。
  - 本次只落地可替换的首版图标，不视为最终品牌定稿。
- 运行构建、测试、格式和启动验证。

## 4. 不做什么

本次不处理：

- SQLite / GRDB 持久化。
- SwiftData。
- 真实数据库 schema、迁移、FTS 或向量索引。
- 真实 AI Provider 请求。
- API Key、Keychain 或 Provider 配置保存。
- 真实 TTS、录音、Speech Recognition、OCR。
- 相机、照片、麦克风权限。
- 对象存储、WebDAV、S3、R2、iCloud 同步。
- StoreKit、买断制购买或恢复购买。
- 真实 App icon 定稿和完整品牌 VI。
- 深色模式完整适配。
- 真实多语言本地化。
- 完整 macOS 菜单栏、多窗口和 Command Palette。
- 完整业务数据编辑、删除、导入导出和冲突处理。

## 5. 分析

### 5.1 产品体验必要性

语迹是付费 App，用户对第一印象、视觉质感和操作路径会比普通 Demo 更敏感。继续停留在工程占位界面会妨碍判断真实产品方向。因此先开发可浏览的产品骨架是必要的。

### 5.2 与 Stage 0 / Stage 1 的关系

本次工作处于 Stage 0 App Shell 之后、Stage 1 核心学习闭环之前。它不实现完整学习闭环，但为 Stage 1 的首次启动、语言空间和主体导航建立界面与状态基础。

### 5.3 启动分流边界

欢迎页不应是营销页，而应是短暂、安静、有品牌感的启动过渡。它未来可承载本地数据加载、最近语言空间恢复、加密状态检查、同步状态检查等任务。本次只模拟这条状态路径。

欢迎页应采用方案 A 的设计感，但不能变成只展示品牌的静态封面。它必须服务启动分流：用户看到产品名称、主 slogan、轻量状态后，进入首次引导或主体页面。

### 5.4 Mock 数据边界

为了直观感受产品，本次页面会出现示例记录、示例练习、示例记忆和示例设置状态。但 UI 必须避免让用户误以为 AI、同步、TTS 或数据库已真实可用。需要使用状态文案表达“本地演示”“未配置 AI”或等价语义。

### 5.5 三端边界

iPhone、iPad、macOS 共享核心状态和产品对象，但界面结构必须区分：

- iPhone：单列、底部导航、快速记录和轻量练习。
- iPad：多栏学习桌面，强调写作区和学习面板。
- macOS：资料库工作台，强调 Sidebar、搜索、整理和 Inspector。

### 5.6 视觉设计边界

本次需要吸收方案 A 的设计方向，形成首版 SwiftUI 视觉基线：

- 产品感来自真实结构、克制色彩和清晰层级，不靠装饰性渐变或大面积玻璃拟态。
- 背景应像纸面、日记页或资料库工作台一样温和，避免当前纯黑安全区包裹白卡片的割裂感。
- 主要操作应围绕“今天记录一点生活”，而不是工程状态或功能介绍。
- 本地优先和 AI 未配置可以轻量可见，但不应压过记录主流程。
- 图标方向应与产品概念一致：语言轨迹、生活痕迹、记录页、长期记忆，而不是聊天气泡或课程徽章。

## 6. 方案

采用“产品骨架优先”的方案：

1. 在 Core 中补充轻量模型：
   - `LanguageSpacePreview`
   - `LanguageLevel`
   - `LaunchRoute`
   - `OnboardingDraft`
2. 在 App Shell 中引入 InMemory `AppSessionState`。
3. 启动时先进入 `WelcomeView`，短暂延迟后根据状态切换：
   - `onboarding`
   - `main`
4. 在 UI Package 中建立基础视觉层：
   - `LangoTraceDesign`
   - 语义颜色。
   - 间距。
   - 圆角。
   - 卡片/面板样式。
5. 建立首版品牌入口：
   - `WelcomeView` 使用方案 A 的高级 App Shell 视觉方向。
   - 欢迎页显示产品名、主 slogan、轻量本地状态和进入语言空间的语义。
   - 欢迎页不展示工程文案，不做营销功能介绍。
6. 建立主要页面骨架：
   - `WelcomeView`
   - `OnboardingView`
   - `PhoneMainView`
   - `PadMainView`
   - `MacMainView`
   - `TodayView`
   - `EntriesView`
   - `PracticeView`
   - `MemoryView`
   - `SettingsView`
7. iPhone 使用 TabView。
8. iPad 使用 NavigationSplitView 或自定义三栏布局。
9. macOS 使用 NavigationSplitView + Inspector 风格布局。
10. 使用 Mock 数据展示英语空间和示例记录。
11. 增加 `Assets.xcassets` 和 `AppIcon.appiconset`，落地首版可替换 App icon 占位。

替代方案：

- 直接做完整首次启动和真实语言空间持久化：更接近功能，但会提前引入存储设计，不适合当前阶段。
- 只美化当前占位页：成本最低，但不能解决用户需要直观看到页面结构的问题。
- 先做 App icon 和品牌资产：有价值，但不能替代产品体验骨架。
- 将方案 A 作为独立任务：会导致欢迎页视觉和主体页面骨架割裂，因此不采用。

推荐采用当前方案，因为它能以较低技术风险快速形成可体验产品壳，同时为后续真实功能保留清晰边界。

## 7. 风险与边界

- 风险：Mock 页面太完整，容易被误认为真实功能已完成。
  - 缓解：明确显示 AI 未配置、本地演示状态，避免真实发送、保存或同步暗示。
- 风险：过早追求视觉细节，拖慢后续核心功能。
  - 缓解：本次只做可复用的基础 token 和页面骨架，不做完整设计系统。
- 风险：启动欢迎页时间过长影响体验。
  - 缓解：本次使用短延迟；后续真实加载应尽量快速并可跳过。
- 风险：InMemory 状态在 App 重启后丢失，与真实首次使用逻辑不同。
  - 缓解：本次明确为 Mock / InMemory；后续持久化进入单独 worklog。
- 风险：iPad / macOS 页面骨架过度复杂。
  - 缓解：先表达结构，不实现高级操作。
- 风险：App icon 首版占位被误认为最终品牌定稿。
  - 缓解：文档和实现中明确它是可替换首版方向，用于摆脱默认图标和验证品牌气质。
- 风险：欢迎页看起来像营销页，违反 App 首屏应进入可用体验的规范。
  - 缓解：欢迎页保持短暂启动过渡，并通过状态路由进入 onboarding 或主体页面。
- 风险：视觉色彩过度偏单一松石色。
  - 缓解：深松石只作为强调色，主体使用暖灰、纸白、墨黑和少量金色，避免单一色相堆叠。

## 8. 测试与验证

计划运行：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
xcodebuild -list -project LangoTrace.xcodeproj
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
git status --short
```

手动或半自动验证：

- iPhone Simulator 可以启动 App。
- 首次状态显示欢迎页后进入首次引导。
- 引导页可以选择或输入母语、目标语言、水平自评。
- 创建语言空间后进入 iPhone 主体 Tab。
- iPhone 五个 Tab 可切换。
- iPad 构建后页面结构保留三栏学习桌面方向。
- macOS 构建后页面结构保留资料库工作台方向。
- Simulator 主屏幕显示首版 App icon，不再是默认占位图标。
- 欢迎页不出现 `iPhone App Shell`、`iPad App Shell`、`macOS App Shell` 等工程文案。
- 欢迎页视觉符合方案 A 的方向：温润浅背景、深墨黑、深松石强调、少量金色点缀。

## 9. 用户确认记录

状态为 `Draft` 时不能开始实现。

用户确认后记录：

```text
2026-05-17：用户确认先提交当前 worklog，然后进入实施。
```

## 10. 实施记录

- 已补充 Core 层启动流模型与测试：
  - `LanguageLevel`
  - `LanguageSpacePreview`
  - `LaunchRoute`
  - `OnboardingDraft`
  - `LaunchFlowTests`
- 已在 App target 中加入轻量 `AppSessionState`，用于模拟 welcome / onboarding / main 三段启动路径。
- 已将根视图从工程占位替换为产品体验骨架：
  - 欢迎页展示 `语迹 / LangoTrace`、固定 slogan、`本地优先`、`未配置 AI` 和 `今天记录一点生活`。
  - 首次引导页询问母语、目标语言和水平自评，并创建第一个语言空间。
  - iPhone 使用 `今日 / 记录 / 练习 / 记忆 / 设置` 五个 Tab。
  - iPad 使用三栏学习桌面骨架。
  - macOS 使用资料库工作台骨架。
- 已新增 `LangoTraceDesign` 作为首版视觉 token，统一纸感背景、墨黑文字、深松石强调、低饱和金色点缀、面板圆角和基础间距。
- 已新增首版可替换 App icon 资产：
  - 使用深松石底色、暖白记录页、抽象语言轨迹和金色点缀。
  - 通过 `scripts/generate-app-icon.swift` 生成 iOS / iPadOS / macOS 所需 PNG 尺寸。
  - 通过 XcodeGen `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` 接入 App target。

## 11. 验证结果

已验证通过：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
xcodebuild -list -project LangoTrace.xcodeproj
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
xcrun simctl install booted /Users/zibuyu/Library/Developer/Xcode/DerivedData/LangoTrace-hdfadqhothdwgbahopjjqiwrxhky/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch booted com.zibuyu.LangoTrace
```

结果：

- Core 测试 4 个全部通过。
- iPhone 17 Simulator 构建通过。
- iPad Pro 13-inch (M5) Simulator 构建通过。
- macOS arm64 构建通过。
- SwiftLint 0 violations。
- SwiftFormat lint 0 files require formatting。
- `git diff --check` 无空白错误。
- Booted iPhone 17 Simulator 已成功安装并启动 `com.zibuyu.LangoTrace`。
