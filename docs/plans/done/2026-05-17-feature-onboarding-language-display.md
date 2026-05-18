# 工作记录：首次启动语言选择与信息去冗余

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`

关联 ADR：

- `docs/decisions/004-use-language-space-as-primary-model.md`

关联提交：

- 未提交

## 1. 背景

当前 Mac、iPad、iPhone 首次启动都共用 `OnboardingView` 和 `OnboardingDraft`。用户在 Mac 端首页截图中指出两个问题：

- 首次启动表单存在信息冗余：
  - `母语` 左侧已经是字段名，右侧 Picker 已显示当前值，左侧副标题又显示一次 `中文`。
  - `目标语言` 同理重复显示 `英语`。
  - `水平自评` 在标题区域显示一次，在 segmented picker 的 label 中又显示一次。
- 语言选择项全部使用中文展示，例如 `英语`、`日语`、`法语`。如果用户的母语不是中文，首次启动时可能看不懂选项，无法顺利选择语言。

这不是 Mac 单端问题。`LangoTraceRootView` 在三端进入首次启动时都渲染同一个 `OnboardingView`，因此需要从共享模型和共享 UI 处理，避免三端体验不一致。

## 2. 目标

本次完成后，应达到以下可验证结果：

- Mac、iPad、iPhone 首次启动页都去除表单内重复信息。
- `母语` 和 `目标语言` 字段左侧只显示字段名，不再重复显示当前选择值。
- `水平自评` 只在标题区域显示一次，segmented picker 不再显示重复 label。
- 语言选项不再只用中文展示，而是使用语言自称名称，并在中文 UI 下辅以中文名，例如：
  - `中文`
  - `English（英语）`
  - `日本語（日语）`
  - `Français（法语）`
  - `Deutsch（德语）`
  - `Español（西班牙语）`
  - `한국어（韩语）`
- Core 层不再把语言选择只当作任意中文字符串处理，应引入稳定语言标识，避免后续本地化、同步、词典、AI Prompt 和语言空间 ID 依赖展示文案。
- 语言显示名需要分层：存储 code、语言自称名、中文界面名、英文通用名、选择器菜单名、选择器选中名、语言空间中文名和 AI / TTS 可用名不能混在一起。
- 母语和目标语言不应允许形成同语种语言空间；本次至少在方案中定义清楚自动调整或禁用策略。
- 当前仍保持 Mock / App Shell 阶段边界，不实现完整多语言 UI 本地化、真实持久化、真实语言包管理或系统语言自动切换。
- 根据入口文档的早期开发原则，本次不为现有 `OnboardingDraft` 的中文字符串字段做兼容迁移，可以直接重构为 code 驱动模型。

## 3. 范围

本次会处理：

- Core：
  - 新增轻量语言模型，例如 `LearningLanguage`。
  - 为支持的首批语言定义稳定 code、自称名、中文界面名和英文名。
  - 为选择器菜单、选择器当前值、语言空间名称和 AI / TTS 名称提供不同语义的显示入口。
  - 定义母语与目标语言相同的处理规则。
  - 直接重构 `OnboardingDraft`，让其基于稳定语言标识生成语言空间预览，不保留旧字符串字段兼容层。
  - 更新 Core 测试，覆盖默认语言、显示名和语言空间生成结果。
- UI：
  - `OnboardingView` 使用共享语言列表渲染 Picker。
  - 删除 `PickerRow` 左侧重复 value。
  - 对水平 segmented picker 使用隐藏 label 的表现方式，保留无障碍 label / hint。
  - 确认 Mac、iPad、iPhone 共享修改后都能正常显示。
- 文档：
  - 更新本 worklog 的实施记录和验证结果。
  - 如实现过程中确认语言模型会影响长期规范，则同步 `docs/spec/003-ui-design-system.md` 的国际化与语言显示规则。

## 4. 不做什么

本次不处理：

- 完整 App UI 多语言本地化。
- 根据系统语言自动切换界面文案。
- 真实语言空间持久化、迁移或同步。
- 真实语言数据库、BCP-47 全量语言支持或地区变体管理。
- 对当前 mock 阶段中文字符串字段做历史迁移或向后兼容。
- 语言搜索、语言分组、最近使用语言、热门语言排序。
- 复杂的语言能力矩阵，例如某个 AI / TTS / Speech Provider 是否支持某个语言。
- 右到左语言布局。
- 语言切换后的已有记录迁移。
- 词典、TTS、Speech、OCR 或 AI Provider 的真实语言能力映射。
- 设置页中的语言空间编辑功能。
- iPhone 主体页、iPad 主体页、Mac 主体页的语言显示全面重构。

## 5. 分析

### 5.1 三端是否都需要修改

需要，但应通过共享层一次修改。

当前结构：

- `LangoTraceRootView`：
  - welcome 后进入 `OnboardingView`。
  - 三端共用同一首次启动视图。
- `OnboardingView`：
  - 内部硬编码 `nativeLanguages` 和 `targetLanguages` 字符串数组。
  - Mac、iPad、iPhone 首次启动都会受影响。
- `OnboardingDraft`：
  - 当前用 `String` 保存 `nativeLanguage` 和 `targetLanguage`。
  - 当前默认值为 `中文` 和 `英语`。

因此，如果只针对 Mac 写一套逻辑，会造成 iPad / iPhone 与 Mac 表达不一致。正确做法是把语言选择能力下沉到 Core 模型和共享 onboarding UI。

因为当前还没有真实数据库、同步数据或公开发布版本，本次不需要保留 `nativeLanguage: String`、`targetLanguage: String` 的旧字段语义。更好的做法是一次性把 onboarding draft 改成 code 驱动，避免继续让早期 mock 字符串向 UI、测试和未来数据层扩散。

### 5.2 为什么不能只把 `英语` 改成 `English`

只替换展示字符串会产生新的问题：

- 中文用户看到 `Deutsch`、`Español` 可能不知道对应中文语言名称。
- 后续语言空间 ID 如果继续用展示字符串，会从 `英语` 变成 `English`，影响数据稳定性。
- AI Prompt、TTS、词典和同步 manifest 后续需要稳定语言标识，不能依赖 UI 展示名。
- 同一语言可能有多个界面显示名，但数据层应该只有一个稳定 code。

所以应拆分：

- 稳定标识：`en`、`ja`、`zh-Hans` 等。
- 自称名称：`English`、`日本語`、`中文`。
- 当前中文 UI 辅助名称：`英语`、`日语`、`中文`。
- 选择器菜单展示组合：`English（英语）`。
- 选择器选中短标题：`English`。
- 语言空间中文名：`英语空间`。
- AI / TTS / Prompt 英文名称：`English`、`Japanese`、`Chinese` 等。

这些名称的用途不同：

- 稳定标识用于未来存储、同步、语言空间 ID 和正式 schema 设计。
- 自称名称用于降低非中文用户在首次启动时的理解门槛。
- 中文界面名用于中文 UI 的解释和主体页文案。
- 英文名称用于 AI Provider、TTS、Speech、OCR、Prompt 模板和第三方能力映射。

实现时不能从中文名临时推断英文名，也不能把 Picker 展示字符串写入数据模型。

### 5.3 是否应该在当前阶段引入完整 Locale 系统

不建议。

当前仍处于 App Shell / Mock 阶段，完整 Locale、语言包、本地化资源、地区变体、排序规则和搜索能力会过早扩大范围。更稳妥的方式是引入一个小而稳定的 `LearningLanguage` 模型，只覆盖当前首批语言，同时让模型边界为后续扩展留出口。

但稳定 code 应倾向 BCP-47：

- 简体中文使用 `zh-Hans`。
- 英语使用 `en`。
- 日语使用 `ja`。
- 韩语使用 `ko`。
- 法语使用 `fr`。
- 德语使用 `de`。
- 西班牙语使用 `es`。

后续如果扩展繁体中文、巴西葡语、欧洲葡语、英美变体，可以自然扩展为 `zh-Hant`、`pt-BR`、`pt-PT`、`en-US`、`en-GB` 等。当前不实现这些变体，但首版 code 设计不能堵死这条路。

### 5.4 UI 去冗余原则

首次启动页是付费 App 的第一印象，应减少解释性重复，让用户感到页面安静、清楚、可操作。

推荐保留：

- 字段名：`母语`、`目标语言`、`水平自评`。
- 控件当前值：由 Picker 或 segmented control 自身显示。
- 必要说明：`用于调整生成难度，之后可以随时修改。`
- 底部摘要：建议使用 `中文 -> English · B1`，用目标语言自称名强化用户刚做出的选择。

推荐删除：

- PickerRow 左侧副标题中的当前语言值。
- segmented picker 外显 label 中重复的 `水平自评`。

Picker 展示策略建议分两层：

- 菜单项使用长显示名：`English（英语）`、`日本語（日语）`。
- 折叠后的当前值优先使用较短自称名：`English`、`日本語`、`中文`。
- 底部摘要使用短显示名：`中文 -> English · B1`。
- 主体页语言空间名称仍使用中文 UI 短名：`英语空间`。

这样能兼顾可理解性和 iPhone 小屏空间。若 SwiftUI `Picker` 在当前阶段不方便分别控制菜单项和折叠值，可以先统一显示长显示名，但需要在验证中检查 iPhone 是否截断；一旦出现截断，优先拆出短显示名。

### 5.5 语言空间显示名边界

当前 `LanguageSpacePreview` 仍使用字符串保存 `nativeLanguage`、`targetLanguage` 和 `name`。本次可以在生成 preview 时继续填入适合中文 UI 的展示名，但源头必须来自 `LearningLanguage`，不要继续由任意字符串拼接。

推荐首版规则：

- `LanguageSpacePreview.nativeLanguage`：使用中文 UI 中短展示名，例如 `中文`。
- `LanguageSpacePreview.targetLanguage`：使用中文 UI 中短展示名，例如 `英语`。
- `LanguageSpacePreview.name`：继续生成 `英语空间`。
- `LanguageSpacePreview.id`：使用稳定 code，例如 `en`。

后续真实数据模型可以再把 `nativeLanguageCode`、`targetLanguageCode` 作为正式字段，而不是只保留展示名。

需要明确这里和首次启动底部摘要的差异：

- Onboarding 选择器和底部确认摘要面向“正在选择语言”的用户，优先显示语言自称名，例如 `English`。
- 主体页当前仍是中文 UI，语言空间名称和说明文案可以继续使用中文 UI 短名，例如 `英语空间`、`把中文生活记录转换为 英语 学习材料`。
- 后续完整本地化时，再由界面语言决定语言空间显示名。

### 5.6 同语种选择边界

从产品心理和数据模型看，母语和目标语言相同通常不是有效语言空间。例如 `English -> English` 不符合“从母语记录学习目标语言”的主路径。

当前 Mock 阶段不需要实现复杂错误流，但不应继续允许无意义组合：

- MVP 前应避免母语和目标语言相同。
- 目标语言列表默认排除当前母语。
- 当用户把母语改成当前目标语言时，系统自动把目标语言调整为支持列表中第一个不同语言。
- 不推荐在首次启动页弹错误或禁用创建按钮，因为此处目标是快速完成首个语言空间创建。
- 设置页或高级语言空间编辑可以再考虑显式提示“目标语言需要不同于母语”。

本次建议直接实现自动排除和自动调整，因为 `OnboardingDraft` 还没有真实持久化，状态联动成本可控。对应逻辑应尽量放在 Core 或可测试的 helper 中，而不是散落在 SwiftUI 视图里。

### 5.7 无历史负担下的 code 边界

根据入口文档的早期开发原则，当前不需要为尚不存在的历史数据设计迁移或兼容。具体到本任务：

- 不保留旧的中文字符串字段。
- 不支持从 `英语`、`日语` 等旧展示字符串自动迁移到 code。
- 不为了未来可能导入的外部数据增加复杂 fallback。
- 不把 unknown code 当作真实业务路径处理。

但为了避免内部编程错误造成 UI 崩溃，Core 仍应保留轻量查询边界：

- `LearningLanguage.find(code:)` 返回可选值。
- `OnboardingDraft` 的初始化和语言切换路径应尽量只产生支持列表中的 code。
- 如果测试或临时代码传入未知 code，可以通过 `normalized()` 回到默认有效组合 `zh-Hans -> en`，并在测试中固定该行为。

这里的 `normalized()` 是开发阶段保护，不是历史数据兼容承诺。等真实持久化 schema 出现后，再单独设计迁移和兼容策略。

### 5.8 非中文界面风险

本次把语言选项改为 `English（英语）` 这类双语展示，只能解决“用户至少能识别语言选项”的问题，不能解决完整首次启动 UI 本地化问题。

仍然存在的风险：

- 非中文用户仍可能看不懂 `母语`、`目标语言`、`水平自评` 等字段名。
- 隐私说明、创建按钮、底部摘要仍是中文界面。
- 语言空间创建后的主体页仍是中文 UI。

当前项目仍以中文 UI 原型为主，因此这个风险可以接受，但必须记录为未来国际化方案的输入。后续如果计划面向非中文用户销售，应优先补一轮最小首次启动本地化：至少让 onboarding 根据系统语言显示英文 UI。

### 5.9 排序与默认值

语言列表顺序不是技术细节，会影响首次启动效率。

首版推荐：

- 母语列表默认顺序：`zh-Hans`、`en`、`ja`、`ko`、`fr`、`de`、`es`。
- 目标语言列表默认顺序：`en`、`ja`、`fr`、`de`、`es`、`ko`、`zh-Hans`，但渲染时排除当前母语。
- 默认 draft：`zh-Hans -> en · B1`。

原因：

- 当前产品原型和开发语境以中文用户为主，默认母语为中文合理。
- 英语是最常见目标语言，默认目标语言为英语合理。
- 保持固定产品顺序比根据中文拼音、英文名或系统 locale 排序更稳定，能减少测试快照和用户认知变化。

### 5.10 基于早期重构原则的复审结论

引入入口文档的早期重构原则后，本方案需要避免过度保守：

- 不再把“旧字符串数据兼容”作为目标，因为当前没有真实用户数据。
- 不保留 `OnboardingDraft.nativeLanguage` / `targetLanguage` 这类展示字符串字段。
- 不新增字符串到 code 的迁移表。
- 不为了未来未知导入场景提前扩展容错系统。

但方案仍应保留 `LearningLanguage`，原因不是兼容历史，而是尽早建立正确边界：

- UI 展示名、语言空间名称、AI / TTS 名称本来就不是同一个概念。
- 如果继续使用中文展示字符串，后续 AI、同步、词典和数据层都会被临时文案污染。
- 现在直接重构比之后有数据库和同步数据后再迁移更便宜。

因此，最终推荐仍是方案 D，但实施时应采用“直接替换早期模型”的方式，而不是在旧模型外面叠兼容层。

## 6. 方案

推荐采用“Core 语言模型 + 共享 Onboarding 去冗余”的方案。

### 6.1 Core 模型

新增 `LearningLanguage`：

```swift
public struct LearningLanguage: Equatable, Sendable, Identifiable {
    public let code: String
    public let nativeName: String
    public let zhHansName: String
    public let englishName: String

    public var id: String {
        code
    }

    public var pickerMenuTitleForChineseUI: String {
        nativeName == zhHansName ? nativeName : "\(nativeName)（\(zhHansName)）"
    }

    public var selectedTitleForChineseUI: String {
        nativeName
    }

    public var spaceNameForChineseUI: String {
        "\(zhHansName)空间"
    }

    public var promptLanguageName: String {
        englishName
    }
}
```

首批语言：

```text
zh-Hans: 中文 / 中文 / Chinese
en: English / 英语 / English
ja: 日本語 / 日语 / Japanese
ko: 한국어 / 韩语 / Korean
fr: Français / 法语 / French
de: Deutsch / 德语 / German
es: Español / 西班牙语 / Spanish
```

推荐提供：

- `LearningLanguage.supportedNativeLanguages`
- `LearningLanguage.supportedTargetLanguages`
- `LearningLanguage.zhHans`
- `LearningLanguage.english`
- `LearningLanguage.find(code:)`
- `LearningLanguage.defaultNative`
- `LearningLanguage.defaultTarget`

命名要求：

- `pickerMenuTitleForChineseUI` 只用于菜单项，不写入数据。
- `selectedTitleForChineseUI` 只用于当前选中值和 onboarding 摘要，不写入数据。
- `spaceNameForChineseUI` 只用于当前中文 UI 的语言空间展示名。
- `promptLanguageName` 可作为未来 AI Prompt、TTS、Speech、OCR 能力映射的基础字段，但本次不接入真实 provider。

### 6.2 OnboardingDraft

推荐调整为保存稳定 code：

```swift
public struct OnboardingDraft: Equatable, Sendable {
    public var nativeLanguageCode: String
    public var targetLanguageCode: String
    public var level: LanguageLevel
}
```

同时提供便捷计算：

- `resolvedNativeLanguage`
- `resolvedTargetLanguage`
- `availableTargetLanguages`
- `normalized()`
- `makeLanguageSpacePreview()`

当前 Mock 输出要求：

- 默认母语：`zh-Hans`。
- 默认目标语言：`en`。
- 如果 `nativeLanguageCode == targetLanguageCode`，`normalized()` 自动选择第一个不同目标语言。
- 如果开发期传入未知 code，`normalized()` 回到默认有效组合，不做旧数据兼容。
- `makeLanguageSpacePreview()` 输出仍可满足现有主体页面文案。

### 6.3 OnboardingView

UI 调整：

- 从 `LearningLanguage.supportedNativeLanguages` 和 `LearningLanguage.supportedTargetLanguages` 读取选项。
- Picker 的 selection 绑定到 `draft.nativeLanguageCode` 和 `draft.targetLanguageCode`。
- Picker 菜单项显示 `language.pickerMenuTitleForChineseUI`。
- Picker 当前值优先显示 `language.selectedTitleForChineseUI`；若 SwiftUI 当前结构难以拆分，可先统一显示 `pickerMenuTitleForChineseUI`，但必须在 iPhone 验证截断。
- `PickerRow` 只显示标题，不显示重复 value。
- 水平 segmented picker 增加 `.labelsHidden()`，保留 accessibility label / hint。
- 目标语言选项排除当前母语。
- 当母语变化导致当前目标语言无效时，自动切换到第一个可用目标语言。
- 底部摘要显示 `selectedTitleForChineseUI`，例如 `中文 -> English · B1`。

无障碍要求：

- 隐藏 segmented picker 的视觉 label 时，需要保留 `accessibilityLabel("水平自评")`。
- 语言 Picker 需要有明确 label，VoiceOver 能读出字段名和当前值。
- 语言菜单项使用 `English，英语` 这类可读组合时，避免 VoiceOver 把括号内容读得过于混乱；如果实际体验不好，后续可为菜单项单独设置 accessibility label。

### 6.4 预计文件变更

预计涉及：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningLanguage.swift`：新增语言模型。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/OnboardingDraft.swift`：改为 code 驱动，增加语言解析与 preview 生成。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LearningLanguageTests.swift`：新增语言模型测试。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LaunchFlowTests.swift`：更新 onboarding draft 相关测试。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`：去冗余、改 Picker 数据源和显示逻辑。
- `docs/spec/003-ui-design-system.md`：如实现后确认语言显示规则进入长期规范，则补充“语言名称显示分层”。

### 6.5 替代方案

方案 A：只删除重复文案，不改语言选项。

- 优点：改动最小。
- 缺点：非中文母语者仍看不懂语言选项，数据层仍依赖展示字符串。

方案 B：只把语言选项从中文改成英文或自称名。

- 优点：视觉上立刻改善。
- 缺点：中文用户理解成本变高，数据层仍不稳定。

方案 C：引入完整 Locale / 本地化系统。

- 优点：长期最完整。
- 缺点：当前阶段过重，会把首次启动小改动扩大成国际化系统工程。

方案 D：新增轻量 `LearningLanguage` 模型，UI 显示 `nativeName（中文名）`，同时去除表单冗余。

- 优点：解决当前问题，兼顾未来扩展，改动范围可控。
- 缺点：需要调整 Core 测试和部分 mock 文案。

推荐方案 D。

## 7. 风险与边界

- 风险：`OnboardingDraft` 字段从展示字符串变为 code，会影响现有测试。
  - 缓解：这是早期 mock 阶段允许的破坏性重构；先写测试定义新行为，再更新实现。
- 风险：主体页仍使用 `LanguageSpacePreview.targetLanguage` 生成中文文案，例如 `把中文生活记录转换为 英语 学习材料`。
  - 缓解：本次保持 preview 输出中文 UI 短名，避免主体页连锁重构。
- 风险：Onboarding 摘要使用 `English`，主体页使用 `英语空间`，看起来不完全一致。
  - 缓解：文档明确两者职责不同；选择阶段用语言自称名提高识别度，中文主体页暂用中文 UI 短名。
- 风险：`English（英语）` 在小屏 Picker 中可能偏长。
  - 缓解：iPhone 上 Picker 是 menu 样式，只在菜单项和当前值处显示；如后续发生截断，再设计短显示名与长菜单名。
- 风险：母语变化后系统自动调整目标语言，用户可能短暂感到“选项变了”。
  - 缓解：首次启动阶段优先减少错误路径；调整规则保持稳定顺序，不做随机选择。
- 风险：`zh-Hans`、`en` 等 code 未来需要和 BCP-47 完整规范对齐。
  - 缓解：首版使用常见稳定 code，不引入完整地区变体；后续真实持久化前再定正式语言规范。
- 风险：非中文用户仍看不懂 `母语`、`目标语言` 等 UI 文案。
  - 缓解：本次只解决语言选项可识别性；完整 UI 本地化另起方案。
- 风险：当前 worklog 只处理首次启动页，主体页的语言显示仍以中文 UI 为主。
  - 缓解：主体页语言显示全面国际化不在本次范围。
- 风险：母语和目标语言相同导致无意义语言空间。
  - 缓解：本方案推荐本次实现自动过滤和自动调整，并通过 Core 测试覆盖。
- 风险：开发期未知 language code 被静默归一化为默认组合，可能掩盖调用方错误。
  - 缓解：当前没有真实持久化，优先保证 mock flow 可运行；测试中固定归一化行为，真实 schema 出现后再设计更严格的迁移和错误处理。

## 8. 测试与验证

完成前至少执行：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
swiftlint --no-cache
swiftformat --lint . --cache ignore
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS' build
git diff --check
xcrun simctl install booted /Users/zibuyu/Library/Developer/Xcode/DerivedData/LangoTrace-hdfadqhothdwgbahopjjqiwrxhky/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch booted com.zibuyu.LangoTrace
xcrun simctl io booted screenshot /private/tmp/langotrace-onboarding-check.png
```

手动验证：

- Mac：
  - 首次启动页 `母语` 左侧不再重复显示 `中文`。
  - 首次启动页 `目标语言` 左侧不再重复显示 `英语`。
  - `水平自评` 不再重复显示第二个 label。
  - 语言 Picker 选项显示 `English（英语）`、`日本語（日语）` 等。
- iPad：
  - 首次启动页与 Mac 同步去冗余。
  - 表单内容不溢出，不出现按钮或文字遮挡。
- iPhone：
  - 首次启动页与 Mac 同步去冗余。
  - 语言菜单项可读，创建按钮底部摘要仍清晰。
- Core：
  - 默认 draft 生成 `zh-Hans -> en · B1` 对应语言空间。
  - `LanguageSpacePreview.id` 使用稳定 code。
  - `LanguageSpacePreview.name` 仍生成适合中文 UI 的 `英语空间`。
  - `LearningLanguage` 菜单显示名包含 `English（英语）` 和 `日本語（日语）`。
  - `LearningLanguage` 选中短标题分别为 `English`、`日本語`、`中文`。
  - `LearningLanguage` 的 AI / Prompt 名称分别为 `English`、`Japanese`、`Chinese`。
  - 开发期未知 code 经过 `normalized()` 后回到默认有效组合。
  - 母语改为 `en` 后，目标语言不会继续保持 `en`。
  - 目标语言列表不包含当前母语。

## 9. 用户确认记录

状态为 `Draft` 时不能开始实现。

用户确认后记录：

```text
2026-05-17：用户确认本方案，可以开始实现。
```

确认记录：

```text
2026-05-17：用户确认“立即开始实施”，进入实现阶段。
```

## 10. 实施记录

已实施：

- 新增 `LearningLanguage`，用稳定 code 区分数据标识、语言自称名、中文界面名、英文 Prompt 名和语言空间显示名。
- 将 `OnboardingDraft` 从展示字符串改为 `nativeLanguageCode` / `targetLanguageCode`，并增加 `normalized()`、语言解析和目标语言过滤。
- 更新 `makeLanguageSpacePreview()`，继续向当前中文主体页输出 `英语空间`、`中文 -> 英语 · B1` 这类短中文上下文，但内部 ID 改为稳定 code。
- 首次启动页删除 `母语`、`目标语言` 左侧重复值，`水平自评` segmented picker 隐藏重复 label，同时保留无障碍 label / hint。
- 首次启动页语言选择改为 `Menu`：
  - 折叠状态显示短标题，例如 `English`。
  - 展开菜单显示完整双语标题，例如 `English（英语）`、`日本語（日语）`。
- 当母语变化导致目标语言相同时，系统自动调整到第一个可用目标语言，避免创建同语种语言空间。
- 同步更新 `docs/spec/003-ui-design-system.md`，把语言显示分层、稳定 code、菜单短长标题和同语种过滤写入 UI 规范。

实施中发现并修正：

- 原方案中的 `xcodebuild` destination 写法 `platform=iPhone 17 Simulator` / `platform=iPad Pro 13-inch (M5)` 在当前 Xcode 26.5 不可用，实际应使用 `platform=iOS Simulator,name=...`。
- 首次 iPhone 构建发现 `OnboardingView` 引用了不存在的 `panelBorder` token，已改为现有 `hairline` token，避免为了单一菜单临时扩展颜色体系。

## 11. 验证结果

已执行：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
swiftformat --lint . --cache ignore
swiftlint --no-cache
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS' build
git diff --check
```

结果：

- `xcodegen generate` 通过。
- `swift test --package-path Packages/LangoTraceCore` 通过，16 个 Testing 测试通过。
- `swiftformat --lint . --cache ignore` 通过。
- `swiftlint --no-cache` 通过，0 violations。
- iPhone 17 Simulator 构建通过。
- iPad Pro 13-inch (M5) Simulator 构建通过。
- macOS 构建通过；Xcode 输出 arm64 / x86_64 多 destination 常规 warning，不影响构建结果。
- `git diff --check` 通过。
- 已将当前构建重新安装并启动到 booted Simulator，截图 `/private/tmp/langotrace-onboarding-check.png` 验证：
  - `母语` 左侧不再显示 `中文` 副标题。
  - `目标语言` 左侧不再显示 `英语` 副标题。
  - 折叠控件显示短标题 `中文` / `English`。

说明：

- 本次已完成编译级、测试级和 Simulator 截图验收。
