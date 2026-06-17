import Foundation

public enum GuidanceChipKind: String, CaseIterable, Hashable, Sendable {
    case describeScene
    case recordFeelings

    var titleKey: String {
        switch self {
        case .describeScene: "photoWriting.chip.describeScene"
        case .recordFeelings: "photoWriting.chip.recordFeelings"
        }
    }

    var hintKey: String {
        switch self {
        case .describeScene: "photoWriting.chip.describeScene.hint"
        case .recordFeelings: "photoWriting.chip.recordFeelings.hint"
        }
    }
}

/// Presentation state for the photo writing compose flow.
/// Guidance chip selection does NOT write to draftText — chips are prompts only.
public struct PhotoWritingDraftState: Equatable, Sendable {
    public var draftText: String
    public var activeGuidanceChip: GuidanceChipKind?

    public init(draftText: String = "", activeGuidanceChip: GuidanceChipKind? = nil) {
        self.draftText = draftText
        self.activeGuidanceChip = activeGuidanceChip
    }

    public mutating func selectGuidanceChip(_ chip: GuidanceChipKind) {
        if activeGuidanceChip == chip {
            activeGuidanceChip = nil
        } else {
            activeGuidanceChip = chip
        }
        // draftText is explicitly NOT modified — chips are hint prompts, not writers.
    }

    public func isSaveEnabled(hasPhoto: Bool) -> Bool {
        hasPhoto && !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
