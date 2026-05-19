import LangoTraceCore
import SwiftUI

struct PhotoWritingPreviewView: View {
    let languageSpace: LanguageSpacePreview
    let onCreateEntry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    mockPhoto
                    previewHeader
                    PhotoWritingSuggestionPanel(
                        titleKey: "photoWriting.topic.title",
                        bodyKey: "photoWriting.topic.body",
                        systemImage: "sparkles"
                    )
                    TextPanel(
                        title: localizedString("photoWriting.nativeDraft.title"),
                        text: localizedString("photoWriting.nativeDraft.body")
                    )
                    TextPanel(
                        title: localizedString("photoWriting.targetExample.title", languageSpace.targetLanguage),
                        text: localizedString("photoWriting.targetExample.body")
                    )
                    localPreviewNotice
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
                    Button(action: onCreateEntry) {
                        localizedText("photoWriting.createEntry")
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText("photoWriting.preview.title")
                .font(.title3.weight(.semibold))
            localizedText("photoWriting.preview.summary")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var localPreviewNotice: some View {
        Label {
            localizedText("photoWriting.localPreview.notice")
        } icon: {
            Image(systemName: "lock")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(LangoTraceDesign.ColorToken.privacyLocal)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var mockPhoto: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            LangoTraceDesign.ColorToken.surfaceAccentMuted,
                            LangoTraceDesign.ColorToken.elevatedPaper,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            mockPhotoCaption
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.borderSubtle, lineWidth: 1)
        }
        .accessibilityLabel(localizedText("photoWriting.mockPhoto.accessibilityLabel"))
    }

    private var mockPhotoCaption: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                Image(systemName: "cup.and.saucer.fill")
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
            }
            .font(.title2)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            localizedText("photoWriting.mockPhoto.caption")
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
        }
        .padding(18)
    }
}

private struct PhotoWritingSuggestionPanel: View {
    let titleKey: String
    let bodyKey: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                localizedText(titleKey)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.headline)
            localizedText(bodyKey)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel()
    }
}
