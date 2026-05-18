# String Catalog 与界面语言设置闭环规格草案

状态：Draft

日期：2026-05-17

关联文档：

- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/worklogs/2026-05-17-feature-string-catalog-interface-language-settings.md`
- `docs/superpowers/plans/2026-05-17-string-catalog-interface-language-settings.md`

## 1. 目标

本规格定义语迹下一阶段界面国际化实现闭环：把 App chrome 文案迁移到 String Catalog，提供 App 内界面语言设置入口，并通过三端英文/简体中文验证，确保后续页面设计和功能开发不再默认中文硬编码。

成功标准：

- 用户可在设置中看到并选择 `System / English / 简体中文`。
- App 自有 SwiftUI chrome 文案可以根据选择显示英文或简体中文。
- 默认策略为跟随系统；不支持的系统语言回退英文。
- 切换界面语言不会改变用户母语、目标语言空间、用户内容或 mock 学习内容。
- iPhone、iPad、macOS 在英文和简体中文下都能完成基本页面导航。

## 2. 设计原则

- 界面语言、用户母语和目标学习语言继续保持三轴独立。
- 英文是基础语言和 fallback，简体中文是首批验证语言。
- String Catalog 只负责 App chrome 文案，不负责翻译用户内容。
- UI 层负责展示文案本地化；Core / Data 层优先提供稳定 code、kind 和状态，不把展示语言当作业务标识。
- App 内语言设置只承诺影响语迹自有 SwiftUI 文案；系统弹窗、权限 purpose strings、StoreKit sheet、文件选择器和 Apple 服务 UI 按平台能力单独处理。
- 当前阶段优先完成可验证闭环，不追求一次性覆盖所有历史 mock 字符串。

## 3. 用户路径

### 3.1 首次启动

用户首次打开 App 时，界面语言默认跟随系统。如果系统语言为英文或简体中文，Welcome / Onboarding 使用对应语言。如果系统语言不在支持清单内，界面回退英文。

首次启动仍只询问母语、目标语言和水平自评。界面语言不是创建第一个语言空间的必填步骤。

### 3.2 设置中切换界面语言

用户进入 Settings，打开 Interface Language：

- `System`：跟随系统或系统 per-app language。
- `English`：语迹自有 SwiftUI 文案使用英文。
- `简体中文`：语迹自有 SwiftUI 文案使用简体中文。

设置页必须说明：

- 该设置只影响 App 界面。
- 不改变母语。
- 不改变目标语言空间。
- 不改变已生成或保存的学习内容。
- 部分系统界面可能仍遵循系统语言。

### 3.3 切换后的页面状态

切换界面语言后，当前页面不应丢失导航状态、当前语言空间、选中的记录或练习步骤。允许 SwiftUI 重新渲染可见文案。

如果实现中发现某些系统控件无法即时刷新，第一阶段可以要求用户重新打开页面或重启 App，但必须在设置说明中明确。

## 4. 架构设计

### 4.1 资源位置

首批 String Catalog 放在 `LangoTraceUI` package 内：

```text
Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings
```

`Packages/LangoTraceUI/Package.swift` 需要把 `Resources` 作为 target resources 处理，确保 Swift Package 和 Xcode app target 都能找到资源。

架构复查结论：这个位置适合当前阶段。当前 Welcome、Onboarding、iPhone、iPad、macOS 页面主体都在 `LangoTraceUI` package 中，资源跟随 UI package 可以避免把 UI 文案散落到 App target。由于资源属于 Swift Package，UI 代码查找本地化字符串时必须显式使用 `Bundle.module`；不能依赖 main bundle 的默认 `Localizable` 查找。

边界复查补充：`LangoTraceUI` package 内的 String Catalog 只解决 SwiftUI package 自有 chrome 文案的资源归属。它不自动等价于主 App bundle 已经完整声明所有系统级本地化语言。若要让 iOS / iPadOS / macOS 系统设置中的 per-app language 稳定展示 `English / 简体中文`，后续实现必须确认主 App bundle 的本地化声明、`CFBundleLocalizations` 或等效 App target 资源也覆盖这些语言；权限 purpose strings、InfoPlist 展示字段、App Store 元数据和系统承载界面不能只依赖 `LangoTraceUI` package catalog。

实现约束：

- `project.yml` 的 `developmentLanguage` 已是 `en`，String Catalog 的 `sourceLanguage` 也必须保持 `en`。
- Swift Package target 需要配置 `resources: [.process("Resources")]`。
- `Text`、`Label`、`Button` label、`navigationTitle`、`accessibilityLabel`、`TextField` prompt 等在 UI package 内使用本地化 key 时，都需要走 `bundle: .module` 或经过同等封装。
- 对于 `Button("取消")`、`Label("请求预览", systemImage:)`、`.navigationTitle("记录详情")` 这类便捷 API，不能直接替换成 key 后结束；应改成 label builder 或 `Text("key", bundle: .module)`，否则可能查错 bundle。
- `String(localized:bundle:)` 是立即求值，不应作为依赖 SwiftUI `locale` 环境即时刷新文案的默认方案。确实需要 `String` 的 API，必须显式传入当前 resolved locale，或改造成接受 `Text` / label builder 的组件。
- 未来如果 `LangoTraceApp` target、InfoPlist、权限 purpose strings、App Store 元数据或 widget / App Intent 暴露用户可见文案，应在对应 target 或平台配置中单独本地化，不放入 `LangoTraceUI` package 的 UI catalog 中。

### 4.2 界面语言偏好存储

界面语言偏好是设备级 App 设置。推荐第一阶段使用 `UserDefaults`，key 为：

```text
interfaceLanguagePreference
```

存储值使用 `InterfaceLanguagePreference.storageValue`：

- `system`
- `en`
- `zh-Hans`

无效值按 `system` 处理。该设置不进入语言空间模型，不进入 Data repository，不进入同步计划。

### 4.3 Locale 注入

App shell 负责读取界面语言偏好，结合系统语言解析出当前 App chrome locale，并注入到根视图：

```swift
.environment(\.locale, Locale(identifier: resolvedLanguageCode))
```

当偏好为 `system` 时，resolved language 由 `InterfaceLanguagePreference.resolvedLanguageCode(systemLanguageCodes:)` 决定。不支持的系统语言回退 `en`。

App 内设置与系统 per-app language 的优先级：

1. 用户选择 `System` 时，语迹读取平台提供的语言偏好列表，例如 `Locale.preferredLanguages`，并从中解析 `en` 或 `zh-Hans`；如果系统级 per-app language 已为语迹指定语言，该选择应通过平台语言偏好进入解析路径。
2. 用户选择 `English` 或 `简体中文` 时，App 内偏好优先，只覆盖语迹自有 SwiftUI chrome 的 `locale` 环境。
3. App 内偏好不是系统级 per-app language 的替代品：它不会修改系统设置，不会改变 `Bundle.main` 的 preferred localization，不承诺覆盖权限弹窗、StoreKit sheet、文件选择器、分享面板、系统键盘候选、第三方 SDK UI 或 Apple 服务 UI。
4. 如果用户在系统设置中修改 per-app language，`System` 模式下第一阶段只承诺下次启动或重新激活后读取到平台结果；不把系统设置变更监听作为本阶段核心需求。

因此设置页文案必须避免表达为“改变系统 App 语言”。准确表述是：改变语迹 App 自有界面语言；选择 `System` 时跟随系统或系统为语迹设置的 App 语言。

主 App bundle 复查结论：若 App target 只有 `developmentLanguage: en` 和 package 内 `zh-Hans` catalog，系统 per-app language 的可见语言清单可能无法稳定包含简体中文。因此第一阶段需要在 iOS 和 macOS App target 的 InfoPlist 中声明 `CFBundleLocalizations = [en, zh-Hans]`，并把同一配置写回 `project.yml`，避免 XcodeGen 后配置漂移。该声明只代表 App bundle 支持这些本地化语言；系统弹窗、StoreKit、文件选择器和第三方 UI 仍按平台边界处理。

### 4.4 设置入口

`SettingsCapability.Kind.interfaceLanguage` 已存在。下一阶段应让该设置详情页从只读说明升级为可交互 Picker。

平台呈现：

- iPhone：Settings tab 内进入详情页，使用 Form 或垂直列表。
- iPad：右侧或主工作区详情中呈现，保持 workspace 不被 modal 打断。
- macOS：inspector 或 settings workspace 中呈现，支持 pointer 和键盘焦点。

交互复查结论：

- iPhone 上不把界面语言放进首次启动必填路径，避免与母语和目标语言选择混淆。
- iPad 上在常规宽度应保持侧栏和详情上下文可见；在 Split View / Slide Over 窄宽度下允许退化为 iPhone 式纵向详情，但不能丢失当前语言空间。
- macOS 上语言设置属于偏好型低频操作，可在现有 settings workspace 中呈现；后续进入真正 Mac 设置体系时，应评估 SwiftUI `Settings` scene 和 `Cmd+,`，但本阶段不要求重构 App scene。
- 三端切换后应保留当前 route、选中记录、练习步骤和语言空间 preview；只允许可见文案重新渲染。

### 4.5 文案迁移边界

首批迁移 App chrome：

- Welcome 标题、slogan 附近说明、状态胶囊。
- Onboarding 标题、说明、字段标题、按钮、隐私说明。
- iPhone Tab 标题、空状态、主要按钮、设置页标题。
- iPad sidebar、workspace bar、空状态、路由标题。
- macOS sidebar、toolbar、inspector 标题和主要按钮。
- 通用 unavailable、request preview、privacy status、settings capability 的标题和说明。

暂不迁移内容样本：

- 用户记录正文。
- Mock target sentences。
- Mock translation。
- Mock note。
- Prompt 示例正文。
- 语言空间名称中的目标语言内容。

### 4.6 Data 层文案处理

当前 `SettingsCapability` 仍包含中文 `title / summary / detail / nextRequirement`。长期方向是让 Data 层输出稳定 kind 和能力状态，UI 层根据 kind 选择本地化文案。

下一阶段可采用小步迁移：

1. 先为 `SettingsCapability.Kind` 增加稳定 localization key。
2. UI 层显示设置标题时优先使用本地化 key。
3. 对 `summary / detail / nextRequirement` 中属于 App chrome 的部分逐步迁出到 UI 层。
4. 对确属 mock 内容的部分保留原内容语言，不强制翻译。

实现复查补充：`CapabilityStatus.title` 和 `SettingsCapability.Kind.title` 当前位于 Data package，属于 App chrome 展示文案，不宜继续作为长期 UI 显示来源。下一阶段可以先保留字段以降低改动面，但 UI 显示设置列表和状态时应优先根据 `kind` / `status` 映射到 `LangoTraceUI` 的本地化 key。Data 中的 mock 内容、seed entry、target sentence、translation、note 和用户创建记录仍按内容处理，不被界面语言设置重写。

## 5. 错误状态和边界说明

- 读取到未知偏好值：恢复为 `system`，不崩溃。
- 系统语言为未支持语言：回退英文。
- String Catalog 缺少简体中文翻译：必须在测试中发现，不能静默通过为最终状态。
- 设置切换后系统弹窗仍显示系统语言：这是平台边界，设置页需提前说明。
- UI 文案变长导致截断：优先调整布局、术语或信息层级，不通过缩小字号解决。

## 6. 测试策略

单元测试：

- `InterfaceLanguagePreference` 对无效存储值回到 `system`。
- resolved language 对 `en-*`、`zh-Hans-*` 和未支持语言行为正确。
- 设置 store 保存、读取和重置行为正确。
- 界面语言偏好不会修改 `LanguageSpacePreview`。
- UI 设置入口包含三种选项并保持当前语言空间不变。

构建验证：

- `swift test --package-path Packages/LangoTraceCore`
- `swift test --package-path Packages/LangoTraceData`
- `swift test --package-path Packages/LangoTraceUI`
- `scripts/verify.sh`

截图验证：

- iPhone 17：English / 简体中文。
- iPad Pro 13-inch (M5)：English / 简体中文。
- macOS arm64：English / 简体中文。

## 7. 不做事项

- 不实现真实数据持久化和启动恢复。
- 不实现完整语言空间编辑。
- 不实现真实 AI 请求。
- 不实现内容自动翻译。
- 不支持大量界面语言。
- 不把 App 内语言设置宣传为覆盖所有系统 UI。

## 8. 开放问题

以下问题在实施前已有推荐答案，本阶段按推荐答案执行；若后续发现平台限制，再回到文档修订。

- App 内设置与系统 per-app language 是否并存：并存，但 App 内设置只覆盖语迹自有 SwiftUI chrome。
- 是否需要即时切换：第一阶段尽量即时刷新 SwiftUI 文案；无法即时刷新的系统 UI 作为平台边界说明。
- Data 层文案是否一次性迁完：不一次性迁完，先迁 App chrome 和设置能力标题，再逐步迁说明文案。
- 是否加入第三种语言：不加入，先稳定英文和简体中文。
