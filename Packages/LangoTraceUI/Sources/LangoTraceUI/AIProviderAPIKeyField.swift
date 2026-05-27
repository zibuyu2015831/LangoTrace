import LangoTraceCore
import SwiftUI

struct AIProviderAPIKeyField: View {
    @Binding var text: String
    var savedCredential: AIProviderCredentialMetadata?
    var onRevealSavedCredential: (() async -> AIProviderCredentialRevealResult)?
    @State private var isVisible = false
    @State private var revealState: AIProviderCredentialRevealState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText("aiProviderSettings.apiKey.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            HStack(spacing: 8) {
                Group {
                    if isVisible {
                        TextField(localizedString(presentation.placeholderKey), text: $text)
                    } else {
                        SecureField(localizedString(presentation.placeholderKey), text: $text)
                    }
                }
                .langoProviderTextInput(keyboardHint: .plain)
                .font(.body.monospaced())

                Button {
                    revealOrToggleVisibility()
                } label: {
                    Image(systemName: visibilityIconName)
                        .frame(
                            width: LangoTraceDesign.Density.minimumTouchTarget,
                            height: LangoTraceDesign.Density.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .disabled(revealState == .authenticating)
                .accessibilityLabel(localizedText(visibilityLabelKey))
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .background(LangoTraceDesign.ColorToken.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))

            if let helperKey = presentation.helperKey {
                localizedText(helperKey)
                    .font(.footnote)
                    .foregroundStyle(helperTone)
            }
        }
        .onChange(of: text) {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                revealState = isVisible ? .revealedVisible : .revealedHidden
            }
        }
    }

    private var presentation: AIProviderAPIKeyFieldPresentation {
        AIProviderAPIKeyFieldPresentation(
            text: text,
            hasSavedCredential: savedCredential != nil,
            revealState: revealState
        )
    }

    private var visibilityLabelKey: String {
        isVisible ? "aiProviderSettings.apiKey.hide" : "aiProviderSettings.apiKey.show"
    }

    private var visibilityIconName: String {
        isVisible ? "eye.slash" : "eye"
    }

    private var helperTone: Color {
        switch revealState {
        case .failed, .cancelled:
            LangoTraceDesign.ColorToken.danger
        case .idle, .authenticating, .revealedVisible, .revealedHidden:
            LangoTraceDesign.ColorToken.textSecondary
        }
    }

    private func revealOrToggleVisibility() {
        guard presentation.shouldResolveSavedCredential,
              let onRevealSavedCredential,
              !isVisible
        else {
            isVisible.toggle()
            revealState = isVisible ? .revealedVisible : .revealedHidden
            return
        }

        revealState = .authenticating
        Task { @MainActor in
            switch await onRevealSavedCredential() {
            case let .succeeded(secret):
                text = secret
                isVisible = true
                revealState = .revealedVisible
            case .failed(.cancelled):
                isVisible = false
                revealState = .cancelled
            case let .failed(failure):
                isVisible = false
                revealState = .failed(failure)
            }
        }
    }
}
