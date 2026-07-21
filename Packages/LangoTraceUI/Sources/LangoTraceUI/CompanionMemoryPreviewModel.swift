import LangoTraceCore

/// Presentation model for the companion Memory-injection **one-time** consent
/// preview (LM03-S2b-1). Built from the real `companionConversation` projection,
/// so what the card shows is what is sent.
///
/// Unlike `RequestPreviewCardModel` (which is bound to a `LearningEntry` and only
/// renders included labels + a static footer), this renders BOTH the included
/// categories — including `.curatedLearnerMemory` — AND a few explicit excluded
/// disclosures (`.longTermMemory` first), so the user honestly sees "sends: the
/// curated, scrubbed subset" alongside "does not send: your full memory store".
struct CompanionMemoryPreviewModel: Equatable {
    /// Localized labels for the content categories that WILL be sent.
    let includedLabels: [String]
    /// Localized reassurances for notable categories that will NOT be sent.
    let excludedLabels: [String]
    let provider: String
    let model: String

    init(projection: AIRequestPreviewProjection) {
        includedLabels = projection.includedContent
            .map(RequestPreviewCardModel.label(for:))
            .filter { !$0.isEmpty }
        // Disclose the headline reassurances (full memory store, photos, audio).
        excludedLabels = [
            AIRequestContentDescriptor.longTermMemory,
            .photoAttachments,
            .audioRecordings,
        ]
        .filter { projection.excludedContent.contains($0) }
        .map(RequestPreviewCardModel.excludedDisclosureLabel(for:))
        .filter { !$0.isEmpty }
        provider = projection.providerPresetID ?? localizedString("requestPreview.field.provider")
        model = projection.modelName ?? "—"
    }
}
