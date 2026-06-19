# Welcome 示例卡组分页预览优化

状态：Verified

类型：feature

创建日期：2026-05-18

最后更新日期：2026-05-19

## 用户确认记录

- 2026-05-18：用户基于 iPad Welcome 示例方框截图提出设想：示例方框是否可以设计成更像卡片的样式，并增加两个示例，用户滑动该区域可以切换。
- 2026-05-18：用户要求针对该需求展开深入思考和头脑风暴，覆盖 iPad、macOS、iOS 三端边界；如有疑问立即提出，否则创建对应方案文档供审核。
- 2026-05-18：用户确认“根据方案，立即开始实施”。

## 需求描述

将 Welcome 首页当前单一“今日语迹”示例升级为三端可复用的多场景示例卡组。卡组展示 3 个生活场景示例，用户可在示例区域横向滑动切换，帮助首次进入 App 的用户更快理解“生活记录可以变成语言学习素材”的核心价值。

本需求是 Welcome 首页解释层优化，不是新建真实记录、真实 AI 生成、真实练习或数据持久化能力。

## 现状描述

当前 `WelcomeView` 中 `WelcomeTracePreviewCard` 只展示一个“咖啡店点单”示例：

- iPhone：紧凑卡片放在标题、说明和状态 badge 后，CTA 位于底部安全区。
- iPad / macOS 宽屏：右侧为固定宽度示例卡，左侧为品牌、价值主张和状态 badge，CTA 位于 stage 下方。
- 示例文案来自 `Localizable.xcstrings` 的一组 `welcome.tracePreview.*` key。
- `WelcomeHomeOptimizationTests` 以源码约束和 String Catalog 覆盖测试保证 Welcome 布局和本地化 key 不回退。

当前不足：

- 单一示例只能表达日常点单，覆盖面偏窄。
- 示例卡视觉上像信息面板，卡片感、场景切换感和探索性还不够。
- iPad / macOS 大画布上右侧区域可以承载更多“真实生活场景谱系”，但必须保持克制，不能抢走 CTA。

## 目标

1. 将 Welcome 示例区升级为 3 个生活场景卡片。
2. 支持用户在示例区域横向滑动切换。
3. iPhone、iPad、macOS 共用同一组示例数据和文案，但按平台尺寸使用不同卡片密度。
4. 保持 Welcome 首屏主目标清晰：理解价值、确认本地优先与 AI 可选、开始设置。
5. 避免自动轮播、复杂动画和真实数据副作用。
6. 保持当前三端布局重心，不让示例卡组破坏 iPhone 底部 CTA、iPad stage、macOS 窗口可伸缩性。

## 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`
- 本任务方案文档

## 不做什么

- 不接入真实 AI、数据库、语音、OCR、TTS、同步或 StoreKit。
- 不新增真实学习内容模型，不把 Welcome 示例写入 Core / Data 层。
- 不改变 onboarding 流程、语言空间创建逻辑或启动路由。
- 不自动轮播，不做营销式大幅动效。
- 不增加 Welcome 页主要 CTA 数量。
- 不引入第三方轮播库或 UIKit/AppKit bridge。
- 不把示例卡做成卡片套卡片；外层可以是分页容器，单张示例本身才是卡片。

## 证据与决策依据

- `docs/spec/003-ui-design-system.md` 要求首屏不要变成营销页，UI 应保持安静、清晰、长期可读，且不能卡片套卡片。
- `docs/spec/003-ui-design-system.md` 要求 iPhone 单列、iPad 响应式多栏、macOS 更高信息密度，但三端都要避免文本溢出和状态混淆。
- `docs/spec/002-navigation-and-routing.md` 要求首次启动不默认创建语言空间，AI Provider、同步等能力不成为首次体验门槛；因此示例卡只能表达 mock / preview，不表达真实记录已创建或真实 AI 已执行。
- iPadOS 设计原则要求 iPad 不是放大的 iPhone，应利用大屏多区布局，并支持 Split View / Stage Manager / 任意尺寸变化。
- SwiftUI 实现上，静态本地数据 + 原生横向分页滚动可以满足触控横滑、trackpad 横滑和 SwiftUI 原生交互，不需要手写复杂 drag gesture。实现阶段曾评估 `TabView` page style，但 `PageTabViewStyle` 在 macOS 不可用，因此采用 `ScrollView(.horizontal)`、`scrollTargetBehavior(.paging)` 和 `scrollPosition(id:)` 保持三端共享实现。

## 头脑风暴结论

### 方案 A：三张完整分页卡片

右侧或紧凑预览区显示一张完整卡片，用户横向滑动切换，底部用轻量分页点提示当前页。

优点：

- 信息最清晰，iPhone 不会被挤压。
- SwiftUI 原生实现简单，可访问性和状态管理更可控。
- 三端可以共用组件和数据。

缺点：

- 如果没有分页点或局部露出，部分用户可能不知道可以滑动。

结论：推荐采用。

### 方案 B：Peek 卡组，下一张露出边缘

当前卡片完整展示，下一张卡片在右侧露出 12-24pt，强化“可横滑”暗示。

优点：

- 可发现性强，视觉更像卡组。

缺点：

- iPhone 上会压缩内容宽度，容易影响中文、德文、法文等较长本地化文案。
- iPad / macOS 上如果处理不好，会与右侧 stage 宽度和阴影冲突。

结论：不作为第一版默认方案；可在实现后根据截图评估是否在 iPad / macOS 单独添加很轻的 peek。

### 方案 C：垂直堆叠三张小卡

三张示例同时展示，不需要滑动。

优点：

- 无交互学习成本。
- macOS 大窗口信息密度更高。

缺点：

- iPhone 首屏会被严重拉长，CTA 和核心文案被挤压。
- Welcome 变得像功能介绍列表，削弱克制感。

结论：不采用。

## 推荐设计

采用“静态三场景 + 原生分页 + 轻量指示器”的卡组设计。

### 示例场景

第一版建议使用 3 个覆盖不同生活语境的示例：

1. 咖啡店点单：日常口语、点单表达、消费场景词汇。
2. 通勤路上：听力碎片、路线表达、日常观察。
3. 工作会议或旅行问路：更高价值语境，体现学习材料不仅来自闲聊，也来自真实任务。

每张卡结构保持一致：

- eyebrow：今日语迹 / 场景预览一类的轻标题。
- scene：场景标题，例如“咖啡店点单”。
- note：一条母语生活记录。
- vocabulary：3-5 个目标语言词或短语。
- expression：1 个可跟读表达。
- practice：1 行练习动作摘要，例如 `Shadowing · 收藏 · 复习`。

### 交互

- 用户可在示例卡区域横向滑动切换。
- 不自动轮播。
- 不改变左侧价值文案、badge 或 CTA。
- 分页点放在卡片下方或卡片内部底部，视觉弱于 CTA。
- VoiceOver 应能读出当前示例序号，例如“示例 1，共 3”。
- macOS 鼠标/触控板用户可以横向滚动或点击分页点；分页点不应成为主要按钮群。

### 视觉

- 单张示例更像“真实材料卡”：保留白色或浅纸色底、细描边、柔和阴影和 18pt 左右圆角。
- 卡片内部不再像表格，使用更清晰的 section spacing。
- 不使用强渐变、装饰光球或营销海报式插图。
- 不做卡片套卡片：分页容器不再额外包一层重卡片边框。

## 三端边界

### iPhone

- 保持单列和底部 `safeAreaInset` CTA。
- 示例卡组仍位于标题和状态 badge 之后。
- 卡片宽度继续受 `compactPreviewWidth(in:)` 控制。
- 卡片高度应稳定，不随不同示例大幅跳动；必要时用固定最小高度。
- 分页指示器必须足够轻，不能像第二个 CTA。
- 横滑区域不能干扰页面纵向滚动；优先使用系统横向分页滚动，避免自定义高优先级 drag gesture。

### iPad

- 保留当前宽屏 stage：左侧价值主张，右侧示例卡组，CTA 在 stage 下方。
- 示例卡组宽度继续由 `previewCardWidth(in:)` 控制，避免被 `HStack` 压缩。
- 卡片内容可以比 iPhone 展开更多，例如保留完整 note、词汇、表达、练习四段。
- Stage Manager / Split View 下如果宽度降到 compact，应自动走 iPhone-like compact 布局。
- 不在 iPad 上为了展示三张示例而改成三列卡片；Welcome 首屏仍只聚焦一个当前示例。

### macOS

- macOS 沿用宽屏布局，但密度可以略高于 iPad。
- 支持窗口缩放：窄窗口走 compact 或更保守布局，不能出现文本溢出。
- 分页点或切换控件需要支持指针 hover / keyboard focus 的基本可见状态。
- 不把 Welcome 示例做成 macOS inspector 或 sidebar；它仍是启动欢迎页的说明性预览。

## 边界问题清单

### 文案与国际化

- 每个新增示例都需要覆盖 `en`、`zh-Hans`、`es`、`ja`、`fr`、`de`、`ko`、`ru`。
- 不同语言长度差异较大，卡片不能依赖某一种语言刚好排版。
- UI 文案使用界面语言，示例中的目标语言学习素材可以保留英语示例，但不要让 UI 层误以为学习语言数据来自界面语言。
- 如果未来支持动态目标语言示例，本任务不处理；当前只做 Welcome 静态 preview。

### 可访问性

- 卡片组需要合并读屏语义，避免 VoiceOver 把每个装饰性分隔点都读出来。
- 当前页和总页数需要可读。
- 分页点如果可点击，需要有 label，例如“显示通勤示例”。
- Reduce Motion 下不应有额外自定义动画；系统 page transition 即可。

### 状态与数据

- 示例数据是 UI 层静态 preview，不进入 Core / Data / Sync。
- 示例不能暗示已经保存用户真实记录。
- 示例不能暗示 AI 已自动生成学习材料。
- 本地优先和 AI 可选 badge 保持原语义，不因示例增多而改变能力边界。

### 布局与性能

- 示例数量固定为 3，避免引入无限列表、动态加载或复杂缓存。
- 用稳定 id，避免 `ForEach` 使用不稳定索引语义导致测试或更新问题。
- 避免在 `body` 内构造复杂本地化解析；静态数组和小型 value type 足够。
- 卡片高度应由布局函数控制，避免三张卡切换时 CTA 上下跳动。

### 测试与验证

- 需要先补源码级回归测试，确保存在 3 个示例、分页容器、分页指示器、静态数据边界和 String Catalog key。
- 需要扩展本地化覆盖测试，把新增 key 加入 required list。
- 需要运行 `swift test --package-path Packages/LangoTraceUI --filter WelcomeHomeOptimizationTests`。
- 完成后运行 `scripts/verify.sh` 和 `git diff --check`。
- 建议最终重新安装并启动 iPhone 17、iPad Pro 13-inch (M5)、macOS Debug App，截图或人工检查三端 Welcome。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/InterfaceLocalization.swift`

## 涉及的文档路径

- `docs/plans/active/2026-05-18-feature-welcome-example-carousel.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/plans/done/2026-05-18-feature-welcome-home-next-optimization.md`

## 实施方案

1. 在 `WelcomeHomeOptimizationTests` 中先新增失败测试，覆盖 3 个示例、分页组件、分页点、无自动轮播、三端布局不回退和本地化 key 完整性。
2. 在 `WelcomeView.swift` 中引入 UI 层静态数据结构，例如 `WelcomeTraceExample`，只服务 Welcome preview。
3. 将 `WelcomeTracePreviewCard` 改造为接收单个示例数据，而不是硬编码一个场景。
4. 新增 `WelcomeTracePreviewCarousel`，内部使用 SwiftUI 原生分页切换，管理本地 `@State private var selectedExampleID`。
5. iPhone compact 布局使用紧凑卡片高度和现有 `compactPreviewWidth(in:)`。
6. iPad / macOS wide 布局使用当前 `previewCardWidth(in:)` 与 `previewCardMinHeight(in:)`，保持 stage 宽度和 CTA 位置。
7. 在 `Localizable.xcstrings` 增加 3 个示例所需 key，并覆盖当前支持的 8 个界面语言。
8. 运行聚焦测试，修正布局和本地化问题。
9. 运行统一验证脚本。
10. 如用户确认实施并需要视觉复查，重启三端模拟器并检查 iPhone、iPad、macOS 截图。

## 复查方法

- 对照本方案的“三端边界”和“边界问题清单”逐项复查。
- 检查 `WelcomeView.swift` 中示例数据是否仍留在 UI 层，没有进入 Core / Data。
- 检查 `Localizable.xcstrings` 新增 key 是否 8 种语言都有非空值。
- 检查 iPhone 底部 CTA 是否仍由 `safeAreaInset(edge: .bottom)` 承载。
- 检查 iPad / macOS 示例区是否仍使用固定预览宽度，未回退为压缩 `maxWidth`。
- 检查没有出现自动轮播、网络、AI 请求、数据写入或同步相关代码。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter WelcomeHomeOptimizationTests
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
git status --short
```

## 文档影响检查

本任务是 Welcome 首页静态示例预览和交互优化，不改变产品北极星、导航路由、语言空间模型、AI Provider、隐私、同步、权限、付费或发布规则；无需新增 ADR 或长期 spec。

如果实施过程中决定改变 Welcome 首屏信息架构，例如新增长期“场景示例组件规范”、改变首次启动路径或引入真实示例数据来源，应重新评估是否更新 `docs/spec/003-ui-design-system.md`、`docs/spec/002-navigation-and-routing.md` 或新增任务方案。

## 实施记录

- 2026-05-18：创建 Draft 方案，完成需求头脑风暴、三端边界分析和实施计划；尚未实现代码。
- 2026-05-19：用户确认按方案立即实施。
- 2026-05-19：按 TDD 新增 Welcome 示例卡组回归测试，首次运行失败，失败点覆盖缺少三示例数据、分页组件、分页状态和新增本地化 key。
- 2026-05-19：实现过程中发现 `TabView` 的 `.page(indexDisplayMode:)` 在 macOS 不可用，因此将方案中的原生分页实现调整为三端可编译的横向 `ScrollView`、`scrollTargetBehavior(.paging)` 和 `scrollPosition`。
- 2026-05-19：新增 `WelcomeTracePreviewCarousel.swift`，将三张 Welcome 示例、分页滚动容器、页点和示例卡片从 `WelcomeView.swift` 中拆出，避免 Welcome 主视图继续膨胀。
- 2026-05-19：`WelcomeView.swift` 保留三端 stage、CTA 和品牌价值主张布局，只把原单卡替换为 `WelcomeTracePreviewCarousel(isExpanded:)`。
- 2026-05-19：`Localizable.xcstrings` 增加咖啡店点单、通勤路上、工作会议三组示例文案及页码可访问性文案，覆盖 `en`、`zh-Hans`、`es`、`ja`、`fr`、`de`、`ko`、`ru`。
- 2026-05-19：`swift test --package-path Packages/LangoTraceUI --filter WelcomeHomeOptimizationTests` 通过，9 个 Welcome 测试全部通过。
- 2026-05-19：`scripts/verify.sh` 通过；Core 26 个测试、Data 10 个测试、UI 52 个测试全部通过；iPhone 17、iPad Pro 13-inch (M5)、macOS arm64 Debug 构建成功；SwiftLint 0 violations；SwiftFormat 0 files require formatting。
- 2026-05-19：根据三端实测反馈完成回归修复：移除“首次设置约 30 秒 · 默认本地保存”底部提示语；将 iOS 示例卡上移；将示例卡改为固定高度，避免三张卡尺寸不一致；将分页点收紧到卡片下方，避免 iPad / macOS 间距过大。
- 2026-05-19：回归修复后 `swift test --package-path Packages/LangoTraceUI --filter WelcomeHomeOptimizationTests` 通过，10 个 Welcome 测试全部通过；`scripts/verify.sh` 通过，UI 测试数更新为 53 个，SwiftLint 0 violations，SwiftFormat 0 files require formatting。

## 完成标准

- Welcome 示例区展示 3 个静态生活场景。
- 用户可以在示例区域横向切换。
- iPhone、iPad、macOS 布局均不挤压主价值文案或 CTA。
- 不自动轮播，不产生真实 AI / 数据 / 同步副作用。
- 新增文案 key 覆盖当前全部界面语言。
- Welcome 聚焦测试通过。
- `scripts/verify.sh` 通过。
- 任务完成后方案从 `docs/plans/active/` 移入 `docs/plans/done/`。

## 剩余风险

- 静态源码测试不能完全替代三端视觉 QA；后续仍建议保留截图或人工复查。
- 多语言文案长度仍可能导致卡片高度变化；当前已通过固定最小高度和较短示例文案控制跳动。
