import SwiftUI

/// Vertical alignment of the shadowing session stage (the sentence Hero area).
enum PracticeShadowingStageAlignment: Equatable {
    case center
    case top
}

/// Layout intent for the shadowing practice session screen.
///
/// The screen is composed of a scrollable "stage" (sentence Hero + disclosures + any
/// visible failure) and a bottom-docked "control deck" (listen / playback / record plus
/// the in-record sentence navigation). This model captures the layout *decisions* so they
/// can be unit-tested without asserting on rendered geometry, mirroring `EntryDetailPhotoLayout`.
struct PracticeShadowingLayout: Equatable {
    /// Whether the bottom-docked control deck is rendered. Hidden when there is no session
    /// to act on (the stage shows a status row only).
    var rendersControlDeck: Bool

    /// How the stage content is anchored within the available height. Short content centers
    /// as a Hero; when a failure is visible it top-aligns so the message stays in view.
    var stageAlignment: PracticeShadowingStageAlignment

    static func resolve(hasSession: Bool, hasVisibleFailure: Bool) -> PracticeShadowingLayout {
        guard hasSession else {
            return PracticeShadowingLayout(rendersControlDeck: false, stageAlignment: .center)
        }
        return PracticeShadowingLayout(
            rendersControlDeck: true,
            stageAlignment: hasVisibleFailure ? .top : .center
        )
    }

    var stageFrameAlignment: Alignment {
        switch stageAlignment {
        case .center: .center
        case .top: .top
        }
    }
}

/// Measures the rendered height of the bottom-docked control deck so the stage can reserve
/// exactly the remaining viewport height (no hardcoded deck height).
struct PracticeControlDeckHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
