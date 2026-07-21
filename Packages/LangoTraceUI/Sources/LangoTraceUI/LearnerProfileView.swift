import LangoTraceCore
import LangoTraceLearnerModel
import SwiftUI

/// Three-platform learner-profile overview page (LM02 Slice 1). Reached as an
/// independent navigation item (iPhone settings / iPad·macOS sidebar peer) —
/// **not** a `SettingsCapability`, since the profile is not a status-bearing
/// configuration capability.
///
/// Shows a gentle, never-downgrading level (constraint 5), Ability knowledge
/// coverage, review statistics, the system-level Memory facts with unified
/// governance (explicit-remember add / single delete / system reset), and the
/// blind-spot section (LM02-S3: repeated dictation-practice errors).
struct LearnerProfileView: View {
    let languageSpace: LanguageSpacePreview

    @Environment(\.learnerProfileActions) private var actions
    @StateObject private var store: LearnerProfileStore
    @State private var isPresentingResetConfirm = false

    init(languageSpace: LanguageSpacePreview) {
        self.languageSpace = languageSpace
        _store = StateObject(wrappedValue: LearnerProfileStore(
            spaceID: languageSpace.id,
            languageCode: languageSpace.targetLanguageCode,
            level: languageSpace.level,
            actions: .disabled
        ))
    }

    var body: some View {
        List {
            switch store.phase {
            case .loading:
                ProgressView()
            case .unavailable:
                localizedText("learnerProfile.unavailable")
                    .foregroundStyle(.secondary)
            case .ready:
                if let presentation = store.presentation {
                    content(presentation)
                }
            }
        }
        .navigationTitle(localizedString("learnerProfile.title"))
        .task {
            store.reconnect(actions)
            await store.load()
        }
    }

    @ViewBuilder
    private func content(_ presentation: LearnerProfilePresentation) -> some View {
        levelSection(presentation.levelDisplay)
        if presentation.isEmpty {
            Section {
                localizedText("learnerProfile.memory.empty")
                    .foregroundStyle(.secondary)
            }
        } else {
            coverageSection(presentation)
            reviewSection(presentation)
        }
        memorySection(presentation)
        blindSpotSection(presentation)
        governanceSection()
    }

    private func levelSection(_ display: LearnerProfileLevelDisplay) -> some View {
        Section(localizedString("learnerProfile.level.title")) {
            // Gentle, never-downgrading: only ever the static onboarding level
            // marked as still-calibrating. No downgrade verdict is representable.
            Text(String(
                format: localizedString("learnerProfile.level.calibrating"),
                display.level.rawValue
            ))
        }
    }

    private func coverageSection(_ presentation: LearnerProfilePresentation) -> some View {
        Section(localizedString("learnerProfile.coverage.title")) {
            Text(String(format: localizedString("learnerProfile.coverage.count"), presentation.coverageEntryCount))
        }
    }

    private func reviewSection(_ presentation: LearnerProfilePresentation) -> some View {
        Section(localizedString("learnerProfile.review.title")) {
            Text(String(format: localizedString("learnerProfile.review.due"), presentation.dueCount))
            Text(String(format: localizedString("learnerProfile.review.mastered"), presentation.masteredCount))
            Text(String(format: localizedString("learnerProfile.review.thisWeek"), presentation.depositedThisWeek))
        }
    }

    private func memorySection(_ presentation: LearnerProfilePresentation) -> some View {
        Section {
            ForEach(presentation.memoryFacts) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    localizedText(kindKey(fact.kind))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fact.text)
                }
            }
            .onDelete { indexSet in
                let ids = indexSet.map { presentation.memoryFacts[$0].id }
                Task { for id in ids {
                    await store.deleteFact(id: id)
                } }
            }
            addFactRow
        } header: {
            localizedText("learnerProfile.memory.title")
        } footer: {
            localizedText("learnerProfile.memory.subtitle")
        }
    }

    private var addFactRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(localizedString("learnerProfile.memory.kind"), selection: $store.draftKind) {
                ForEach(MemoryFactKind.allCases, id: \.self) { kind in
                    localizedText(kindKey(kind)).tag(kind)
                }
            }
            TextField(localizedString("learnerProfile.memory.textPlaceholder"), text: $store.draftText)
            Button {
                Task { await store.addDraftFact() }
            } label: {
                localizedText("learnerProfile.memory.save")
            }
            .disabled(!store.canSubmitDraft)
        }
    }

    private func blindSpotSection(_ presentation: LearnerProfilePresentation) -> some View {
        Section {
            if presentation.blindSpots.isEmpty {
                // Honest empty state: guidance to do dictation practice (the signal
                // source), never a fabricated blind spot.
                localizedText("learnerProfile.blindSpots.empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presentation.blindSpots) { spot in
                    HStack {
                        localizedText(blindSpotKindKey(spot.kind))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(spot.text)
                        Spacer()
                        Text(String(format: localizedString("learnerProfile.blindSpots.count"), spot.occurrenceCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            localizedText("learnerProfile.blindSpots.title")
        } footer: {
            // Honest framing (constraint 4): repeated practice errors from dictation, not a
            // grammar verdict or a level judgement.
            localizedText("learnerProfile.blindSpots.footer")
        }
    }

    private func blindSpotKindKey(_ kind: BlindSpotKind) -> String {
        switch kind {
        case .missing: "learnerProfile.blindSpots.kind.missing"
        case .changed: "learnerProfile.blindSpots.kind.changed"
        case .extra: "learnerProfile.blindSpots.kind.extra"
        }
    }

    private func governanceSection() -> some View {
        Section {
            Button(role: .destructive) {
                isPresentingResetConfirm = true
            } label: {
                localizedText("learnerProfile.reset.button")
            }
        }
        .confirmationDialog(
            localizedString("learnerProfile.reset.confirm.title"),
            isPresented: $isPresentingResetConfirm,
            titleVisibility: .visible
        ) {
            Button(localizedString("learnerProfile.reset.confirm.action"), role: .destructive) {
                Task { await store.resetAllFacts() }
            }
            Button(localizedString("learnerProfile.cancel"), role: .cancel) {}
        } message: {
            localizedText("learnerProfile.reset.confirm.message")
        }
    }

    private func kindKey(_ kind: MemoryFactKind) -> String {
        switch kind {
        case .lifeFact: "learnerProfile.kind.lifeFact"
        case .preference: "learnerProfile.kind.preference"
        case .goal: "learnerProfile.kind.goal"
        case .relationship: "learnerProfile.kind.relationship"
        }
    }
}
