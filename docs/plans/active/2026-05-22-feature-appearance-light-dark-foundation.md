# 外观浅色与深色基础设施方案

状态：User Approved, Awaiting Implementation
类型：feature
创建日期：2026-05-22
最后更新日期：2026-05-23

## 用户确认记录

- 2026-05-22：用户提出是否需要为系统设置新增“主题”，用于让用户切换 App 主题；前期可能仅包含 UI 颜色变化，后期可能加入字体和交互样式。
- 2026-05-22：讨论结论为不在当前阶段展开多套品牌色或皮肤，而是先做 Apple 平台语义下的“外观”设置。
- 2026-05-22：用户确认采用该方向：本轮先完成深色与浅色外观，不展开多套品牌色；同时要求完成可供后续扩展的基础设施搭建。
- 2026-05-22：本方案用于记录当前要实现的功能；长期主题扩展边界另见 `docs/architecture/notes/2026-05-22-appearance-theme-extension-notes.md`。
- 2026-05-22：进行系统架构师视角的严格代码审查后，补充无语言空间设置详情、SwiftUI 颜色 token 技术边界、状态同步和测试落点要求。
- 2026-05-23：用户审核通过 iPhone 设置页和主学习页浅色 / 深色轻量原型中的候选色号，确认作为本轮实现基准；原型路径为 `prototypes/appearance-theme-review/index.html`。

## 1. 需求描述

LangoTrace 是长时间阅读、写作、双语对照、跟读和记忆复习的 Apple 三端 App。用户在不同光线环境下使用时，需要清晰、低负担、符合系统习惯的浅色与深色外观。

当前需求不是做多套皮肤，也不是把“主题”作为视觉卖点，而是在设置中新增“外观”能力，让用户选择：

- 跟随系统。
- 浅色。
- 深色。

同时，本轮实现必须把颜色 token、偏好存储、App 注入、三端设置页和测试边界搭好，避免后续加入品牌色、字体或交互样式时需要推翻当前设计。

## 2. 当前事实

### 2.1 产品与文档事实

- `docs/spec/003-ui-design-system.md` 已要求 LangoTrace UI 保持安静、清晰、现代和长期可读。
- `docs/spec/003-ui-design-system.md` 明确深色模式在没有完整 token 映射和截图验证前只能写成预留能力，不能写成已完成能力。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md` 要求 UI 任务不能只靠编译完成声明，涉及页面结构和交互变化时必须说明自动化覆盖、截图或人工验证范围。
- `docs/spec/002-navigation-and-routing.md` 规定设置是低频配置入口，不进入 iPhone 底部 Tab。
- `docs/platform-page-inventory.md` 记录当前三端设置入口：iPhone 通过顶部 gear，iPad / macOS 通过 Sidebar 底部设置和 macOS 原生 Settings scene。
- `prototypes/appearance-theme-review/README.md` 记录本轮浅色 / 深色色号评估、优化理由和对比度检查结果。

### 2.2 代码事实

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift` 当前使用静态 RGB `ColorToken`，浅色 UI 事实已经散落在 token 内。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift` 与 `InterfaceLanguagePreferenceStore.swift` 已提供设备级偏好模式，可作为外观偏好的实现参考。
- `LangoTraceApp/LangoTraceApp.swift` 当前在 App 层持有 `interfaceLanguagePreference`，并注入 `LangoTraceRootView` 和 macOS `LangoTraceSettingsSceneView`。
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift` 当前设置能力包含 `languageSpace`、`interfaceLanguage`、`aiProvider`、`sync`、`localData`、`privacy`、`importExport`，没有 `appearance`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift` 已通过共享设置详情承载 `interfaceLanguage`、`aiProvider` 和 `sync` 的特殊内容。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift` 已承载 macOS 原生 Settings scene，并复用共享设置详情。
- `SettingsCapabilityDetailView` 当前强制接收 `LanguageSpacePreview`；`LangoTraceSettingsSceneView` 目前只为 `.interfaceLanguage` 在无当前语言空间时提供 placeholder。外观设置是设备级全局偏好，不能沿用“伪造语言空间”方案。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/SettingsCapabilityTests.swift` 已覆盖界面语言设置能力；`InMemoryLearningContentRepositoryTests.swift` 已覆盖 settings capability 顺序、完整性和 read-only 边界。
- 当前 `ColorToken` 是 `static let Color`。这种调用面可通过系统浅深色动态颜色或 palette factory 支撑本轮 `preferredColorScheme`，但不能直接读取未来任意 `ThemeID` 或字体 / 交互 profile 的环境状态。

## 3. 目标

本任务完成后必须达到：

- 设置列表新增 `外观 / Appearance` 能力项。
- `外观` 详情页支持选择 `跟随系统 / 浅色 / 深色`。
- iPhone、iPad、macOS 工作台设置入口，以及 macOS 原生 Settings scene 都能进入同一外观设置。
- 外观详情页在没有当前语言空间时仍然可进入；实现不得为外观伪造语言空间上下文。
- 用户选择即时影响当前 App 窗口或场景的浅色 / 深色渲染。
- 选择 `跟随系统` 时尊重系统外观。
- 外观偏好持久化在设备本地 `UserDefaults`，不进入 SQLite / GRDB、Keychain、语言空间、AI Provider、同步 manifest 或用户学习数据。
- `LangoTraceDesign` 颜色入口从单套静态浅色 token 升级为可按浅色 / 深色解析的语义 palette。
- 本轮实现的浅色 / 深色 palette 必须以 2026-05-23 审核通过的色号表为基准；若实现阶段因 SwiftUI / 平台动态颜色需要微调，必须回写实施记录并保留对比度证据。
- 本轮颜色基础设施必须准确表达“系统浅深色外观”能力，不把未来多品牌主题误写成已经具备环境化主题引擎。
- 状态色、危险色、隐私本地 / 外发状态色、AI / Sync 状态色继续保持语义，不被未来装饰主题随意覆盖。
- 为后续主题扩展保留清晰命名和边界，但本轮不展示多套品牌色、字体或交互样式选项。

## 4. 不做什么

本任务不实现：

- 不做多套品牌色。
- 不做自定义取色器。
- 不做字体主题。
- 不做交互样式切换。
- 不做每个语言空间独立主题。
- 不把外观偏好同步到云端。
- 不把外观偏好写入语言空间数据库。
- 不改变当前 `记录 / 练习 / 记忆` 主导航。
- 不把外观设置放入 onboarding。
- 不把深色模式写成已经完成发布级视觉验收，除非本任务执行阶段补齐截图或人工验证记录。

## 5. 架构决策

| 问题 | 当前决策 | 理由 |
| --- | --- | --- |
| 用户可见名称 | 使用 `外观 / Appearance`，不使用 `主题 / Theme` | Apple 平台用户更熟悉外观设置；“主题”容易暗示多套皮肤。 |
| 当前选项 | `跟随系统 / 浅色 / 深色` | 满足当前需求，控制验证矩阵。 |
| 偏好归属 | 设备级偏好 | 外观是设备使用环境，不属于语言空间主数据。 |
| 存储位置 | `UserDefaultsAppearancePreferenceStore` | 与界面语言偏好一致，低风险、可测试。 |
| App 注入 | App 层持有状态并传入 Root / Settings scene | 选择应即时影响三端 UI。 |
| SwiftUI 机制 | 使用 `preferredColorScheme(_:)` 表达浅色 / 深色强制选择；系统模式传 `nil` | 符合 SwiftUI 平台机制，避免手写全局样式切换。 |
| 颜色基础设施 | 引入语义 `LangoTracePalette` 或等价 palette，`LangoTraceDesign.ColorToken` 保持调用面，并用动态 `Color` / palette factory 解析浅深色 | 本轮只需要响应系统 color scheme；未来多主题不能假装由当前 `static let` 自动解决。 |
| 无语言空间详情 | 外观和界面语言属于全局设备偏好，详情页应支持无 `LanguageSpacePreview`；AI Provider / 同步等空间相关详情继续要求真实当前语言空间 | 避免用 placeholder space 污染外观语义，也避免无空间时误触发当前空间相关配置。 |
| 状态同步 | App 层 `@State` 是 UI source of truth，UserDefaults store 是持久化 source；设置行点击先避免重复写入，再在主线程更新 App 状态 | 保证主窗口和 macOS Settings scene 观察同一偏好，避免 stale UI 或重复写入。 |
| 后续主题扩展 | 只保留代码边界和备忘录，不在 UI 暴露 | 避免当前阶段被多主题复杂度拖散。 |

## 6. 涉及代码文件

预计新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AppearancePreference.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AppearancePreferenceStore.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/AppearancePreferenceTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AppearanceSettingsTests.swift`

预计修改：

- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/InMemoryLearningContentRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/SettingsCapabilityTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `docs/platform-page-inventory.md`
- `docs/spec/003-ui-design-system.md`
- `docs/testing/README.md`

## 7. 参考文件

实施前建议按顺序阅读：

1. `docs/spec/003-ui-design-system.md`
2. `docs/spec/010-apple-platform-interaction-and-accessibility.md`
3. `docs/spec/002-navigation-and-routing.md`
4. `docs/spec/006-interface-localization-and-language-boundaries.md`
5. `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift`
6. `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreferenceStore.swift`
7. `LangoTraceApp/LangoTraceApp.swift`
8. `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
9. `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
10. `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`

## 8. 数据与状态模型

### 8.1 Core 偏好模型

新增 `AppearancePreference`：

```swift
public enum AppearancePreference: String, CaseIterable, Equatable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String {
        storageValue
    }

    public var storageValue: String {
        rawValue
    }

    public init(storageValue: String) {
        self = Self(rawValue: storageValue) ?? .system
    }
}
```

新增本地 store：

```swift
public protocol AppearancePreferenceStore: AnyObject, Sendable {
    var preference: AppearancePreference { get set }
    func reset()
}

public final class UserDefaultsAppearancePreferenceStore: AppearancePreferenceStore, @unchecked Sendable {
    public static let storageKey = "appearancePreference"

    private let defaults: UserDefaults

    public var preference: AppearancePreference {
        get {
            AppearancePreference(
                storageValue: defaults.string(forKey: Self.storageKey)
                    ?? AppearancePreference.system.storageValue
            )
        }
        set {
            defaults.set(newValue.storageValue, forKey: Self.storageKey)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
```

### 8.2 SwiftUI 映射

在 UI 或 App 层提供 `ColorScheme?` 映射：

```swift
extension AppearancePreference {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
```

该 extension 可以放在 `LangoTraceApp` 内部或 `LangoTraceUI` 内部。若放在 `LangoTraceCore`，不得让 Core 依赖 SwiftUI。

### 8.3 主题扩展预留

本轮只持久化 `AppearancePreference`。不要提前持久化 `themeID`、`fontProfileID`、`interactionProfileID` 等未来字段。

为了后续扩展，命名上应区分：

- `AppearancePreference`：当前浅色 / 深色 / 跟随系统模式。
- `LangoTracePalette`：具体颜色 palette。
- `LangoTraceDesign`：设计 token 入口。
- `ThemeID`：未来多套品牌色或完整主题的候选概念，本轮不进入代码存储。

### 8.4 设置详情上下文

当前 `SettingsCapabilityDetailView` 强制持有 `LanguageSpacePreview`，这对 AI Provider 和同步是合理的，因为它们需要当前目标语言或当前空间边界；但外观和界面语言不属于语言空间。

实施时应采用以下任一方式，推荐第一种：

1. 将 `SettingsCapabilityDetailView` 的 `languageSpace` 改为 `LanguageSpacePreview?`，并在 `header` 和具体能力内容中按能力判断是否需要空间。
2. 引入轻量 `SettingsDetailContext`，显式区分 `.global` 与 `.languageSpace(LanguageSpacePreview)`。

约束：

- `.appearance` 与 `.interfaceLanguage` 必须可在 `.global` 上下文展示。
- `.aiProvider` 和 `.sync` 需要真实 `LanguageSpacePreview`；无空间时显示全局边界说明或 no-space 状态，不进入可执行配置表单。
- 不为外观设置创建 `appearancePlaceholderSpace`。
- iPhone 主界面通常已有语言空间，但 macOS Settings scene 可能在无语言空间时打开，必须覆盖该路径。

## 9. UI 设计

### 9.1 设置列表

新增能力项：

- 标题：`外观`
- 英文：`Appearance`
- 图标建议：`circle.lefthalf.filled`
- 状态：`ready`
- 摘要：说明当前选择影响 App 的浅色 / 深色显示，默认跟随系统。

外观设置属于全局设备偏好，但可在当前设置体系中与界面语言并列。它不应显示当前语言空间上下文为必需条件，也不应在无语言空间时被 macOS Settings scene 的 no-space boundary 拦截。

### 9.2 详情页

详情页使用三行选项：

- 跟随系统。
- 浅色。
- 深色。

交互规则：

- 点击已选项不重复写入。
- 点击其他项立即保存到 UserDefaults 并更新 App 状态。
- 选中态通过勾选图标、背景、accessibility value 或 selected trait 表达，不能只靠颜色。
- iPhone 触控目标不小于 44pt。
- iPad 和 macOS 复用同一详情内容，但外壳保持各平台设置承载方式。
- macOS Settings scene 和主窗口同时打开时，二者应观察同一个 App 层 `appearancePreference`，任一入口切换后另一入口下次渲染必须显示新选中态。

### 9.3 文案边界

文案不得承诺多套主题、字体切换、动态壁纸或阅读模式已经存在。

推荐中文文案：

- 标题：`外观`
- 摘要：`选择语迹使用系统外观、浅色或深色。`
- 说明：`外观只影响这台设备上的界面显示，不改变语言空间、学习内容或同步范围。`
- 跟随系统：`跟随系统`
- 浅色：`浅色`
- 深色：`深色`

推荐英文文案：

- Title: `Appearance`
- Summary: `Choose whether LangoTrace follows the system appearance, uses Light, or uses Dark.`
- Explanation: `Appearance only changes the interface on this device. It does not change language spaces, learning content, or sync scope.`
- System: `System`
- Light: `Light`
- Dark: `Dark`

## 10. 颜色 token 方案

当前 `LangoTraceDesign.ColorToken` 不能继续只保存一套浅色 RGB。实施时应建立外观可解析的语义 palette。

推荐最小结构：

```swift
struct LangoTracePalette: Equatable {
    let paper: Color
    let elevatedPaper: Color
    let ink: Color
    let mutedInk: Color
    let hairline: Color
    let accent: Color
    let accentStrong: Color
    let accentMuted: Color
    let warning: Color
    let danger: Color
    let dangerMuted: Color
    let privacyLocal: Color
    let privacyExternal: Color
    let surfaceCanvas: Color
    let surfaceSidebar: Color
    let surfacePanel: Color
    let surfaceInspector: Color
    let surfaceSelected: Color
    let stateReady: Color
    let stateLocalMock: Color
    let stateUnavailable: Color
    let stateWarning: Color
    let stateError: Color
    let separator: Color
}
```

推荐保留 `LangoTraceDesign.ColorToken` 作为调用入口，避免一次性改动所有 View。内部实现本轮优先使用动态 `Color` 资产、UIKit/AppKit dynamic provider，或同等 light / dark palette factory 表达浅深色。

重要技术边界：

- `static let Color` 不能直接读取 SwiftUI `Environment` 中未来的任意 `ThemeID`、字体 profile 或交互 profile。
- 本轮可依赖 `preferredColorScheme` 改变系统 color scheme，再由动态 `Color` 解析浅深色值。
- 如果实施者选择自定义 `EnvironmentKey` 注入 palette，不应一次性改造所有 View；先保留 `ColorToken` facade，并记录后续迁移范围。
- 未来多品牌主题需要另行引入环境化 theme registry 或 view-level palette resolver，不应把本轮 light / dark dynamic color 误写成完整主题引擎。

### 10.1 已审核通过的浅色 / 深色色号

以下色号来自 `prototypes/appearance-theme-review/` 的 iPhone 设置页与主学习页轻量对照原型，已在 2026-05-23 通过用户审核。本表是本轮 SwiftUI 实现的颜色基准，不代表未来多品牌主题注册表已经确定。

| Role | Light | Dark | 用途 |
| --- | --- | --- | --- |
| `paper` | `#F6F1E8` | `#101A18` | 页面主背景 |
| `elevatedPaper` / `panel` | `#FFFDF8` | `#172522` | 卡片、设置面板 |
| `panelSoft` / `surfaceMuted` | `#EEE7DC` | `#13201D` | 次级面、图标底面 |
| `panelStrong` | `#FFFFFF` | `#1D2E2A` | 高层级浮层、强面板 |
| `ink` / `textPrimary` | `#192220` | `#E8F0EA` | 主文字 |
| `mutedInk` / `textSecondary` | `#5A6963` | `#9AA8A1` | 辅助文字 |
| `hairline` / `borderSubtle` | `#D7CEC0` | `#2D3C38` | 边框 |
| `lineSoft` / `separator` | `#E9E0D3` | `#24332F` | 弱分割线 |
| `accent` | `#126B5D` | `#72D2BF` | 主强调 |
| `accentStrong` | `#0D544B` | `#9AE5D5` | 强强调、焦点态 |
| `accentMuted` / `surfaceSelected` | `#E2F1EC` | `#203A35` | 选中背景 |
| `warning` | `#835B1F` | `#D8AE64` | 警告文字、警告图标 |
| `warningMuted` | `#F3E4C9` | `#332818` | 警告弱背景 |
| `danger` | `#AD2D25` | `#FF8B80` | 危险、错误 |
| `privacyLocal` / `stateLocalMock` | `#23786A` | `#86D9C9` | 本地、local mock 状态 |
| `tabBackground` | `rgba(255, 253, 248, .92)` | `rgba(23, 37, 34, .92)` | iPhone 底部 Tab 背景 |
| `shadow` | `rgba(25, 34, 32, .10)` | `rgba(0, 0, 0, .34)` | 投影 |

实现约束：

- 不得在实现中重新引入原型评估阶段已淘汰的浅色 `#F7F3EA`、`#6E7B76`、`#B08234` 作为同一语义 role 的正式值，除非重新记录设计理由和对比度证据。
- 如果 SwiftUI 颜色资产或平台动态颜色需要使用小数 RGB 表达，应保持视觉等价，并在实施记录中保留换算依据。
- `tabBackground` 和 `shadow` 是平台表层效果 token；如果某个平台没有完全一致的 Tab 或投影结构，可以映射到等价的 surface / material role，但不能散落在页面局部。

### 10.2 对比度审核结果

以下结果用于证明当前色号可作为实现基准；真实 App 落地后仍需要 iPhone 截图或人工验收确认组件层级、文字尺寸和状态表达没有被布局破坏。

| 检查项 | Light | Dark |
| --- | ---: | ---: |
| `textPrimary` on `paper` | 14.46:1 | 15.29:1 |
| `textSecondary` on `paper` | 5.13:1 | 7.18:1 |
| `textPrimary` on `panel` | 16.00:1 | 13.66:1 |
| `textSecondary` on `panel` | 5.68:1 | 6.41:1 |
| `accent` text on `surfaceSelected` | 5.48:1 | 6.80:1 |
| Tab active text on `accent` | 5.68:1 | 9.88:1 |
| `privacyLocal` on `accentMuted` | 4.55:1 | 7.44:1 |
| `warning` on `warningMuted` | 4.81:1 | 6.97:1 |
| `danger` on `paper` | 5.87:1 | 7.82:1 |

约束：

- 不在页面里新增散落 RGB。
- 不让状态色只靠外观切换改变含义。
- 深色 palette 不应是浅色 palette 的机械反转。
- 危险、警告、不可用、本地预览、隐私本地、隐私外发必须在深色下保持可读和语义清楚。
- 如果本轮无法完成截图验证，文档必须保留“完成代码基础设施，视觉需人工验收”的剩余风险。

## 11. 实施步骤

### 任务 1：Core 偏好模型与测试

- [ ] 新增 `AppearancePreference`。
- [ ] 新增 `AppearancePreferenceStore` 与 `UserDefaultsAppearancePreferenceStore`。
- [ ] 新增 `AppearancePreferenceTests`，覆盖：
  - `system` 是未知存储值 fallback。
  - `light` 和 `dark` 可从 storage value 恢复。
  - store 写入、读取和 reset 行为。

验证命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter AppearancePreferenceTests
```

### 任务 2：设置能力模型接入

- [ ] 在 `SettingsCapability.Kind` 新增 `.appearance`。
- [ ] 为 `.appearance` 配置 `circle.lefthalf.filled` 图标。
- [ ] 在学习内容 repository 的 settings capabilities 中加入外观项。
- [ ] 更新 `InMemoryLearningContentRepositoryTests` 和 `SettingsCapabilityTests`，确认设置能力包含外观、顺序稳定、文案 key 完整，且不依赖语言空间写入。

验证命令：

```bash
swift test --package-path Packages/LangoTraceData
```

### 任务 3：App 层状态与 `preferredColorScheme`

- [ ] 在 `LangoTraceApp` 增加 `UserDefaultsAppearancePreferenceStore`。
- [ ] 增加 `@State private var appearancePreference: AppearancePreference`。
- [ ] 将 preference 传入 `LangoTraceRootView` 和 `LangoTraceSettingsSceneView`。
- [ ] 在 root content 和 macOS Settings scene 上应用 `preferredColorScheme(appearancePreference.preferredColorScheme)`。
- [ ] 确保 `system` 模式传入 `nil`，不覆盖系统外观。
- [ ] 外观变更 closure 中先写入 store，再更新 App 层 `@State`；若后续引入异步 store，必须保持 UI 主线程更新和重复点击防抖。

验证重点：

- App 启动读取本地偏好。
- 设置页切换后当前界面即时变化。
- macOS `Cmd+,` 打开的 Settings scene 与主窗口保持同一外观偏好。

### 任务 4：UI 设置详情

- [ ] 扩展 `LangoTraceRootView`、`PhoneMainView`、`PadMainView`、`MacMainView` 和 `LangoTraceSettingsSceneView` 的初始化参数。
- [ ] 扩展 `PadMainSections`、`MacWorkspaceContentView` 和 `MacInspectorContent` 的共享设置详情传参，避免只接通 iPhone 或 macOS Settings scene。
- [ ] 在 `SettingsCapabilityDetailView` 新增外观设置内容。
- [ ] 将设置详情上下文改为可表达全局偏好，确保 `.appearance` 和 `.interfaceLanguage` 无当前语言空间时仍可展示。
- [ ] 在 `LocalizedChrome.swift` 增加外观相关 localization key resolver。
- [ ] 更新 `Localizable.xcstrings` 的中文和英文文案。
- [ ] 增加 `AppearanceSettingsTests`，用源码或 presentation model 覆盖：
  - 外观能力存在。
  - 三个选项存在。
  - 已选项具备可访问状态。
  - 详情页不要求当前语言空间。
  - macOS Settings scene 无当前语言空间时不会拦截外观详情。

验证命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter AppearanceSettingsTests
```

### 任务 5：设计 token 浅深色基础设施

- [ ] 重构 `LangoTraceDesign.swift`，让颜色 token 具备浅色 / 深色解析能力。
- [ ] 保留现有 `LangoTraceDesign.ColorToken.*` 调用面，降低本轮改动面。
- [ ] 按第 10.1 节已审核通过色号表实现浅色 / 深色 palette；如需平台等价映射，必须记录原因和对比度结果。
- [ ] 检查设置、Welcome、Onboarding、记录、练习、记忆、AI Provider 设置和 Sync 设置中是否仍有新增散落 RGB。
- [ ] 若仍存在历史 RGB，记录在实施记录中；本轮至少不能新增更多散落颜色。

验证命令：

```bash
rg -n "Color\\(red:" Packages/LangoTraceUI/Sources/LangoTraceUI --glob '!LangoTraceDesign.swift'
swift test --package-path Packages/LangoTraceUI
```

如果 `rg` 命令仍有历史结果，实施记录必须逐项判断是否属于本轮应清理范围。

### 任务 6：文档同步

- [ ] 更新 `docs/spec/003-ui-design-system.md`，把“深色模式预留”改为“浅色 / 深色外观基础设施已接入，发布级视觉仍需截图验收”的准确表述。
- [ ] 更新 `docs/platform-page-inventory.md`，记录外观设置入口、状态和代码路径。
- [ ] 更新 `docs/testing/README.md`，加入浅色 / 深色 / 跟随系统的人工验证清单。
- [ ] 若实现中改变了设置能力列表或 Settings scene 行为，按 `docs/review/README.md` 判断是否需要文档影响检查。

## 12. 测试方案

自动化测试：

- Core：`AppearancePreference` storage value、fallback、UserDefaults store reset。
- Data：`SettingsCapability.Kind.appearance` 和 settings capabilities 列表。
- UI：外观设置详情选项、可访问状态、当前语言空间非必需边界、iPhone / iPad / macOS 工作台和 macOS Settings scene 传参完整性。
- UI 源码约束：不新增页面级散落 RGB。

人工验证：

- iPhone：进入设置 > 外观，切换浅色 / 深色 / 跟随系统；检查记录、练习、记忆和设置列表主要区域可读。
- iPad：regular width 进入 Sidebar 设置 > 外观；切换后检查 Sidebar、主区、学习面板和设置详情都变更。
- iPad compact / Stage Manager 窄窗口：外观详情仍可读可点。
- macOS 工作台：Sidebar 设置 > 外观可切换。
- macOS `Cmd+,`：Settings scene 中外观可切换，并影响主窗口。
- Accessibility：选项行有可访问 label 和 selected 状态；状态不能只靠颜色表达。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter AppearancePreferenceTests
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI --filter AppearanceSettingsTests
swift test --package-path Packages/LangoTraceUI
```

完整验证：

```bash
scripts/verify.sh
```

文档检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 14. 文档影响检查

本任务会改变设置体系、UI 设计系统和测试清单，因此实施完成后至少需要检查：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/platform-page-inventory.md`
- `docs/testing/README.md`
- `docs/review/README.md`

如果实现中只完成基础设施但没有完成截图或人工验证，文档必须明确剩余风险，不能把深色视觉体验描述为发布级完成。

## 15. 完成标准

- 三端设置入口都能进入外观设置。
- `跟随系统 / 浅色 / 深色` 可持久化，并即时影响界面。
- 外观偏好不进入语言空间、同步、AI Provider 或 Keychain。
- 设计 token 具备浅色 / 深色基础设施，不再依赖单套静态浅色事实。
- 自动化测试覆盖 Core store、设置能力和 UI 设置详情。
- 聚焦测试和完整验证命令通过，或在实施记录中说明无法运行原因和剩余风险。
- 相关文档更新完成，且文档 placeholder 扫描通过。

## 16. 剩余风险

- 深色 palette 的高级感和对比度需要真实设备或模拟器截图确认，单元测试无法证明视觉质量。
- 当前设计系统中已有页面可能存在历史静态颜色；本任务至少应阻止新增散落颜色，并优先把核心页面迁到 palette。
- macOS 多窗口如果后续支持不同窗口不同外观，需要单独设计；本轮按 App 级设备偏好处理。
- 未来字体、交互样式和多品牌色扩展必须回到 `docs/architecture/notes/2026-05-22-appearance-theme-extension-notes.md` 重新决策，不能直接在当前三选一设置里堆选项。
- 如果只给 `ColorToken` 换成动态 light / dark `Color`，它仍不是完整主题引擎；后续多品牌色必须补 environment theme registry 或等价机制。
- 设置详情从强制 `LanguageSpacePreview` 改为可选上下文会影响 AI Provider、同步、隐私、本地数据和导入导出说明页，实施时必须逐项确认哪些能力允许 global context，哪些能力必须显示 no-space boundary。

## 17. 实施记录

- 2026-05-22：创建方案文档，当前尚未修改 Swift 代码。
- 2026-05-22：完成严格代码审查并更新方案。主要修正：外观详情必须支持无语言空间；`ColorToken` 的静态调用面不能被描述为完整未来主题引擎；补充 `PadMainSections`、`MacWorkspaceContentView`、`MacInspectorContent` 和 `SettingsCapabilityTests` 等实际影响面；补充 App 状态同步和 macOS Settings scene 无空间验证要求。
- 2026-05-23：完成 iPhone 设置页与主学习页浅色 / 深色轻量原型的专业色彩审核；用户确认色号审核通过；已将本轮实现基准色号表和对比度结果写入本方案。原型目录：`prototypes/appearance-theme-review/`。
