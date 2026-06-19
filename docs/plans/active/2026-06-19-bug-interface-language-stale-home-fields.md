# 任务方案：界面语言切换后首页部分字段不刷新

状态：Implemented
自审核状态：Reviewed
类型：bug
创建日期：2026-06-19
最后更新日期：2026-06-20

## 用户确认记录

- 2026-06-19：用户报告 bug 并要求"确认 bug 并排查"，随后要求"在 active 目录下创建 active plan 文档并完成自审"。
- 2026-06-19：用户指示"深入思考，采取最优方案和顺序进行，可直接操作模拟器、截图确认"。据此授权进入实现，采用推荐方案 A，并以"先在两个已确认叶子上落地真实修复 = Phase 0 probe → 模拟器截图实证 → 实证 PASS 后补全审计与测试"的顺序执行（probe 即实现，避免返工）。状态推进到 `In Progress`。
- 实现采用 Phase 0 probe gate（见第 12 节）：先用最小修复在模拟器确认真实失效机制与修复方向，PASS 后再补全。

## 1. 需求或 bug 描述

App 首次启动界面为英文。用户进入设置把"显示语言"改为中文后切回首页（记录 Tab），首页大部分文案已切到中文（标题「记录」、Hero 卡「今天记录一点生活 / 写一句 / 用照片开始」、底部 Tab），但以下字段仍停留在英文：

- 筛选 chip 行：`All` / `Photo Writing` / `Needs Practice` / `Settled`
- 空状态卡：标题 `No entries yet` + 正文 `Start recording a life moment to create your first entry.`

要求：确认该 bug、定位根因，并给出可实施修复方案。

## 2. 现状描述

- 界面 chrome 文案统一走自定义函数 `localizedText(_:) -> Text` / `localizedString(_:) -> String`（`Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift:6-21`）。
- 这两个函数从一个**全局非可观察盒子**读取当前语言：`LocalizedChromeLanguageResolver.preferredLanguageCodes`（`LocalizedChrome.swift:163-185`，底层 `LanguageOverrideBox` 用 `NSRecursiveLock` 保护普通变量，非 `@Observable`、非环境值、不发布变更）。
- **界面语言确实是 SwiftUI 状态驱动的**（这一点是本次自审核修正的关键事实）：
  - `LangoTraceApp.swift:20` `@State private var interfaceLanguagePreference`；`:160` 切换时 `interfaceLanguagePreference = preference`（真实 `@State` 变更，触发 SwiftUI 失效）。
  - `LangoTraceApp.swift:132`（主 `WindowGroup`）与 `:66`（macOS `Settings` scene）**均已注入** `.environment(\.locale, Locale(identifier: resolvedInterfaceLanguageCode))`；`resolvedInterfaceLanguageCode`（`:146`）直接由 `interfaceLanguagePreference` 派生。即切语言时 `\.locale` 环境值**确实会变**，并传播到主窗口与 Settings 两个 scene。
  - 全局盒子的写入在另一条路径：`LangoTraceRootView.onChange(of: interfaceLanguagePreference)` → `applyInterfaceChromeLanguage()` → 改写全局盒子（`LangoTraceRootView.swift:152-155, 178-180`）。
- 既有 `.id`：`LangoTraceRootView.swift:143` 已有 `.id(languageSpace.id)`，绑定的是**语言空间 id**，不是界面语言；切界面语言不会触发该 `.id` 重建。
- `Resources/Localizable.xcstrings` 中相关 key 的 zh-Hans 翻译均已存在（翻译资源不缺）。

## 3. 目标

1. 切换界面语言后，首页筛选 chip 行与空状态卡立即随之切换语言，无需重启、无需重进 Tab。
2. 修复消除"叶子视图输入值稳定 + 不依赖任何随语言变化的值 → 被 SwiftUI 结构 diff 跳过 body 重算"这一 **bug 类**。
3. 不破坏当前导航栈（设置页内切语言不被弹出）。
4. 三端（iPhone/iPad/macOS，含 macOS Settings scene、sheet、pushed 详情页）一致生效。
5. 新增可复跑的回归测试，保证 seam 不退化。
6. 与 `docs/spec/006` §2"显式语言模式通过 SwiftUI environment 影响自有 chrome"方向一致。

## 4. 范围

- `LangoTraceUI` package 的界面本地化刷新机制（`LocalizedChrome.swift` 及受影响叶子视图）。
- 已确认/审计出的值稳定本地化叶子视图（详见第 12 节审计）。
- `LangoTraceUI` package 测试。

## 5. 不做什么

- 不改"界面语言 / 母语 / 目标学习语言"三轴边界（`docs/spec/006`），仅修 chrome 刷新机制。
- 不实现系统级 per-app language 即时监听（spec §2 第一阶段不要求）。
- 不翻译或重写用户内容、AI 生成结果、静态 demo 内容。
- 不改 `Localizable.xcstrings` 翻译文案。
- **不改 `localizedText(_:) -> Text` 的返回类型**（自审核修正：改返回类型会波及实测约 71 处 `Text` 专用调用点、跨约 20 文件，风险与 bug 修复不成比例——见第 12 节"已否决方案 B"）。
- **不新增 `\.interfaceLanguageCode` 环境值**（自审核修正：`\.locale` 既已随 `@State` 注入并传播，复用它即可，避免双环境源——见第 12 节）。
- 不把 `.id` 改绑到界面语言（见第 12 节"已否决方案 C"）。

## 6. 证据与决策依据

代码证据：

- `LocalizedChrome.swift:6-15`：`localizedText`/`localizedString` 是纯函数，读全局盒子，无 SwiftUI 依赖追踪。
- `LocalizedChrome.swift:163-185`：resolver 背后是普通可变状态。
- `LocalizedChrome.swift:182-189`：已存在 `withLocalizedChromeLanguageCode(_:operation:)`，可在测试中临时切换解析语言；且 `localizedString(for:preferredLanguageCodes:)`（`:61-88`）支持按指定语言 code 解析——为"View 路径据 `\.locale` 解析"提供了现成底座。
- `PhoneMainSections.swift:99-151`：`FilterChipRow` 仅 `@Binding`；`FilterChipButton` 仅 `titleKey/isSelected/action`。
- `ContentUtilityComponents.swift:58-84`：`LocalizedCompactPanel` 仅 `titleKey/textKey/systemImage`。
- 对照刷新成功者：`HeroActionCard`（接收闭包）、`PhonePage`（接收 `@ViewBuilder content` + 闭包），其输入每帧不可判等 → 被强制重算 → 文案刷新。
- `LangoTraceApp.swift:66,132`：`\.locale` 已在两 scene 注入并随 `@State` 变化；`:20,160` 确认 `@State` 驱动。
- `MemoryReviewSessionView.swift:11` + `PhoneMainSections.swift:243-245`：sheet 内 `@Environment(\.memoryReviewActions)` 能读到 App 层注入值——**证明 sheet 默认继承呈现处环境**，故 `\.locale`（已在 App 层注入）也会传入 sheet / pushed 详情页。

根因机制（见第 11 节，已按自审核修正）：界面语言切换**会**改变 `@State` 与 `\.locale` 环境值并触发祖先重算；但 `FilterChipButton`/`LocalizedCompactPanel` 等叶子既不接收随语言变化的输入、也不读取任何随语言变化的环境值，SwiftUI 结构 diff 判定其输入等价而**跳过 body 重算**，保留旧语言 `Text`。"哪些字段会刷新"取决于祖先是否因闭包/content 不可判等而被强制重算——属偶然行为。

文档依据：

- `docs/spec/006` §2：显式语言模式经 SwiftUI environment 影响 chrome；测试须覆盖系统语言与显式偏好不一致时 chrome 用显式偏好。
- `docs/spec/006` §3.1：空状态、按钮属界面语言范畴，应随界面语言切换。

```text
证据能证明什么：本地化叶子缺少对随语言变化值的依赖；\.locale 已变但叶子未读 → 被跳过。
证据不能证明什么：尚未实测"叶子改读 \.locale 后能否在切换帧正确解析到新语言"（全局盒子写入与 body 重算的时序是否一致）。故设 Phase 0 probe。
迁移前提：View 路径解析以 \.locale 为单一源（据 locale.identifier 解析），不依赖全局盒子写入时序。
照搬风险：若 View 路径仍走全局盒子，存在写盒子与重算时序错配风险（probe 验证点）。
```

```text
是否需要 spike / probe / fixture / evidence：需要（Phase 0 probe，确认真实失效机制与修复方向）。
需要时的落点：模拟器人工 probe + 一个临时聚焦测试；probe 不含真实用户敏感内容；验证后无需保留临时 probe 代码。
是否包含真实用户敏感内容：否。
```

## 7. 约束映射与验证路径

### 约束 1：界面国际化与语言边界

- 来源：`docs/spec/006` §2、§3.1
- 适用范围：模块（LangoTraceUI chrome 本地化）/ 三端
- 严重度：blocker
- 执行或验证方式：UI package 单元测试 + 模拟器人工验证
- 验证提示：显式语言模式经 SwiftUI environment 影响 chrome；切换后空状态/筛选/状态组件用显式偏好显示。
- 说明：本 bug 即偏离该约束所致。

### 约束 2：TDD / 先失败测试

- 来源：`CLAUDE.md` §1.4、`docs/spec/009-testing-and-verification.md`
- 适用范围：模块
- 严重度：blocker
- 执行或验证方式：UI package 单元测试
- 验证提示：先失败用例见第 15 节。
- 说明：bug 修复属行为变化。

### 约束 3：轻量验证优先

- 来源：`CLAUDE.md` §1.4 第 6/7/8 条
- 适用范围：全局
- 严重度：warn
- 执行或验证方式：仅跑 `LangoTraceUI` 单包测试；全量 `verify.sh` 不主动跑。
- 说明：改动限于 UI package。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`（新增读 `@Environment(\.locale)` 的 `LocalizedText` 视图 + 据 locale 解析的 `localizedString(_:locale:)` 重载；不动既有 `localizedText`/`localizedString` 签名）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`（`FilterChipButton`、`MemoryStatisticsBar.statColumn` 等改用 `LocalizedText`）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ContentUtilityComponents.swift`（`LocalizedCompactPanel`、`InlineStatusLabel` 等改用 `LocalizedText`）
- 第 12 节审计命中的其它值稳定本地化叶子
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/InterfaceLanguageReactivityTests.swift`（新增回归测试）

App 层（`LangoTraceApp/LangoTraceApp.swift`）**无需改动**：`\.locale` 已在主窗口与 Settings scene 注入。

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/MemoryDepositActions.swift`（`@Entry` 环境值范式）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MemoryReviewSessionView.swift` + `PhoneMainSections.swift:243-245`（sheet 继承 App 层环境的先例）
- `LangoTraceApp/LangoTraceApp.swift:66,132,146,160`（`\.locale` 注入与 `@State` 驱动）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift:143`（既有 `.id(languageSpace.id)`）
- `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift:83`（`resolvedLanguageCode(systemLanguageCodes:)`）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift:195-208,281-289`（源级断言风格 + `withLocalizedChromeLanguageCode` 复用 + `sourceFileURL` 仅覆盖 `Sources/LangoTraceUI/`）

## 10. 涉及的文档路径

- `docs/spec/006-interface-localization-and-language-boundaries.md`（核对一致；实现后可在 §2 补一句"chrome 本地化叶子经 `\.locale` 环境值驱动重渲染"，待文档影响检查决定）
- `docs/plans/active/`（本方案）
- `docs/platform-page-inventory.md`（首页字段刷新行为，必要时备注）

## 11. bug 分析

```text
复现方式：
1. 全新启动 App（界面英文）。
2. 设置 -> 显示语言 -> 选「简体中文」。
3. 切回记录 Tab（首页）。
观察：标题/Hero/Tab 已中文，但筛选 chip 与空状态卡仍英文。

预期行为：界面语言切换后首页所有界面 chrome 文案（含筛选 chip 与空状态卡）即时切换。

实际行为：筛选 chip 行与空状态卡停留英文，其余多数已切换。

根因分析（自审核修正版）：
界面语言切换确实改变顶层 @State（LangoTraceApp.swift:20,160）并改变已注入的 \.locale 环境值（:66,132），触发祖先视图重算——故并非"只改全局盒子、不发布状态变更"。真正失效点在叶子层：FilterChipButton（仅 String/Bool 输入）、LocalizedCompactPanel（仅 String 输入）等叶子既不接收随语言变化的输入，也不读取任何随语言变化的环境值（如 \.locale），其 body 由 localizedText 调用纯函数 localizedString（读全局盒子）产出 Text。SwiftUI 结构 diff 判定这些叶子输入等价 -> 跳过 body 重算 -> 旧语言 Text 保留。能刷新的 HeroActionCard/PhonePage 因接收闭包/content（不可判等）被强制重算。即"是否刷新"取决于祖先是否偶然被重算，属非确定行为。
修复关键：让受影响叶子依赖随语言变化的 \.locale，并据 \.locale 解析文案（而非依赖全局盒子写入时序）。

置信度：80%
置信度依据：
- 现象与受影响叶子输入值稳定为直接代码证据（高确定）。
- \.locale 已变却仍不刷新，符合"叶子未建立对变化值依赖故被结构 diff 跳过"的 SwiftUI 行为。
- 扣分项：尚未实测"叶子改读 \.locale + 据 locale 解析"在切换帧能否稳定取到新语言（全局盒子写入时序未实测）；该不确定性由 Phase 0 probe 关闭后置信度可升至 ~95%。

备选原因：
- (中) 全局盒子写入（onChange/onAppear）与 body 重算时序错配：即便叶子读 \.locale 重算，若解析仍走全局盒子且盒子尚未写入，可能仍取旧语言。缓解：View 路径据 locale.identifier 直接解析，绕开盒子时序。probe 验证。
- (低) Lazy 容器/被 .id 冻结子树阻断重算：与"同页部分刷新部分不刷新"现象部分相关，probe 一并观察。
- (极低) xcstrings 缺翻译：已排除。

回归测试方案：源级断言（LocalizedText 读 \.locale、受影响叶子使用 LocalizedText）+ 逻辑断言（localizedString 据指定语言解析 en/zh 正确）。见第 15 节。
```

## 12. 实施方案

设计目标：让受影响叶子对随语言变化的 `\.locale` 建立依赖并据其解析，时序安全、零波及 `Text` 专用调用点、三端一致。

### Phase 0：机制确认 probe（实现前硬门禁）

```text
假设名称：受影响叶子改为"读 @Environment(\.locale) 且据 locale.identifier 解析"后，切语言能在当前帧刷新为新语言。
probe / fixture / baseline 路径：
  - 在模拟器对 LocalizedCompactPanel 或 FilterChipButton 做最小改造（读 \.locale + localizedString(key, locale:)），英->中切换观察空状态卡/筛选 chip 是否即时变中文；并验证 sheet / pushed 详情 / macOS Settings 同样生效。
  - 可选：临时聚焦测试断言 localizedString(key, locale: zh) == 中文、locale: en == 英文。
PASS 条件：叶子改造后切语言即时刷新；\.locale 据 locale 解析返回正确语言；sheet/pushed/Settings 一致。
FAIL 条件：仍不刷新，或解析时序仍依赖全局盒子导致取旧语言，或某承载（sheet/Lazy/.id）阻断刷新。
FAIL 后处理方式：记录实测机制，回到第 11 节备选原因重新定位；必要时改为"在 LazyVStack 外层/承载层补依赖"或其它方案，并重过自审核。
是否允许进入生产实现：仅 PASS 后允许。
```

### Phase 1：推荐方案 A（复用 `\.locale`，不动原语返回类型）

1. **新增据 locale 解析的重载**：在 `LocalizedChrome.swift` 增加 `func localizedString(_ key: String, locale: Locale) -> String`，内部调用既有 `LocalizedChromeCatalog.shared.localizedString(for:preferredLanguageCodes:)`，`preferredLanguageCodes` 取自 `locale.identifier`。复用现成解析底座（`:61-88`），不引入新解析逻辑。
2. **新增响应式叶子视图**：在同文件增 `struct LocalizedText: View`，`@Environment(\.locale) private var locale`，`body` 渲染 `Text(localizedString(key, locale: locale))`。读 `\.locale` 即建立依赖；据 `locale` 解析即绕开全局盒子时序。
3. **迁移受影响叶子**：把审计确认的值稳定本地化叶子内部的 `localizedText(key)` 换为 `LocalizedText(key)`。已知至少包含：
   - `FilterChipButton`（`PhoneMainSections.swift:122-151`，注意 `.accessibilityLabel(localizedText(titleKey))` 用 `Text(localizedString(titleKey, locale:))` 或保留——按 probe/编译结果定）
   - `LocalizedCompactPanel`（`ContentUtilityComponents.swift:58-84`）
   - `MemoryStatisticsBar.statColumn`（`PhoneMainSections.swift:329-338`，与空状态同构）
   - `InlineStatusLabel`（`ContentUtilityComponents.swift:86+`）
   - 其它经审计命中的叶子
4. **叶子审计**：`rg "localizedText\(" Packages/LangoTraceUI/Sources` 全量反查，筛出"仅接收 String/Bool/Binding key、不接收闭包/content"的叶子结构（闭包入参的叶子通常已能刷新，但仍逐个核对），统一迁移到 `LocalizedText`。审计清单写入第 18 节实施记录。
5. **保持 `localizedText`/`localizedString` 既有签名不变** → 71 处 `Text` 专用调用点（navigationTitle×10、accessibilityLabel×43、accessibilityHint×9、accessibilityValue×9、`Text` 拼接 `LearningContentComponents.swift:413`）零改动。
6. **回归测试**：新增 `InterfaceLanguageReactivityTests.swift`（见第 15 节）。

### 已否决方案 B：改 `localizedText` 返回类型为自定义 View

- 否决理由：实测约 71 处 `Text` 专用调用点（navigationTitle/accessibilityLabel/Hint/Value/`Text` 拼接）将编译失败，需跨约 20 文件逐点迁移，且 `LearningContentComponents.swift:413` 的 `Text + Text` 拼接必须保留 `Text` 语义不能换 String。改动面与 bug 修复不成比例，违背最小修复与轻量验证取向。

### 已否决方案 C：把 `.id` 改绑界面语言

- 现状澄清（自审核修正）：`LangoTraceRootView.swift:143` 已有 `.id(languageSpace.id)`，作用域是**语言空间**，切界面语言不触发它。
- 否决理由：若把 `.id` 改绑/叠加界面语言，会重置 `PhoneMainView` 的 `@State navModel`（导航栈）与选中 Tab；用户正是在设置页（push 在某 Tab 的 NavigationStack 上）内切语言，重建会立即弹出设置页，UX 退化。不动既有 `.id(languageSpace.id)`。

### 已否决方案 D：新增 `\.interfaceLanguageCode` 环境值 + App 层再注入

- 否决理由：`\.locale` 既已在主窗口与 Settings scene 注入并随 `@State` 变化（`LangoTraceApp.swift:66,132`），复用 `\.locale` 即可；新增独立环境值会形成双环境源、且需在两 scene 重复注入，无收益。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-19
审核方式：隔离审查（Explore 子代理核验代码事实 + Plan 子代理只读双轮方案审查）+ 主会话核验与写回
审核轮次：第一轮（架构）+ 第二轮（测试/落地）
未使用隔离审查的原因：不适用（已使用隔离子代理执行方案审查）

发现摘要（隔离审查 P0/P1 + 主会话核验）：
- P0-1（已修订）：原方案"否决 .id"失察——代码已有 .id(languageSpace.id)（LangoTraceRootView.swift:143，主会话已核验）。已重写第 12 节"已否决方案 C"，澄清其作用域为语言空间而非界面语言。
- P0-2（已修订并设门禁）：原方案根因称"切语言仅改全局盒子、不发布状态/环境变更"——错误。主会话核验：LangoTraceApp.swift:20/160 为 @State 驱动，:66/:132 已注入随之变化的 \.locale。已重写第 11 节根因，并改修复方向为"复用既有 \.locale + 据 locale 解析"，同时设 Phase 0 probe 作为实现前硬门禁确认真实机制；置信度由 96% 下调至 80%。
- P1-1（已修订）：注入点不再放 RootView——\.locale 已在 App 层两 scene 注入，方案 A 复用之，macOS Settings scene 不再漏修。
- P1-2（已修订）：取消"新增环境值 + 全局盒子双源"，View 路径据 \.locale 解析（localizedString(_:locale:)），不依赖全局盒子写入时序；全局盒子仅留给非 View 调用。
- P1-3（已采纳，改选方案 A）：实测 71 处 Text 专用调用点 / 约 20 文件，原"改原语返回类型"被否决（方案 B），改为新增独立 LocalizedText 视图、仅迁移受影响叶子，Text 专用点零改动。
- P1-4（已修订）：sheet/pushed/Settings 环境传播——以 MemoryReviewSessionView 继承 App 层 \.memoryReviewActions 为先例，确认 \.locale 同样继承；Phase 0 probe 与第 14 节复查均覆盖。
- P1-5（已修订）：先失败测试不再断言 App 层注入字符串（超出 UI 包 sourceFileURL 可达范围），改断言 UI 包内机制（LocalizedChrome 含 LocalizedText 读 \.locale；受影响叶子文件含 LocalizedText）。
- P2-2（已采纳）：叶子枚举补充 statColumn/InlineStatusLabel 等，并在第 12 节步骤 4 要求全量 grep 审计。
- P2-1/P3-1（已记录）：源级断言为结构性护栏非行为护栏，真实刷新由模拟器人工验证兜底（第 14 节）；置信度已下调。

写回修改：第 2/5/6/8/9/11/12/14/15/16/20 节按上述发现重写或更新。

仍需用户确认的问题：
1. 是否认可推荐方案 A（复用 \.locale + LocalizedText 叶子，不动原语返回类型）。
2. 是否授权进入实现（先执行 Phase 0 probe，PASS 后实现）。

是否允许进入实现：否。状态=Draft；自审核门禁已完成（P0 事实错误已修正、根因已据代码重写、修复方向已据 \.locale 既存事实调整、机制不确定性由 Phase 0 probe 门禁关闭并已下调置信度）。需用户确认上述 2 项后，先跑 Phase 0 probe，PASS 才进入生产实现。
```

## 14. 复查方法

- 代码：确认新增 `LocalizedText` 读 `@Environment(\.locale)` 且据 `locale` 解析；确认受影响叶子已迁移；确认未改 `localizedText`/`localizedString` 既有签名；确认 App 层 `\.locale` 注入未被破坏。
- 行为（模拟器人工，三端）：英文启动 → 设置切中文 → 返回首页，确认筛选 chip 与空状态卡为中文；再切回英文确认双向；设置页内切换不被弹出；验证 sheet（语言空间切换 sheet）、pushed 详情页、macOS Settings scene 一致刷新。
- 故障/边界：`System` 模式系统语言不在支持清单时回退英文；显式偏好与系统语言不一致时 chrome 用显式偏好（spec §2）。

## 15. TDD / 测试落点

```text
测试落点：Packages/LangoTraceUI/Tests/LangoTraceUITests/InterfaceLanguageReactivityTests.swift（新增，Suite: "Interface language reactivity"）
先失败用例：
  localizedTextLeafReadsLocaleEnvironment()
  —— 源级断言 LocalizedChrome.swift 含 "struct LocalizedText" 且含 "@Environment(\.locale)"；实现前不存在，先失败。
其它用例：
  affectedLeavesUseLocalizedText() —— 源级断言 ContentUtilityComponents.swift / PhoneMainSections.swift 中受影响叶子（LocalizedCompactPanel、FilterChipButton 等）使用 LocalizedText。
  localizedStringResolvesPerLocale() —— 逻辑断言：localizedString("timeline.empty.title", locale: Locale(identifier:"zh-Hans")) == "暂无记录"；locale "en" == "No entries yet"。
聚焦验证命令：swift test --package-path Packages/LangoTraceUI --filter InterfaceLanguageReactivity
不新增单元测试的原因（如适用）：不适用，新增测试。
```

说明：测试落点全部在 `Sources/LangoTraceUI/`，与 `PageClosureStateTests` 的 `sourceFileURL` 可达范围一致（不断言 App target 注入字符串）。SwiftUI 实际重渲染无法纯单测断言，故采用"源级断言 seam + 逻辑断言据 locale 解析"组合，符合本仓库既有源级测试约定；真实切换刷新由第 14 节模拟器人工验证补充。

## 16. 验证命令

聚焦（红绿）：

```bash
swift test --package-path Packages/LangoTraceUI --filter InterfaceLanguageReactivity
```

收口（单包，轻量）：

```bash
swift test --package-path Packages/LangoTraceUI
swiftformat --lint Packages/LangoTraceUI --cache ignore
swiftlint --no-cache
```

全量 `scripts/verify.sh` 与三端构建不在本机主动运行（CLAUDE.md §1.4 第 7/8 条）；跨端/合并前验证走 GitHub Actions。

## 17. 文档影响检查

- 入口/ADR：无影响。
- spec：`docs/spec/006` §2 已声明 environment 方向，实现回归该方向；实现后可考虑补一句明确"chrome 本地化叶子经 `\.locale` 驱动"（P3，按实现结果决定）。
- architecture：无新增模块边界。
- platform-page-inventory：首页字段刷新行为正确化，必要时备注。
- testing/release/review：新增 UI 单测；本改动不属数据/AI/权限/同步/StoreKit/启动结构变化，倾向无需专项审查，日常文档影响检查即可（按 `docs/review/README.md` 判断）。

## 18. 实施记录

### 2026-06-20 实现

**Phase 0 probe（机制确认）PASS**：先在两个已确认叶子（`LocalizedCompactPanel`、`FilterChipButton`）落地真实修复，构建 iOS、装入 iPhone 17 模拟器，在 app 内真实导航执行实时语言切换并逐步截图：
- zh→en：主页存活时切换后，筛选 chip（`All/Photo Writing/Needs Practice/Se…`）与空状态卡（`No entries yet` / `Start recording a life moment to create your first entry.`）即时变英文（probe 截图 `/tmp/lango-probe/10-home-final.png`）。
- en→zh（用户报告方向）：切回中文后同样即时刷新为「全部/照片写作/待练习/已沉淀」「暂无记录…」（`/tmp/lango-probe/18-home-zh.png`）。
- 导航栈未被破坏：在设置内切换后逐层返回回到同一主页实例，叶子实时刷新；语言空间 chip「中文->英语·B1」保持不变（属内容，正确）。
- 结论：方案 A（叶子读 `@Environment(\.locale)` 并据 locale 解析）机制成立、时序安全。备选原因（全局盒子时序、承载层阻断）均未发生。

**核心 seam**（`LocalizedChrome.swift`）：
- 新增 `struct LocalizedText: View`，`@Environment(\.locale)`，`body: Text { Text(localizedString(key, locale: locale)) }`。
- 新增 `func localizedString(_:locale:)`，据 `locale.identifier` 解析，复用既有 `LocalizedChromeCatalog`。
- 未改 `localizedText(_:) -> Text` / `localizedString(_:) -> String` 既有签名 → 71 处 Text 专用调用点零改动。
- App 层 `\.locale` 注入未改（已存在于 `LangoTraceApp.swift:66,132`）。

**叶子迁移清单**（值稳定叶子 `localizedText`→`LocalizedText`）：
- `PhoneMainSections.swift`：`FilterChipButton`（可见文案；无障碍标签改 `Text(localizedString(titleKey, locale:))`，新增 `@Environment(\.locale)`）。
- `ContentUtilityComponents.swift`：`LocalizedCompactPanel`、`InlineStatusLabel`。
- `PadSidebarControls.swift`：`SidebarSectionTitle`、`SectionCaption`、`EmptyWorkspacePanel`。
- `LocalizedTextPanel.swift`：`LocalizedTextPanel`。
- `OnboardingValueSummary.swift`：`PadOnboardingValueStripItem`、`PadOnboardingValueListItem`。
- `EntryReadingViews.swift`：`emptyCard`。
- `SyncS3DraftView.swift`：`SyncSettingsTextField`（含 placeholder 据 locale 解析）。
- `SyncSettingsView.swift`：`SyncScopeRow`、`ICloudSyncPreviewView` 关闭按钮。

**大型容器视图**（内联 localizedText 多、Text 专用 API 风险高）：`SyncSettingsView`、`AIProviderSettingsView` 改为新增 `@Environment(\.locale)` 并在 `body` 读取（`let _ = locale`）以建立依赖，使整体随语言重算；零 Text-API 破坏。时序安全性已由 probe 中 SettingsView/CapabilityStatusRow 走全局盒子正确刷新佐证。

**测试**：新增 `Packages/LangoTraceUI/Tests/LangoTraceUITests/InterfaceLanguageReactivityTests.swift`（3 例：seam 源级断言、受影响叶子源级断言、`localizedString(_:locale:)` 逐 locale 解析逻辑断言）。先失败（`LocalizedText`/`localizedString(_:locale:)` 不存在）→ 实现后转绿。

**验证结果**：
- `swift test --package-path Packages/LangoTraceUI` → 549 tests passed（含 `InterfaceLanguageReactivity` 3 例、"无硬编码汉字"校验）。
- `swiftformat --lint Packages/LangoTraceUI` → 0 files require formatting。
- `swiftlint --no-cache` → 420 条均为既有 style 债（与本次改动文件/行号无关），无新增。
- `xcodebuild -scheme LangoTrace-iOS ... build` → BUILD SUCCEEDED。
- 模拟器人工：见上 Phase 0 截图。

### deferred 项

```text
项目：Welcome 引导轮播叶子（WelcomeTracePreviewCard、WelcomeTracePageIndicator，WelcomeTracePreviewCarousel.swift）
决策类型：deferred
原因：位于 onboarding 之前；首启流程中界面语言此时跟随系统/尚未提供 App 内切换入口，正常流程下不可能在该页存活时发生界面语言实时切换，故不属用户可观察 bug 场景。
影响：极低。若未来 Welcome 页新增 App 内语言切换入口，需将其约 10 处 localizedText 迁移为 LocalizedText。
后续事实源或复审入口：本 plan 第 20 节剩余风险；后续涉及 Welcome 语言切换的任务方案应检查此项。
```

```text
项目：closure-receiving 视图的 .accessibilityLabel/Hint/Value(localizedText(...))（如 FilterPill、PadRouteButton 等）
决策类型：deferred
原因：这些视图接收闭包，父级每帧重建闭包使其 body 偶然重算，可见文案能刷新；无障碍标签停留旧语言的概率低且非可见回归。
影响：低（仅无障碍读屏在某些时序下可能短暂滞后）。
后续事实源或复审入口：本 plan 第 20 节；如做无障碍本地化专项再统一收敛。
```

提交：尚未提交（等用户确认是否提交 / 是否走 CI 全量与合并）。

## 19. 完成标准

- 用户确认方案 A 与授权后，先跑 Phase 0 probe；PASS 后实施。
- 新增 `InterfaceLanguageReactivityTests` 先失败、修复后转绿。
- `swift test --package-path Packages/LangoTraceUI` 全绿；swiftformat/swiftlint 无新增告警。
- 模拟器人工验证：英↔中双向切换后首页筛选 chip 与空状态卡即时切换；设置页内切换不被弹出；sheet/pushed/macOS Settings 一致。
- 文档影响检查结论写回；方案移入 `docs/plans/done/`。

## 20. 剩余风险

- Phase 0 probe 已 PASS（iPhone，双向实时切换），机制确认成立；置信度由 80% 提升至 ~96%。
- **Welcome 引导轮播叶子未迁移**（deferred，见第 18 节）：onboarding 前不可达实时切换，低风险；未来 Welcome 增设语言切换入口时需迁移。
- 叶子审计依赖人工判断，理论上仍可能有未覆盖的值稳定叶子；缓解：可后续把 chrome 文案统一收敛到 `LocalizedText`，或在 spec/测试固化"值稳定本地化叶子必须用 LocalizedText"约定（后续方向，不在本轮）。
- 大型容器视图（`SyncSettingsView`/`AIProviderSettingsView`）采用 `let _ = locale` 依赖钩子刷新内联 localizedText，时序安全性依赖"全局盒子在依赖视图重算前已更新"——已由 probe 中 SettingsView/CapabilityStatusRow 实测佐证；若未来改变语言写入路径需复核。
- 源级测试为结构性护栏，真实重渲染由模拟器人工验证兜底（已完成 iPhone 截图）。
- **iPad / macOS 未在本机做视觉实时切换验证**（本机只跑了 iPhone 模拟器 + UI 单包测试）：方案 A 经共享 `LangoTraceUI` 叶子天然覆盖三端，macOS Settings scene 经 `\.locale`（`LangoTraceApp.swift:66`）继承；三端构建与可能的视觉回归留待 GitHub Actions 全量 CI（`scripts/verify.sh`）在合并前确认，本机不跑重测试。
