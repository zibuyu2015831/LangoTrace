import LangoTraceCore
import LangoTraceData
import SwiftUI

/// Synchronous seam that supplies the real "will-send" projection for an entry's
/// learning-material generation. App Shell backs it with the loaded default
/// provider profile; when no provider is configured it returns `nil` and the
/// preview falls back to the explicit local-draft copy (no fabricated promise).
public struct AIRequestPreviewActions: Sendable {
    public var projection: @Sendable (_ entry: LearningEntry) -> AIRequestPreviewProjection?

    public init(projection: @escaping @Sendable (LearningEntry) -> AIRequestPreviewProjection?) {
        self.projection = projection
    }

    public static let disabled = AIRequestPreviewActions(projection: { _ in nil })
}

public extension EnvironmentValues {
    @Entry var aiRequestPreviewActions = AIRequestPreviewActions.disabled
}

/// Presentation model for `RequestPreviewCard`.
///
/// Built from the real `AIRequestPreviewProjection` when generation is
/// configured, so what the card shows is what is sent. Renders only
/// non-sensitive descriptors — service, model, a size bucket, and the
/// included content *categories* — never any content. Excluded categories and
/// the privacy footer reuse the existing `requestPreview.notSent` copy.
struct RequestPreviewCardModel: Equatable {
    enum State: Equatable {
        /// A real outbound projection (online generation configured).
        case projected(provider: String, model: String, lengthLabel: String, includedLabels: [String])
        /// Online generation not configured / not enabled for this entry.
        case offline
        /// Local draft (mock rendering) — keeps the existing Local Mock copy.
        case localDraft(body: String)
    }

    let state: State

    init(projection: AIRequestPreviewProjection?, entry: LearningEntry, rendering: LearningRendering?) {
        if rendering?.isMock == true {
            state = .localDraft(
                body: RequestPreviewCopy.localMock(entryTitle: entry.title, promptLabel: rendering?.promptLabel).body
            )
            return
        }
        if let projection {
            state = .projected(
                provider: projection.providerPresetID ?? localizedString("requestPreview.field.provider"),
                model: projection.modelName ?? "—",
                lengthLabel: Self.lengthLabel(projection.lengthBucket),
                includedLabels: projection.includedContent.map(Self.label(for:))
            )
        } else {
            state = .offline
        }
    }

    static func lengthLabel(_ bucket: AIRequestLengthBucket) -> String {
        switch bucket {
        case .short: localizedString("requestPreview.length.short")
        case .medium: localizedString("requestPreview.length.medium")
        case .long: localizedString("requestPreview.length.long")
        }
    }

    /// Localized label for an *included* content descriptor. Excluded categories
    /// are surfaced via the shared `requestPreview.notSent` copy, not here.
    static func label(for descriptor: AIRequestContentDescriptor) -> String {
        switch descriptor {
        case .currentEntryBody: localizedString("requestPreview.content.currentEntryBody")
        case .currentLearningText: localizedString("requestPreview.content.currentLearningText")
        case .selectedReadingPassage: localizedString("requestPreview.content.selectedReadingPassage")
        case .readingContextWindow: localizedString("requestPreview.content.readingContextWindow")
        case .practiceAttempt: localizedString("requestPreview.content.practiceAttempt")
        case .backtranslationReferenceSentence: localizedString("requestPreview.content.backtranslationReferenceSentence")
        case .nativeLanguageProfile: localizedString("requestPreview.content.nativeLanguageProfile")
        case .targetLanguageProfile: localizedString("requestPreview.content.targetLanguageProfile")
        case .proficiencyLevel: localizedString("requestPreview.content.proficiencyLevel")
        case .companionConversation: localizedString("requestPreview.content.companionConversation")
        case .curatedLearnerMemory: localizedString("requestPreview.content.curatedLearnerMemory")
        case .historicalEntries, .photoAttachments, .audioRecordings,
             .longTermMemory, .apiCredential, .otherLanguageSpaces:
            // Excluded categories are never rendered as "included"; surfaced via
            // the shared not-sent copy instead.
            ""
        }
    }

    /// Localized label for an *excluded* descriptor when a preview wants to
    /// explicitly reassure the user a category is NOT sent (LM03-S2b-1 companion
    /// preview). Distinct from `label(for:)`'s included path, which keeps
    /// `.longTermMemory` empty: here the raw full memory store is disclosed as
    /// not-sent alongside the curated subset that is.
    static func excludedDisclosureLabel(for descriptor: AIRequestContentDescriptor) -> String {
        switch descriptor {
        case .longTermMemory: localizedString("requestPreview.notSent.longTermMemory")
        case .photoAttachments: localizedString("requestPreview.notSent.photoAttachments")
        case .audioRecordings: localizedString("requestPreview.notSent.audioRecordings")
        default: ""
        }
    }
}
