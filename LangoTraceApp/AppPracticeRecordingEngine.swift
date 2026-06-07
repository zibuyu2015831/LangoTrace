import AVFoundation
import CryptoKit
import Foundation
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech

actor AppPracticeRecordingEngine: PracticeRecordingEngine {
    private let fileStore: LocalMediaArtifactFileStore
    private var activeRecorder: AVAudioRecorder?
    private var activeURL: URL?

    init(fileStore: LocalMediaArtifactFileStore) {
        self.fileStore = fileStore
    }

    func requestPermission() async -> PracticeMicrophonePermission {
        #if os(iOS)
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                let granted = await AVAudioApplication.requestRecordPermission()
                return granted ? .authorized : .denied
            @unknown default:
                return .unavailable
            }
        #elseif os(macOS)
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                return .authorized
            case .denied:
                return .denied
            case .restricted:
                return .restricted
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                return granted ? .authorized : .denied
            @unknown default:
                return .unavailable
            }
        #else
            return .unavailable
        #endif
    }

    func start(_ request: PracticeRecordingStartRequest) async throws {
        let url = try fileStore.absoluteURLForInternalUse(relativePath: request.stagingRelativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        #endif
        let recorder = try AVAudioRecorder(url: url, settings: recordingSettings)
        recorder.isMeteringEnabled = false
        guard recorder.record() else {
            throw PracticeRecordingFailure.startFailed
        }
        activeRecorder = recorder
        activeURL = url
    }

    func stop(recordingID _: String) async throws -> PracticeRecordingEngineStopResult {
        guard let recorder = activeRecorder, let activeURL else {
            throw PracticeRecordingFailure.noActiveRecording
        }
        recorder.stop()
        activeRecorder = nil
        self.activeURL = nil
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        let data = try Data(contentsOf: activeURL)
        return PracticeRecordingEngineStopResult(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: "staging/\(activeURL.lastPathComponent)",
                byteSize: Int64(data.count),
                contentHash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            ),
            durationSeconds: recorder.currentTime,
            byteSize: Int64(data.count),
            contentHash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        )
    }

    func cancel(recordingID _: String) async {
        activeRecorder?.stop()
        activeRecorder = nil
        if let activeURL {
            try? FileManager.default.removeItem(at: activeURL)
        }
        activeURL = nil
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
    }
}
