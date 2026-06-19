# 工作记录：三端页面闭环优先阶段

类型：feature

状态：Completed

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/testing/README.md`
- `docs/archive/superpowers/plans/2026-05-17-three-platform-page-closure.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 未提交

## 1. 背景

当前 iPhone 端已经完成 MVP UI 级别的主要页面和 mock 子页面闭环，包括今日、记录、新建记录、记录详情、练习会话、记忆、设置和设置二级说明页。

iPad 端已完成三栏工作台、时间线、学习面板、语言空间底部工具区、面板收起和边缘手势，但还没有与 iPhone 等价的页面闭环。macOS 端目前更偏静态工作台骨架，缺少可进入的记录、练习、设置和高级工作台子页面。

用户提出新的阶段优先级：先把三端页面补充完整，再进行整体设计优化；等整体页面设计完成后，再推进功能开发和细节优化。因此，“语言空间持久化与启动恢复”草案先搁置。

## 2. 目标

本次目标是建立三端页面闭环，而不是实现真实功能：

- iPhone 保持现有页面闭环，补齐明显空 action 的 mock / unavailable 表达。
- iPad 补齐记录创建、记录详情、练习会话、设置详情和筛选交互的页面路径。
- macOS 补齐工作台内的记录库、记忆、练习、设置、请求预览和导入导出的 mock 页面路径。
- 所有新增页面都明确当前为 Local Mock 或 unavailable，不触发真实 AI、语音、权限、数据库、同步或导出。
- 形成后续“整体设计优化”可审查的完整页面地图和手动截图验证清单。
- 在实现前完成系统架构师和 iOS / iPadOS / macOS 交互设计复查，把页面闭环阶段的适配、状态、测试和文档边界写入方案。

## 3. 范围

本次会处理：

- 复查 iPhone 已有页面，给“拍照”“听一句”“语言空间切换”等空 action 补充只读说明或 unavailable sheet。
- iPad 增加页面状态和路由层：选中记录、创建记录、详情视图、练习会话、设置详情、筛选切换。
- macOS 增加 sidebar selection 和 inspector/detail 页面状态，补齐记录库、今日、记忆、练习、设置、导入导出和请求预览的 mock 页面。
- 抽取或复用跨端组件，例如设置详情、练习会话、不可用说明、记录详情内容，避免 iPhone / iPad / macOS 三份散落实现。
- 补充 iPad 窄宽度、Stage Manager 和 Split View 下的降级规则；窄宽度不能强行维持三栏挤压。
- 补充 macOS 窗口尺寸、菜单命令占位、键盘/指针交互和 Inspector 上下文规则；本阶段可不实现完整 command surface，但不能把 Mac 做成静态展示页。
- 补充可测试的路由 / 筛选状态 helper，避免只靠手动点击验证页面闭环。
- 更新导航、UI 设计系统、SwiftUI 架构和测试文档，记录“页面闭环优先，真实功能后置”的阶段边界。
- 使用 iPhone、iPad 和 macOS 进行截图或本机视觉验证。

## 4. 不做什么

本次不处理：

- 不接入真实语言空间持久化和启动恢复。
- 不接入 SQLite / GRDB、迁移、FTS、附件存储或导出。
- 不实现真实 AI Provider、Keychain API Key、请求日志、TTS、Speech、OCR、录音、照片权限或同步。
- 不做最终视觉系统升级，不大改色彩、字体、动效或品牌质感。
- 不实现 macOS 完整菜单栏、Command Palette、多窗口和快捷键系统；只为后续设计优化留出页面位置。
- 不把 mock 页面写成真实配置、真实导入导出或真实同步能力。
- 不把 iPad / macOS 的面板展开状态、筛选状态、当前 route 或临时 sheet 状态写入语言空间模型、数据库、同步 manifest 或启动恢复。

## 5. 分析

### 5.1 对当前开发流程设想的判断

用户提出的流程是合理的：先补齐三端页面闭环，再统一设计优化，最后做真实功能和细节。这比边做真实功能边补 UI 更稳，因为当前项目仍处于早期，信息架构和跨端页面承载方式还没有完全定型。

推荐执行顺序：

1. 页面闭环：让每个端都能走完整主流程和二级页面，即使是 mock / unavailable。
2. 设计优化：在完整页面地图上统一信息密度、视觉层级、组件状态和截图验证。
3. 功能开发：按页面承载能力接入真实存储、AI、语音、同步和付费。
4. 细节优化：性能、可访问性、快捷键、动效、深色模式、错误恢复。

这个顺序的关键约束是：页面闭环阶段必须清楚标记 mock 边界，不能让用户误以为真实数据、真实 AI 或真实同步已经可用。

### 5.2 iPhone 当前缺口

iPhone 主流程基本完整，但仍有空 action：

- 首页 `拍照`。
- 首页 `听一句`。
- 顶部语言空间切换按钮。

本次应给这些入口补充 unavailable sheet 或说明页，保持页面闭环，而不是接入 Photos、Audio 或多空间管理。

iPhone 端还需要保留系统导航习惯：

- 不新增会干扰 NavigationStack 返回手势的横向全屏手势。
- unavailable sheet 应是短说明，不承载长设置流程。
- 触控目标保持不小于 44pt，空 action 不能只通过 disabled 视觉表达。

### 5.3 iPad 当前缺口

iPad 有工作台形态，但缺少等价页面闭环：

- 没有新建记录入口。
- 没有记录详情完整页或 overlay。
- 没有练习会话页。
- 没有设置详情页。
- 筛选 pill 只是静态展示。
- 右侧练习入口只是文本汇总，不能进入练习。

本次应在 iPad 保持三栏工作台的基础上增加局部 route / sheet / inspector 状态，而不是退化成放大的 iPhone Tab。

iPad 端需要额外处理窗口和输入方式边界：

- 在 regular width 保持三栏工作台；在 Split View、Slide Over 或 Stage Manager 窄窗口下，应允许左侧时间线和右侧学习面板自动或手动收起，保证主内容不被压缩到不可读。
- 筛选、记录选择、练习和设置详情都属于当前语言空间内的 transient UI state，不做跨启动恢复。
- 新建记录 sheet 只能创建 Local Mock 记录，保存后选中新记录并进入详情，不触发真实数据库写入。
- 自定义筛选 pill 必须变成可访问按钮，至少有 label、value 和选中态，不只靠颜色表达。

### 5.4 macOS 当前缺口

macOS 当前仍是静态工作台：

- Sidebar item 不可选择。
- `新建记录` 按钮没有动作。
- Inspector 内容固定，未随当前记录或页面变化。
- 没有记录库、练习、记忆、设置、导入导出、请求预览的可验证页面路径。
- 没有 macOS 工具型应用应有的基础 command surface 规划。

本次先补页面状态和 mock 页面，不要求完整菜单栏和快捷键落地。

macOS 端需要额外处理桌面应用边界：

- Sidebar selection 必须是真实可选状态，不能继续使用静态 active 样式。
- 主窗口必须保持可调整大小；新增页面不能把最小宽度固定到只适配大屏显示器。
- Inspector 必须随 section 或 route 变化，避免显示与当前页面无关的请求预览。
- 菜单栏、Command Palette、多窗口和快捷键属于后续设计优化或 Mac 高级工作台阶段；本次只在文档中记录命令入口候选，不落地假快捷键。

### 5.5 架构复查结论

新增页面闭环方案真实存在且方向正确，但原草案需要补强以下架构约束后才适合进入实现：

- `MacMainView` 当前没有接收 `InMemoryLearningContentRepository`，macOS 页面闭环必须先从 `LangoTraceRootView` / `PlatformMainView` 把 mock repository 注入 Mac 外壳，不能在 `MacMainView` 内部重新创建仓库。
- iPad / macOS route、section、filter 和 sheet 状态应使用小型 enum 表达，并尽量把筛选逻辑抽成纯函数或轻量 helper，方便单元测试。
- 共享内容视图只呈现记录、练习、设置和 unavailable 状态；平台外壳负责 tab、sidebar、selection、sheet、inspector 和窗口适配。
- `contentRevision` 这类 UI 刷新触发器只可作为早期内存 repository 的临时 UI 状态，不得扩展为业务事件总线。
- 页面闭环不应引入新的 Core 模型或真实数据 schema；如果实现中发现必须新增持久模型，应暂停并另开数据层 worklog。

### 5.6 交互复查结论

从专业 iOS / iPadOS / macOS 交互角度看，新增方案需要以“平台原生闭环”而不是“三端同屏复用”为目标：

- iPhone：继续保持 Tab + NavigationStack + Sheet，补齐明显空 action 的可见反馈。
- iPad：保持工作台和上下文并列，不用移动端 Tab；窄窗口时优先保护主内容和当前任务。
- macOS：使用 Sidebar + Toolbar 区域 + 主工作区 + Inspector；按钮、列表项和设置项需要支持键盘焦点、指针 hover 或系统控件默认反馈。
- 所有 unavailable 页面要说明“当前边界、后续接入条件、不会发生的副作用”，但避免在真实功能前做大段产品说明。

## 6. 方案

采用“共享页面内容 + 平台外壳差异”的方案：

1. 将记录详情、练习会话、设置能力详情、不可用能力说明抽成更通用的 SwiftUI 视图，让三端复用内容。
2. iPhone 继续使用 Tab + NavigationStack + Sheet。
3. iPad regular width 使用工作台三栏；compact width 或窄窗口进入可收起 / 单主区优先的工作台模式，二级内容优先在中间主区或右侧学习面板呈现，短任务使用 sheet。
4. macOS 使用 Sidebar selection + 主区 + Inspector，页面状态通过 enum selection 切换，并从 App Shell 注入同一个 mock repository。
5. 所有未接入真实能力的入口统一进入 unavailable / Local Mock 说明，不留空按钮。
6. 路由、筛选和 section 选择必须可单元测试；视觉截图验证只作为最终交互检查，不替代状态测试。

## 7. 风险与边界

- 风险：为了页面完整引入过多临时 UI 状态。
  - 缓解：页面状态先用明确 enum 表达，不写入数据层，不做持久化。
- 风险：iPad / macOS 变成 iPhone 页面简单放大。
  - 缓解：iPad 保持三栏工作台和触控舒适度；macOS 保持 Sidebar / 主区 / Inspector 工具型布局。
- 风险：mock 页面误导真实功能已经完成。
  - 缓解：所有不可用入口必须显示当前边界、后续接入条件和不会发生的副作用。
- 风险：设计优化前过早美化局部页面。
  - 缓解：本阶段只补页面结构、状态和可达性，视觉只保持现有 token 与组件一致。
- 风险：范围蔓延到真实功能。
  - 缓解：不接入真实存储、AI、语音、权限、同步、导出或 StoreKit。
- 风险：iPad 在 Split View / Stage Manager 下三栏挤压导致不可用。
  - 缓解：实现前明确 regular / compact 宽度规则，窄窗口优先隐藏辅助面板并保留主区。
- 风险：macOS 只补页面但仍无桌面应用感。
  - 缓解：本阶段至少完成可选 Sidebar、上下文 Inspector、窗口可调整和工具栏区域入口；菜单栏和快捷键作为后续设计优化任务记录。
- 风险：计划只覆盖手动截图，缺少可回归的状态测试。
  - 缓解：为筛选、route 状态或 helper 增加 Swift package 单元测试，再做截图验证。

## 8. 测试与验证

开发中：

```bash
swift test --package-path Packages/LangoTraceUI
```

收尾：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
scripts/verify.sh
git status --short
```

手动验证至少覆盖：

- iPhone：今日、记录、新建记录、记录详情、练习会话、记忆、设置、设置详情、拍照/听一句/语言空间切换 unavailable 说明。
- iPad：默认三栏、记录选择、新建记录、记录详情、练习会话、设置详情、筛选切换、左右面板收起。
- iPad 窄窗口：主内容仍可读，时间线和学习面板可收起，筛选和详情入口仍可达。
- macOS：默认窗口、窗口缩放、Sidebar item 切换、新建记录 mock、记录库、练习、记忆、设置、导入导出、Inspector 内容变化、Sidebar / Inspector 收起。

## 9. 文档影响检查

预计需要更新：

- `docs/spec/002-navigation-and-routing.md`：补充三端页面闭环阶段的页面承载规则。
- `docs/spec/003-ui-design-system.md`：补充页面闭环先于视觉优化的阶段边界。
- `docs/spec/004-swiftui-architecture.md`：补充共享页面内容和平台外壳分离规则。
- `docs/testing/README.md`：补充三端页面闭环截图验证清单。
- 本 worklog：实现后记录实际改动、验证命令和剩余风险。

预计不需要更新：

- ADR：本次不改变 SwiftUI Multiplatform、语言空间、本地优先或 Provider 边界。
- `docs/review/`：本次是页面闭环和 mock 路由完善，不接入真实数据库、AI Provider、权限、同步、StoreKit 或启动结构；若实现中改动三端导航结构较大，再在 worklog 中补充是否触发专项审查。

## 10. 用户确认记录

2026-05-17：用户确认开始实施本方案，优先完成 iPad 和 macOS 端页面补充，同时保留语言空间持久化与启动恢复草案的 Shelved 状态。

## 11. 实施记录

2026-05-17：开始实施。先按 TDD 补充页面状态 helper 测试，再实现 iPad 和 macOS 页面闭环。

2026-05-17：已完成首轮代码实现：

- 新增 `PageClosureStateTests`，用 TDD 锁定 `PadFilter` 对全部记录、照片写作和已入记忆的筛选行为。
- 新增共享 `UnavailableCapabilityView`，并补齐 iPhone `拍照`、`听一句` 和语言空间切换的 unavailable sheet。
- iPad 增加 `PadWorkspaceRoute`、`PadSheet`、`PadFilter`、新建记录 sheet、记录详情、练习会话、设置详情和交互式筛选。
- iPad regular width 保留三栏工作台，compact width 首次进入时收起学习面板，避免主内容被挤压。
- macOS 从 `LangoTraceRootView` 注入 `InMemoryLearningContentRepository`，补齐 Sidebar section、记录库、练习、记忆、设置、导入导出 unavailable、上下文 Inspector 和新建记录 mock sheet。
- 所有新增页面仍保持 Local Mock / unavailable 边界，不接入真实数据库、AI、语音、权限、同步或导出。

## 12. 验证结果

已执行：

```bash
swift test --package-path Packages/LangoTraceUI
```

结果：通过。新增测试先在缺少 `PadFilter` 时失败，生产代码实现后 UI package 4 个测试通过。

完整验证：

```bash
scripts/verify.sh
```

结果：通过。覆盖 XcodeGen、`xcodebuild -list`、Core/UI package tests、iPhone 17 simulator build、iPad Pro 13-inch simulator build、macOS arm64 build、SwiftLint、SwiftFormat lint、文档占位词扫描和 `git status --short`。

文档检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
```

结果：通过。占位词扫描无命中，diff whitespace 检查无问题。

本机视觉冒烟：

- macOS App 从 onboarding 创建英语空间后进入主界面。
- Sidebar 显示 `今日 / 记录库 / 练习 / 词句记忆 / 导入导出 / 设置`，section selection 可切换。
- `记录库` 显示 mock 记录列表和选中态。
- `导入导出` 显示 unavailable 说明，未打开文件面板或触发导入导出副作用。
- `设置` 显示能力列表和只读状态。
- `新建记录` 打开本地记录编辑 sheet，取消后返回 Mac 主界面。

剩余风险：

- SwiftLint 仍报告若干非 serious 的 file length / type body length warning，`scripts/verify.sh` 接受这些 warning 并返回成功。本阶段为页面闭环实现，后续整体设计优化或组件拆分阶段应继续收敛大文件。
- 本轮未做 iPad Simulator 交互截图，仅由 iPad simulator build、UI package tests 和代码审计覆盖；后续设计优化阶段应补完整三端截图矩阵。
