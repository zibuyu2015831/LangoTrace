# 010：Apple 三端交互与可访问性规范

状态：Accepted

适用阶段：MVP 早期开发、SwiftUI 页面迭代、三端 UI 审查、截图验证和发布前质量收口。

## 1. 适用范围

本文档规定 LangoTrace 在 iPhone、iPad 和 macOS 上的原生交互、输入方式、窗口 / 尺寸适配、可访问性和人工验证底线。它补充但不替代：

- [002：导航与路由规范](002-navigation-and-routing.md)
- [003：UI 设计系统规范](003-ui-design-system.md)
- [004：SwiftUI 架构规范](004-swiftui-architecture.md)
- [006：界面国际化与语言边界规范](006-interface-localization-and-language-boundaries.md)
- [009：测试与验证入口规范](009-testing-and-verification.md)

任何新增或重构 SwiftUI 页面、控制、菜单、键盘快捷键、指针交互、sheet、popover、toolbar、inspector、设置页或可访问状态时，都应读取本文档。

## 2. 当前结论

语迹是 Apple 三端首发的本地优先语言学习 App。三端应共享产品对象和业务边界，但不能共享一套放大的移动端界面。

设计目标：

- iPhone：触控优先，快速记录和碎片练习，主路径少而清楚。
- iPad：触控、指针和键盘并存，支持多栏、Split View、Slide Over 和 Stage Manager。
- macOS：菜单栏、快捷键、窗口、toolbar、sidebar 和 inspector 是桌面体验的一部分，不是移动端附属。
- 可访问性：Dynamic Type、VoiceOver、键盘焦点、Reduce Motion、对比度和状态语义从 MVP 早期开始纳入验收。

## 3. 强制规则

- iPhone 交互控件的触控目标不得小于 44pt；iPad 触控入口同样遵守 44pt 底线。
- 重要文本、输入框、按钮和状态不能被 notch、Dynamic Island、home indicator、sidebar、toolbar、sheet detent 或窗口边缘遮挡。
- iPhone 不使用汉堡菜单隐藏主导航；当前顶层保持 `记录 / 练习 / 记忆` 三个主目的地。
- iPad regular width 不得退化为放大的 iPhone Tab。必须优先使用 sidebar、多栏、主内容区和上下文学习面板。
- iPad 必须考虑 Split View、Slide Over、Stage Manager 和横竖屏尺寸变化；不能假设全屏或固定宽高。
- macOS 必须有原生 `Settings` scene 或等价系统设置入口；常用桌面命令必须通过 menu command、toolbar 或快捷键稳定可达。
- macOS 不使用移动端底部 Tab 作为主导航；应使用 sidebar、toolbar、主工作区、inspector、菜单和窗口行为。
- 图标按钮必须有可访问 label；表达开关或展开状态的按钮还必须有 value 或 hint。
- 状态不能只靠颜色表达。ready、local preview、warning、error、permission denied、sync conflict、loading 等状态必须有文案、图标或布局语义。
- Dynamic Type、较长英文 / 德文 / 俄文、中文、日文、韩文和未来 RTL 不能导致主操作不可见、按钮文字溢出或内容互相遮挡。
- Reduce Motion 开启时，面板展开 / 收起、carousel、loading 和状态切换不能依赖动画本身传达含义。
- 任何会读取照片、录音、Speech、OCR、文件、Keychain、网络、AI Provider、同步或导出的入口，都必须在触发前有用户动作和当前界面语言说明；不得因页面出现自动触发敏感能力。
- UI 任务完成声明不能只靠编译。涉及页面结构或交互变化时，必须至少说明自动化覆盖、截图 / 手动验证范围和未验证风险。

## 4. 默认推荐

### 4.1 iPhone 交互

- 主操作放在触控自然可达区域，尤其是 onboarding、创建记录、保存、继续练习和确认类动作。
- 设置、AI Provider、同步、导入导出和隐私属于低频配置，不进入底部 Tab。
- 编辑、保存、删除和配置 sheet 应轻量、清楚，少量字段优先使用语迹主题化 panel，而不是无差别放大系统 `Form`。
- iPhone 顶部语言空间入口用于快速切换和进入管理，不恢复只读 summary。
- 横向手势不能干扰系统返回手势；自定义边缘手势只在明确平台和区域约束下使用。
- 小屏和 Dynamic Type 下，按钮可以换行或改用图标加辅助标签，但不能缩小触控目标。

### 4.2 iPad 交互

- regular width 优先使用多栏结构：sidebar、主内容区、学习面板或 inspector。
- compact width、Slide Over 和窄 Stage Manager 窗口优先保证主内容可读，辅助面板可以自动或手动收起。
- iPad 顶部 toolbar 服务当前任务：搜索、面板切换、新建记录等；低频设置入口放在 sidebar footer 或设置 route。
- 指针设备存在时，标准 Button、List row、context menu 和 hover feedback 应自然可用；自定义可点击区域需要明确 `contentShape` 和可访问语义。
- 键盘用户应能进入主列表、主内容、设置详情和主要操作；隐藏面板后不能丢失当前选择。
- 旋转、Split View 比例变化和 Stage Manager resize 不应重置当前记录、练习步骤、设置 route 或输入草稿。

### 4.3 macOS 交互

- 主窗口应可调整尺寸，并设置合理最小尺寸；窗口缩放后主内容仍可读可操作。
- `Settings...` 使用 `Cmd+,`；New Entry、Search、Toggle Sidebar、Toggle Inspector 等高频命令应有菜单或快捷键镜像。
- 菜单命令不得有空 action。未接入真实能力时，命令应打开明确的 local mock 或 unavailable 状态。
- Sidebar selection、主区 route、inspector 内容和 Settings scene 之间的状态来源必须清楚，不应各自复制业务状态。
- toolbar 和 sidebar item 使用稳定命名；桌面用户应能从菜单栏或快捷键重新发现同一能力。
- 支持右键 context menu 的列表项，应只提供当前对象适用的操作；破坏性操作使用 destructive 语义和确认路径。
- hover tooltip 可以补充图标解释，但不能成为唯一说明；VoiceOver 和键盘用户仍需要 label、value 和 hint。

### 4.4 可访问性

- 可交互元素必须有可理解名称。图标、状态 badge、面板切换、播放、保存、删除、AI 测试、同步和导出入口尤其不能只暴露图标。
- 选中、当前、已保存、失败、不可用、运行中、已取消和本地预览必须通过 accessibility value、trait 或邻近状态文案表达。
- 删除语言空间、清空数据、导出、外部 AI 请求和权限流程必须提供可恢复路径、确认路径或清楚后果说明。
- 文本行高、列表行高度、sheet detent 和 scroll 区域必须允许 Dynamic Type；不得通过缩小字号解决布局冲突。
- 混合语言内容需要考虑朗读语义。目标语言句子、母语解释和界面 chrome 不应被同一个本地化字符串混在一起。
- 对比度不足、仅靠浅灰说明、仅靠红黄状态、仅靠动画提示，均视为可访问性风险。

### 4.5 验证入口

页面或交互任务的最低验证应包含：

- 对应 package 的聚焦测试；SwiftUI presentation model、route、panel helper、状态映射和本地化 key 优先自动化。
- `scripts/verify.sh`，除非任务是纯文档或当前环境缺少明确工具并记录剩余风险。
- iPhone 小屏 / iPhone 17、iPad regular / compact、macOS 默认窗口 / 缩小窗口的截图或人工验证记录。
- 至少英文和简体中文文案检查；涉及空间紧张控件时，增加较长语言 smoke。
- 涉及可访问性状态时，记录 VoiceOver、键盘焦点、Reduce Motion、Dynamic Type 或指针 / hover 的检查范围。

## 5. 可演进部分

- 是否引入系统化 UI 自动截图测试。
- 是否建立专门的 accessibility lint 或 snapshot 工具。
- macOS Command Palette、多窗口、DocumentGroup 或 AppKit bridge 的深度。
- iPad 多窗口和 Stage Manager 下的状态恢复策略。
- 发布前完整 VoiceOver 脚本、伪本地化和 RTL 验证矩阵。

这些内容可随着 MVP 推进逐步收紧，但不得把当前未验证能力写成已完成。

## 6. 反例

不应这样做：

- 在 iPad 上横向拉满 iPhone 单列页面。
- 在 macOS 上只提供移动端按钮，不提供菜单、快捷键或窗口语义。
- 用颜色变化表达 AI Provider 测试失败，却没有错误文案和恢复路径。
- 图标按钮没有 label，VoiceOver 只读出系统图标名或本地化 key。
- 为了容纳翻译文本而缩小字号、负字距或压缩触控目标。
- 页面打开时自动请求 Photos、麦克风、Speech、Keychain、AI Provider 或同步权限。
- 把未接入真实能力的命令做成空 action。

## 7. AI 开发提示

AI 在新增或修改 Apple 三端 UI 前，必须先回答：

- 这个界面在 iPhone、iPad 和 macOS 上分别由什么平台外壳承载？
- 当前操作是主流程、配置流程、临时任务、inspector、sheet、popover 还是 Settings scene？
- 是否需要触控、指针、键盘、菜单命令或快捷键？
- 哪些状态需要通过文案、图标、accessibility value 或 trait 表达？
- Dynamic Type、长文案、窄窗口和 Reduce Motion 下是否仍可操作？
- 是否涉及照片、音频、OCR、Speech、AI Provider、Keychain、同步、导出或权限？
- 哪些行为可用单元测试证明，哪些必须截图或人工验证？

如果无法回答这些问题，应先补任务方案或更新相关 spec，不应直接实现页面。

## 8. 变更记录

- 2026-05-22：创建 Apple 三端交互与可访问性规范。原因：文档体系审查确认相关规则分散在 UI、导航、本地化和测试文档中，需要一个长期入口支撑 AI 辅助编程、Apple 平台体验和可访问性验收。影响范围：iPhone、iPad、macOS UI 任务、测试文档、规范入口和后续人工验证。是否需要 ADR：否，延续 SwiftUI Multiplatform 和三端分平台 UI 决策。
