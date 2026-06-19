/// Steps in a shadowing (跟读) practice session.
///
/// Currently hard-coded for shadowing only. E3 (practice mode routing) will
/// make steps dynamic per exercise type and add dictation / back-translation steps.
public enum PracticeSessionStep: String, CaseIterable, Equatable, Hashable, Sendable {
    case prepare
    case shadow
    case compare
    case completed

    public var title: String {
        rawValue
    }
}

public struct PracticeSessionState: Equatable, Sendable {
    public let entryID: String
    public let providerLabel: String
    public let isExternalRequestRequired: Bool
    public let steps: [PracticeSessionStep]
    public let targetText: String

    public var isLocalOnly: Bool {
        !isExternalRequestRequired
    }

    public init(
        entryID: String,
        providerLabel: String,
        isExternalRequestRequired: Bool,
        steps: [PracticeSessionStep],
        targetText: String
    ) {
        self.entryID = entryID
        self.providerLabel = providerLabel
        self.isExternalRequestRequired = isExternalRequestRequired
        self.steps = steps
        self.targetText = targetText
    }

    public func nextStep(after step: PracticeSessionStep) -> PracticeSessionStep {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else {
            return step
        }

        return steps[index + 1]
    }
}
