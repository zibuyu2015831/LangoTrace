import Foundation
import LangoTraceCore

/// Registry for the single photo-writing assist prompt (看图辅助写作). One prompt
/// id serves both output modes; `PhotoWritingAssistMode` selects between writing
/// suggestions and a native-language draft, and picks the matching strict
/// schema (see `PhotoWritingAssistService`).
///
/// Phase 0 pins only the id/version so the preview projection and request log
/// can reference a stable contract. Prompt rendering and the per-mode response
/// schema live alongside the service (Phase 1).
public enum PhotoWritingAssistPromptRegistry {
    public static let promptID = "builtin.photo_writing.assist.v1"
    public static let promptVersion = "1"
    public static let schemaVersion = "photo_writing_assist.v1"
}
