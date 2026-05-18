# String Catalog and Interface Language Settings Implementation Plan

状态：Draft

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first complete interface-localization loop: String Catalog resources, persisted interface language preference, settings UI, and English / Simplified Chinese verification across iPhone, iPad, and macOS.

**Architecture:** Keep content language separate from App chrome language. Store interface language as a device-level App preference, resolve it through `InterfaceLanguagePreference`, inject the resulting SwiftUI locale at the app shell, and localize App-owned UI copy from `LangoTraceUI` resources. Do not translate user content, mock learning content, language space target language, or Provider output.

**Architecture Review Addendum:** The String Catalog belongs in `LangoTraceUI` for this stage because the visible SwiftUI chrome is implemented there. Every lookup from that package must use `Bundle.module` or a package-local wrapper. App-internal explicit language choices override system per-app language only for LangoTrace-owned SwiftUI chrome; `System` follows the platform language preference list and falls back to English for unsupported languages. Package resources do not by themselves prove that the main App bundle advertises Simplified Chinese to system per-app language settings, so implementation must either add App target localization declarations or keep system-setting language availability explicitly out of scope. Avoid `String(localized:bundle:)` for environment-driven instant switching unless the current resolved locale is passed explicitly.

**Tech Stack:** Swift 6, SwiftUI Multiplatform, Swift Package resources, String Catalog, `UserDefaults`, Swift Testing, XcodeGen, iOS Simulator, macOS build.

---

## File Structure Map

- Create: `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
  - Owns first English and Simplified Chinese App chrome strings.
- Modify: `Packages/LangoTraceUI/Package.swift`
  - Adds `Resources` as processed package resources.
- Modify: `project.yml` and `LangoTraceApp/Supporting/Info-iOS.plist` / `Info-macOS.plist` if system per-app language availability is claimed
  - Declares App target supported localizations, for example `English` and `Simplified Chinese`, separately from package chrome resources.
- Create: `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreferenceStore.swift`
  - Defines a small protocol and `UserDefaultsInterfaceLanguageStore` for device-level preference persistence.
- Test: `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/InterfaceLanguagePreferenceStoreTests.swift`
  - Verifies persistence, invalid value recovery, and reset behavior.
- Modify: `LangoTraceApp/LangoTraceApp.swift`
  - Holds the interface language preference state and injects resolved locale into `LangoTraceRootView`.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
  - Accepts current interface language preference and update action if needed by child settings views.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
  - Adds an interactive settings detail for `interfaceLanguage`.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
  - Migrates common App chrome labels and unavailable/request-preview text to localized resources.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
  - Migrates Welcome chrome text.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
  - Migrates Onboarding chrome text while preserving language names and target language values.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
  - Migrates Tab labels and primary chrome text.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
  - Migrates iPad route titles and empty states.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PadWorkspaceBar.swift`
  - Migrates iPad search placeholder and new-entry action.
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
  - Migrates macOS sidebar, toolbar and inspector chrome.
- Test: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
  - Adds checks that settings routes expose interface language without changing route identity.
- Modify: `docs/testing/README.md`
  - Adds final screenshot verification result fields for English and Simplified Chinese.
- Create or update: `docs/review/rounds/2026-05-17-string-catalog-interface-language-settings/README.md`
  - Records document/code consistency review if implementation changes app shell, package resources, verification script or localization boundaries.

## Task 1: String Catalog Resource Skeleton

**Files:**

- Modify: `Packages/LangoTraceUI/Package.swift`
- Create: `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

- [x] **Step 1: Add package resource processing**

Update the `LangoTraceUI` target so `Bundle.module` can load localized resources:

```swift
.target(
    name: "LangoTraceUI",
    dependencies: [
        .product(name: "LangoTraceCore", package: "LangoTraceCore"),
        .product(name: "LangoTraceData", package: "LangoTraceData"),
    ],
    resources: [
        .process("Resources"),
    ]
),
```

Confirm `project.yml` keeps `options.developmentLanguage: en`, matching the String Catalog source language.

- [x] **Step 2: Create the first String Catalog**

Create `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings` with English as source language and Simplified Chinese as a translated language. Start with a small but real key set:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "app.badge.aiNotConfigured" : {
      "comment" : "Welcome badge indicating external AI is not configured.",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "AI not configured" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "未配置 AI" } }
      }
    },
    "app.badge.localFirst" : {
      "comment" : "Welcome badge for local-first product behavior.",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Local-first" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "本地优先" } }
      }
    },
    "settings.interfaceLanguage.title" : {
      "comment" : "Settings row title for choosing App interface language.",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Interface Language" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "界面语言" } }
      }
    },
    "settings.interfaceLanguage.system" : {
      "comment" : "Picker option that follows system App language.",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "System" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "跟随系统" } }
      }
    },
    "tab.today" : {
      "comment" : "iPhone tab for today's learning workspace.",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Today" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "今日" } }
      }
    }
  },
  "version" : "1.0"
}
```

- [x] **Step 3: Verify package resources build**

Run:

```bash
swift test --package-path Packages/LangoTraceUI
```

Expected: PASS. If SwiftPM reports the resource path is invalid, keep the resource under `Sources/LangoTraceUI/Resources` and keep `.process("Resources")`.

- [x] **Step 4: Verify bundle lookup discipline**

Before broad migration, add or document a small package-local convention:

- Use `Text("key", bundle: .module)` for localized text in `LangoTraceUI`.
- Use label builders for controls that do not expose a `bundle` parameter directly.
- Use `.navigationTitle(Text("key", bundle: .module))` instead of `.navigationTitle("key")`.
- Use `.accessibilityLabel(Text("key", bundle: .module))` for localized accessibility-only strings.
- Keep `Text(dynamicString)` for user content, seed content, Provider names, model names and target-language text that must not be catalog-localized.

- [x] **Step 5: Decide App target localization declaration**

Check whether the current App bundle advertises `zh-Hans` to iOS / iPadOS / macOS system per-app language settings. If not, either:

- Add App target localization declarations such as `CFBundleLocalizations` for `en` and `zh-Hans`, then verify the system settings language list.
- Or explicitly keep system per-app language availability outside this phase and adjust user-facing copy so `System` only means following the platform language preference already provided to the app.

Implemented decision: add `CFBundleLocalizations = [en, zh-Hans]` to both App target InfoPlists and mirror the same declaration in `project.yml`.

## Task 2: Interface Language Preference Store

**Files:**

- Create: `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreferenceStore.swift`
- Create: `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/InterfaceLanguagePreferenceStoreTests.swift`

- [x] **Step 1: Write persistence tests**

Create `InterfaceLanguagePreferenceStoreTests.swift`:

```swift
import Foundation
import LangoTraceCore
import Testing

@Suite("Interface language preference store")
struct InterfaceLanguagePreferenceStoreTests {
    @Test("Store reads system by default")
    func readsSystemByDefault() {
        let defaults = UserDefaults(suiteName: "InterfaceLanguagePreferenceStoreTests.default")!
        defaults.removePersistentDomain(forName: "InterfaceLanguagePreferenceStoreTests.default")
        let store = UserDefaultsInterfaceLanguageStore(defaults: defaults)

        #expect(store.preference == .system)
    }

    @Test("Store persists explicit preference")
    func persistsExplicitPreference() {
        let defaults = UserDefaults(suiteName: "InterfaceLanguagePreferenceStoreTests.persist")!
        defaults.removePersistentDomain(forName: "InterfaceLanguagePreferenceStoreTests.persist")
        let store = UserDefaultsInterfaceLanguageStore(defaults: defaults)

        store.preference = .simplifiedChinese

        #expect(UserDefaultsInterfaceLanguageStore(defaults: defaults).preference == .simplifiedChinese)
    }

    @Test("Store recovers invalid values as system")
    func recoversInvalidValues() {
        let defaults = UserDefaults(suiteName: "InterfaceLanguagePreferenceStoreTests.invalid")!
        defaults.removePersistentDomain(forName: "InterfaceLanguagePreferenceStoreTests.invalid")
        defaults.set("fr", forKey: UserDefaultsInterfaceLanguageStore.storageKey)
        let store = UserDefaultsInterfaceLanguageStore(defaults: defaults)

        #expect(store.preference == .system)
    }
}
```

- [x] **Step 2: Run tests and confirm failure**

Run:

```bash
swift test --package-path Packages/LangoTraceCore --filter InterfaceLanguagePreferenceStoreTests
```

Expected: FAIL because `UserDefaultsInterfaceLanguageStore` does not exist yet.

- [x] **Step 3: Add the store**

Create `InterfaceLanguagePreferenceStore.swift`:

```swift
import Foundation

public protocol InterfaceLanguagePreferenceStore: AnyObject, Sendable {
    var preference: InterfaceLanguagePreference { get set }
}

public final class UserDefaultsInterfaceLanguageStore: InterfaceLanguagePreferenceStore, @unchecked Sendable {
    public static let storageKey = "interfaceLanguagePreference"

    private let defaults: UserDefaults

    public var preference: InterfaceLanguagePreference {
        get {
            InterfaceLanguagePreference(
                storageValue: defaults.string(forKey: Self.storageKey) ?? InterfaceLanguagePreference.system.storageValue
            )
        }
        set {
            defaults.set(newValue.storageValue, forKey: Self.storageKey)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}
```

- [x] **Step 4: Run Core tests**

Run:

```bash
swift test --package-path Packages/LangoTraceCore
```

Expected: PASS.

## Task 3: App Shell Locale Injection

**Files:**

- Modify: `LangoTraceApp/LangoTraceApp.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`

- [x] **Step 1: Add app-level state**

In `LangoTraceApp`, create a `UserDefaultsInterfaceLanguageStore` and store the current preference in `@State`. Do not initialize the `let` property inline if it is assigned inside `init`:

```swift
private let interfaceLanguagePreferenceStore: UserDefaultsInterfaceLanguageStore
@State private var interfaceLanguagePreference: InterfaceLanguagePreference
```

Initialize the state from the store in `init`:

```swift
init() {
    let store = UserDefaultsInterfaceLanguageStore()
    self.interfaceLanguagePreferenceStore = store
    self._interfaceLanguagePreference = State(initialValue: store.preference)
}
```

- [x] **Step 2: Inject locale into the root view**

Resolve the language from `Locale.preferredLanguages` and inject it:

```swift
let resolvedLanguageCode = interfaceLanguagePreference.resolvedLanguageCode(
    systemLanguageCodes: Locale.preferredLanguages
)

LangoTraceRootView(...)
    .environment(\.locale, Locale(identifier: resolvedLanguageCode))
```

Priority rule:

- `.system` reads the platform preference list. This is the mode that should reflect system language and system per-app language where the platform exposes it through language preferences.
- `.english` and `.simplifiedChinese` are App-internal overrides for LangoTrace-owned SwiftUI chrome only.
- Do not describe this as changing the system App language, and do not expect it to localize system permission prompts, StoreKit sheets, file pickers, share sheets, keyboard UI or third-party SDK UI.

- [x] **Step 3: Pass preference update into UI**

Extend `LangoTraceRootView` with:

```swift
let interfaceLanguagePreference: InterfaceLanguagePreference
let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
```

Call the handler from settings UI in a later task. In the app shell, persist and update state:

```swift
onInterfaceLanguagePreferenceChange: { preference in
    interfaceLanguagePreferenceStore.preference = preference
    interfaceLanguagePreference = preference
}
```

If a user changes system per-app language while the App is already running, first-stage behavior may require app restart or scene reactivation. Record this as a platform boundary in settings copy rather than building a custom system-settings observer.

- [x] **Step 4: Run app target build smoke**

Run:

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: BUILD SUCCEEDED.

## Task 4: Localize Core App Chrome Views

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PadWorkspaceBar.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`

- [x] **Step 1: Replace iPhone tab literals**

Use String Catalog keys for tab labels. Prefer label builders so `Text` can load from `Bundle.module`:

```swift
.tabItem {
    Label {
        Text("tab.today", bundle: .module)
    } icon: {
        Image(systemName: "sun.max")
    }
}
```

Add equivalent keys:

- `tab.today`
- `tab.entries`
- `tab.practice`
- `tab.memory`
- `tab.settings`

- [x] **Step 2: Replace Welcome chrome text**

Migrate badges and explanatory text. Prefer changing reusable components to accept `LocalizedStringKey` or `@ViewBuilder` label content when they are App chrome, instead of converting everything to eager `String` values:

```swift
CapsuleLabel(systemImage: "lock") {
    Text("app.badge.localFirst", bundle: .module)
}
CapsuleLabel(systemImage: "sparkle.magnifyingglass") {
    Text("app.badge.aiNotConfigured", bundle: .module)
}
```

If a component must keep a `String` parameter because it also displays user content, add a separate localized initializer or wrapper. Do not route user content through String Catalog keys.

Add keys:

- `welcome.headline`
- `welcome.subtitle`
- `app.badge.localFirst`
- `app.badge.aiNotConfigured`

- [x] **Step 3: Replace Onboarding chrome text**

Migrate only labels and explanations. Preserve target language values from `LearningLanguage`:

```swift
Text("onboarding.title", bundle: .module)
Text("onboarding.subtitle", bundle: .module)
Picker(selection: $draft.level) {
    ...
} label: {
    Text("onboarding.level.title", bundle: .module)
}
```

Add keys:

- `onboarding.eyebrow`
- `onboarding.title`
- `onboarding.subtitle`
- `onboarding.level.title`
- `onboarding.level.summary`
- `onboarding.privacy.localStorage`
- `onboarding.privacy.noExternalAI`
- `onboarding.createSpace`

- [x] **Step 4: Replace shared status and unavailable text**

Migrate common status labels:

- `common.cancel`
- `common.save`
- `common.close`
- `common.next`
- `common.newEntry`
- `common.unavailable.nextRequirement`
- `common.unavailable.noSideEffects`
- `requestPreview.title`
- `requestPreview.localMock`
- `requestPreview.notSent`

Also migrate Data-backed App chrome at the UI boundary:

- Map `CapabilityStatus.ready/mockOnly/unavailable` to UI-localized status labels.
- Map `SettingsCapability.Kind` to UI-localized titles in settings lists and detail headers.
- Keep `SettingsCapability.summary/detail/nextRequirement` as temporary implementation inputs only when they still describe mock state; do not treat them as the long-term source for UI copy.

Examples that need explicit builder conversion:

```swift
Button {
    dismiss()
} label: {
    Text("common.cancel", bundle: .module)
}

Label {
    Text("requestPreview.title", bundle: .module)
} icon: {
    Image(systemName: "eye")
}

.navigationTitle(Text("entryDetail.title", bundle: .module))
```

- [x] **Step 5: Run UI tests**

Run:

```bash
swift test --package-path Packages/LangoTraceUI
```

Expected: PASS.

## Task 5: Interactive Interface Language Settings

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- Test: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

- [x] **Step 1: Add settings detail view input**

Thread these values into settings detail rendering:

```swift
let interfaceLanguagePreference: InterfaceLanguagePreference
let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
```

- [x] **Step 2: Render Picker for interface language**

When `capability.kind == .interfaceLanguage`, render:

```swift
Picker(selection: Binding(
        get: { interfaceLanguagePreference },
        set: onInterfaceLanguagePreferenceChange
    )
) {
    ForEach(InterfaceLanguagePreference.allCases) { preference in
        Text(interfaceLanguagePreferenceTitleKey(for: preference), bundle: .module)
            .tag(preference)
    }
} label: {
    Text("settings.interfaceLanguage.title", bundle: .module)
}
```

Keep String Catalog keys in the UI layer instead of adding UI resource keys to Core. Add a small helper near the settings detail view:

```swift
private func interfaceLanguagePreferenceTitleKey(
    for preference: InterfaceLanguagePreference
) -> LocalizedStringKey {
    switch preference {
    case .system:
        "settings.interfaceLanguage.system"
    case .english:
        "settings.interfaceLanguage.english"
    case .simplifiedChinese:
        "settings.interfaceLanguage.zhHans"
    }
}
```

Use it in the Picker:

```swift
Text(interfaceLanguagePreferenceTitleKey(for: preference), bundle: .module)
    .tag(preference)
```

- [x] **Step 3: Add boundary explanation**

Show localized explanatory text:

- `settings.interfaceLanguage.explanation`
- `settings.interfaceLanguage.systemBoundary`
- `settings.interfaceLanguage.contentBoundary`

The copy must make these boundaries explicit:

- `System` follows system language or the system per-app language chosen for LangoTrace.
- `English` and `简体中文` are LangoTrace App-internal overrides for App chrome.
- This setting does not change native language, target language, language spaces, saved content, generated content, Provider output, system permission prompts, StoreKit sheets or file picker UI.

- [x] **Step 4: Add UI state tests**

Extend UI tests to confirm the settings capability still exists and route identity is stable:

```swift
#expect(SettingsCapability.Kind.allCases.contains(.interfaceLanguage))
#expect(SettingsCapability.Kind.interfaceLanguage.rawValue == "interfaceLanguage")
```

Add a focused route/state assertion around the settings detail where feasible: selecting interface language must not change the selected language space preview or the settings route identity.

- [x] **Step 5: Run Data and UI tests**

Run:

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

Expected: PASS.

## Task 6: Documentation, Visual Verification, and Final Gate

**Files:**

- Modify: `docs/testing/README.md`
- Create or update: `docs/review/rounds/2026-05-17-string-catalog-interface-language-settings/README.md`
- Modify if implementation differs: `docs/spec/006-interface-localization-and-language-boundaries.md`
- Modify if layout rules change: `docs/spec/003-ui-design-system.md`
- Modify: `docs/worklogs/2026-05-17-feature-string-catalog-interface-language-settings.md`

- [x] **Step 1: Update testing docs**

Add a section named `String Catalog 与界面语言设置验证清单` with these required rows:

```text
iPhone 17 / English / Welcome + Onboarding + Settings / pass or issue link
iPhone 17 / 简体中文 / Welcome + Onboarding + Settings / pass or issue link
iPad Pro 13-inch (M5) / English / sidebar + workspace + settings / pass or issue link
iPad Pro 13-inch (M5) / 简体中文 / sidebar + workspace + settings / pass or issue link
macOS arm64 / English / sidebar + toolbar + inspector / pass or issue link
macOS arm64 / 简体中文 / sidebar + toolbar + inspector / pass or issue link
```

- [x] **Step 2: Run complete verification**

Run:

```bash
scripts/verify.sh
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
```

Expected:

- `scripts/verify.sh` exits 0.
- `git diff --check` has no output.
- Placeholder scan has no output.

- [x] **Step 3: Record visual verification**

Record screenshot/device results in the worklog. If a simulator cannot be launched, record the exact command failure and remaining risk instead of marking the visual check complete.

- [x] **Step 4: Update worklog status**

After all tests and visual checks pass, update:

```text
状态：Verified
```

Record actual commands, pass/fail results, and any deferred localization strings.

- [x] **Step 5: Commit**

Use one focused commit:

```bash
git add LangoTraceApp Packages docs project.yml scripts LangoTrace.xcodeproj
git commit -m "feat: add interface localization settings loop"
```
