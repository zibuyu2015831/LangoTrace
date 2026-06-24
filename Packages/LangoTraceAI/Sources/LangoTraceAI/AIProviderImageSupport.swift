import Foundation
import LangoTraceCore

/// Single source of truth for which adapter kinds can carry an inline image.
///
/// Both the configuration image probe (`AIProviderConfigurationProbeService`)
/// and the photo-writing assist service consult this so the two image paths
/// cannot drift apart (self-review P1-6). The switch is exhaustive on purpose:
/// adding a new adapter kind forces a deliberate decision here instead of
/// silently defaulting one path on and the other off.
enum AIProviderImageSupport {
    static func supportsInlineImage(_ adapterKind: AIProviderAdapterKind) -> Bool {
        switch adapterKind {
        case .openAICompatibleChat, .openAIResponses:
            true
        case .mimoCompatibleChat, .anthropicMessages, .geminiGenerateContent:
            false
        }
    }
}
