# 测试文档

本目录用于记录自动化测试策略、手动测试流程、模拟器验证、真机验证和回归检查清单。

语迹是长期付费 App，测试文档需要重点覆盖：

- 数据迁移。
- 本地存储。
- AI 请求隐私边界。
- 权限流程。
- 练习闭环。
- 同步冲突。
- StoreKit 购买和恢复购买。

## 模拟器截图验证

涉及 iPhone、iPad、macOS 页面结构、设计系统、导航和主要用户路径的改动，除自动化测试外，应保留一轮模拟器或本机截图验证记录。

最低截图覆盖：

- iPhone：welcome、onboarding、主 Tab、关键二级页。
- iPad：三栏默认状态、左栏收起、右栏收起、关键详情页。
- macOS：默认窗口、Sidebar 收起、Inspector 收起。

截图验证重点：

- 页面是否完整可操作，主行动入口是否可见。
- 文案、按钮、状态标签和面板是否溢出或互相遮挡。
- 触控目标是否过小。
- 空状态、不可用状态、请求预览和错误状态是否清楚。
- Mock、Disabled、未配置 AI Provider、同步未启用是否不会被误读成真实能力。
- 深色模式或 Reduce Motion 若被声明支持，必须有对应验证。

## MVP UI 手动验证清单

设置与练习状态闭环阶段至少覆盖：

- iPhone 设置：进入设置 Tab 后，语言空间、AI Provider、同步、本地数据、隐私边界和导出每一项都能进入二级说明页。
- iPhone 设置二级页：每页必须显示当前状态、当前边界、后续接入条件和“不会发生”的副作用说明。
- iPhone 练习：练习 Tab 中可从已有记录进入本地 mock 练习会话。
- iPhone 练习会话：准备、跟读、对照、完成四个步骤可以切换；下一步按钮不会触发音频、录音、AI 请求或持久化。
- iPhone 记录详情：逐句练习入口仍能进入同一 mock 练习会话。
- 不可用状态：无 rendering 的记录应显示不可用说明，而不是空白或误导性按钮。
- 隐私表达：AI Provider 未配置、同步未启用、导出未实现时，不得出现“已连接”“已同步”“已生成真实结果”等文案。

## 三端页面闭环验证清单

三端页面补全阶段完成后，除自动化测试外，需要执行一轮 iPhone、iPad 和 macOS 的页面闭环验证。

自动化最低要求：

- `swift test --package-path Packages/LangoTraceUI` 通过。
- route、filter、panel gesture 或其他可纯函数化的页面状态 helper 有单元测试覆盖。
- `scripts/verify.sh` 通过，除非当前环境缺少明确工具；跳过时必须记录原因和剩余风险。

iPhone 手动验证：

- `今日 / 记录 / 练习 / 记忆 / 设置` 五个 Tab 均可进入。
- `写一句` 打开本地记录编辑 sheet，保存后进入记录详情。
- `拍照`、`听一句` 和语言空间切换入口打开 unavailable 说明，不访问照片、麦克风、网络、Keychain、真实数据库、同步服务或导出文件。
- 记录详情可进入 mock 练习会话。
- 设置列表每个能力项可进入只读说明页。
- iPhone 17 和较窄宽度下文案、按钮和状态标签不溢出。

iPad 手动验证：

- regular width 默认工作台可显示时间线、主内容和学习面板。
- 时间线和学习面板可独立收起与展开，Reduce Motion 下不依赖动效理解状态。
- 记录选择会更新主内容和学习面板。
- 新建记录打开 sheet，保存后选中新记录并进入详情。
- 筛选按钮可切换全部记录、照片写作、待练习和已入记忆；选中态有可访问状态，不只靠颜色表达。
- 练习会话、设置详情和请求预览可从当前记录或面板进入。
- Split View、Slide Over 或 Stage Manager 窄窗口下，主内容仍可读，辅助面板不把主内容挤压到不可用。

macOS 手动验证：

- 默认窗口显示 Sidebar、主工作区和 Inspector。
- Sidebar section 可切换今日、记录库、练习、词句记忆、导入导出和设置。
- 新建记录打开 mock 编辑 sheet，保存后进入对应记录详情。
- Inspector 内容随记录详情、练习、设置、导入导出或 overview 变化。
- Sidebar 和 Inspector 可独立隐藏，窗口缩放后主内容仍可操作。
- 导入导出、向量索引、真实 AI、同步和快捷键未实现时，页面明确显示 unavailable 或 Local Mock，不写成真实能力。
- 未接线菜单、Command Palette、多窗口和快捷键不作为已完成项验收。

## 界面国际化基础验证清单

国际化基础落地阶段至少覆盖：

- Core 测试：界面语言偏好支持 `system / en / zh-Hans` 稳定存储值。
- Core 测试：跟随系统时，支持的系统语言解析为对应界面语言，不支持时回退英文。
- Core 测试：修改界面语言偏好不会改变 `LanguageSpacePreview` 的母语、目标语言或水平。
- Data 测试：设置能力列表包含“界面语言”入口，并明确它不改变用户母语、目标语言或已生成内容。
- UI 测试：新增设置能力项后，iPad 和 macOS footer 的 AI Provider、同步和设置路由仍指向正确页面；同名 enum case 必须使用显式类型避免误解析。

后续进入 String Catalog 和真实设置页时，还需要补充：

- 英文和简体中文截图，覆盖 Welcome、Onboarding、iPhone Tab、iPad workspace、macOS workspace 和 Settings。
- Dynamic Type、较窄 iPhone、iPad Split View / Stage Manager、macOS 窄窗口下的长文本检查。
- 至少一轮 RTL 或伪本地化 smoke，确认没有明显 left / right 硬编码导致布局方向错误。
- 权限 purpose strings、隐私说明、请求预览、unavailable 页面和 App Store 元数据的本地化检查。

## String Catalog 与界面语言设置验证清单

本清单用于验证 `LangoTraceUI` String Catalog、App 内界面语言设置和三端页面 chrome 本地化。实现完成后必须补齐实际截图或问题链接。

| 平台 | 界面语言 | 覆盖页面 | 结果 |
| --- | --- | --- | --- |
| iPhone 17 | English | Welcome + Onboarding + Settings | 通过，Onboarding 截图：`/private/tmp/langotrace-ui-review/iphone17-en.png`；Settings 路由和 Picker key 由 `LangoTraceUITests` 覆盖。 |
| iPhone 17 | 简体中文 | Welcome + Onboarding + Settings | 通过，Onboarding 截图：`/private/tmp/langotrace-ui-review/iphone17-zh-Hans.png`；Settings 路由和 Picker key 由 `LangoTraceUITests` 覆盖。 |
| iPad Pro 13-inch (M5) | English | sidebar + workspace + settings | 通过，Onboarding 截图：`/private/tmp/langotrace-ui-review/ipad-pro-13-m5-en.png`；Settings 路由和 Picker key 由 `LangoTraceUITests` 覆盖。 |
| iPad Pro 13-inch (M5) | 简体中文 | sidebar + workspace + settings | 通过，Onboarding 截图：`/private/tmp/langotrace-ui-review/ipad-pro-13-m5-zh-Hans.png`；Settings 路由和 Picker key 由 `LangoTraceUITests` 覆盖。 |
| macOS arm64 | English | sidebar + toolbar + inspector | 通过，Computer Use 读取窗口确认 Welcome / Onboarding 英文 chrome、主窗口和 Settings 可见；`screencapture` 在当前环境返回 `could not create image from display`，未生成文件截图。 |
| macOS arm64 | 简体中文 | sidebar + toolbar + inspector | 通过，Computer Use 读取窗口确认 Welcome / Onboarding 简体中文 chrome、主窗口和 Settings 可见；`screencapture` 在当前环境返回 `could not create image from display`，未生成文件截图。 |

补充记录：

- iPhone / iPad 模拟器 tab bar 的子元素在 Computer Use accessibility tree 中没有稳定暴露，未保留 Settings 页截图；Settings 可达性通过 `PageClosureStateTests` 的 route 断言和 settings capability localization key 断言覆盖。
- macOS Settings 页面复查时发现 settings row 的 accessibility label 曾暴露本地化 key；已改为使用 `Text` 组合本地化标题和状态，避免 VoiceOver 读出 catalog key。

检查标准：

- `System / English / 简体中文` 三个选项在设置详情页可见。
- 选择 English 或 简体中文后，语迹自有 SwiftUI chrome 文案刷新。
- 当前语言空间、选中记录、练习步骤和 mock 内容不被界面语言设置重写。
- 系统弹窗、StoreKit、文件选择器和第三方 UI 不作为 App 内语言设置的即时覆盖范围。
