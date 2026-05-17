public protocol SyncService: Sendable {}

public struct DisabledSyncService: SyncService {
    public init() {}
}
