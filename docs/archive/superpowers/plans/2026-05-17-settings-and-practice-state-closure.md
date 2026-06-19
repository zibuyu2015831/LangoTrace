# Settings And Practice State Closure Implementation Plan

状态：Verified

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the second MVP UI closure layer: settings detail routes, explicit unavailable/mock states, and a credible local mock practice session.

**Architecture:** Keep all new behavior local and side-effect free. `LangoTraceData` owns pure value models for feature availability and practice session state; SwiftUI views render those models and update transient UI state only.

**Tech Stack:** Swift 6, SwiftUI Multiplatform, Swift Package tests, XcodeGen verification through `scripts/verify.sh`.

---

## Task 1: Pure State Models

**Files:**

- Modify: `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- Modify: `Packages/LangoTraceData/Tests/LangoTraceDataTests/InMemoryLearningContentRepositoryTests.swift`

- [x] Add failing tests for setting capability defaults and practice session step progression.
- [x] Add unit tests for complete settings detail data, unavailable practice sessions, and created-entry local-only sessions.
- [x] Add `CapabilityStatus`, `SettingsCapability`, `PracticeSessionStep` and `PracticeSessionState` pure value models.
- [x] Add explicit `PracticeSessionState.isLocalOnly` local-only semantics.
- [x] Add repository helpers returning default settings capabilities and a mock practice session for an entry.
- [x] Run `swift test --package-path Packages/LangoTraceData` and confirm the new tests pass.

## Task 2: Reusable UI State Components

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`

- [x] Add a `CapabilityStatusRow` component for settings and unavailable states.
- [x] Add a `PracticeControlBar` component for local mock practice actions.
- [x] Use existing design tokens and accessibility labels.
- [x] Run `swift test --package-path Packages/LangoTraceUI` after integration.

## Task 3: iPhone Settings Detail Routes

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`

- [x] Add `PhoneRoute.settings(SettingsCapability.Kind)` to `NavigationStack`.
- [x] Make Settings rows real navigation buttons.
- [x] Add `SettingsCapabilityDetailView` showing status, privacy boundary, and next implementation dependency.
- [x] Keep all routes read-only and local.

## Task 4: Mock Practice Session Flow

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`

- [x] Pass repository-provided `PracticeSessionState` into `PracticeSessionView`.
- [x] Add local step switching for prepare, shadow, compare, and completed.
- [x] Show unavailable state if no rendering exists.
- [x] Ensure no audio, recording, AI, or persistence side effects are triggered.

## Task 5: Documentation And Verification

**Files:**

- Modify: `docs/plans/done/2026-05-17-feature-settings-and-practice-state-closure.md`
- Modify: `docs/testing/README.md`
- Modify if needed: `docs/spec/002-navigation-and-routing.md`
- Modify if needed: `docs/spec/003-ui-design-system.md`
- Modify if needed: `docs/spec/004-swiftui-architecture.md`

- [x] Update docs with the implemented routes, UI states and manual verification checklist.
- [x] Run placeholder scan, whitespace check, focused tests and `scripts/verify.sh`.
- [x] Record verification results in the worklog.
