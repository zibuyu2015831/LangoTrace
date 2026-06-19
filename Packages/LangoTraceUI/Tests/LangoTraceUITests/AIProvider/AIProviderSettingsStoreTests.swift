import Foundation
@testable import LangoTraceUI
import Testing

@Suite("AIProviderSettingsStore")
@MainActor
struct AIProviderSettingsStoreTests {
    @Test("initial state is idle")
    func initialStateIsIdle() {
        let store = AIProviderSettingsStore()
        if case .idle = store.saveState {
            // pass
        } else {
            Issue.record("expected .idle saveState, got \(store.saveState)")
        }
        if case .idle = store.probeState {
            // pass
        } else {
            Issue.record("expected .idle probeState, got \(store.probeState)")
        }
    }

    @Test("probe failure maps to displayable probeState")
    func probeFailureMapsToDisplayableState() async {
        let store = AIProviderSettingsStore()
        await store.recordProbeFailure("Connection refused")
        if case let .failed(message) = store.probeState {
            #expect(!message.isEmpty)
        } else {
            Issue.record("expected .failed probeState after recordProbeFailure")
        }
    }

    @Test("probe success clears failure state")
    func probeSuccessClearsFailure() async {
        let store = AIProviderSettingsStore()
        await store.recordProbeFailure("error")
        await store.recordProbeSuccess()
        if case .success = store.probeState {
            // pass
        } else {
            Issue.record("expected .success probeState after recordProbeSuccess")
        }
    }

    @Test("save state transitions idle → saving → saved")
    func saveStateTransitionsCorrectly() async {
        let store = AIProviderSettingsStore()
        await store.beginSave()
        if case .saving = store.saveState { } else {
            Issue.record("expected .saving after beginSave")
        }
        await store.recordSaveSuccess()
        if case .saved = store.saveState { } else {
            Issue.record("expected .saved after recordSaveSuccess")
        }
    }

    @Test("save failure maps to displayable saveState")
    func saveFailureMapsToDisplayable() async {
        let store = AIProviderSettingsStore()
        await store.beginSave()
        await store.recordSaveFailure("Keychain error")
        if case let .failed(message) = store.saveState {
            #expect(!message.isEmpty)
        } else {
            Issue.record("expected .failed saveState after recordSaveFailure")
        }
    }
}
