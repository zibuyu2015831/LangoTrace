# 主流界面语言扩展方案

状态：Partially Implemented

日期：2026-05-18

关联文档：

- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/plans/done/2026-05-18-chore-interface-language-expansion-plan.md`
- `docs/testing/README.md`
- `docs/spec/interface-localization/2026-05-17-string-catalog-interface-language-settings-design.md`

复查依据：

- Apple Developer Localization：iOS / iPadOS 支持用户为单个 App 选择独立于设备语言的偏好语言。
- Apple Developer String Catalog / package localization：Swift package 或 framework 内的本地化资源需要通过对应 bundle 查找。
- App Store Connect localization：App Store metadata localization 只影响商店元数据，不等同于 App binary 内本地化。

## 1. 背景与判断

LangoTrace 的定位是“用生活记录学习语言”的本地优先语言学习 App，面向所有语种学习者，不应长期呈现为只服务中文用户或英语学习者的工具。当前界面语言只支持英文和简体中文，已经足够验证 String Catalog、App 内语言设置和三端页面闭环，但不足以支撑全球化产品愿景。

因此，主流界面语言扩展有必要进入路线图，但不应一次性扩大为完整多语种学习能力交付。界面语言只影响 App chrome，包括导航、按钮、设置、状态、隐私说明、请求预览和不可用能力说明；它不自动改变用户母语、目标学习语言、用户内容、AI 生成内容、TTS、OCR、语音识别或 Provider 输出。

## 2. 第一批语言清单

第一批正式候选界面语言：

| Code | 界面语言 | 进入第一批的理由 |
| --- | --- | --- |
| `en` | English | Source language、fallback、全球发行基础。 |
| `zh-Hans` | 简体中文 | 当前开发验证语言，也是中文用户主要界面语言。 |
| `es` | Español | 西班牙语属于全球主流语言和重要 App 市场语言，不应被归为小语种。 |
| `ja` | 日本語 | 日本是重要付费 App 市场，且与语言学习场景高度相关。 |
| `fr` | Français | 法语覆盖欧洲、加拿大和多地区学习市场。 |
| `de` | Deutsch | 德语是重要欧洲市场语言，适合作为长文本布局压力测试语言。 |
| `ko` | 한국어 | 韩国是重要移动 App 和语言学习市场。 |
| `ru` | Русский | 俄语覆盖广泛，能提前暴露西里尔文字、长词和断行问题。 |

小语种暂不进入第一批正式支持清单。后续新增语言必须经过同样的资源、布局、测试和发布材料评估。

## 3. 产品边界

### 3.1 支持内容

第一批语言只表示 App 自有界面可以显示对应语言。覆盖对象包括：

- Welcome / Onboarding / Main 的 App chrome。
- iPhone Tab、iPad workspace、macOS sidebar 和 inspector。
- 设置页、设置详情、状态说明和不可用能力说明。
- 本地优先、AI Provider、同步、隐私和请求预览相关说明。
- App 内可访问 label、hint 和 value。

### 3.2 不代表的能力

界面语言扩展不代表以下能力已经完成：

- 对应目标学习语言空间完整可用。
- 对应语言的 TTS、Speech、OCR 或手写识别质量已验证。
- AI Prompt 已为对应母语或目标语言完成提示词优化。
- App Store 元数据、截图、隐私政策和客服材料已完成所有语言版本。
- 用户内容、mock 学习内容或已生成内容会自动翻译。

### 3.3 对用户的表达

设置页和发布材料需要避免“支持西班牙语学习 / 支持日语学习”这类模糊表达，除非对应学习能力已经完成。准确表达应是：

- 支持 `English / 简体中文 / Español / 日本語 / Français / Deutsch / 한국어 / Русский` 界面语言。
- 目标学习语言、母语讲解和 Provider 输出由语言空间和 AI 请求设置决定。

## 4. 架构影响

### 4.0 架构复查结论

本次架构复查确认：`Localizable.xcstrings` 继续放在 `LangoTraceUI` package 内是当前阶段的正确选择，因为现有 Welcome、Onboarding、iPhone、iPad 和 macOS 主界面 chrome 都由该 package 承载。这个放置方式的边界也必须明确：它只解决 package 自有 SwiftUI 文案的资源归属，不自动代表主 App bundle、InfoPlist、App Intents、系统 Settings、StoreKit、权限弹窗、文件选择器、分享面板或第三方 SDK UI 已经完成相同语言支持。

App 内语言设置和系统 per-app language 必须并存但分层：

- `System` 模式：语迹跟随 Apple 平台为当前 App 选择的 bundle localization。实现时应优先使用 `Bundle.main.preferredLocalizations` 或等效 bundle localization 结果与支持语言清单求交集，而不是只读取一个手写系统语言数组。
- 显式语言模式：用户选择 `en / zh-Hans / es / ja / fr / de / ko / ru` 时，语迹通过 SwiftUI `locale` 环境和 UI 层本地化封装覆盖 App 自有 SwiftUI chrome。
- 显式语言模式不修改系统 per-app language，不改变 `Bundle.main.preferredLocalizations`，也不承诺影响任何系统承载界面。
- 如果某段 UI 必须使用 `String(localized:bundle:)` 这类立即求值 API，必须显式传入当前 resolved locale；否则应保持为 `Text`、`Label` 或 label builder，让 SwiftUI 环境驱动刷新。

因此，新增语言的正式支持需要同时满足两套条件：`LangoTraceUI` package 的 String Catalog 覆盖 App chrome，App target 通过 `CFBundleLocalizations` 或等效本地化资源声明 bundle 级支持。缺少任一层，都只能称为“内部候选语言”或“App 自有 SwiftUI chrome 候选”，不能称为完整系统级 App 语言支持。

### 4.1 Core 模型

`InterfaceLanguagePreference` 当前已经包含第一批偏好值：

- `system`
- `en`
- `zh-Hans`
- `es`
- `ja`
- `fr`
- `de`
- `ko`
- `ru`

当前实现已经把 Core 偏好值和 App target `CFBundleLocalizations` 扩展到 8 种界面语言；但 `LangoTraceUI` 的 String Catalog 仍未完成所有 key 的 8 语言覆盖，因此不能称为完整实现。后续扩展应避免在多个 `switch` 中手写散落逻辑。推荐继续维护稳定的支持语言定义，例如：

- code：`en`、`zh-Hans`、`es`、`ja`、`fr`、`de`、`ko`、`ru`
- native display name：`English`、`简体中文`、`Español`、`日本語`、`Français`、`Deutsch`、`한국어`、`Русский`
- fallback title key：供 UI 层 String Catalog 渲染设置选项名称。

`System` 仍然是偏好模式，不是一种语言。系统语言解析规则应按 BCP 47 前缀匹配：

- `es-MX`、`es-ES` 解析为 `es`
- `ja-JP` 解析为 `ja`
- `fr-CA`、`fr-FR` 解析为 `fr`
- `de-DE`、`de-AT` 解析为 `de`
- `ko-KR` 解析为 `ko`
- `ru-RU` 解析为 `ru`
- `zh-Hans-CN` 解析为 `zh-Hans`
- 未支持语言回退 `en`

中文脚本需要显式处理：第一批只包含 `zh-Hans`，不把 `zh-Hant`、`zh-HK` 或 `zh-TW` 自动映射到简体中文。若用户系统为繁体中文且没有显式选择简体中文，`System` 模式应回退英文，直到繁体中文进入正式支持清单。

### 4.2 UI String Catalog

`LangoTraceUI` 的 `Localizable.xcstrings` 需要为 8 种语言补齐 App chrome。当前已有 catalog 和部分语言条目，但复审检查显示仍存在大量 key 未覆盖新增 6 种语言。新增语言不得只补设置页选项名称；如果用户可以选择该语言，核心导航、设置、隐私说明和主要状态都必须具备同等质量翻译。

关键要求：

- `sourceLanguage` 保持 `en`。
- 继续使用 `Bundle.module` 或统一封装查找 package 内资源。
- 新增语言前先完成 key 覆盖清点，避免部分页面落回英文或中文。
- String Catalog 只放 UI package 自有 chrome。`LangoTraceApp` target、InfoPlist、App Intent phrase、权限 purpose strings、StoreKit、本地通知、widget 或后续 extension 的用户可见文案，应放在各自 target 的本地化资源或平台配置中。
- package 内使用本地化 key 时，`Text`、`Label`、`Button` label、`navigationTitle`、`accessibilityLabel`、`TextField` prompt 和空状态文案都必须走 `Bundle.module` 或统一封装，不能依赖 main bundle 默认查找。
- 不把用户内容、seed entry、target sentence、translation、note 放入界面语言翻译范围。
- 品牌名 `LangoTrace` 和中文名 `语迹` 的翻译策略需要固定，不由机器翻译自由改写。

### 4.3 App Target 声明

如果设置页或产品文案声明系统 per-app language 可识别这些语言，App target 也需要声明对应本地化语言。后续实现应同步更新 XcodeGen 配置和生成后的 App target：

```text
CFBundleLocalizations = en, zh-Hans, es, ja, fr, de, ko, ru
```

权限 purpose strings、InfoPlist 展示字段、StoreKit、文件选择器、分享面板和第三方 SDK UI 不由 `LangoTraceUI` package catalog 自动覆盖，发布阶段必须单独检查。

当前 `project.yml` 已为 iOS 和 macOS target 声明 `en / zh-Hans / es / ja / fr / de / ko / ru`。后续修改必须继续写回 `project.yml`，不能只改生成后的 `.xcodeproj` 或 InfoPlist 产物，否则 XcodeGen 重新生成会丢失配置。

### 4.4 设置入口

设置详情页不应继续假设只有 3 个选项。推荐改为可滚动列表或分组 picker：

- `System`
- `English`
- `简体中文`
- `Español`
- `日本語`
- `Français`
- `Deutsch`
- `한국어`
- `Русский`

在 iPhone 上，语言列表需要支持动态字体和较长语言名，不使用横向 segmented control。iPad 和 macOS 可以使用列表、menu 或 picker，但语义必须与 iPhone 一致。

三端交互复查结论：

- iPhone：设置入口仍放在 Settings tab 的二级详情页；语言详情页使用 inline navigation title，列表行触控目标不少于 44pt，长语言名不压缩字号。不要把界面语言放入首次启动必填流程，避免与母语和目标学习语言混淆。
- iPadOS：regular width 下保持 sidebar / workspace / inspector 结构，语言设置在详情区域呈现；compact width、Slide Over 或窄 Stage Manager 窗口退化为 iPhone 式纵向层级。语言列表应支持 pointer、键盘焦点和滚动，不用临时 modal 打断当前 workspace。
- macOS：长期应接入 SwiftUI `Settings` scene 和 `Cmd+,` 的系统设置心智；当前 workspace 内 Settings 可以保留为产品内入口，但不应成为 Mac 上唯一偏好入口。语言选择控件应支持键盘导航、VoiceOver、窗口缩放和较长文案。

切换语言后，三端都必须保留当前 route、语言空间 preview、选中记录、练习步骤和侧栏展开状态。允许刷新可见文案，但不能重建学习上下文或清空用户输入。

## 5. 翻译与术语治理

第一批扩展语言必须有术语治理，不应直接批量机器翻译后上线。

首批稳定术语至少包括：

- LangoTrace
- 语迹
- Language Space
- Entry
- Memory
- Practice
- Interface Language
- Native Language
- Target Language
- Local-first
- AI Provider
- Request Preview
- Sync
- Privacy Boundary

要求：

- 每个术语在 8 种语言中形成稳定译法。
- String Catalog key 需要提供足够上下文，说明文案位于按钮、导航、状态还是正文。
- 对短按钮和长说明分开翻译，不能为了复用同一术语牺牲布局。
- 机器翻译可用于初稿，但正式支持前必须人工审校或至少人工抽检核心路径。

## 6. 布局与交互风险

新增语言会扩大布局压力：

- 德语和俄语容易让按钮、sidebar row、settings row 和 inspector 标题变长。
- 日语和韩语需要检查系统字体、行高、断行和较小屏幕下的可读性。
- 西班牙语和法语含重音字符，需要确认搜索、排序、VoiceOver 和截图显示正常。
- 俄语使用西里尔文字，需要确认字体 fallback 和截断策略。

设计要求：

- iPhone 小屏不能依赖大标题和内容标题同时出现，二级页优先 inline title。
- 语言设置列表不使用横向固定宽度 segmented control。
- 宽度敏感位置优先使用图标加可访问 label，或把长说明放到详情页。
- 不通过缩小字号解决翻译变长问题。
- Dynamic Type、窄 iPhone、iPad Split View / Stage Manager、macOS 窄窗口必须进入验证。

## 7. 测试与发布门槛

### 7.1 实现阶段测试

实现阶段至少需要：

- Core 测试：每个 code 的存储值、解析、无效值 fallback。
- Core 测试：`System` 对 `es-* / ja-* / fr-* / de-* / ko-* / ru-*` 的系统语言解析。
- UI 测试：设置项 key 稳定，语言列表包含 8 种语言和 `System`。
- String Catalog 检查：核心 key 均包含 8 种语言。
- App target 配置检查：`project.yml` 中 iOS 和 macOS target 的 `CFBundleLocalizations` 包含 8 种语言，且 XcodeGen 后仍保留。
- Bundle 解析检查：`System` 模式使用 bundle localization 结果解析支持语言，显式语言模式使用 App 内偏好覆盖 SwiftUI chrome。
- `scripts/verify.sh` 通过。

复审时使用的 String Catalog 覆盖检查口径：

```bash
jq '[.strings | to_entries[] | select(([.value.localizations["es"], .value.localizations["ja"], .value.localizations["fr"], .value.localizations["de"], .value.localizations["ko"], .value.localizations["ru"]] | any(. == null)))] | length' Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings
```

该命令只用于发现新增 6 种语言是否有缺口；发布前还需要人工审校、截图和权限 / StoreKit / App Store 文案检查。

### 7.2 截图和手动验证

每次普通开发不强制 8 语言全量截图。推荐矩阵：

- 常规回归：`en`、`zh-Hans`、`de`、`ru`。
- 字体和断行 smoke：`ja`、`ko`。
- 发布前完整验证：`en / zh-Hans / es / ja / fr / de / ko / ru` 三端覆盖。

覆盖页面：

- Welcome
- Onboarding
- iPhone main tabs
- iPad workspace
- macOS workspace
- Settings
- Interface Language detail
- Request Preview
- unavailable capability page

### 7.3 发布门槛

对外宣称某语言正式支持前，必须同时满足：

- App chrome 翻译完整。
- 核心路径人工审校或人工抽检通过。
- 三端关键页面截图无重叠、截断或明显混合语言问题。
- 权限 purpose strings、隐私说明、App Store 元数据和截图策略已同步。
- 系统 per-app language 与 App 内语言设置关系已在设置页说明清楚。

## 8. 推荐实施顺序

1. 更新国际化规范和方案文档，明确第一批语言清单和质量门槛。
2. 重构 `InterfaceLanguagePreference`，让支持语言清单集中定义。
3. 扩展 Core 测试，覆盖 8 种语言和 `System` fallback。
4. 扩展 UI 设置入口，改为可容纳 8 种语言的列表或 picker。
5. 补齐 String Catalog 8 种语言的核心 chrome 翻译。
6. 更新 App target 本地化声明。
7. 扩展测试文档和截图验证矩阵。
8. 执行三端 smoke，修复长文本和标题布局问题。
9. 发布前补齐 release 文档、权限文案和 App Store 元数据策略。

## 9. 不做事项

- 不在第一批支持小语种。
- 不把界面语言扩展绑定到语言空间持久化。
- 不在没有审校的情况下宣称正式支持新增语言。
- 不用界面语言设置重写用户内容或 mock 学习内容。
- 不承诺 App 内语言设置覆盖系统弹窗、StoreKit sheet、文件选择器或第三方 UI。

## 10. 当前推荐结论

建议将 `es / ja / fr / de / ko / ru` 加入第一批主流界面语言候选，与现有 `en / zh-Hans` 组成 8 语言清单。该扩展与 LangoTrace 的全球化定位一致，工程上可行，但必须按“模型集中定义、资源完整、布局验证、发布材料同步”的顺序推进。

在当前早期阶段，下一步不应直接批量填翻译，而应先创建实施计划，锁定 Core 支持语言模型、设置入口交互、String Catalog 完整性检查和测试矩阵。
