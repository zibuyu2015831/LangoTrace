public protocol SpeechService: Sendable {}

public struct DisabledSpeechService: SpeechService {
    public init() {}
}
