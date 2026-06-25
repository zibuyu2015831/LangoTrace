import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData
import LangoTraceLearnerModel
import LangoTraceUI

/// Adapts the multi-turn streaming service to the companion engine's transport
/// seam, binding the resolved provider endpoint + secret (LM03-S1, §12.6).
private struct CompanionStreamingTransport: CompanionReplyTransport {
    let service: AIChatStreamingService
    let endpoint: AIProviderEndpointInput
    let plaintextSecret: String?

    func streamReply(
        system: String,
        messages: [ConversationMessage]
    ) -> AsyncThrowingStream<AIChatStreamEvent, Error> {
        service.stream(AIChatStreamingServiceRequest(
            endpoint: endpoint,
            plaintextSecret: plaintextSecret,
            system: system,
            messages: messages
        ))
    }
}

/// App-level feature switch for the Language Companion (default OFF, ADR-008
/// §2.6). UserDefaults-backed, mirroring the appearance / interface-language
/// preference stores.
func makeCompanionFeatureStore() -> any CompanionFeaturePreferenceStore {
    UserDefaultsCompanionFeatureStore()
}

/// Assembles the companion conversation seam: per-space thread persistence
/// (`GRDBCompanionRepository`) + the multi-turn engine, with the difficulty
/// baseline read straight from `LanguageSpace.level` and **no** Memory / FTS
/// injection (S1 zero system-auto-injection). Persists the user + assistant turns
/// only on success; honest failure keeps the user's input.
func makeCompanionChatActions(
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore
) -> CompanionChatActions {
    let detector = NaturalLanguageDetector()
    let detectLanguage: @Sendable (String) -> String? = { detector.detect($0)?.language }

    return CompanionChatActions(
        loadThread: { spaceID, sourceEntryID in
            guard let database = try? databaseFactory.database() else { return nil }
            let repository = GRDBCompanionRepository(writer: database.writer)
            guard let thread = try? repository.loadOrCreateThread(spaceID: spaceID, sourceEntryID: sourceEntryID)
            else { return nil }
            let messages = (try? repository.messages(threadID: thread.id)) ?? []
            return CompanionLoadedThread(threadID: thread.id, messages: messages)
        },
        send: { threadID, userInput in
            await companionSend(
                threadID: threadID,
                userInput: userInput,
                databaseFactory: databaseFactory,
                credentialStore: credentialStore,
                detectLanguage: detectLanguage
            )
        },
        deleteFrom: { messageID in
            guard let database = try? databaseFactory.database() else { return }
            try? GRDBCompanionRepository(writer: database.writer).deleteMessageAndSubsequent(messageID: messageID)
        },
        clear: { threadID in
            guard let database = try? databaseFactory.database() else { return }
            try? GRDBCompanionRepository(writer: database.writer).clearThread(threadID: threadID)
        }
    )
}

/// One companion turn: resolve space + persona + endpoint, run the engine, and
/// persist both turns on success.
private func companionSend(
    threadID: String,
    userInput: String,
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore,
    detectLanguage: @escaping @Sendable (String) -> String?
) async -> CompanionSendOutcome {
    guard
        let database = try? databaseFactory.database()
    else {
        return .failed(.other)
    }
    let repository = GRDBCompanionRepository(writer: database.writer)
    guard
        let thread = try? repository.thread(id: threadID),
        let space = try? repository.languageContext(spaceID: thread.languageSpaceID)
    else {
        return .failed(.other)
    }
    let history = (try? repository.messages(threadID: threadID)) ?? []
    let persona = (try? repository.loadPersona(spaceID: thread.languageSpaceID)) ?? .default

    // Plan-A: seed the brought-in record only on the first turn.
    let seedEntryBody: String? = (history.isEmpty ? thread.sourceEntryID : nil)
        .flatMap { try? repository.entryBody(entryID: $0) }

    // Resolve the provider endpoint + secret (honest failure when not configured).
    let configurationRepository = GRDBAIProviderConfigurationRepository(database: database)
    guard
        let profile = try? await configurationRepository.loadDefaultProfile(),
        let endpoint = profile.textGenerationEndpointInput
    else {
        return .failed(.providerUnavailable)
    }
    let plaintextSecret = try? await resolveLearningMaterialSecret(
        endpoint: endpoint,
        profile: profile,
        credentialStore: credentialStore
    )

    let engine = CompanionConversationEngine(
        transport: CompanionStreamingTransport(
            service: AIChatStreamingService(httpClient: URLSessionAIProviderHTTPClient()),
            endpoint: endpoint,
            plaintextSecret: plaintextSecret
        ),
        detectLanguage: detectLanguage
    )
    let outcome = await engine.reply(
        userInput: userInput,
        history: history,
        persona: persona,
        targetLanguageCode: space.targetLanguageCode,
        nativeLanguageCode: space.nativeLanguageCode,
        proficiencyLevel: space.level,
        seedEntryBody: seedEntryBody
    )

    switch outcome {
    case let .reply(text, detected):
        guard
            let user = try? repository.appendMessage(
                threadID: threadID, role: .user, content: userInput,
                detectedLanguage: detected, targetLanguageCode: space.targetLanguageCode
            ),
            let assistant = try? repository.appendMessage(
                threadID: threadID, role: .assistant, content: text,
                targetLanguageCode: space.targetLanguageCode
            )
        else {
            return .failed(.other)
        }
        return .appended(user: user, assistant: assistant)
    case let .failure(reason):
        return .failed(reason)
    }
}
