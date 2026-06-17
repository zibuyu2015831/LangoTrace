import LangoTraceCore
import PhotosUI
import SwiftUI

struct PhotoWritingView: View {
    let languageSpace: LanguageSpacePreview
    let onSave: (_ body: String, _ imageData: Data?) throws -> Void
    let onDismiss: () -> Void

    @State private var draftState = PhotoWritingDraftState()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImage: Image?
    @State private var saveError: String?

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
                    privacyNotice
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
                        localizedText("photoWriting.createEntry")
                    }
                    .disabled(!draftState.isSaveEnabled(hasPhoto: selectedImageData != nil))
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
            }
        }
    }

    // MARK: - Sub-views

    private var photoArea: some View {
        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            photoAreaContent
        }
        .buttonStyle(.plain)
    }

    private var photoAreaContent: some View {
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

    private var privacyNotice: some View {
        Label {
            localizedText("photoWriting.privacy.notice")
        } icon: {
            Image(systemName: "lock")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(LangoTraceDesign.ColorToken.privacyLocal)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Actions

    private func performSave() {
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
