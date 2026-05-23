import Foundation
import LangoTraceCore

public struct SentenceAudioPlaybackActions: Sendable {
    public var handleTap: @Sendable (SentenceAudioRequest) async -> SentenceAudioPresentationState
    public var presentationState: @Sendable (SentenceAudioRequest) async -> SentenceAudioPresentationState

    public init(
        handleTap: @escaping @Sendable (SentenceAudioRequest) async -> SentenceAudioPresentationState,
        presentationState: @escaping @Sendable (SentenceAudioRequest) async -> SentenceAudioPresentationState
    ) {
        self.handleTap = handleTap
        self.presentationState = presentationState
    }

    public static let disabled = SentenceAudioPlaybackActions(
        handleTap: { _ in .requiresConfiguration(.notConfigured) },
        presentationState: { _ in .idle }
    )

    public static func coordinator(_ coordinator: SentenceAudioPlaybackCoordinator) -> SentenceAudioPlaybackActions {
        SentenceAudioPlaybackActions(
            handleTap: { request in
                do {
                    try await coordinator.handleTap(request)
                    return await coordinator.presentationState(for: request)
                } catch let failure as SentenceAudioPlaybackFailure {
                    return .failed(failure)
                } catch {
                    return .failed(.playbackFailed)
                }
            },
            presentationState: { request in
                await coordinator.presentationState(for: request)
            }
        )
    }
}
