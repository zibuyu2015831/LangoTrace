import LangoTraceCore
import SwiftUI

/// Three-platform Language Companion chat (LM03-S1). Reached from the practice-tab
/// secondary entry (cold-start) or a record's "talk about this record" entry
/// (plan-A seed). Reads the conversation seam from the environment and drives the
/// `CompanionChatStore`: a local cold-start greeting (zero outbound), send with
/// honest failure (input preserved, no faked reply), and delete / clear.
struct CompanionChatView: View {
    let languageSpace: LanguageSpacePreview
    let seed: CompanionChatRouteSeed

    @Environment(\.companionChatActions) private var actions
    @StateObject private var store: CompanionChatStore
    @State private var isPresentingClearConfirm = false
    @State private var memoryPreview: CompanionMemoryPreviewModel?
    @State private var isPresentingMemoryPreview = false

    init(languageSpace: LanguageSpacePreview, seed: CompanionChatRouteSeed) {
        self.languageSpace = languageSpace
        self.seed = seed
        _store = StateObject(wrappedValue: CompanionChatStore(
            spaceID: languageSpace.id,
            sourceEntryID: seed.sourceEntryID,
            actions: .disabled
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            transcript
            inputBar
        }
        .navigationTitle(localizedString(CompanionChatCopy.entryTitleKey))
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Task { await store.extractCandidates() }
                } label: {
                    localizedText(CompanionChatCopy.extractActionKey)
                }
                .disabled(!store.canExtract)
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle(isOn: Binding(
                    get: { store.usesLearnerProfile },
                    set: { enabled in Task { await store.setUsesLearnerProfile(enabled) } }
                )) {
                    localizedText(CompanionChatCopy.memoryToggleKey)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isPresentingClearConfirm = true
                } label: {
                    localizedText(CompanionChatCopy.clearKey)
                }
                .disabled(store.messages.isEmpty)
            }
        }
        .sheet(isPresented: $isPresentingMemoryPreview) {
            memoryConsentPreview
        }
        .confirmationDialog(
            localizedString(CompanionChatCopy.clearKey),
            isPresented: $isPresentingClearConfirm,
            titleVisibility: .visible
        ) {
            Button(localizedString(CompanionChatCopy.clearKey), role: .destructive) {
                Task { await store.clear() }
            }
        }
        .task {
            store.reconnect(actions)
            await store.load()
            // One-time disclosure: surface the injection preview once when the user
            // has not yet decided (zero-friction afterwards — never per-send).
            if store.needsMemoryConsentPreview {
                memoryPreview = await store.memoryPreviewModel()
                isPresentingMemoryPreview = true
            }
        }
    }

    /// The one-time Memory-injection consent preview (LM03-S2b-1). Honestly shows
    /// the curated subset that will be sent and the full memory store that will
    /// not, then records the sticky decision.
    private var memoryConsentPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            localizedText(CompanionChatCopy.memoryPreviewTitleKey)
                .font(.headline)
            if let preview = memoryPreview {
                localizedText(CompanionChatCopy.memoryPreviewSendsKey)
                    .font(.subheadline.weight(.semibold))
                ForEach(preview.includedLabels, id: \.self) { label in
                    Text("• \(label)").font(.footnote)
                }
                localizedText(CompanionChatCopy.memoryPreviewNotSendsKey)
                    .font(.subheadline.weight(.semibold))
                ForEach(preview.excludedLabels, id: \.self) { label in
                    Text("• \(label)").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack {
                Button(localizedString(CompanionChatCopy.memoryDeclineKey), role: .cancel) {
                    store.setMemoryConsent(.disabled)
                    isPresentingMemoryPreview = false
                }
                Spacer()
                Button(localizedString(CompanionChatCopy.memoryUseKey)) {
                    store.setMemoryConsent(.enabled)
                    isPresentingMemoryPreview = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if store.showsColdStartGreeting {
                    bubble(text: localizedString(CompanionChatCopy.coldStartGreetingKey), isUser: false)
                }
                ForEach(store.messages) { message in
                    bubble(text: message.text, isUser: message.isUser)
                }
                if let failure = store.failure {
                    Text(localizedString(CompanionChatCopy.failureKey(failure)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                extractionResults
            }
            .padding()
        }
    }

    @ViewBuilder private var extractionResults: some View {
        if store.isExtracting {
            Text(localizedString(CompanionChatCopy.extractLoadingKey))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let error = store.extractionFailure {
            Text(localizedString(CompanionChatCopy.extractionFailureKey(error)))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let count = store.lastExtractionCount {
            if count == 0 {
                Text(localizedString(CompanionChatCopy.extractEmptyKey))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(format: localizedString(CompanionChatCopy.extractSuccessCountKey), count))
                    .font(.footnote.weight(.semibold))
                ForEach(store.candidates) { candidate in
                    candidateRow(candidate)
                }
            }
        }
    }

    private func candidateRow(_ candidate: CompanionCandidatePresentation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(candidate.text).font(.subheadline.weight(.medium))
            Text(candidate.explanationNative).font(.caption).foregroundStyle(.secondary)
            if candidate.isSourceMessageDeleted {
                Text(localizedString(CompanionChatCopy.extractSourceDeletedKey))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bubble(text: String, isUser: Bool) -> some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .padding(10)
                .background(
                    isUser ? LangoTraceDesign.ColorToken.accent.opacity(0.15)
                        : LangoTraceDesign.ColorToken.surfaceRaised
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(
                localizedString(CompanionChatCopy.inputPlaceholderKey),
                text: $store.draftText,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1 ... 4)
            .onSubmit { send() }
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(!store.canSend)
        }
        .padding()
    }

    private func send() {
        guard store.canSend else { return }
        Task { await store.send() }
    }
}
