# Language Space Persistence And Startup Restore Implementation Plan

状态：Shelved

> 2026-05-17：本计划暂时搁置。用户确认当前优先级调整为先补齐 iPad 和 macOS 页面闭环，再做整体设计优化，之后再进入功能开发和细节优化。恢复本计划前必须重新复查当时的三端页面结构、文档状态和启动状态边界。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist the first language space locally and restore it on startup without turning UI preview state into the long-term storage schema.

**Architecture:** Store a dedicated `StoredLanguageSpace` snapshot with schema version, language codes, level, creation date and a single-space MVP identifier. `LanguageSpaceRepository` owns save / restore / clear behavior and maps valid stored snapshots into `LanguageSpacePreview`; `AppSessionState` only consumes that repository and enters Main after a save succeeds. UserDefaults is a temporary local startup bridge before SQLite / GRDB, not a formal language-space database.

**Tech Stack:** Swift 6, SwiftUI Multiplatform, Swift Testing, UserDefaults, XcodeGen verification through `scripts/verify.sh`.

---

## Task 1: Stored Language Space Snapshot

**Files:**

- Create: `Packages/LangoTraceCore/Sources/LangoTraceCore/StoredLanguageSpace.swift`
- Modify: `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageLevel.swift`
- Modify: `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LaunchFlowTests.swift`

- [ ] Add failing Core tests for snapshot creation, preview mapping and invalid stored data.

Add these tests to `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LaunchFlowTests.swift`:

```swift
@Test("Stored language space maps onboarding preview without storing UI-only fields")
func storedLanguageSpaceMapsToPreview() throws {
    let draft = OnboardingDraft(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1
    )

    let stored = StoredLanguageSpace(draft: draft, createdAt: Date(timeIntervalSince1970: 1_776_000_000))
    let preview = try #require(stored.makePreview())

    #expect(stored.schemaVersion == 1)
    #expect(stored.id == "en")
    #expect(stored.nativeLanguageCode == "zh-Hans")
    #expect(stored.targetLanguageCode == "en")
    #expect(stored.level == .b1)
    #expect(stored.createdAt == Date(timeIntervalSince1970: 1_776_000_000))
    #expect(preview.id == "en")
    #expect(preview.name == "英语空间")
    #expect(preview.displayContext == "中文 -> 英语 · B1")
}

@Test("Stored language space rejects unsupported versions and invalid language pairs")
func storedLanguageSpaceRejectsInvalidSnapshots() {
    let unsupportedVersion = StoredLanguageSpace(
        schemaVersion: 2,
        id: "en",
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1,
        createdAt: Date(timeIntervalSince1970: 1_776_000_000)
    )
    #expect(unsupportedVersion.makePreview() == nil)

    let sameLanguage = StoredLanguageSpace(
        schemaVersion: 1,
        id: "en",
        nativeLanguageCode: "en",
        targetLanguageCode: "en",
        level: .b1,
        createdAt: Date(timeIntervalSince1970: 1_776_000_000)
    )
    #expect(sameLanguage.makePreview() == nil)

    let mismatchedID = StoredLanguageSpace(
        schemaVersion: 1,
        id: "ja",
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1,
        createdAt: Date(timeIntervalSince1970: 1_776_000_000)
    )
    #expect(mismatchedID.makePreview() == nil)
}
```

- [ ] Run the focused Core tests and confirm they fail because `StoredLanguageSpace` does not exist.

Run:

```bash
swift test --package-path Packages/LangoTraceCore --filter Stored
```

Expected result: FAIL with missing `StoredLanguageSpace`.

- [ ] Make `LanguageLevel` codable.

Change `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageLevel.swift` to:

```swift
public enum LanguageLevel: String, CaseIterable, Codable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
}
```

- [ ] Add the stored snapshot model.

Create `Packages/LangoTraceCore/Sources/LangoTraceCore/StoredLanguageSpace.swift`:

```swift
import Foundation

public struct StoredLanguageSpace: Codable, Equatable, Sendable, Identifiable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public let nativeLanguageCode: String
    public let targetLanguageCode: String
    public let level: LanguageLevel
    public let createdAt: Date

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        id: String,
        nativeLanguageCode: String,
        targetLanguageCode: String,
        level: LanguageLevel,
        createdAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.level = level
        self.createdAt = createdAt
    }

    public init(draft: OnboardingDraft, createdAt: Date = Date()) {
        let normalizedDraft = draft.normalized()
        self.init(
            id: normalizedDraft.targetLanguageCode,
            nativeLanguageCode: normalizedDraft.nativeLanguageCode,
            targetLanguageCode: normalizedDraft.targetLanguageCode,
            level: normalizedDraft.level,
            createdAt: createdAt
        )
    }

    public func makePreview() -> LanguageSpacePreview? {
        guard schemaVersion == Self.currentSchemaVersion,
              id == targetLanguageCode,
              nativeLanguageCode != targetLanguageCode,
              let nativeLanguage = LearningLanguage.find(code: nativeLanguageCode),
              let targetLanguage = LearningLanguage.find(code: targetLanguageCode)
        else {
            return nil
        }

        return LanguageSpacePreview(
            id: id,
            name: targetLanguage.spaceNameForChineseUI,
            nativeLanguage: nativeLanguage.zhHansName,
            targetLanguage: targetLanguage.zhHansName,
            level: level
        )
    }
}
```

- [ ] Run Core tests.

Run:

```bash
swift test --package-path Packages/LangoTraceCore
```

Expected result: PASS.

## Task 2: Language Space Repository Contract

**Files:**

- Modify: `Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift`
- Create: `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`

- [ ] Add failing Data tests for in-memory repository restore, save and clear.

Create `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`:

```swift
import Foundation
import LangoTraceCore
import Testing
@testable import LangoTraceData

@Test("In-memory language space repository starts empty then saves and clears")
func inMemoryLanguageSpaceRepositoryStartsEmptyThenSavesAndClears() throws {
    let repository = InMemoryLanguageSpaceRepository()
    #expect(repository.currentLanguageSpace() == nil)

    let stored = StoredLanguageSpace(
        id: "en",
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1,
        createdAt: Date(timeIntervalSince1970: 1_776_000_000)
    )

    try repository.saveCurrentLanguageSpace(stored)
    #expect(repository.currentLanguageSpace() == stored.makePreview())

    repository.clearCurrentLanguageSpace()
    #expect(repository.currentLanguageSpace() == nil)
}
```

- [ ] Run the focused Data test and confirm it fails because the protocol and repository do not exist yet.

Run:

```bash
swift test --package-path Packages/LangoTraceData --filter inMemoryLanguageSpaceRepositoryStartsEmptyThenSavesAndClears
```

Expected result: FAIL with missing `InMemoryLanguageSpaceRepository` or missing protocol methods.

- [ ] Replace the empty repository protocol with a throwing contract and in-memory implementation.

Replace `Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift` with:

```swift
import Foundation
import LangoTraceCore

public protocol LanguageSpaceRepository: Sendable {
    func currentLanguageSpace() -> LanguageSpacePreview?
    func saveCurrentLanguageSpace(_ space: StoredLanguageSpace) throws
    func clearCurrentLanguageSpace()
}

public final class InMemoryLanguageSpaceRepository: LanguageSpaceRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storedSpace: StoredLanguageSpace?

    public init(initialSpace: StoredLanguageSpace? = nil) {
        self.storedSpace = initialSpace
    }

    public func currentLanguageSpace() -> LanguageSpacePreview? {
        lock.withLock {
            storedSpace?.makePreview()
        }
    }

    public func saveCurrentLanguageSpace(_ space: StoredLanguageSpace) throws {
        lock.withLock {
            storedSpace = space
        }
    }

    public func clearCurrentLanguageSpace() {
        lock.withLock {
            storedSpace = nil
        }
    }
}

public struct EmptyLanguageSpaceRepository: LanguageSpaceRepository {
    public init() {}

    public func currentLanguageSpace() -> LanguageSpacePreview? {
        nil
    }

    public func saveCurrentLanguageSpace(_ space: StoredLanguageSpace) throws {}

    public func clearCurrentLanguageSpace() {}
}
```

- [ ] Run Data tests.

Run:

```bash
swift test --package-path Packages/LangoTraceData
```

Expected result: PASS.

## Task 3: UserDefaults Startup Repository

**Files:**

- Modify: `Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift`
- Modify: `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`

- [ ] Add failing tests for UserDefaults restore, clear, corrupted data fallback and invalid snapshot fallback.

Append these tests to `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`:

```swift
@Test("UserDefaults language space repository restores saved snapshots")
func userDefaultsLanguageSpaceRepositoryRestoresSavedSpace() throws {
    let suiteName = "LangoTraceTests.LanguageSpaceRepository.restore"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let repository = UserDefaultsLanguageSpaceRepository(userDefaults: defaults)
    let stored = StoredLanguageSpace(
        id: "ja",
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "ja",
        level: .a2,
        createdAt: Date(timeIntervalSince1970: 1_776_000_000)
    )

    try repository.saveCurrentLanguageSpace(stored)

    let restoredRepository = UserDefaultsLanguageSpaceRepository(userDefaults: defaults)
    #expect(restoredRepository.currentLanguageSpace() == stored.makePreview())

    restoredRepository.clearCurrentLanguageSpace()
    #expect(restoredRepository.currentLanguageSpace() == nil)
}

@Test("UserDefaults language space repository returns nil for corrupted data")
func userDefaultsLanguageSpaceRepositoryReturnsNilForCorruptedData() throws {
    let suiteName = "LangoTraceTests.LanguageSpaceRepository.corrupted"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set(Data("not-json".utf8), forKey: UserDefaultsLanguageSpaceRepository.currentLanguageSpaceKey)

    let repository = UserDefaultsLanguageSpaceRepository(userDefaults: defaults)

    #expect(repository.currentLanguageSpace() == nil)
}

@Test("UserDefaults language space repository returns nil for semantically invalid snapshots")
func userDefaultsLanguageSpaceRepositoryReturnsNilForInvalidSnapshot() throws {
    let suiteName = "LangoTraceTests.LanguageSpaceRepository.invalid"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let invalidStoredSpace = StoredLanguageSpace(
        schemaVersion: 1,
        id: "en",
        nativeLanguageCode: "en",
        targetLanguageCode: "en",
        level: .b1,
        createdAt: Date(timeIntervalSince1970: 1_776_000_000)
    )
    let data = try JSONEncoder().encode(invalidStoredSpace)
    defaults.set(data, forKey: UserDefaultsLanguageSpaceRepository.currentLanguageSpaceKey)

    let repository = UserDefaultsLanguageSpaceRepository(userDefaults: defaults)

    #expect(repository.currentLanguageSpace() == nil)
}
```

- [ ] Run the focused Data tests and confirm they fail because the UserDefaults repository does not exist.

Run:

```bash
swift test --package-path Packages/LangoTraceData --filter UserDefaultsLanguageSpaceRepository
```

Expected result: FAIL with missing `UserDefaultsLanguageSpaceRepository`.

- [ ] Add the UserDefaults-backed implementation.

Append to `Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift`:

```swift
public final class UserDefaultsLanguageSpaceRepository: LanguageSpaceRepository, @unchecked Sendable {
    public static let currentLanguageSpaceKey = "com.zibuyu.LangoTrace.currentLanguageSpace.v1"

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    public func currentLanguageSpace() -> LanguageSpacePreview? {
        guard let data = userDefaults.data(forKey: Self.currentLanguageSpaceKey),
              let storedSpace = try? decoder.decode(StoredLanguageSpace.self, from: data)
        else {
            return nil
        }

        return storedSpace.makePreview()
    }

    public func saveCurrentLanguageSpace(_ space: StoredLanguageSpace) throws {
        guard space.makePreview() != nil else {
            throw LanguageSpaceRepositoryError.invalidStoredLanguageSpace
        }

        let data = try encoder.encode(space)
        userDefaults.set(data, forKey: Self.currentLanguageSpaceKey)
    }

    public func clearCurrentLanguageSpace() {
        userDefaults.removeObject(forKey: Self.currentLanguageSpaceKey)
    }
}

public enum LanguageSpaceRepositoryError: Error, Equatable, Sendable {
    case invalidStoredLanguageSpace
}
```

- [ ] Run Data tests.

Run:

```bash
swift test --package-path Packages/LangoTraceData
```

Expected result: PASS.

## Task 4: App Session Restore And Save Failure

**Files:**

- Modify: `project.yml`
- Create: `LangoTraceApp/AppSessionState.swift`
- Modify: `LangoTraceApp/AppEnvironment.swift`
- Modify: `LangoTraceApp/LangoTraceApp.swift`
- Create: `LangoTraceAppTests/AppSessionStateTests.swift`

- [ ] Add an app test target for startup session behavior.

Add this target to `project.yml` under `targets`:

```yaml
  LangoTraceAppTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "18.0"
    sources:
      - path: LangoTraceAppTests
    dependencies:
      - target: LangoTrace-iOS
      - package: LangoTraceCore
        product: LangoTraceCore
      - package: LangoTraceData
        product: LangoTraceData
      - package: LangoTraceUI
        product: LangoTraceUI
```

Add this test target to the `LangoTrace-iOS` scheme test section:

```yaml
    test:
      config: Debug
      gatherCoverageData: true
      targets:
        - LangoTraceAppTests
```

- [ ] Move `AppSessionState` into a focused file before changing behavior.

Create `LangoTraceApp/AppSessionState.swift` with the existing `AppSessionState` and `LaunchRoute.appPhase` extension from `LangoTraceApp/AppEnvironment.swift`. Keep imports:

```swift
import LangoTraceCore
import LangoTraceData
import LangoTraceUI
import SwiftUI
```

Remove the moved `AppSessionState` and private `LaunchRoute` extension from `LangoTraceApp/AppEnvironment.swift`.

- [ ] Add failing App session tests for restore, create and save failure.

Create `LangoTraceAppTests/AppSessionStateTests.swift`:

```swift
import LangoTraceCore
import LangoTraceData
import Testing
@testable import LangoTrace

private final class FailingLanguageSpaceRepository: LanguageSpaceRepository, @unchecked Sendable {
    func currentLanguageSpace() -> LanguageSpacePreview? {
        nil
    }

    func saveCurrentLanguageSpace(_ space: StoredLanguageSpace) throws {
        throw LanguageSpaceRepositoryError.invalidStoredLanguageSpace
    }

    func clearCurrentLanguageSpace() {}
}

@MainActor
@Test("App session restores language space from repository before welcome completes")
func appSessionRestoresLanguageSpaceFromRepository() {
    let stored = StoredLanguageSpace(
        id: "en",
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1,
        createdAt: Date(timeIntervalSince1970: 1_776_000_000)
    )
    let repository = InMemoryLanguageSpaceRepository(initialSpace: stored)
    let session = AppSessionState(languageSpaceRepository: repository)

    #expect(session.currentLanguageSpace == stored.makePreview())

    session.completeWelcome()

    #expect(session.phase == .main)
}

@MainActor
@Test("App session saves language space before entering main")
func appSessionSavesLanguageSpaceBeforeEnteringMain() {
    let repository = InMemoryLanguageSpaceRepository()
    let session = AppSessionState(languageSpaceRepository: repository)

    session.createLanguageSpace()

    #expect(session.phase == .main)
    #expect(session.currentLanguageSpace == repository.currentLanguageSpace())
    #expect(session.sessionErrorMessage == nil)
}

@MainActor
@Test("App session stays in onboarding when saving language space fails")
func appSessionStaysInOnboardingWhenSaveFails() {
    let session = AppSessionState(languageSpaceRepository: FailingLanguageSpaceRepository())

    session.createLanguageSpace()

    #expect(session.phase == .onboarding)
    #expect(session.currentLanguageSpace == nil)
    #expect(session.sessionErrorMessage == "语言空间保存失败，请重试。")
}
```

- [ ] Run the app test target and confirm it fails before the AppSessionState initializer changes.

Run:

```bash
xcodegen generate
xcodebuild test -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LangoTraceAppTests
```

Expected result: FAIL because `AppSessionState` does not yet accept a `LanguageSpaceRepository`.

- [ ] Update `AppEnvironment.bootstrap()` to use the local startup repository.

In `LangoTraceApp/AppEnvironment.swift`, change:

```swift
languageSpaceRepository: EmptyLanguageSpaceRepository(),
```

to:

```swift
languageSpaceRepository: UserDefaultsLanguageSpaceRepository(),
```

- [ ] Inject the repository into `AppSessionState` and make save failure visible.

Replace `LangoTraceApp/AppSessionState.swift` contents with:

```swift
import LangoTraceCore
import LangoTraceData
import LangoTraceUI
import SwiftUI

@MainActor
final class AppSessionState: ObservableObject {
    @Published var phase: LangoTraceAppPhase = .welcome
    @Published var onboardingDraft = OnboardingDraft()
    @Published private(set) var currentLanguageSpace: LanguageSpacePreview?
    @Published private(set) var sessionErrorMessage: String?

    private let languageSpaceRepository: any LanguageSpaceRepository

    init(languageSpaceRepository: any LanguageSpaceRepository) {
        self.languageSpaceRepository = languageSpaceRepository
        self.currentLanguageSpace = languageSpaceRepository.currentLanguageSpace()
    }

    func completeWelcome() {
        phase = LaunchRoute.route(hasLanguageSpace: currentLanguageSpace != nil).appPhase
    }

    func createLanguageSpace() {
        let storedSpace = StoredLanguageSpace(draft: onboardingDraft)

        do {
            try languageSpaceRepository.saveCurrentLanguageSpace(storedSpace)
            currentLanguageSpace = storedSpace.makePreview()
            sessionErrorMessage = nil
            phase = .main
        } catch {
            sessionErrorMessage = "语言空间保存失败，请重试。"
            phase = .onboarding
        }
    }
}

private extension LaunchRoute {
    var appPhase: LangoTraceAppPhase {
        switch self {
        case .onboarding:
            .onboarding
        case .main:
            .main
        }
    }
}
```

- [ ] Update `LangoTraceApp` to initialize session after environment is available.

Replace the stored properties and initializer in `LangoTraceApp/LangoTraceApp.swift` with:

```swift
@main
struct LangoTraceApp: App {
    private let environment: AppEnvironment
    @StateObject private var session: AppSessionState

    init() {
        let environment = AppEnvironment.bootstrap()
        self.environment = environment
        _session = StateObject(
            wrappedValue: AppSessionState(
                languageSpaceRepository: environment.languageSpaceRepository
            )
        )
    }
```

Keep the existing `body` unchanged after these stored properties and `init()`.

- [ ] Build the app targets.

Run:

```bash
xcodegen generate
xcodebuild test -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LangoTraceAppTests
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
```

Expected result: app tests pass and both builds succeed.

## Task 5: Root View Main Boundary

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/LaunchViewTests.swift`

- [ ] Create a UI route test proving Main without a language space resolves to onboarding.

Create `Packages/LangoTraceUI/Tests/LangoTraceUITests/LaunchViewTests.swift`:

```swift
@testable import LangoTraceUI
import Testing

@Test("Root view resolves main without language space back to onboarding")
func rootViewResolvesMainWithoutLanguageSpaceToOnboarding() {
    #expect(
        LangoTraceRootView.resolvedPhase(
            requestedPhase: .main,
            hasLanguageSpace: false
        ) == .onboarding
    )
}

@Test("Root view resolves main with language space to main")
func rootViewResolvesMainWithLanguageSpaceToMain() {
    #expect(
        LangoTraceRootView.resolvedPhase(
            requestedPhase: .main,
            hasLanguageSpace: true
        ) == .main
    )
}
```

- [ ] Run the UI route test and confirm it fails because `resolvedPhase` does not exist.

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter rootViewResolvesMain
```

Expected result: FAIL with missing `LangoTraceRootView.resolvedPhase`.

- [ ] Add the route helper.

Add this internal static helper to `LangoTraceRootView`:

```swift
static func resolvedPhase(
    requestedPhase: LangoTraceAppPhase,
    hasLanguageSpace: Bool
) -> LangoTraceAppPhase {
    switch requestedPhase {
    case .welcome:
        .welcome
    case .onboarding:
        .onboarding
    case .main:
        switch LaunchRoute.route(requestedPhase: .main, hasLanguageSpace: hasLanguageSpace) {
        case .onboarding:
            .onboarding
        case .main:
            .main
        }
    }
}
```

Then update `effectivePhase` to call:

```swift
Self.resolvedPhase(requestedPhase: phase, hasLanguageSpace: languageSpace != nil)
```

- [ ] Replace the implicit main fallback.

Change the `.main` branch in `LangoTraceRootView.body` from:

```swift
PlatformMainView(
    languageSpace: languageSpace ?? onboardingDraft.makeLanguageSpacePreview(),
    learningContentRepository: learningContentRepository
)
```

to:

```swift
if let languageSpace {
    PlatformMainView(
        languageSpace: languageSpace,
        learningContentRepository: learningContentRepository
    )
} else {
    OnboardingView(
        draft: $onboardingDraft,
        onCreateLanguageSpace: onCreateLanguageSpace
    )
}
```

- [ ] Run UI package tests.

Run:

```bash
swift test --package-path Packages/LangoTraceUI
```

Expected result: PASS.

## Task 6: Documentation And Review Record

**Files:**

- Modify: `docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md`
- Modify: `docs/README.md`
- Modify: `docs/spec/002-navigation-and-routing.md`
- Modify: `docs/spec/004-swiftui-architecture.md`
- Modify: `docs/testing/README.md`
- Modify: `docs/review/INDEX.md`
- Create: `docs/review/rounds/2026-05-17-language-space-startup-restore.md`

- [ ] Update `docs/README.md` project status.

Required completed-state wording after implementation:

```markdown
- 首个语言空间的轻量本地保存和启动恢复。
```

Required remaining-work wording:

```markdown
- 正式语言空间数据模型、SQLite / GRDB Repository、迁移和多空间管理。
```

- [ ] Update navigation and SwiftUI architecture guidelines.

Record these rules:

```markdown
- Welcome 完成后必须通过已恢复的当前语言空间判断进入 Main 还是 Onboarding。
- App 不应默认创建语言空间；没有本地保存空间、保存数据不可读或保存数据语义无效时，仍进入 Onboarding。
- Main 页面不得自行从 onboarding draft 生成 fallback 语言空间。
- `AppSessionState` 可以持有当前语言空间状态，但读取和保存必须通过 `LanguageSpaceRepository`。
- UserDefaults-backed repository 只是启动恢复的早期桥接，不是长期主存储。
- 当前 `StoredLanguageSpace.id == targetLanguageCode` 只是单空间 MVP 临时策略，多空间阶段必须引入真正唯一的 Space ID。
```

- [ ] Update `docs/testing/README.md`.

Add this manual regression checklist:

```markdown
### 首次启动与语言空间恢复

- 清空 App 数据后首次启动，点击 Welcome 后进入 Onboarding。
- 完成 Onboarding 创建英语空间后进入 Main。
- 终止并重启 App，点击 Welcome 后直接进入 Main。
- 恢复后的语言空间名称、目标语言和水平与创建时一致。
- 损坏、缺失、不兼容版本或语义无效的本地语言空间数据时，App 不 crash，并回到 Onboarding。
- 语言空间本地保存只包含语言 code、水平、创建时间和临时空间 ID，不包含生活记录正文、照片、音频、API Key、AI 请求日志或同步配置。
```

- [ ] Create the专项审查记录 and update the index.

`docs/review/rounds/2026-05-17-language-space-startup-restore.md` must record:

```markdown
# 文档专项审查：语言空间持久化与启动恢复

日期：2026-05-17

触发原因：

- 首次启动闭环。
- 语言空间闭环。
- App 启动结构变化。

审查结论：

- 当前实现只完成首个语言空间的轻量本地保存和启动恢复。
- 当前实现没有引入 SQLite / GRDB、同步、账号、Keychain、AI Provider 或权限请求。
- 当前 UserDefaults 保存的是 `StoredLanguageSpace` 快照，不是 `LanguageSpacePreview` UI 投影。
- 长期数据主存储仍应通过 SQLite / GRDB Repository 设计，不以 UserDefaults 作为正式数据层。
- 当前 `StoredLanguageSpace.id == targetLanguageCode` 只适用于单空间 MVP，多空间阶段必须替换为真正唯一的 Space ID。
```

- [ ] Update the worklog implementation and verification sections with actual commands and results.

## Task 7: Final Verification

**Files:**

- Verify only unless failures require targeted fixes.

- [ ] Run focused package tests.

Run:

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
xcodebuild test -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LangoTraceAppTests
```

Expected result: PASS.

- [ ] Run documentation checks.

Run:

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
```

Expected result: file list prints, placeholder scan has no matches, diff check passes.

- [ ] Run full verification.

Run:

```bash
scripts/verify.sh
```

Expected result: PASS, including XcodeGen, Core / UI tests, iPhone build, iPad build, macOS build, SwiftLint, SwiftFormat and documentation placeholder scan.

- [ ] Manual smoke test with simulator when build verification is green.

Use iPhone 17 Simulator:

1. Clear installed app data.
2. Launch the app.
3. Tap through Welcome.
4. Complete onboarding with default Chinese -> English B1.
5. Confirm Main shows `英语空间` and `中文 -> 英语 · B1`.
6. Terminate and relaunch the app.
7. Tap through Welcome.
8. Confirm the app enters Main without showing onboarding again.

- [ ] Commit after verification passes.

Run:

```bash
git status --short
git add project.yml Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageLevel.swift Packages/LangoTraceCore/Sources/LangoTraceCore/StoredLanguageSpace.swift Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LaunchFlowTests.swift Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/LaunchViewTests.swift LangoTraceApp/AppEnvironment.swift LangoTraceApp/AppSessionState.swift LangoTraceApp/LangoTraceApp.swift LangoTraceAppTests/AppSessionStateTests.swift docs/README.md docs/spec/002-navigation-and-routing.md docs/spec/004-swiftui-architecture.md docs/testing/README.md docs/review/INDEX.md docs/review/rounds/2026-05-17-language-space-startup-restore.md docs/plans/active/2026-05-17-feature-language-space-persistence-startup-restore.md docs/archive/superpowers/plans/2026-05-17-language-space-persistence-startup-restore.md
git commit -m "Persist language space startup state"
```
