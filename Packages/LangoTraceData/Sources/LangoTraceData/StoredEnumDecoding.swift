import Foundation
import LangoTraceCore

/// Utilities for decoding stored enum values from the database with diagnostic event emission
/// on unrecognized raw values, instead of silent fallback.
enum StoredEnumDecoding {
    /// Decode a `RawRepresentable` enum from a stored raw value string.
    /// When the raw value is unrecognized (init returns nil), emits a diagnostic event
    /// and falls back to the provided default value.
    ///
    /// - Parameters:
    ///   - type: The enum type to decode.
    ///   - rawValue: The stored raw value string.
    ///   - fallback: The default value to use when decoding fails.
    ///   - context: A description of the decoding context (e.g., "entries.source") for diagnostics.
    ///   - diagnosticLogger: The logger to emit fallback events to.
    ///   - clock: A clock function for event timestamps.
    /// - Returns: The decoded enum value, or the fallback if the raw value is unrecognized.
    static func decode<T: RawRepresentable>(
        _ type: T.Type,
        from rawValue: String,
        fallback: T,
        context: String,
        diagnosticLogger: any DiagnosticLogging,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) -> T where T.RawValue == String {
        if let value = T(rawValue: rawValue) {
            return value
        }
        let event = DiagnosticEvent(
            id: UUID().uuidString,
            name: .storedEnumDecodeFallback,
            domain: .dataStorage,
            level: .warning,
            outcome: .failed,
            attributes: [
                .enumTypeName(String(describing: type)),
                .rawValue(rawValue),
                .repositoryReadOperation(context),
            ],
            createdAt: clock()
        )
        Task { [diagnosticLogger] in
            await diagnosticLogger.record(event)
        }
        return fallback
    }
}
