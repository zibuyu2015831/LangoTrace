import SwiftUI

struct S3SyncDraftView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = S3SyncDraft()
    @State private var showsSecret = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                providerSection
                connectionSection
                securityBoundary
                actionSection
            }
            .padding(20)
        }
        .navigationTitle(localizedString("syncSettings.s3.navigationTitle"))
        .langoInlineS3ModalTitle()
        .langoPageBackground()
    }

    private var header: some View {
        LocalizedCompactPanel(
            titleKey: "syncSettings.s3.header.title",
            textKey: "syncSettings.s3.header.body",
            systemImage: "externaldrive.connected.to.line.below"
        )
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AIProviderSectionTitle("syncSettings.s3.provider.title")
            Menu {
                ForEach(S3SyncProvider.allCases) { provider in
                    Button(provider.displayName) {
                        draft.updateProvider(provider)
                    }
                }
            } label: {
                HStack {
                    Text(draft.provider.displayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .accessibilityLabel(localizedText("syncSettings.s3.provider.picker"))
        }
        .langoPanel()
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AIProviderSectionTitle("syncSettings.s3.connection.title")
            SyncSettingsTextField(titleKey: "syncSettings.s3.endpoint.title", text: $draft.endpoint, keyboardHint: .url)
            SyncSettingsTextField(titleKey: "syncSettings.s3.region.title", text: $draft.region, keyboardHint: .plain)
            SyncSettingsTextField(titleKey: "syncSettings.s3.bucket.title", text: $draft.bucket, keyboardHint: .plain)
            SyncSettingsTextField(
                titleKey: "syncSettings.s3.pathPrefix.title",
                text: $draft.pathPrefix,
                keyboardHint: .plain
            )
            SyncSettingsTextField(
                titleKey: "syncSettings.s3.accessKey.title",
                text: $draft.accessKeyID,
                keyboardHint: .plain
            )
            secretAccessKeyField
            Toggle(isOn: $draft.usesHTTPS) {
                localizedText("syncSettings.s3.https.title")
                    .font(.callout.weight(.semibold))
            }
            Toggle(isOn: $draft.usesPathStyleAccess) {
                localizedText("syncSettings.s3.pathStyle.title")
                    .font(.callout.weight(.semibold))
            }
        }
        .langoPanel()
    }

    private var secretAccessKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText("syncSettings.s3.secretKey.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            HStack(spacing: 8) {
                secretInput
                    .langoSyncTextInput(keyboardHint: .plain)
                    .font(.body.monospaced())

                Button {
                    showsSecret.toggle()
                } label: {
                    Image(systemName: showsSecret ? "eye.slash" : "eye")
                        .frame(
                            width: LangoTraceDesign.Density.minimumTouchTarget,
                            height: LangoTraceDesign.Density.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .accessibilityLabel(localizedText(secretVisibilityLabelKey))
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .background(LangoTraceDesign.ColorToken.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        }
    }

    @ViewBuilder
    private var secretInput: some View {
        if showsSecret {
            TextField(localizedString("syncSettings.s3.secretKey.placeholder"), text: $draft.secretAccessKey)
        } else {
            SecureField(localizedString("syncSettings.s3.secretKey.placeholder"), text: $draft.secretAccessKey)
        }
    }

    private var secretVisibilityLabelKey: String {
        showsSecret ? "syncSettings.s3.secretKey.hide" : "syncSettings.s3.secretKey.show"
    }

    private var securityBoundary: some View {
        LocalizedTextPanel(
            titleKey: "syncSettings.s3.security.title",
            textKey: "syncSettings.s3.security.body"
        )
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            InlineStatusLabel(localizedTextKey: draft.validationState.titleKey, systemImage: "checklist")
            Button {
                dismiss()
            } label: {
                localizedText("syncSettings.s3.close")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel()
    }
}

private struct SyncSettingsTextField: View {
    let titleKey: String
    @Binding var text: String
    let keyboardHint: AIProviderKeyboardHint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText(titleKey)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            TextField(localizedString(titleKey), text: $text)
                .langoSyncTextInput(keyboardHint: keyboardHint)
                .padding(.horizontal, 12)
                .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
                .background(LangoTraceDesign.ColorToken.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        }
    }
}

private extension View {
    @ViewBuilder
    func langoSyncTextInput(keyboardHint: AIProviderKeyboardHint) -> some View {
        #if os(iOS)
            textInputAutocapitalization(.never)
                .keyboardType(keyboardHint.keyboardType)
                .autocorrectionDisabled()
        #else
            self
        #endif
    }

    @ViewBuilder
    func langoInlineS3ModalTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
