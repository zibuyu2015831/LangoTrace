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
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isPresentingClearConfirm = true
                } label: {
                    localizedText(CompanionChatCopy.clearKey)
                }
                .disabled(store.messages.isEmpty)
            }
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
        }
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
            }
            .padding()
        }
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
