/// The app's sync entry point (E11). Promoted from an empty marker to a real
/// protocol: a sync service reports whether a channel is configured and can run
/// one synchronize pass. `DisabledSyncService` is the assembled default until a
/// real channel (e.g. the deferred iCloud/CloudKit adapter) is configured.
public protocol SyncService: Sendable {
    /// Whether a remote channel is configured. Off until iCloud (deferred) lands.
    var isEnabled: Bool { get }
    /// Runs one synchronize pass. No-op while disabled.
    func synchronize() async throws
}

public struct DisabledSyncService: SyncService {
    public init() {}
    public var isEnabled: Bool {
        false
    }

    public func synchronize() async throws {
        // No channel configured yet — the real iCloud/CloudKit adapter is a
        // deferred slice. Engine + conflict logic live in SyncEngine.swift.
    }
}
