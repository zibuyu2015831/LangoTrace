public struct ReadingLibrarySearchQuery: Equatable, Hashable, Sendable {
    public static let maxLength = 128

    public var normalized: String

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        normalized = String(trimmed.prefix(Self.maxLength))
    }
}
