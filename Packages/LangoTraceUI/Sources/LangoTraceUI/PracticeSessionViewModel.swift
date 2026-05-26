import Foundation
import LangoTraceCore

@MainActor
final class PracticeSessionViewModel: ObservableObject {
    private let languageSpaceID: String
    private let snapshot: PracticeSentenceSnapshot
    private let actions: PracticeActions
    private let playDemoAction: @MainActor @Sendable () async -> SentenceAudioPresentationState
    private let stopDemoAction: @MainActor @Sendable () async -> Void

    @Published private(set) var session: PracticeSession?
    @Published private(set) var isLoading = false
    @Published private(set) var isRecording = false
    @Published private(set) var isPlayingDemo = false
    @Published private(set) var isPlayingRecording = false
    @Published private(set) var activeRecordingID: String?
    @Published private(set) var failure: PracticeActionFailure?

    private var isDemoTapInFlight = false

    var visibleFailure: PracticeActionFailure? {
        guard failure != .missingReadyRecording else {
            return nil
        }
        return failure
    }

    init(
        languageSpaceID: String,
        snapshot: PracticeSentenceSnapshot,
        actions: PracticeActions,
        playDemo: @escaping @MainActor @Sendable () async -> SentenceAudioPresentationState = { .idle },
        stopDemo: @escaping @MainActor @Sendable () async -> Void = {}
    ) {
        self.languageSpaceID = languageSpaceID
        self.snapshot = snapshot
        self.actions = actions
        playDemoAction = playDemo
        stopDemoAction = stopDemo
    }

    func load() async {
        guard session == nil else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            session = try await actions.createOrRestoreShadowingSession(languageSpaceID, snapshot)
            failure = nil
        } catch {
            failure = .missingSession
        }
    }

    func startRecording() async {
        guard !isPlayingDemo, !isPlayingRecording else {
            failure = .audioBusy
            return
        }
        await stopDemoAction()
        guard let session else {
            failure = .missingSession
            return
        }
        do {
            let start = try await actions.startRecording(session)
            self.session = start.session
            activeRecordingID = start.recordingID
            isRecording = true
            failure = nil
        } catch {
            failure = .disabled
        }
    }

    func stopRecording() async {
        guard let session else {
            failure = .missingSession
            return
        }
        guard let activeRecordingID else {
            failure = .missingReadyRecording
            return
        }
        do {
            self.session = try await actions.stopRecording(session, activeRecordingID)
            self.activeRecordingID = nil
            isRecording = false
            failure = nil
        } catch {
            self.activeRecordingID = nil
            failure = .recordingUnavailable
            isRecording = false
        }
    }

    func completeLatestRecording() async {
        guard let session else {
            failure = .missingSession
            return
        }
        guard let recordingID = session.latestReadyRecordingID else {
            failure = .missingReadyRecording
            return
        }
        do {
            self.session = try await actions.complete(session, recordingID)
            failure = nil
        } catch {
            failure = .missingReadyRecording
        }
    }

    func playDemo() async {
        guard !isRecording, !isPlayingRecording else {
            failure = .audioBusy
            return
        }
        guard !isDemoTapInFlight else {
            failure = .audioBusy
            return
        }
        isDemoTapInFlight = true
        defer { isDemoTapInFlight = false }
        let state = await playDemoAction()
        switch state {
        case .failed:
            failure = .playbackUnavailable
        default:
            failure = nil
        }
    }

    func stopDemoPlayback() async {
        await stopDemoAction()
        isPlayingDemo = false
    }

    func playLatestRecording() async {
        guard !isRecording, !isPlayingDemo else {
            failure = .audioBusy
            return
        }
        guard let session else {
            failure = .missingSession
            return
        }
        guard let recordingID = session.latestReadyRecordingID else {
            failure = .missingReadyRecording
            return
        }
        isPlayingRecording = true
        defer { isPlayingRecording = false }
        do {
            try await actions.playRecording(session, recordingID)
            failure = nil
        } catch {
            failure = .playbackUnavailable
        }
    }
}
