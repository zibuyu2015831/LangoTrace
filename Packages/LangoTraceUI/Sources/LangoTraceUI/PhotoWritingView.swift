import LangoTraceCore
import PhotosUI
import SwiftUI

struct PhotoWritingView: View {
    let languageSpace: LanguageSpacePreview
    let actions: PhotoWritingActions
    let onSave: (_ body: String, _ imageData: Data?) throws -> Void
    let onDismiss: () -> Void

    @StateObject private var assist: PhotoWritingAssistViewModel
    @State private var draftState = PhotoWritingDraftState()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImage: Image?
    @State private var saveError: String?
    @State private var isSaving = false
    @State private var showAssistConfirm = false

    init(
        languageSpace: LanguageSpacePreview,
        actions: PhotoWritingActions = .disabled,
        onSave: @escaping (_ body: String, _ imageData: Data?) throws -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.languageSpace = languageSpace
        self.actions = actions
        self.onSave = onSave
        self.onDismiss = onDismiss
        _assist = StateObject(
            wrappedValue: PhotoWritingAssistViewModel(languageSpace: languageSpace, actions: actions)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photoArea
                    guidanceChipRow
                    if let chip = draftState.activeGuidanceChip {
                        chipHintPanel(chip: chip)
                    }
                    writingArea
                    assistSection
                }
                .padding(20)
            }
            .langoPageBackground()
            .navigationTitle(localizedText("entrySource.photoWriting"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        localizedText("common.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        performSave()
                    } label: {
                        if isSaving {
                            localizedText("common.saving")
                        } else {
                            localizedText("photoWriting.createEntry")
                        }
                    }
                    .disabled(isSaving || !draftState.isSaveEnabled(hasPhoto: selectedImageData != nil))
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: selectedItem) { _, item in
            Task {
                selectedImageData = nil
                selectedImage = nil
                if let item {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        if let uiImage = loadImage(from: data) {
                            selectedImage = uiImage
                        }
                    }
                }
                // A new photo invalidates any prior assist result.
                assist.reset()
            }
        }
        .confirmationDialog(
            localizedString("photoWriting.assist.confirm.title"),
            isPresented: $showAssistConfirm,
            titleVisibility: .visible
        ) {
            Button(localizedString("photoWriting.assist.confirm.send")) {
                startAssist()
            }
            Button(localizedString("common.cancel"), role: .cancel) {}
        } message: {
            localizedText("photoWriting.assist.confirm.message")
        }
    }

    // MARK: - Sub-views

    private var photoArea: some View {
        let currentSelectedImage = selectedImage
        return PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            PhotoWritingPhotoAreaContent(selectedImage: currentSelectedImage)
        }
        .buttonStyle(.plain)
    }

    private var guidanceChipRow: some View {
        HStack(spacing: 10) {
            ForEach(GuidanceChipKind.allCases, id: \.self) { chip in
                guidanceChip(chip)
            }
            Spacer(minLength: 0)
        }
    }

    private func guidanceChip(_ chip: GuidanceChipKind) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                draftState.selectGuidanceChip(chip)
            }
        } label: {
            localizedText(chip.titleKey)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    draftState.activeGuidanceChip == chip
                        ? LangoTraceDesign.ColorToken.accent.opacity(0.12)
                        : LangoTraceDesign.ColorToken.elevatedPaper
                )
                .foregroundStyle(
                    draftState.activeGuidanceChip == chip
                        ? LangoTraceDesign.ColorToken.accent
                        : LangoTraceDesign.ColorToken.textSecondary
                )
                .clipShape(Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            draftState.activeGuidanceChip == chip
                                ? LangoTraceDesign.ColorToken.accent.opacity(0.4)
                                : LangoTraceDesign.ColorToken.borderSubtle,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func chipHintPanel(chip: GuidanceChipKind) -> some View {
        localizedText(chip.hintKey)
            .font(.callout)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(LangoTraceDesign.ColorToken.surfaceAccentMuted.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var writingArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $draftState.draftText)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if draftState.draftText.isEmpty {
                        localizedText("photoWriting.draft.placeholder")
                            .font(.body)
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
            if let saveError {
                Text(saveError)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.stateError)
            }
        }
        .langoPanel(padding: 10)
    }

    // MARK: - AI assist

    private var assistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(selection: $assist.selectedMode) {
                localizedText("photoWriting.assist.mode.suggestions")
                    .tag(PhotoWritingAssistMode.writingSuggestions)
                localizedText("photoWriting.assist.mode.draft")
                    .tag(PhotoWritingAssistMode.sourceLanguageDraft)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .disabled(assist.isSending)

            Button {
                showAssistConfirm = true
            } label: {
                Label(localizedString("photoWriting.assist.button"), systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImageData == nil || assist.isSending)

            assistStateView
        }
        .langoPanel(padding: 14)
    }

    @ViewBuilder
    private var assistStateView: some View {
        switch assist.state {
        case .idle:
            EmptyView()
        case .sending:
            HStack(spacing: 10) {
                ProgressView()
                localizedText("photoWriting.assist.sending")
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                Spacer(minLength: 0)
                Button(action: assist.cancel) {
                    localizedText("common.cancel")
                }
                .buttonStyle(.borderless)
            }
        case let .result(result):
            PhotoWritingAssistResultPanel(
                result: result,
                onAdopt: assist.adoptableText == nil ? nil : { adopt() },
                onDismiss: assist.reset
            )
        case let .failed(category):
            assistFailureView(category)
        }
    }

    @ViewBuilder
    private func assistFailureView(_ category: PhotoWritingAssistFailureCategory) -> some View {
        let key = category == .imageInputNotEnabled
            ? "photoWriting.assist.guidance.imageInputDisabled"
            : "photoWriting.assist.error.generic"
        Label {
            localizedText(key)
        } icon: {
            Image(systemName: category == .imageInputNotEnabled ? "wand.and.stars" : "exclamationmark.triangle")
        }
        .font(.footnote)
        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startAssist() {
        guard let data = selectedImageData else { return }
        assist.requestAssist(imageData: data, note: draftState.draftText)
    }

    /// Non-destructive adopt: append the native draft to the writing area instead
    /// of overwriting whatever the user already wrote.
    private func adopt() {
        guard let text = assist.adoptableText else { return }
        if draftState.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draftState.draftText = text
        } else {
            draftState.draftText += "\n\n" + text
        }
        assist.reset()
    }

    // MARK: - Actions

    private func performSave() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try onSave(draftState.draftText, selectedImageData)
            saveError = nil
        } catch {
            saveError = localizedString("common.errorSaveFailedRetry")
        }
    }

    // MARK: - Helpers

    private func loadImage(from data: Data) -> Image? {
        #if os(iOS)
            guard let uiImage = UIImage(data: data) else { return nil }
            return Image(uiImage: uiImage)
        #elseif os(macOS)
            guard let nsImage = NSImage(data: data) else { return nil }
            return Image(nsImage: nsImage)
        #else
            return nil
        #endif
    }
}

private struct PhotoWritingPhotoAreaContent: View {
    let selectedImage: Image?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let selectedImage {
                    selectedImage
                        .resizable()
                        .scaledToFill()
                } else {
                    photoPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 220)
            .clipped()
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.borderSubtle, lineWidth: 1)
        }
        .accessibilityLabel(localizedText("photoWriting.photo.accessibilityLabel"))
    }

    private var photoPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    LangoTraceDesign.ColorToken.surfaceAccentMuted,
                    LangoTraceDesign.ColorToken.elevatedPaper,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                localizedText("photoWriting.photo.addPrompt")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
    }
}
