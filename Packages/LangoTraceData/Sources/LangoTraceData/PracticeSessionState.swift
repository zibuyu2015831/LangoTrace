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
        !isExternalRequestRequired && providerLabel == "Local Mock"
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
