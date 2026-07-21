import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

/// Covers the E6 preview-card + request-log presentation models. The preview
/// renders the real projection when generation is configured, keeps the local
/// draft copy for mock renderings, and shows an explicit offline state when no
/// projection is available (never a fabricated "will send" promise). The log
/// row model is content-free.
@Suite("AI request preview card + log row models")
struct RequestPreviewCardTests {
    private func makeEntry() -> LearningEntry {
        LearningEntry(
            id: "e1",
            spaceID: "s1",
            title: "Coffee",
            body: "今天我去了咖啡馆。",
            source: .typedText,
            scene: "生活",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func makeRendering(isMock: Bool) -> LearningRendering {
        LearningRendering(
            id: "m1",
            entryID: "e1",
            targetText: "Learning text",
            promptLabel: "prompt",
            providerLabel: "gpt-4o",
            isMock: isMock,
            sourceEntryBodyHash: "hash",
            sentences: []
        )
    }

    private func projection() -> AIRequestPreviewProjection {
        AIRequestPreviewProjection(
            capability: .learningMaterialGeneration,
            providerPresetID: "openai",
            modelName: "gpt-4.1-mini",
            promptID: "builtin.learning_material",
            promptVersion: "1",
            lengthBucket: .medium,
            includedContent: [.currentEntryBody],
            excludedContent: [.apiCredential, .photoAttachments]
        )
    }

    @Test("a real projection renders provider, model and included content categories")
    func realProjectionRendersFields() {
        let model = RequestPreviewCardModel(projection: projection(), entry: makeEntry(), rendering: makeRendering(isMock: false))
        guard case let .projected(provider, modelName, _, includedLabels) = model.state else {
            Issue.record("expected projected state")
            return
        }
        #expect(provider == "openai")
        #expect(modelName == "gpt-4.1-mini")
        #expect(includedLabels == [localizedString("requestPreview.content.currentEntryBody")])
    }

    @Test("curatedLearnerStyle descriptor renders its localized included label (LM03-S4a)")
    func curatedLearnerStyleHasIncludedLabel() {
        let label = RequestPreviewCardModel.label(for: .curatedLearnerStyle)
        #expect(label == localizedString("requestPreview.content.curatedLearnerStyle"))
        #expect(!label.isEmpty)
    }

    @Test("a mock rendering keeps the local draft copy")
    func mockRenderingKeepsLocalDraft() {
        let model = RequestPreviewCardModel(projection: projection(), entry: makeEntry(), rendering: makeRendering(isMock: true))
        guard case .localDraft = model.state else {
            Issue.record("expected local draft state")
            return
        }
    }

    @Test("no projection on a non-mock rendering shows the explicit offline state, not a fabricated promise")
    func noProjectionShowsOffline() {
        let model = RequestPreviewCardModel(projection: nil, entry: makeEntry(), rendering: makeRendering(isMock: false))
        #expect(model.state == .offline)
    }

    @Test("a failed log row carries a failure label, a successful one does not")
    func logRowFailureLabel() {
        let failed = AIRequestLogRowModel(entry: logEntry(status: .failed, failureBucket: .network))
        let success = AIRequestLogRowModel(entry: logEntry(status: .success, failureBucket: nil))
        #expect(failed.failureLabel == localizedString("aiRequestLog.failure.network"))
        #expect(failed.statusLabel == localizedString("aiRequestLog.status.failed"))
        #expect(success.failureLabel == nil)
    }

    @Test("log row capability label maps to user-facing copy")
    func logRowCapabilityLabel() {
        let row = AIRequestLogRowModel(entry: logEntry(status: .success, failureBucket: nil))
        #expect(row.capabilityLabel == localizedString("aiRequestLog.capability.learningMaterialGeneration"))
    }

    private func logEntry(status: AIRequestLogStatus, failureBucket: AIRequestLogFailureBucket?) -> AIRequestLogEntry {
        AIRequestLogEntry(
            id: "log-1",
            operationID: DiagnosticOperationID(rawValue: "op-1"),
            capability: .learningMaterialGeneration,
            providerPresetID: "openai",
            endpointPurpose: .textGeneration,
            adapterKind: .openAICompatibleChat,
            modelName: "gpt",
            promptID: "p",
            promptVersion: "1",
            inputLengthBucket: .short,
            status: status,
            failureBucket: failureBucket,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
