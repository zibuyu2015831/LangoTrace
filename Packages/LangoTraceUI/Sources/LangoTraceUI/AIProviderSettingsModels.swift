import Foundation
import LangoTraceCore

enum AIProviderAdapterKind: String, CaseIterable, Equatable {
    case openAICompatibleChat
    case openAIResponses
    case anthropicMessages
    case geminiGenerateContent

    var title: String {
        switch self {
        case .openAICompatibleChat:
            "OpenAI-compatible Chat"
        case .openAIResponses:
            "OpenAI Responses"
        case .anthropicMessages:
            "Anthropic Messages"
        case .geminiGenerateContent:
            "Gemini generateContent"
        }
    }
}

struct AIProviderCapabilitySet: Equatable {
    let chat: Bool
    let embedding: Bool
    let tts: Bool
    let imageUnderstanding: Bool
    let speechRecognition: Bool
    let openAICompatible: Bool
    let customHeaders: Bool

    static let openAICompatibleText = AIProviderCapabilitySet(
        chat: true,
        embedding: false,
        tts: false,
        imageUnderstanding: false,
        speechRecognition: false,
        openAICompatible: true,
        customHeaders: false
    )

    static let openAI = AIProviderCapabilitySet(
        chat: true,
        embedding: true,
        tts: true,
        imageUnderstanding: true,
        speechRecognition: true,
        openAICompatible: true,
        customHeaders: false
    )

    static let custom = AIProviderCapabilitySet(
        chat: true,
        embedding: true,
        tts: true,
        imageUnderstanding: true,
        speechRecognition: false,
        openAICompatible: true,
        customHeaders: true
    )
}

enum AIProviderCapabilitySupport: Equatable {
    case supported
    case unsupported
    case modelDependent
    case adapterUnsupported
}

enum TTSFirstStageProbeAvailability: Equatable {
    case realProbe
    case futureCompatible
    case futureProviderSpecific
    case unsupported
}

struct AIProviderCapabilityPolicy: Equatable {
    var textGeneration: AIProviderCapabilitySupport
    var structuredJSON: AIProviderCapabilitySupport
    var imageInput: AIProviderCapabilitySupport
    var speechSynthesis: AIProviderCapabilitySupport
    var embedding: AIProviderCapabilitySupport
}

struct AIProviderAdapterCapabilityPolicy: Equatable {
    var canProbeText: Bool
    var canProbeStructuredJSON: Bool
    var canProbeImageInput: Bool
    var canProbeSpeechSynthesis: Bool
    var canProbeEmbedding: Bool
}

struct AIProviderCapabilityDecision: Equatable {
    var support: AIProviderCapabilitySupport
    var canToggle: Bool
    var canProbe: Bool
    var requiresUserAssertion: Bool
    var shouldPersistImageSupport: Bool
    var explanationKey: String
}

enum AIProviderEndpointCapabilityResolver {
    static func imageInputDecision(
        provider: AIProviderPreset,
        adapterKind: AIProviderAdapterKind,
        purpose: LangoTraceCore.AIProviderEndpointPurpose,
        modelName _: String
    ) -> AIProviderCapabilityDecision {
        guard purpose == .textGeneration else {
            return .unsupported("aiProviderSettings.capability.image.unsupportedProvider")
        }

        let providerSupport = provider.capabilityPolicy.imageInput
        let adapterCanProbe = adapterKind.capabilityPolicy.canProbeImageInput
        if !adapterCanProbe, providerSupport != .unsupported {
            return .adapterUnsupported("aiProviderSettings.capability.image.adapterUnsupported")
        }

        switch providerSupport {
        case .supported:
            return AIProviderCapabilityDecision(
                support: .supported,
                canToggle: true,
                canProbe: adapterCanProbe,
                requiresUserAssertion: false,
                shouldPersistImageSupport: adapterCanProbe,
                explanationKey: "aiProviderSettings.capability.image.supported"
            )
        case .modelDependent:
            return AIProviderCapabilityDecision(
                support: .modelDependent,
                canToggle: adapterCanProbe,
                canProbe: adapterCanProbe,
                requiresUserAssertion: true,
                shouldPersistImageSupport: adapterCanProbe,
                explanationKey: adapterCanProbe
                    ? "aiProviderSettings.capability.image.modelDependent"
                    : "aiProviderSettings.capability.image.adapterUnsupported"
            )
        case .unsupported:
            return .unsupported("aiProviderSettings.capability.image.unsupportedProvider")
        case .adapterUnsupported:
            return .adapterUnsupported("aiProviderSettings.capability.image.adapterUnsupported")
        }
    }

    static func embeddingDecision(
        provider: AIProviderPreset,
        adapterKind: AIProviderAdapterKind,
        purpose: LangoTraceCore.AIProviderEndpointPurpose,
        modelName _: String
    ) -> AIProviderCapabilityDecision {
        guard purpose == .embedding else {
            return .unsupported("aiProviderSettings.capability.embedding.unsupportedProvider")
        }
        guard provider.isFirstStageEmbeddingProbeProvider else {
            return .unsupported("aiProviderSettings.capability.embedding.unsupportedProvider")
        }

        let providerSupport = provider.capabilityPolicy.embedding
        let adapterCanProbe = adapterKind.capabilityPolicy.canProbeEmbedding
        if !adapterCanProbe, providerSupport != .unsupported {
            return .adapterUnsupported("aiProviderSettings.capability.embedding.adapterUnsupported")
        }

        switch providerSupport {
        case .supported:
            return AIProviderCapabilityDecision(
                support: .supported,
                canToggle: true,
                canProbe: adapterCanProbe,
                requiresUserAssertion: false,
                shouldPersistImageSupport: false,
                explanationKey: "aiProviderSettings.capability.embedding.supported"
            )
        case .modelDependent:
            return AIProviderCapabilityDecision(
                support: .modelDependent,
                canToggle: adapterCanProbe,
                canProbe: adapterCanProbe,
                requiresUserAssertion: true,
                shouldPersistImageSupport: false,
                explanationKey: adapterCanProbe
                    ? "aiProviderSettings.capability.embedding.modelDependent"
                    : "aiProviderSettings.capability.embedding.adapterUnsupported"
            )
        case .unsupported:
            return .unsupported("aiProviderSettings.capability.embedding.unsupportedProvider")
        case .adapterUnsupported:
            return .adapterUnsupported("aiProviderSettings.capability.embedding.adapterUnsupported")
        }
    }
}

private extension AIProviderCapabilityDecision {
    static func unsupported(_ explanationKey: String) -> AIProviderCapabilityDecision {
        AIProviderCapabilityDecision(
            support: .unsupported,
            canToggle: false,
            canProbe: false,
            requiresUserAssertion: false,
            shouldPersistImageSupport: false,
            explanationKey: explanationKey
        )
    }

    static func adapterUnsupported(_ explanationKey: String) -> AIProviderCapabilityDecision {
        AIProviderCapabilityDecision(
            support: .adapterUnsupported,
            canToggle: false,
            canProbe: false,
            requiresUserAssertion: false,
            shouldPersistImageSupport: false,
            explanationKey: explanationKey
        )
    }
}

enum AIProviderPreset: String, CaseIterable, Identifiable, Equatable {
    case openAI
    case anthropic
    case gemini
    case deepSeek
    case mistral
    case groq
    case xAI
    case moonshotKimi
    case openRouter
    case dashScopeQwen
    case zhipuGLM
    case siliconFlow
    case ollamaLocal
    case customOpenAICompatible

    var id: String {
        switch self {
        case .openAI:
            "openai"
        case .anthropic:
            "anthropic"
        case .gemini:
            "gemini"
        case .deepSeek:
            "deepseek"
        case .mistral:
            "mistral"
        case .groq:
            "groq"
        case .xAI:
            "xai"
        case .moonshotKimi:
            "moonshot-kimi"
        case .openRouter:
            "openrouter"
        case .dashScopeQwen:
            "dashscope-qwen"
        case .zhipuGLM:
            "zhipu-glm"
        case .siliconFlow:
            "siliconflow"
        case .ollamaLocal:
            "ollama-local"
        case .customOpenAICompatible:
            "custom-openai-compatible"
        }
    }

    var displayName: String {
        switch self {
        case .openAI:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .gemini:
            "Google Gemini"
        case .deepSeek:
            "DeepSeek"
        case .mistral:
            "Mistral"
        case .groq:
            "Groq"
        case .xAI:
            "xAI"
        case .moonshotKimi:
            "Moonshot / Kimi"
        case .openRouter:
            "OpenRouter"
        case .dashScopeQwen:
            "DashScope / Qwen"
        case .zhipuGLM:
            "Zhipu GLM"
        case .siliconFlow:
            "SiliconFlow"
        case .ollamaLocal:
            "Ollama / Local"
        case .customOpenAICompatible:
            "Custom OpenAI-compatible"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI:
            "https://api.openai.com/v1"
        case .anthropic:
            "https://api.anthropic.com/v1"
        case .gemini:
            "https://generativelanguage.googleapis.com/v1beta"
        case .deepSeek:
            "https://api.deepseek.com"
        case .mistral:
            "https://api.mistral.ai/v1"
        case .groq:
            "https://api.groq.com/openai/v1"
        case .xAI:
            "https://api.x.ai/v1"
        case .moonshotKimi:
            "https://api.moonshot.ai/v1"
        case .openRouter:
            "https://openrouter.ai/api/v1"
        case .dashScopeQwen:
            "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .zhipuGLM:
            "https://open.bigmodel.cn/api/paas/v4"
        case .siliconFlow:
            "https://api.siliconflow.com/v1"
        case .ollamaLocal:
            "http://localhost:11434/v1"
        case .customOpenAICompatible:
            "https://"
        }
    }

    var defaultChatModel: String {
        defaultTextModel
    }

    var defaultTextModel: String {
        switch self {
        case .openAI:
            "gpt-5.2"
        case .anthropic:
            "claude-sonnet-4-5"
        case .gemini:
            "gemini-2.5-flash"
        case .deepSeek:
            "deepseek-v4-flash"
        case .mistral:
            "mistral-small-latest"
        case .groq:
            "llama-3.3-70b-versatile"
        case .xAI:
            "grok-4.3"
        case .moonshotKimi:
            "kimi-k2.5"
        case .openRouter:
            "openai/gpt-5.2"
        case .dashScopeQwen:
            "qwen-plus"
        case .zhipuGLM:
            "glm-4.6"
        case .siliconFlow:
            "Qwen/Qwen3-32B"
        case .ollamaLocal:
            "llama3.2"
        case .customOpenAICompatible:
            ""
        }
    }

    var defaultEmbeddingModel: String {
        switch self {
        case .openAI:
            "text-embedding-3-small"
        case .openRouter:
            "openai/text-embedding-3-small"
        case .customOpenAICompatible:
            ""
        default:
            ""
        }
    }

    var defaultTTSModel: String {
        defaultSpeechModel
    }

    var defaultSpeechModel: String {
        switch self {
        case .openAI:
            "tts-1"
        case .openRouter:
            // OpenRouter has no /audio/speech endpoint; the default adapter is
            // the multimodal chat route, which needs an audio-capable chat model.
            "openai/gpt-audio-mini"
        default:
            ""
        }
    }

    var adapterKind: AIProviderAdapterKind {
        switch self {
        case .openAI:
            .openAIResponses
        case .anthropic:
            .anthropicMessages
        case .gemini:
            .geminiGenerateContent
        default:
            .openAICompatibleChat
        }
    }

    var authHeaderKind: String {
        switch self {
        case .anthropic:
            "x-api-key"
        case .gemini:
            "x-goog-api-key"
        default:
            "Bearer token"
        }
    }

    var capabilities: AIProviderCapabilitySet {
        switch self {
        case .openAI:
            .openAI
        case .customOpenAICompatible:
            .custom
        case .anthropic:
            AIProviderCapabilitySet(
                chat: true,
                embedding: false,
                tts: false,
                imageUnderstanding: false,
                speechRecognition: false,
                openAICompatible: false,
                customHeaders: true
            )
        case .gemini:
            AIProviderCapabilitySet(
                chat: true,
                embedding: false,
                tts: false,
                imageUnderstanding: true,
                speechRecognition: false,
                openAICompatible: false,
                customHeaders: false
            )
        default:
            .openAICompatibleText
        }
    }

    var capabilityPolicy: AIProviderCapabilityPolicy {
        switch self {
        case .openAI:
            AIProviderCapabilityPolicy(
                textGeneration: .supported,
                structuredJSON: .supported,
                imageInput: .supported,
                speechSynthesis: .supported,
                embedding: .supported
            )
        case .openRouter, .customOpenAICompatible:
            AIProviderCapabilityPolicy(
                textGeneration: .supported,
                structuredJSON: .supported,
                imageInput: .modelDependent,
                speechSynthesis: .modelDependent,
                embedding: .modelDependent
            )
        case .gemini:
            AIProviderCapabilityPolicy(
                textGeneration: .supported,
                structuredJSON: .supported,
                imageInput: .supported,
                speechSynthesis: .unsupported,
                embedding: .unsupported
            )
        case .anthropic:
            AIProviderCapabilityPolicy(
                textGeneration: .supported,
                structuredJSON: .supported,
                imageInput: .modelDependent,
                speechSynthesis: .unsupported,
                embedding: .unsupported
            )
        default:
            AIProviderCapabilityPolicy(
                textGeneration: .supported,
                structuredJSON: .supported,
                imageInput: .unsupported,
                speechSynthesis: .unsupported,
                embedding: .unsupported
            )
        }
    }

    var firstStageTTSProbeAvailability: TTSFirstStageProbeAvailability {
        switch self {
        case .openAI, .openRouter:
            .realProbe
        case .customOpenAICompatible:
            .futureCompatible
        case .gemini, .mistral, .groq, .xAI, .dashScopeQwen, .zhipuGLM, .siliconFlow:
            .futureProviderSpecific
        case .anthropic, .deepSeek, .moonshotKimi, .ollamaLocal:
            .unsupported
        }
    }

    var defaultTTSAdapterKind: LangoTraceCore.TTSProviderAdapterKind? {
        switch self {
        case .openAI:
            .openAIAudioSpeech
        case .openRouter:
            .openRouterMultimodalAudio
        case .customOpenAICompatible:
            .customOpenAICompatibleAudioSpeech
        default:
            nil
        }
    }

    var defaultTTSVoiceID: String {
        switch self {
        case .openAI:
            "coral"
        case .openRouter:
            "nova"
        case .customOpenAICompatible:
            "alloy"
        default:
            ""
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollamaLocal:
            false
        default:
            true
        }
    }

    var isFirstStageEmbeddingProbeProvider: Bool {
        switch self {
        case .openAI, .openRouter, .customOpenAICompatible:
            true
        default:
            false
        }
    }

    var riskNoteKey: String {
        switch self {
        case .openRouter, .dashScopeQwen, .zhipuGLM, .siliconFlow:
            "aiProviderSettings.providerRisk.routed"
        case .ollamaLocal:
            "aiProviderSettings.providerRisk.local"
        default:
            "aiProviderSettings.providerRisk.direct"
        }
    }
}

extension AIProviderAdapterKind {
    var capabilityPolicy: AIProviderAdapterCapabilityPolicy {
        switch self {
        case .openAICompatibleChat, .openAIResponses:
            AIProviderAdapterCapabilityPolicy(
                canProbeText: true,
                canProbeStructuredJSON: true,
                canProbeImageInput: true,
                canProbeSpeechSynthesis: true,
                canProbeEmbedding: true
            )
        case .anthropicMessages, .geminiGenerateContent:
            AIProviderAdapterCapabilityPolicy(
                canProbeText: false,
                canProbeStructuredJSON: false,
                canProbeImageInput: false,
                canProbeSpeechSynthesis: false,
                canProbeEmbedding: false
            )
        }
    }
}
