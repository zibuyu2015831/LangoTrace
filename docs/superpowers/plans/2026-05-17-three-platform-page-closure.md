# Three Platform Page Closure Implementation Plan

状态：Completed

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the iPhone, iPad and macOS page map with mock / unavailable routes before visual redesign or real feature integration.

**Architecture:** Keep existing mock data and local-only behavior. Reuse page content views where possible, while preserving platform-specific shells: iPhone uses Tab + NavigationStack; iPad uses a three-column learning workspace; macOS uses Sidebar + main workspace + Inspector. New actions must route to a visible page, sheet or unavailable explanation and must not trigger real AI, storage, audio, photo, sync or export side effects.

**Tech Stack:** Swift 6, SwiftUI Multiplatform, LangoTraceUI, LangoTraceData mock repositories, Swift Package tests, simulator / desktop visual smoke through `scripts/verify.sh`.

---

## Architect and Interaction Review Addendum

This plan was re-reviewed from a systems architecture and Apple-platform interaction perspective before implementation. The implementation must satisfy these additional constraints:

- iPhone remains Tab + NavigationStack + Sheet. Empty actions must produce visible feedback, and no new gesture may interfere with the system back gesture.
- iPad regular width remains a workspace, not a stretched iPhone Tab. Compact width, Split View, Slide Over and Stage Manager must preserve readable main content by allowing timeline and learning panels to collapse.
- macOS must receive the same mock content repository from the app shell. `MacMainView` must not create its own repository or continue as a static skeleton.
- Route, section, sheet and filter state are transient UI state. They must not be persisted, synced, restored at launch, or added to `LanguageSpacePreview`.
- Shared views present entry, practice, settings and unavailable content. Platform shells own navigation, sheet presentation, sidebar selection, inspector content and window adaptation.
- Manual screenshots are required, but they do not replace unit tests for route/filter helper behavior.
- macOS menus, full command palette, multi-window workflows and final shortcut mapping are follow-up design tasks. This page-closure stage may expose visible placeholders only when they clearly say they are unavailable or planned.

## File Structure Map

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`: iPhone sheet routing for empty actions; keep iPhone-only navigation decisions here.
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`: iPad workspace route, sheet, filter and adaptive panel behavior.
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`: macOS section selection, route state, repository-backed mock pages and contextual inspector.
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`: app-shell dependency injection only; pass `learningContentRepository` into `MacMainView`.
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`: shared entry editor, entry detail, practice session, settings detail and unavailable capability views.
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`: shared timeline row, side item, request preview, capability row and practice controls.
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`: route/filter helper tests added by this plan.
- `docs/spec/002-navigation-and-routing.md`: page-closure routing rules.
- `docs/spec/003-ui-design-system.md`: mock/unavailable and pre-visual-upgrade design rules.
- `docs/spec/004-swiftui-architecture.md`: shared content versus platform shell boundaries.
- `docs/testing/README.md`: three-platform screenshot and manual smoke checklist.

## Task 1: Shared Page Content Inventory and Testable Helpers

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- Create: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

- [ ] Identify reusable content views that can be used by iPhone, iPad and macOS.

Current candidates:

- `EntryEditorView`
- `EntryDetailView`
- `PracticeSessionView`
- `SettingsCapabilityDetailView`
- `CapabilityStatusRow`
- `PracticeControlBar`
- `RequestPreviewCard`
- `TextPanel`

- [ ] Keep current view behavior unchanged while making access level and naming suitable for reuse inside the `LangoTraceUI` module.

Required boundary:

```swift
// These views can remain internal to the module.
// They do not need to become public until another package imports them.
```

- [ ] Add a reusable unavailable explanation view for empty actions.

Create a view in `PhoneMainSupportingViews.swift` or a new focused file if the file becomes too large:

```swift
struct UnavailableCapabilityView: View {
    let title: String
    let summary: String
    let nextRequirement: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CapabilityStatusRow(
                title: title,
                summary: summary,
                status: .unavailable,
                systemImage: systemImage,
                action: nil
            )
            TextPanel(title: "后续接入条件", text: nextRequirement)
            TextPanel(
                title: "不会发生",
                text: "当前不会访问照片、麦克风、网络、Keychain、真实数据库、同步服务或导出文件。"
            )
        }
        .padding(20)
        .langoPageBackground()
    }
}
```

- [ ] Add pure filter helpers for iPad timeline filtering.

Use a small module-internal helper so filter behavior can be tested without rendering SwiftUI:

```swift
enum PadFilter: String, CaseIterable, Equatable {
    case all
    case photoWriting
    case needsPractice
    case memorized

    var title: String {
        switch self {
        case .all:
            "全部记录"
        case .photoWriting:
            "照片写作"
        case .needsPractice:
            "待练习"
        case .memorized:
            "已入记忆"
        }
    }

    func includes(entry: LearningEntry, memoryItems: [MemoryItem]) -> Bool {
        switch self {
        case .all:
            true
        case .photoWriting:
            entry.source == .photoWriting
        case .needsPractice:
            entry.practiceSummary.contains("待") || entry.practiceSummary.contains("练习")
        case .memorized:
            memoryItems.contains { $0.entryID == entry.id }
        }
    }
}
```

- [ ] Add route/filter tests.

Create `PageClosureStateTests.swift`:

```swift
import LangoTraceData
import Testing
@testable import LangoTraceUI

@Suite("Page closure state")
struct PageClosureStateTests {
    @Test("Pad filters include the expected mock records")
    func padFiltersIncludeExpectedRecords() {
        let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
        let entries = repository.entries(for: "en")
        let memory = repository.memoryItems(for: "en")

        #expect(entries.filter { PadFilter.all.includes(entry: $0, memoryItems: memory) }.count == entries.count)
        #expect(entries.filter { PadFilter.photoWriting.includes(entry: $0, memoryItems: memory) }.allSatisfy { $0.source == .photoWriting })
        #expect(entries.filter { PadFilter.memorized.includes(entry: $0, memoryItems: memory) }.allSatisfy { entry in
            memory.contains { $0.entryID == entry.id }
        })
    }
}
```

- [ ] Run UI tests to ensure existing helpers and the new filter helper pass.

Run:

```bash
swift test --package-path Packages/LangoTraceUI
```

Expected result: PASS.

## Task 2: iPhone Empty Action Closure

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`

- [ ] Add a sheet enum case for unavailable actions.

Extend `PhoneSheet`:

```swift
private enum PhoneSheet: Identifiable {
    case entryEditor
    case unavailable(PhoneUnavailableAction)

    var id: String {
        switch self {
        case .entryEditor:
            "entry-editor"
        case let .unavailable(action):
            "unavailable-\(action.rawValue)"
        }
    }
}

private enum PhoneUnavailableAction: String {
    case photoWriting
    case listenOne
    case languageSwitcher
}
```

- [ ] Route iPhone empty actions to unavailable sheets.

Update `HeroActionCard` to accept three actions:

```swift
let onNewEntry: () -> Void
let onPhotoWriting: () -> Void
let onListenOne: () -> Void
```

Wire:

```swift
ActionChip(title: "写一句", systemImage: "pencil", action: onNewEntry)
ActionChip(title: "拍照", systemImage: "camera", action: onPhotoWriting)
ActionChip(title: "听一句", systemImage: "play", action: onListenOne)
```

Update `PhonePage` language-space toolbar button to accept an action and present `.unavailable(.languageSwitcher)`.

- [ ] Render unavailable sheets.

In `.sheet(item:)`, add:

```swift
case let .unavailable(action):
    UnavailableCapabilityView(
        title: action.title,
        summary: action.summary,
        nextRequirement: action.nextRequirement,
        systemImage: action.systemImage
    )
    .presentationDetents([.medium, .large])
```

Add computed properties on `PhoneUnavailableAction` for the three actions.

- [ ] Manual check target.

Verify iPhone action coverage:

- `写一句` still opens editor.
- `拍照` opens unavailable sheet.
- `听一句` opens unavailable sheet.
- language switcher opens unavailable sheet.

## Task 3: iPad Page Routes

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- Reuse: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`

- [ ] Add iPad route and sheet state.

Add near `PadMainView`:

```swift
private enum PadWorkspaceRoute: Equatable {
    case workspace
    case entryDetail(String)
    case practice(String)
    case settings(SettingsCapability.Kind)
}

private enum PadSheet: Identifiable {
    case entryEditor

    var id: String {
        switch self {
        case .entryEditor:
            "entry-editor"
        }
    }
}
```

Add state:

```swift
@State private var route: PadWorkspaceRoute = .workspace
@State private var presentedSheet: PadSheet?
@State private var activeFilter: PadFilter = .all
@State private var contentRevision = 0
```

Use the `PadFilter` helper from Task 1.

- [ ] Add iPad adaptive width behavior.

Read horizontal size class and allow the workspace to prioritize the main content when compact or narrow:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

private var shouldPreferSingleMainColumn: Bool {
    horizontalSizeClass == .compact
}
```

When `shouldPreferSingleMainColumn` is true, hide the learning panel by default on appear and keep the timeline user-toggleable. Do not remove access to filters or selected entry details.

- [ ] Make iPad filters interactive.

Replace static `FilterPill` usage with buttons that set `activeFilter`, update counts and filter the timeline entries.

Required filters:

- all records
- photo writing
- needs practice
- memorized

Each filter button must provide an accessibility value such as `当前选中` or `未选中`; active state cannot rely on color alone.

- [ ] Add iPad new-entry sheet.

Add a toolbar or sidebar button:

```swift
Button {
    presentedSheet = .entryEditor
} label: {
    Label("新建记录", systemImage: "plus")
}
```

Use `EntryEditorView` in `.sheet(item:)`, create an entry through `contentRepository.createEntry`, update selection, set route to `.entryDetail(entry.id)`.

- [ ] Route selected records to detail content.

When tapping a timeline row:

```swift
selectedEntryID = entry.id
contentRepository.selectEntry(id: entry.id, spaceID: languageSpace.id)
route = .entryDetail(entry.id)
```

Main workspace should switch:

```swift
switch route {
case .workspace:
    workspaceOverview
case let .entryDetail(entryID):
    iPadEntryDetail(entryID)
case let .practice(entryID):
    iPadPractice(entryID)
case let .settings(kind):
    iPadSettings(kind)
}
```

- [ ] Make iPad practice and settings reachable.

In record detail and learning panel:

- practice action sets `route = .practice(entry.id)`
- settings icons or footer action set `route = .settings(kind)`

Use `PracticeSessionView` and `SettingsCapabilityDetailView` for page content.

- [ ] Preserve iPad platform behavior.

Acceptance checks:

- regular width shows the workspace with available timeline and learning panel controls.
- compact width keeps the selected entry or active route readable.
- panel gestures and toggle buttons continue to respect Reduce Motion.
- no route, filter, panel or sheet state is written to `LanguageSpacePreview` or the repository.

- [ ] Run UI package tests.

Run:

```bash
swift test --package-path Packages/LangoTraceUI
```

Expected result: PASS.

## Task 4: macOS Page Routes

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- Reuse: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`

- [ ] Add macOS section selection.

Add:

```swift
private enum MacWorkspaceSection: Hashable {
    case today
    case entries
    case practice
    case memory
    case importExport
    case settings
}
```

Add state:

```swift
@State private var selectedSection: MacWorkspaceSection = .today
@State private var selectedEntryID: String?
@State private var route: MacWorkspaceRoute = .overview
@State private var isEntryEditorPresented = false
```

Add `MacWorkspaceRoute` for `.overview`, `.entryDetail(String)`, `.practice(String)`, `.settings(SettingsCapability.Kind)`, `.unavailable(String)`.

- [ ] Inject the mock repository into macOS from the app shell.

Change `MacMainView`:

```swift
struct MacMainView: View {
    let languageSpace: LanguageSpacePreview
    let contentRepository: InMemoryLearningContentRepository
}
```

Update `PlatformMainView`:

```swift
MacMainView(
    languageSpace: languageSpace,
    contentRepository: learningContentRepository
)
```

On appear, call `contentRepository.ensureSeeded(spaceID: languageSpace.id)` and initialize `selectedEntryID` from `selectedEntry(for:)`.

- [ ] Replace static sidebar items with selectable buttons.

Sidebar items:

- 今日
- 记录库
- 练习
- 词句记忆
- 导入导出
- 设置

Each updates `selectedSection` and resets `route = .overview`.

- [ ] Make `新建记录` open a mock editor sheet.

Use `EntryEditorView` in a sheet. On save, create entry through the mock repository once `MacMainView` accepts `contentRepository: InMemoryLearningContentRepository`.

If repository injection requires touching `LangoTraceRootView`, update `PlatformMainView` to pass `learningContentRepository` into `MacMainView`.

- [ ] Render macOS section content.

Required section behavior:

- today: selected record summary, request preview and new-entry action.
- entries: list of entries; selecting one opens entry detail.
- practice: list of practice items; selecting one opens `PracticeSessionView`.
- memory: memory items and vector-index unavailable explanation.
- importExport: unavailable explanation for batch import and export.
- settings: settings capability list and detail route.

Each section must show a visible empty or unavailable state when no entry or capability is selected. A blank main area is not acceptable.

- [ ] Make Inspector contextual.

Inspector content should reflect current section or route:

- entry detail: request preview and privacy boundary.
- practice: local-only practice state.
- settings: current capability boundary.
- import/export: unavailable side effects.
- overview: shortcuts and local-first status.

- [ ] Run macOS build through full verification later.

Do not add real menu commands in this task. Record this as design-optimization follow-up.

- [ ] Preserve macOS window and input behavior.

Acceptance checks:

- the window remains usable at the current collapsed minimum width of 680pt.
- sidebar and inspector can be hidden independently.
- section controls are keyboard-focusable standard SwiftUI controls or buttons.
- visible shortcut text does not claim a shortcut is implemented unless the command is actually wired.

## Task 5: Documentation

**Files:**

- Modify: `docs/worklogs/2026-05-17-feature-three-platform-page-closure.md`
- Modify: `docs/spec/002-navigation-and-routing.md`
- Modify: `docs/spec/003-ui-design-system.md`
- Modify: `docs/spec/004-swiftui-architecture.md`
- Modify: `docs/testing/README.md`

- [ ] Update navigation guidance.

Record:

```markdown
- 页面闭环阶段要求三端所有一级入口和明显按钮都必须有可见结果：真实页面、mock 页面、sheet、popover 或 unavailable 说明。
- iPad 不使用放大的 iPhone Tab；保留工作台三栏，通过中间主区和右侧学习面板承载详情、练习和设置。
- iPad 在 compact width、Split View、Slide Over 或 Stage Manager 窄窗口下，优先保护主内容可读性，辅助面板允许收起。
- macOS 不使用移动端 Tab；使用 Sidebar selection、主工作区和 Inspector 承载页面状态。
- macOS 菜单栏、Command Palette、多窗口和快捷键属于后续 Mac 设计优化阶段，页面闭环阶段不得写成已完成能力。
```

- [ ] Update UI design guidance.

Record:

```markdown
- 当前阶段先补齐页面结构和状态闭环，不做最终视觉升级。
- 视觉优化必须等三端页面地图完整后统一进行，避免局部页面先行美化造成风格分裂。
- 所有 mock / unavailable 页面必须清楚说明当前边界和不会发生的副作用。
- 筛选、Sidebar item、能力入口和 unavailable 入口必须有可访问名称、选中态或状态值，不能只靠颜色表达。
```

- [ ] Update SwiftUI architecture guidance.

Record:

```markdown
- 共享内容视图应尽量独立于 iPhone Tab、iPad 三栏和 macOS Sidebar 外壳。
- 平台外壳负责导航、sheet、selection 和 inspector；共享内容视图负责呈现记录、练习、设置和不可用状态。
- route、filter、section、sheet 和面板展开状态属于 transient UI state，不进入语言空间模型、数据库、同步 manifest 或启动恢复。
- macOS 必须由 App Shell 注入现有 mock repository，不能在 Mac view 内部重新创建内容仓库。
```

- [ ] Update testing checklist.

Add three-platform page closure manual checks for iPhone, iPad and macOS.

- [ ] Update worklog implementation and verification sections after implementation.

## Task 6: Verification

**Files:**

- Verify only unless failures require targeted fixes.

- [ ] Run UI package tests.

Run:

```bash
swift test --package-path Packages/LangoTraceUI
```

Expected result: PASS.

- [ ] Run docs checks.

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

Expected result: PASS.

- [ ] Manual visual smoke.

Capture or record evidence for:

- iPhone 17: all tabs, unavailable action sheets, settings detail, practice session.
- iPad Pro 13-inch: default three-column, filters, new-entry sheet, entry detail, practice, settings detail, collapsed panels.
- macOS: default window, sidebar section switching, entry detail, practice, memory, import/export unavailable, settings detail, collapsed Sidebar and Inspector.
