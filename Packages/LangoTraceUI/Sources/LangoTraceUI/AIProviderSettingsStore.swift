import Foundation
import Observation

@MainActor
@Observable
final class AIProviderSettingsStore {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    enum ProbeState: Equatable {
        case idle
        case probing
        case success
        case failed(String)
    }

    private(set) var saveState: SaveState = .idle
    private(set) var probeState: ProbeState = .idle

    private var saveStatusClearTask: Task<Void, Never>?
    private var probeStatusClearTask: Task<Void, Never>?

    func beginSave() {
        saveStatusClearTask?.cancel()
        saveState = .saving
    }

    func recordSaveSuccess() {
        saveState = .saved
        saveStatusClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.saveState = .idle
        }
    }

    func recordSaveFailure(_ message: String) {
        saveState = .failed(message)
    }

    func beginProbe() {
        probeStatusClearTask?.cancel()
        probeState = .probing
    }

    func recordProbeSuccess() {
        probeState = .success
        probeStatusClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.probeState = .idle
        }
    }

    func recordProbeFailure(_ message: String) {
        probeState = .failed(message)
    }

    func resetSaveState() {
        saveStatusClearTask?.cancel()
        saveState = .idle
    }

    func resetProbeState() {
        probeStatusClearTask?.cancel()
        probeState = .idle
    }

    // MARK: - Draft-state auto-clear (view delegates timer ownership to store)

    private var draftSaveClearTask: Task<Void, Never>?
    private var draftTestClearTask: Task<Void, Never>?

    func scheduleDraftSaveClear(after delay: Duration, perform body: @escaping @MainActor () -> Void) {
        draftSaveClearTask?.cancel()
        draftSaveClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            body()
            self?.draftSaveClearTask = nil
        }
    }

    func cancelDraftSaveClear() {
        draftSaveClearTask?.cancel()
        draftSaveClearTask = nil
    }

    func scheduleDraftTestClear(after delay: Duration, perform body: @escaping @MainActor () -> Void) {
        draftTestClearTask?.cancel()
        draftTestClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            body()
            self?.draftTestClearTask = nil
        }
    }

    func cancelDraftTestClear() {
        draftTestClearTask?.cancel()
        draftTestClearTask = nil
    }

    func cancelAllDraftClears() {
        cancelDraftSaveClear()
        cancelDraftTestClear()
    }
}
