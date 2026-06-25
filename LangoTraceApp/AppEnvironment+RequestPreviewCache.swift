import Foundation
import LangoTraceCore

/// Thread-safe holder for the cached default text-generation endpoint that backs
/// the synchronous preview-card projection seam (mirrors the locked-box pattern
/// E0a adopted over `nonisolated(unsafe) static var`).
final class AIRequestPreviewEndpointCache: @unchecked Sendable {
    private let lock = NSLock()
    private var endpoint: AIProviderEndpointInput?

    func set(_ endpoint: AIProviderEndpointInput?) {
        lock.lock()
        defer { lock.unlock() }
        self.endpoint = endpoint
    }

    func current() -> AIProviderEndpointInput? {
        lock.lock()
        defer { lock.unlock() }
        return endpoint
    }
}
