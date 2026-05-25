import Foundation
import LangoTraceCore

@MainActor
final class PracticeSessionViewModel: ObservableObject {
    private let languageSpaceID: String
    private let snapshot: PracticeSentenceSnapshot
    private let actions: PracticeActions

    @Published private(set) var session: PracticeSession?
    @Published private(set) var isLoading = false
    @Published private(set) var isRecording = false
    @Published private(set) var activeRecordingID: String?
    @Published private(set) var failure: PracticeActionFailure?

    init(
        languageSpaceID: String,
        snapshot: PracticeSentenceSnapshot,
        actions: PracticeActions
    ) {
        self.languageSpaceID = languageSpaceID
        self.snapshot = snapshot
        self.actions = actions
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
            failure = .missingReadyRecording
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
}
