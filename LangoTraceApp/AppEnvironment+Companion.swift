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
    // Same UserDefaults keys the UI consent stores read/write — the App send path
    // and the one-time preview decisions stay in sync (LM03-S2b-1 / S2b-2).
    let consentStore = UserDefaultsCompanionMemoryConsentStore()
    let topicConsentStore = UserDefaultsCompanionTopicSourcingConsentStore()

    return CompanionChatActions(
        loadThread: { spaceID, sourceEntryID in
            guard let database = try? databaseFactory.database() else { return nil }
            let repository = GRDBCompanionRepository(writer: database.writer)
            guard let thread = try? repository.loadOrCreateThread(spaceID: spaceID, sourceEntryID: sourceEntryID)
            else { return nil }
            let messages = (try? repository.messages(threadID: thread.id)) ?? []
            // Carry out the persona correction posture so the gentle-recast toggle
            // reflects persisted state on load (LM03-S3a) — persona is otherwise
            // only read inside send.
            let persona = (try? repository.loadPersona(spaceID: spaceID)) ?? .default
            return CompanionLoadedThread(
                threadID: thread.id,
                messages: messages,
                usesLearnerProfile: thread.usesLearnerProfile,
                correction: persona.correction
            )
        },
        send: { threadID, userInput, onPartial in
            await companionSend(
                threadID: threadID,
                userInput: userInput,
                onPartial: onPartial,
                databaseFactory: databaseFactory,
                credentialStore: credentialStore,
                detectLanguage: detectLanguage,
                consent: consentStore.consent,
                topicConsent: topicConsentStore.consent
            )
        },
        deleteFrom: { messageID in
            guard let database = try? databaseFactory.database() else { return }
            try? GRDBCompanionRepository(writer: database.writer).deleteMessageAndSubsequent(messageID: messageID)
        },
        clear: { threadID in
            guard let database = try? databaseFactory.database() else { return }
            try? GRDBCompanionRepository(writer: database.writer).clearThread(threadID: threadID)
        },
        extract: { threadID in
            await companionExtract(
                threadID: threadID,
                databaseFactory: databaseFactory,
                credentialStore: credentialStore
            )
        },
        setUsesLearnerProfile: { threadID, enabled in
            guard let database = try? databaseFactory.database() else { return }
            try? GRDBCompanionRepository(writer: database.writer)
                .setUsesLearnerProfile(threadID: threadID, enabled)
        },
        setGentleRecast: { spaceID, enabled in
            // Read-modify-write: savePersona is a full-field upsert, so load the
            // current persona and change ONLY the correction posture — otherwise we
            // would clobber the user's tone / formality (LM03-S3a).
            guard let database = try? databaseFactory.database() else { return }
            let repository = GRDBCompanionRepository(writer: database.writer)
            let current = (try? repository.loadPersona(spaceID: spaceID)) ?? .default
            let updated = CompanionPersona(
                tone: current.tone,
                formality: current.formality,
                correction: enabled ? .warmRecast : .ifNeeded
            )
            try? repository.savePersona(updated, spaceID: spaceID)
        },
        memoryPreviewProjection: { _ in
            // The "will-send-with-injection" disclosure for the one-time preview.
            guard let database = try? databaseFactory.database() else { return nil }
            let configurationRepository = GRDBAIProviderConfigurationRepository(database: database)
            guard
                let profile = try? await configurationRepository.loadDefaultProfile(),
                let endpoint = profile.textGenerationEndpointInput
            else { return nil }
            return AIRequestPreviewProjection.companionConversation(
                endpoint: endpoint, lengthBucket: .medium, hasMemoryInjection: true
            )
        },
        recordTopicPreviewProjection: { _ in
            // The "will-send-with-a-record" disclosure for the one-time topic
            // sourcing preview (LM03-S2b-2).
            guard let database = try? databaseFactory.database() else { return nil }
            let configurationRepository = GRDBAIProviderConfigurationRepository(database: database)
            guard
                let profile = try? await configurationRepository.loadDefaultProfile(),
                let endpoint = profile.textGenerationEndpointInput
            else { return nil }
            return AIRequestPreviewProjection.companionConversation(
                endpoint: endpoint, lengthBucket: .medium, hasMemoryInjection: false, hasBroughtInRecords: true
            )
        },
        depositAllCandidates: { spaceID in
            // Session summary (LM03-S3b-2): batch-deposit every companion candidate
            // into the E7/E8 memory review system, closing the chat → memory loop.
            // Local-only, idempotent (already-deposited candidates return the existing
            // item). App-level orchestration keeps GRDBMemoryItemRepository free of any
            // companion-table coupling.
            guard let database = try? databaseFactory.database() else { return 0 }
            let companionRepository = GRDBCompanionRepository(writer: database.writer)
            let memoryRepository = GRDBMemoryItemRepository(database: database)
            let candidates = (try? companionRepository.companionCandidates(spaceID: spaceID)) ?? []
            var count = 0
            for candidate in candidates {
                let input = MemoryDepositInput(companionCandidate: candidate, spaceID: spaceID)
                if await (try? memoryRepository.deposit(input)) != nil { count += 1 }
            }
            return count
        },
        depositedCandidateIDs: { spaceID in
            guard let database = try? databaseFactory.database() else { return [] }
            let memoryRepository = GRDBMemoryItemRepository(database: database)
            return await (try? memoryRepository.depositedCandidateIDs(spaceID: spaceID)) ?? []
        }
    )
}

/// One explicit chat-reflux extraction (LM03-S2a): resolve space + endpoint, run
/// the extraction engine over the persisted conversation, persist the candidates
/// anchored to the latest user message, and return the space's full candidate list
/// (newest first, carrying the source-deleted state). Reuses the S1 streaming
/// transport — same provider path, no system-auto-injection.
private func companionExtract(
    threadID: String,
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore
) async -> CompanionExtractionOutcome {
    guard let database = try? databaseFactory.database() else {
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
    // Nothing to mine — an empty success, not an outbound request.
    guard !history.isEmpty else { return .extracted([]) }

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

    let engine = CompanionExtractionEngine(
        transport: CompanionStreamingTransport(
            service: AIChatStreamingService(httpClient: URLSessionAIProviderHTTPClient()),
            endpoint: endpoint,
            plaintextSecret: plaintextSecret
        )
    )
    let result = await engine.extract(
        window: history,
        targetLanguageCode: space.targetLanguageCode,
        nativeLanguageCode: space.nativeLanguageCode
    )
    switch result {
    case let .success(extracted):
        // Anchor the batch to the latest user message (weak link, nulled if deleted).
        let anchorMessageID = history.last(where: { $0.role == .user })?.id
        try? repository.appendCompanionCandidates(
            threadID: threadID,
            messageID: anchorMessageID,
            candidates: extracted
        )
        let all = (try? repository.companionCandidates(spaceID: thread.languageSpaceID)) ?? []
        return .extracted(all)
    case let .failure(error):
        return .failed(error)
    }
}

/// One companion turn: resolve space + persona + endpoint, run the engine, and
/// persist both turns on success.
private func companionSend(
    threadID: String,
    userInput: String,
    onPartial: @escaping @Sendable (String) -> Void,
    databaseFactory: SharedAppDatabaseFactory,
    credentialStore: any AIProviderCredentialStore,
    detectLanguage: @escaping @Sendable (String) -> String?,
    consent: CompanionMemoryConsent,
    topicConsent: CompanionTopicSourcingConsent
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

    // Memory injection (LM03-S2b-1): authoritative egress gate decided here, at the
    // last moment, from the global consent + this thread's toggle. When open, select
    // the recency+quota top-5 global life facts; the engine scrubs them (and the
    // history replay + input) on the way out — persistence keeps the originals.
    let memoryContext: [String]
    if CompanionInjectionGate.shouldInject(consent: consent, threadUsesProfile: thread.usesLearnerProfile) {
        let contextProvider = GRDBLearnerContextProvider(reader: database.reader)
        let facts = (try? contextProvider.memoryFacts(visibility: .global)) ?? []
        memoryContext = CompanionMemorySelection.select(facts: facts).map(\.text)
    } else {
        memoryContext = []
    }

    // Plan-A: seed the brought-in record only on the first turn.
    let seedEntryBody: String? = (history.isEmpty ? thread.sourceEntryID : nil)
        .flatMap { try? repository.entryBody(entryID: $0) }

    // Plan-B topic sourcing (LM03-S2b-2): this is a SEND-turn decision, never on
    // load (cold-start stays zero-outbound). When there is no plan-A seed and the
    // topic-sourcing gate is open (consent read last-moment + the same thread row's
    // shared toggle), auto-source the most recent record (recency top-1, v1). The
    // engine scrubs the record body on the way out — persistence keeps the original.
    let broughtInRecords: [String]
    if seedEntryBody == nil,
       CompanionInjectionGate.shouldSourceTopic(consent: topicConsent, threadUsesProfile: thread.usesLearnerProfile)
    {
        let candidates = (try? repository.recentTopicCandidates(spaceID: thread.languageSpaceID, limit: 1)) ?? []
        broughtInRecords = CompanionTopicSelection.select(candidates: candidates).map(\.body)
    } else {
        broughtInRecords = []
    }

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
        detectLanguage: detectLanguage,
        // Outbound-only PII scrub over history replay + input + injected facts.
        scrub: PIIScrubber.scrub
    )

    // Rolling summary / 对话记忆 (LM03-S3b-1): before replying, fold the turns that
    // have aged out of the recent-verbatim window into the conversation summary, so
    // a long conversation stays grounded without re-sending everything. Best-effort:
    // a summarization failure leaves the stored summary untouched and never blocks
    // the reply. The reply then sends only the unsummarized recent turns verbatim,
    // with the summary carrying the earlier context (no double-send overlap).
    let recentVerbatimWindow = 12
    let existingSummary = try? repository.loadRollingSummary(threadID: threadID)
    if CompanionConversationEngine.shouldSummarize(
        messageCount: history.count, watermark: existingSummary?.coversThroughSequence
    ) {
        let foldBoundary = max(0, history.count - recentVerbatimWindow)
        let priorWatermark = existingSummary?.coversThroughSequence ?? Int.min
        let toFold = history[0 ..< foldBoundary].filter { $0.sequence > priorWatermark }
        if let newWatermark = toFold.last?.sequence {
            let summaryOutcome = await engine.summarize(
                messagesToFold: Array(toFold),
                existingSummary: existingSummary?.text,
                targetLanguageCode: space.targetLanguageCode,
                nativeLanguageCode: space.nativeLanguageCode
            )
            if case let .summary(text) = summaryOutcome {
                try? repository.updateRollingSummary(
                    threadID: threadID, text: text, coversThroughSequence: newWatermark
                )
            }
        }
    }
    let summary = try? repository.loadRollingSummary(threadID: threadID)
    let replyHistory = summary.map { current in
        history.filter { $0.sequence > current.coversThroughSequence }
    } ?? history

    let outcome = await engine.reply(
        userInput: userInput,
        history: replyHistory,
        persona: persona,
        targetLanguageCode: space.targetLanguageCode,
        nativeLanguageCode: space.nativeLanguageCode,
        proficiencyLevel: space.level,
        seedEntryBody: seedEntryBody,
        memoryContext: memoryContext,
        broughtInRecords: broughtInRecords,
        conversationMemory: summary?.text,
        onPartial: onPartial
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
