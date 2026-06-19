# 界面语言设置页轻量化重设计方案

状态：Verified

类型：refactor

创建日期：2026-05-21

最后更新日期：2026-05-21

审核状态：Approved With Changes

## 用户确认记录

- 2026-05-21：用户指出 iPhone「界面语言」设置页文本过多，要求从专业设计师角度重新设计。
- 2026-05-21：已确认采用「选择优先，边界轻提示」方向，并创建本实施方案。
- 2026-05-21：完成系统架构师严格复查。结论：方向正确，但必须补充 App 级偏好与语言空间解耦、无障碍状态、幂等写入和更稳的测试边界。

## 需求描述

iPhone 设置页中的「界面语言」详情目前在同一屏内展示语言选择控件、三段解释文案，以及通用设置能力详情卡片。截图显示首屏主要被说明文字占据，用户需要滚动和阅读大量工程边界说明才能完成核心任务。

本任务要把界面语言详情页重构为更接近 Apple Settings 心智的选择型页面：用户进入后应快速看见当前选择和可选语言，完成切换；必要边界说明只作为低权重脚注存在，不再以多张说明卡抢占主视觉。

## 现状说明

当前实现位于 `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`。

`SettingsCapabilityDetailView.detailContent` 对普通 setting capability 使用统一结构：

- `header`
- `CapabilityStatusRow`
- 可选的能力专属内容
- `LocalizedTextPanel(titleKey: settingsCurrentBoundaryTitleKey, textKey: localizationKeys.detail)`
- `LocalizedTextPanel(titleKey: settingsNextRequirementTitleKey, textKey: localizationKeys.nextRequirement)`
- `LocalizedTextPanel(titleKey: settingsNoSideEffectsTitleKey, textKey: settingsNoSideEffectsBodyKey)`

其中 `.interfaceLanguage` 还会额外展示 `interfaceLanguagePicker`。该 picker 内部除了 inline `Picker`，还展示以下三段说明：

- `settings.interfaceLanguage.explanation`
- `settings.interfaceLanguage.systemBoundary`
- `settings.interfaceLanguage.contentBoundary`

因此用户在一个选择页里同时看到选择器、系统 per-app language 说明、内容边界说明、当前状态、后续要求和隐私说明。信息虽然正确，但信息架构不适合终端用户。

相关本地化资源位于 `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`。现有测试覆盖位于：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/ThreePlatformPresentationCopyTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/SettingsCapabilityTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/InterfaceLanguagePreferenceTests.swift`

## 目标

1. 将「界面语言」详情页变成选择优先的设置页。
2. 保留 `System / English / 简体中文 / Español / 日本語 / Français / Deutsch / 한국어 / Русский` 选项。
3. 当前选择使用 checkmark 或等效视觉反馈表达，且按钮触控目标不少于 44pt。
4. 只保留一句低权重边界脚注：该设置仅影响语迹界面，不改变语言空间或已保存内容。
5. 不再在该页展示「当前状态」「接下来」「隐私说明」三张通用说明卡。
6. 不再在该页展示系统弹窗、StoreKit、文件选择器和第三方 UI 的长说明。
7. 不改变界面语言偏好的模型、持久化、解析逻辑和三端语义。
8. 不在界面语言详情页展示 `languageSpace.displayContext`，避免把 App 级界面语言偏好误表达为当前语言空间的属性。
9. 选项行必须暴露已选 / 未选无障碍状态，不能只依赖视觉 checkmark。

## 范围

### 本轮修改

- 调整 `SettingsCapabilityDetailView` 中 `.interfaceLanguage` 的详情布局。
- 增加界面语言列表式选项行组件或局部 View。
- 增加短脚注文案 key。
- 更新或移除不再适合常驻展示的界面语言说明引用。
- 增加源码级 UI 回归测试，防止长说明卡重新回到界面语言页。
- 运行 UI package 聚焦测试、完整 UI package 测试和文档检查。

### 不做什么

- 不修改 `InterfaceLanguagePreference` case、storage value、resolved language 规则。
- 不修改语言空间模型。
- 不修改 AI Provider、Prompt、TTS、OCR、权限或同步逻辑。
- 不新增系统 per-app language 跳转。
- 不承诺 App 内设置能覆盖系统弹窗、StoreKit sheet、文件选择器或第三方 UI。
- 不重做整个设置页视觉系统。
- 不改 iPad / macOS 的设置语义；如果它们复用该详情页，只接受同一轻量结构自然生效。

## 证据与决策依据

### 产品依据

`docs/spec/006-interface-localization-and-language-boundaries.md` 已明确：

- 界面语言、用户母语和目标学习语言是三条独立轴线。
- 用户修改 App 界面语言不得自动改变语言空间目标语言、用户母语或已生成学习内容。
- 设置中必须预留界面语言入口，并容纳第一批主流界面语言。
- 系统级 App 语言和 App 内界面语言偏好必须明确关系，但不得承诺 App 内 Picker 覆盖所有系统 UI。

这些边界应该被代码和测试守住，但不需要全部在选择页首屏展开。

### 交互依据

从 Apple 设置型页面心智看，语言设置的主任务是选择当前偏好。信息架构应优先支持：

- 识别当前值。
- 浏览可选项。
- 一次点击切换。
- 必要时理解副作用边界。

当前页面把工程边界说明放在主视觉区域，削弱了选择任务。更合适的层级是：列表项承载操作，脚注承载副作用边界，完整规范留在 `docs/spec/006-interface-localization-and-language-boundaries.md`。

### 代码依据

当前问题不是数据模型错误，而是 `SettingsCapabilityDetailView` 的通用详情模板对 `.interfaceLanguage` 过度复用。`.aiProvider` 和 `.sync` 已经存在专属分支，说明该文件允许为复杂能力使用定制详情内容。界面语言也应拥有专属分支，避免继承通用说明卡。

当前 `header` 会固定展示 `languageSpace.displayContext`。这对 AI Provider、Sync 等空间相关设置是有价值的上下文；但对界面语言是错误信号，因为界面语言属于设备级或 App 偏好，不属于某个语言空间。重设计必须让 `.interfaceLanguage` 跳过该空间上下文。

## 涉及的代码文件路径

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- Create: `Packages/LangoTraceUI/Tests/LangoTraceUITests/InterfaceLanguageSettingsPageTests.swift`
- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- Modify if resource wording triggers presentation-copy failures: `Packages/LangoTraceUI/Tests/LangoTraceUITests/ThreePlatformPresentationCopyTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/SettingsCapabilityTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/InterfaceLanguagePreferenceTests.swift`

## 涉及的文档路径

- `docs/plans/README.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`

## 严格复查结论

状态：Approved With Changes

### 关键问题

- P1：界面语言页不能继续展示当前语言空间上下文。证据：`SettingsCapabilityDetailView.header` 固定使用 `Text(languageSpace.displayContext)`；`006` 规范明确界面语言属于 App 级偏好，不属于语言空间。影响：即使移除长文案，用户仍可能以为界面语言随当前空间变化。修改：`.interfaceLanguage` 分支跳过 `header`。
- P1：选项行不能只靠 checkmark 表达选中状态。证据：项目已有 `LanguageSpaceSwitcherSheet`、`LanguageSpaceManagementView`、`OnboardingCompactLevelSelector` 使用 `accessibilityValue` 或 `.isSelected` trait 表达选中状态。影响：VoiceOver 用户无法可靠知道当前界面语言。修改：选项行增加 `accessibilityValue` 和 `.isSelected` trait，checkmark 图标设为 accessibility hidden。
- P2：重复点击当前语言不应触发重复写入。证据：当前方案的按钮 action 每次都调用 `onInterfaceLanguagePreferenceChange(preference)`。影响：可能造成不必要的偏好写入、环境 locale 刷新和视图重算。修改：写入前使用 `guard interfaceLanguagePreference != preference else { return }`。
- P2：分隔线实现不应依赖 `InterfaceLanguagePreference.allCases.last` 的可选比较。影响：实现可读性和可维护性较弱。修改：使用 `Array(preferences.enumerated())`，按 index 判断最后一项。

### 四维切片

- 并发 / 性能边界：本任务不新增异步、网络、Provider 或数据库调用；主要性能风险是重复点击当前项导致重复偏好写入和 locale 环境刷新，已要求幂等 guard。
- 异常边界：本任务不新增可失败外部依赖；本地化资源新增 key 的主要失败模式是 String Catalog 缺项或 JSON 结构损坏，已要求资源级测试和 UI package 测试。
- 状态同步：`InterfaceLanguagePreference` 仍是唯一状态源，`onInterfaceLanguagePreferenceChange` 仍是唯一写入入口；显式语言继续通过 App 根部 locale environment 驱动自有 chrome，不写入语言空间。
- 数据一致性：不改 Core/Data schema，不改 `InterfaceLanguagePreference` storage value，不改语言空间模型，不触发迁移；旧说明 key 保留，避免把 UI 精简扩大成资源清理。

## 实施方案

### Task 1：新增失败测试，锁定轻量化界面结构

**Files:**

- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

新增测试，读取 `SettingsCapabilityDetailView.swift`，断言 `.interfaceLanguage` 使用专属内容分支，并且该分支不再引用三张通用说明卡和三段长解释。

写入以下测试内容：

```swift
@Test("Interface language detail uses choice-first layout without persistent explanation cards")
func interfaceLanguageDetailUsesChoiceFirstLayoutWithoutPersistentExplanationCards() throws {
    let source = try String(contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"), encoding: .utf8)

    #expect(source.contains("if capability.kind != .interfaceLanguage {\n            header\n        }"))
    #expect(source.contains("interfaceLanguageSettingsContent"))
    #expect(source.contains("interfaceLanguageOptionRow"))
    #expect(source.contains("settings.interfaceLanguage.selectionFootnote"))
    #expect(!source.contains("interfaceLanguagePicker"))
    #expect(!source.contains("localizedText(\"settings.interfaceLanguage.explanation\")"))
    #expect(!source.contains("localizedText(\"settings.interfaceLanguage.systemBoundary\")"))
    #expect(!source.contains("localizedText(\"settings.interfaceLanguage.contentBoundary\")"))
}
```

再新增无障碍与幂等写入测试：

```swift
@Test("Interface language option rows expose selection state and avoid duplicate writes")
func interfaceLanguageOptionRowsExposeSelectionStateAndAvoidDuplicateWrites() throws {
    let source = try String(contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"), encoding: .utf8)

    #expect(source.contains("guard interfaceLanguagePreference != preference else {"))
    #expect(source.contains("LangoTraceDesign.Density.minimumTouchTarget"))
    #expect(source.contains(".accessibilityValue(localizedText(isSelected ? \"accessibility.selected\" : \"accessibility.unselected\"))"))
    #expect(source.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
    #expect(source.contains(".accessibilityHidden(true)"))
}
```

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
```

预期：新增测试失败，失败原因是 `interfaceLanguageSettingsContent` 和 `interfaceLanguageOptionRow` 尚不存在，旧长说明仍在源码中，且当前实现尚未声明选项行无障碍状态。

### Task 2：重构界面语言详情布局

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`

调整 `detailContent` 的分支结构，让 `.interfaceLanguage` 与 `.aiProvider`、`.sync` 一样使用专属内容，而不是通用 `CapabilityStatusRow` 加说明卡。

使用以下结构：

```swift
private var detailContent: some View {
    let localizationKeys = settingsCapabilityDetailLocalizationKeys(for: capability.kind)

    return VStack(alignment: .leading, spacing: 18) {
        if capability.kind != .interfaceLanguage {
            header
        }
        if capability.kind == .aiProvider {
            aiProviderSettingsContainer
        } else if capability.kind == .sync {
            syncSettingsContainer
        } else if capability.kind == .interfaceLanguage {
            interfaceLanguageSettingsContent
        } else {
            CapabilityStatusRow(
                localizedTitleKey: capability.kind.localizedTitleKey,
                localizedSummaryKey: localizationKeys.summary,
                status: capability.status,
                systemImage: capability.kind.systemImage,
                action: nil
            )

            LocalizedTextPanel(
                titleKey: settingsCurrentBoundaryTitleKey,
                textKey: localizationKeys.detail
            )
            LocalizedTextPanel(
                titleKey: settingsNextRequirementTitleKey,
                textKey: localizationKeys.nextRequirement
            )
            LocalizedTextPanel(
                titleKey: settingsNoSideEffectsTitleKey,
                textKey: settingsNoSideEffectsBodyKey
            )
        }
    }
    .padding(20)
}
```

新增专属内容：

```swift
private var interfaceLanguageSettingsContent: some View {
    let preferences = InterfaceLanguagePreference.allCases

    VStack(alignment: .leading, spacing: 12) {
        VStack(spacing: 0) {
            ForEach(Array(preferences.enumerated()), id: \.element.id) { index, preference in
                interfaceLanguageOptionRow(for: preference)
                if index < preferences.count - 1 {
                    Divider()
                }
            }
        }
        .langoPanel(padding: 0)

        localizedText("settings.interfaceLanguage.selectionFootnote")
            .font(.footnote)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }
}
```

新增选项行：

```swift
private func interfaceLanguageOptionRow(for preference: InterfaceLanguagePreference) -> some View {
    let isSelected = interfaceLanguagePreference == preference

    Button {
        guard interfaceLanguagePreference != preference else {
            return
        }
        onInterfaceLanguagePreferenceChange(preference)
    } label: {
        HStack(spacing: 12) {
            localizedText(interfaceLanguagePreferenceTitleKey(for: preference))
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(localizedText(interfaceLanguagePreferenceTitleKey(for: preference)))
    .accessibilityValue(localizedText(isSelected ? "accessibility.selected" : "accessibility.unselected"))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
}
```

删除旧的 `interfaceLanguagePicker` 计算属性。该删除会移除三段长解释在 UI 中的常驻展示。

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
```

预期：Task 1 新增测试通过。

### Task 3：精简本地化资源

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

新增短脚注 key：

```text
settings.interfaceLanguage.selectionFootnote
```

中文文案：

```text
仅影响语迹界面，不改变语言空间或已保存内容。
```

英文文案：

```text
Only changes the LangoTrace interface. Language spaces and saved content stay unchanged.
```

其他第一批界面语言使用同等长度的简洁翻译。要求：

- 不使用 `Provider`、`StoreKit`、`per-app language` 等工程词作为常驻脚注。
- 不出现长列表式副作用说明。
- 不删除 `settings.interfaceLanguage.detail`、`settings.interfaceLanguage.nextRequirement`、`settings.interfaceLanguage.systemBoundary` 等旧 key。它们仍可作为其他设置概览、未来帮助页或历史测试的资源，不把本轮 UI 精简扩大为资源清理。

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
```

预期：测试通过，String Catalog 可被测试读取。

### Task 4：补充资源级回归测试

**Files:**

- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

新增测试，确认短脚注存在，并且中文和英文不过度冗长。

写入以下测试内容：

```swift
@Test("Interface language selection footnote stays concise")
func interfaceLanguageSelectionFootnoteStaysConcise() throws {
    let catalogURL = try #require(localizableCatalogURL())
    let data = try Data(contentsOf: catalogURL)
    let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try #require(root["strings"] as? [String: Any])
    let entry = try #require(strings["settings.interfaceLanguage.selectionFootnote"] as? [String: Any])
    let localizations = try #require(entry["localizations"] as? [String: Any])

    let zhHans = try localizedCatalogValue(localizations: localizations, locale: "zh-Hans")
    let english = try localizedCatalogValue(localizations: localizations, locale: "en")

    #expect(zhHans.count <= 32)
    #expect(english.count <= 100)
    #expect(!zhHans.contains("StoreKit"))
    #expect(!english.localizedCaseInsensitiveContains("per-app language"))
}
```

如果当前测试文件没有 `localizedCatalogValue` helper，则新增私有 helper：

```swift
private func localizedCatalogValue(localizations: [String: Any], locale: String) throws -> String {
    let localization = try #require(localizations[locale] as? [String: Any])
    let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
    return try #require(stringUnit["value"] as? String)
}
```

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
```

预期：测试通过。

### Task 5：文档影响检查

**Files:**

- Modify: `docs/spec/006-interface-localization-and-language-boundaries.md`
- Review: `docs/spec/003-ui-design-system.md`

更新长期规范，避免后续开发者把第 5.2 节的完整边界说明误读为设置页必须常驻展示的长文案。

在 `docs/spec/006-interface-localization-and-language-boundaries.md` 第 5.2 节追加：

```text
界面语言选择页应以选择任务为主。完整边界说明属于规范、帮助或发布材料语义，不要求在选择页常驻展示；常驻 UI 可使用短脚注说明“仅影响 App 界面，不改变语言空间或已保存内容”。系统弹窗、StoreKit、文件选择器和第三方 UI 的边界不得被反向承诺，但也不应以长段落压过选择任务。
```

`003` 已要求语言概念分层，本轮不改变。

运行：

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

预期：placeholder scan 无命中，`git diff --check` 无输出。

### Task 6：完整验证

运行聚焦测试：

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
```

运行 UI package 完整测试：

```bash
swift test --package-path Packages/LangoTraceUI
```

运行格式检查：

```bash
swiftformat --lint Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift --cache ignore
```

运行文档检查：

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

运行完整工程门禁：

```bash
scripts/verify.sh
```

## 复查方法

代码复查：

- `SettingsCapabilityDetailView` 中 `.interfaceLanguage` 使用专属分支。
- `.interfaceLanguage` 不展示 `languageSpace.displayContext`。
- `.interfaceLanguage` 不再渲染 `CapabilityStatusRow`、`settingsCurrentBoundaryTitleKey`、`settingsNextRequirementTitleKey` 和 `settingsNoSideEffectsTitleKey` 对应的三张通用卡。
- 语言选项仍来自 `InterfaceLanguagePreference.allCases`，没有手写散落的选项清单。
- `onInterfaceLanguagePreferenceChange` 仍是唯一写入入口，且重复点击当前选项不触发重复写入。
- 选项行使用 `LangoTraceDesign.Density.minimumTouchTarget` 保证 44pt 触控目标。
- 选项行通过 `accessibilityValue` 和 `.isSelected` trait 暴露当前状态。

文案复查：

- 首屏优先显示选择项。
- 常驻说明只剩短脚注。
- 不出现 `Provider`、`StoreKit`、`per-app language` 等工程词。
- 不暗示修改界面语言会改变母语、目标语言、语言空间或已保存内容。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
swift test --package-path Packages/LangoTraceUI
swiftformat --lint Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift --cache ignore
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
scripts/verify.sh
git status --short
```

## 文档影响检查

本任务改变界面语言设置页的呈现方式，但不改变 `006` 中的语言边界决策，不改变 ADR，也不改变 Core / Data 模型。实施时必须更新 `docs/spec/006-interface-localization-and-language-boundaries.md` 第 5.2 节，明确完整边界说明属于规范、帮助或发布材料语义，不要求在设置页常驻展示。

## 实施记录

- 2026-05-21：创建方案。尚未进入代码实施。
- 2026-05-21：按 TDD 增加 `InterfaceLanguageSettingsPageTests`，先确认界面语言详情页结构和资源脚注测试失败；保留 `PageClosureStateTests` 中既有语言选项 key 覆盖。
- 2026-05-21：重构 `SettingsCapabilityDetailView`，让 `.interfaceLanguage` 使用选择优先的专属内容，不再展示当前语言空间上下文、通用说明卡和旧长解释。
- 2026-05-21：新增 `settings.interfaceLanguage.selectionFootnote` 8 语言资源，并在 `006` 规范中明确常驻 UI 可用短脚注承载边界说明。
- 2026-05-21：验证通过。`InterfaceLanguageSettingsPageTests` 3 个测试通过；`Packages/LangoTraceUI` 173 个测试 / 26 个 suites 通过；`scripts/verify.sh` 退出码 0，完成 XcodeGen、Core/Data/UI package 测试、iPhone 17 构建、iPad Pro 13-inch 构建、macOS 构建、SwiftLint、SwiftFormat 和 docs placeholder scan。

## 完成标准

- 「界面语言」详情页以语言选项列表为主体。
- 当前选项有明确 checkmark 或等效反馈。
- 当前选项有无障碍 selected 状态，不只依赖 checkmark。
- 页面只保留一句低权重脚注说明副作用边界。
- 页面不显示当前语言空间上下文，避免混淆 App 级偏好和语言空间。
- 三张通用说明卡不再出现在界面语言详情页。
- 旧的三段长解释不再由该页常驻引用。
- `InterfaceLanguagePreference` 模型和持久化语义不变。
- `PageClosureStateTests` 聚焦测试通过。
- `Packages/LangoTraceUI` 完整测试通过。
- `docs/spec/006-interface-localization-and-language-boundaries.md` 已补充「短脚注可承载常驻 UI 边界」规则。
- 文档 placeholder scan 和 `git diff --check` 通过。

## 剩余风险

- 源码级 UI 测试能锁定结构和文案引用，但不能完全替代模拟器截图审查。实施后如需要视觉确认，应在 iPhone 17 模拟器中打开设置页截图复核。
- 短脚注的多语言翻译需要后续本地化 QA。当前实现阶段只能保证语义短、结构稳定、不过度暴露工程词。
- 如果未来新增帮助中心或二级说明页，可以把系统 per-app language、StoreKit 和文件选择器边界放入帮助页；本轮不新增该入口。
