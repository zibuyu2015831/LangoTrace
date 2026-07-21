import Foundation

/// Preset scene tags for life-record entries.
///
/// The product model is "the language is the space, the scene is a tag"
/// (product main reference §8.1): work, daily life, travel, mood, meetings
/// and email organize entries inside a language space instead of splitting
/// spaces. The raw value is the canonical slug persisted into
/// `entries.scene`; UI layers project it to a localized label. An empty
/// stored scene means "untagged", and free-form scene text (for example
/// imported via the E10 plaintext package) is preserved verbatim.
public enum EntryScenePreset: String, CaseIterable, Equatable, Sendable {
    case daily
    case work
    case travel
    case mood
    case meeting
    case email
}
