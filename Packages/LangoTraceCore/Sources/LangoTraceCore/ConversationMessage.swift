import Foundation

/// Role of a single turn in a multi-turn AI conversation. Stable raw values are
/// the wire identifiers OpenAI-compatible chat/completions and the Responses API
/// both expect (`system` / `user` / `assistant`).
///
/// Closed set on purpose: a multi-turn request carries only these three roles.
/// Tool / function roles are out of scope for the language-companion transport
/// seam this enabler builds.
public enum ConversationRole: String, Codable, CaseIterable, Equatable, Sendable {
    case system
    case user
    case assistant
}

/// A single ordered turn in a multi-turn AI conversation: a role plus its text
/// content.
///
/// Pure value type living in Core so the AI package can construct outbound
/// multi-turn request bodies and future LM03 (语伴) UI / session store can reuse
/// the exact same transcript model without redefining it. Carries no provider
/// credential, no projection metadata — just the positional role + content.
public struct ConversationMessage: Codable, Equatable, Sendable {
    public var role: ConversationRole
    public var content: String

    public init(role: ConversationRole, content: String) {
        self.role = role
        self.content = content
    }
}
