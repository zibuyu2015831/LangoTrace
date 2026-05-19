import Foundation

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
        case .customOpenAICompatible:
            ""
        default:
            ""
        }
    }

    var defaultTTSModel: String {
        switch self {
        case .openAI:
            "gpt-4o-mini-tts"
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
