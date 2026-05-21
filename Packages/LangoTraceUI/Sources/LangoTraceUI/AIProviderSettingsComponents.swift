import LangoTraceCore
import SwiftUI

extension AIProviderConfigurationProbeResult {
    var textProbeCapabilityResults: [AIProviderProbeCapabilityResult] {
        capabilities.filter { capability in
            capability.capability == .textReply || capability.capability == .structuredJSON
        }
    }

    var isUnsupportedTextProbeResult: Bool {
        let results = textProbeCapabilityResults
        return !results.isEmpty && results.allSatisfy { $0.status == .unsupported }
    }

    var primaryProbeFailureCategory: AIProviderValidationErrorCategory? {
        textProbeCapabilityResults.first { $0.errorCategory != nil }?.errorCategory
            ?? capabilities.first { $0.errorCategory != nil }?.errorCategory
    }

    var probePanelTitleKey: String {
        if overallStatus == .succeeded {
            return "aiProviderSettings.testState.succeeded"
        }
        if overallStatus == .cancelled {
            return "aiProviderSettings.testState.cancelled"
        }
        if capabilities.contains(where: { $0.status == .succeeded }) {
            return "aiProviderSettings.testState.partial"
        }
        if isUnsupportedTextProbeResult {
            return "aiProviderSettings.testState.unsupportedProvider"
        }
        return "aiProviderSettings.testState.failed"
    }
}

private extension AIProviderValidationErrorCategory {
    var probeCapabilityStatusKey: String {
        switch self {
        case .missingCredential:
            "aiProviderSettings.probeCapabilityError.missingCredential"
        case .credentialInaccessible:
            "aiProviderSettings.probeCapabilityError.credentialInaccessible"
        case .networkUnavailable:
            "aiProviderSettings.probeCapabilityError.networkUnavailable"
        case .timeout:
            "aiProviderSettings.probeCapabilityError.timeout"
        case .providerRejected:
            "aiProviderSettings.probeCapabilityError.providerRejected"
        case .authenticationFailed:
            "aiProviderSettings.probeCapabilityError.authenticationFailed"
        case .unsupportedModel:
            "aiProviderSettings.probeCapabilityError.unsupportedModel"
        case .unsupportedEndpointPurpose:
            "aiProviderSettings.probeCapabilityError.unsupportedEndpointPurpose"
        case .invalidResponse:
            "aiProviderSettings.probeCapabilityError.invalidResponse"
        case .invalidAudioResponse:
            "aiProviderSettings.probeCapabilityError.invalidAudioResponse"
        case .invalidEmbeddingResponse:
            "aiProviderSettings.probeCapabilityError.invalidEmbeddingResponse"
        }
    }
}

struct AIProviderProbeResultPanelContent: View {
    let result: AIProviderConfigurationProbeResult?
    let isTesting: Bool
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .foregroundStyle(tone)
                    .frame(width: 28, height: 28)
                localizedText(titleKey)
                    .font(.headline)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(
                            width: LangoTraceDesign.Density.minimumTouchTarget,
                            height: LangoTraceDesign.Density.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("aiProviderSettings.probeResult.close"))
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(AIProviderProbeCapability.allCases, id: \.rawValue) { capability in
                    AIProviderProbeCapabilityRow(
                        capability: capability,
                        result: result?.capabilities.first { $0.capability == capability },
                        isTesting: isTesting && (capability == .textReply || capability == .structuredJSON)
                    )
                }
            }

            Button(action: onRetry) {
                Label {
                    localizedText("aiProviderSettings.probeResult.retry")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
                .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTesting)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleKey: String {
        if isTesting {
            return "aiProviderSettings.testState.testing"
        }
        return result?.probePanelTitleKey ?? "aiProviderSettings.probeResult.title"
    }

    private var iconName: String {
        if isTesting {
            return "clock.arrow.circlepath"
        }
        guard let result else {
            return "checkmark.seal"
        }
        if result.overallStatus == .succeeded {
            return "checkmark.circle"
        }
        if result.overallStatus == .cancelled {
            return "xmark.circle"
        }
        if result.capabilities.contains(where: { $0.status == .succeeded }) {
            return "exclamationmark.circle"
        }
        return "exclamationmark.triangle"
    }

    private var tone: Color {
        if isTesting {
            return LangoTraceDesign.ColorToken.accent
        }
        guard let result else {
            return LangoTraceDesign.ColorToken.textSecondary
        }
        if result.overallStatus == .succeeded {
            return LangoTraceDesign.ColorToken.stateReady
        }
        if result.overallStatus == .cancelled {
            return LangoTraceDesign.ColorToken.textSecondary
        }
        if result.capabilities.contains(where: { $0.status == .succeeded }) {
            return LangoTraceDesign.ColorToken.warning
        }
        return LangoTraceDesign.ColorToken.danger
    }
}

private struct AIProviderProbeCapabilityRow: View {
    let capability: AIProviderProbeCapability
    let result: AIProviderProbeCapabilityResult?
    let isTesting: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(tone)
                .frame(width: 24, height: 24)
            localizedText(titleKey)
                .font(.callout.weight(.semibold))
            Spacer(minLength: 0)
            localizedText(statusKey)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
    }

    private var titleKey: String {
        switch capability {
        case .textReply:
            "aiProviderSettings.probeCapability.textReply"
        case .structuredJSON:
            "aiProviderSettings.probeCapability.structuredJSON"
        case .imageUnderstanding:
            "aiProviderSettings.probeCapability.imageUnderstanding"
        case .speechSynthesis:
            "aiProviderSettings.probeCapability.speechSynthesis"
        case .embedding:
            "aiProviderSettings.probeCapability.embedding"
        }
    }

    private var statusKey: String {
        if isTesting {
            return "aiProviderSettings.probeCapabilityStatus.testing"
        }
        return switch result?.status ?? .notRun {
        case .notConfigured:
            "aiProviderSettings.probeCapabilityStatus.notConfigured"
        case .notEnabled:
            "aiProviderSettings.probeCapabilityStatus.notEnabled"
        case .testing:
            "aiProviderSettings.probeCapabilityStatus.testing"
        case .succeeded:
            "aiProviderSettings.probeCapabilityStatus.succeeded"
        case .failed:
            result?.errorCategory?.probeCapabilityStatusKey ?? "aiProviderSettings.probeCapabilityStatus.failed"
        case .cancelled:
            "aiProviderSettings.probeCapabilityStatus.cancelled"
        case .unsupported:
            "aiProviderSettings.probeCapabilityStatus.unsupported"
        case .notRun:
            "aiProviderSettings.probeCapabilityStatus.notRun"
        }
    }

    private var iconName: String {
        if isTesting {
            return "clock"
        }
        return switch result?.status ?? .notRun {
        case .succeeded:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        case .cancelled:
            "xmark.circle"
        case .unsupported, .notEnabled, .notConfigured, .notRun:
            "minus.circle"
        case .testing:
            "clock"
        }
    }

    private var tone: Color {
        if isTesting {
            return LangoTraceDesign.ColorToken.accent
        }
        return switch result?.status ?? .notRun {
        case .succeeded:
            LangoTraceDesign.ColorToken.stateReady
        case .failed:
            LangoTraceDesign.ColorToken.danger
        case .cancelled:
            LangoTraceDesign.ColorToken.textSecondary
        case .unsupported:
            LangoTraceDesign.ColorToken.warning
        case .notConfigured, .notEnabled, .notRun, .testing:
            LangoTraceDesign.ColorToken.textSecondary
        }
    }
}

struct AIProviderOptionalModelSection: View {
    let titleKey: String
    let enabledKey: String
    let modelTitleKey: String
    let textProvider: AIProviderPreset
    @Binding var configuration: AIOptionalModelDraftConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                AIProviderSectionTitle(titleKey)
                Spacer(minLength: 0)
                Toggle(isOn: $configuration.isEnabled) {
                    localizedText(enabledKey)
                }
                .labelsHidden()
            }
            if configuration.isEnabled {
                AIProviderEndpointFields(
                    provider: providerBinding,
                    baseURL: baseURLBinding,
                    model: modelBinding,
                    modelTitleKey: modelTitleKey
                )
                credentialReferencePicker
                if configuration.endpoint.credentialReference == .independent {
                    AIProviderAPIKeyField(text: independentAPIKeyBinding)
                }
            }
        }
        .langoPanel()
    }

    private var credentialReferencePicker: some View {
        Picker(selection: credentialReferenceBinding) {
            localizedText("aiProviderSettings.apiKey.useText")
                .tag(AIProviderCredentialReference.textModelCredential)
            localizedText("aiProviderSettings.apiKey.useIndependent")
                .tag(AIProviderCredentialReference.independent)
        } label: {
            localizedText("aiProviderSettings.apiKey.title")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
    }

    private var providerBinding: Binding<AIProviderPreset> {
        Binding(
            get: { configuration.endpoint.provider },
            set: { provider in
                configuration.updateProvider(
                    provider,
                    shareTextCredentialWhenSameProvider: provider == textProvider
                )
            }
        )
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { configuration.endpoint.baseURL },
            set: { configuration.endpoint.baseURL = $0 }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { configuration.endpoint.model },
            set: { configuration.endpoint.model = $0 }
        )
    }

    private var credentialReferenceBinding: Binding<AIProviderCredentialReference> {
        Binding(
            get: { configuration.endpoint.credentialReference },
            set: { configuration.endpoint.credentialReference = $0 }
        )
    }

    private var independentAPIKeyBinding: Binding<String> {
        Binding(
            get: { configuration.endpoint.independentCredential.apiKeyDraft },
            set: { configuration.endpoint.independentCredential.apiKeyDraft = $0 }
        )
    }
}

struct AIProviderEndpointFields: View {
    @Binding var provider: AIProviderPreset
    @Binding var baseURL: String
    @Binding var model: String
    let modelTitleKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AIProviderRowPicker(provider: $provider)
            AIProviderSettingsTextField(
                titleKey: "aiProviderSettings.baseURL.title",
                text: $baseURL,
                keyboardHint: .url
            )
            AIProviderSettingsTextField(
                titleKey: modelTitleKey,
                text: $model,
                keyboardHint: .plain
            )
        }
    }
}

struct AIProviderRowPicker: View {
    @Binding var provider: AIProviderPreset

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            localizedText("aiProviderSettings.provider.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)

            Menu {
                ForEach(AIProviderPreset.allCases) { provider in
                    Button {
                        self.provider = provider
                    } label: {
                        Text(provider.displayName)
                    }
                }
            } label: {
                selectedProviderLabel
            }
            .tint(LangoTraceDesign.ColorToken.accent)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(localizedText("aiProviderSettings.provider.picker"))
            .accessibilityValue(Text(provider.displayName))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
    }

    private var selectedProviderLabel: some View {
        HStack(spacing: 4) {
            Text(provider.displayName)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .truncationMode(.tail)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
        }
        .font(.callout)
        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct AIProviderCapabilityBoundaryView: View {
    let supportsImageUnderstanding: Bool
    @Binding var imageUnderstandingEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIProviderSectionTitle("aiProviderSettings.capabilities.title")
            AIProviderLockedCapabilityRow(
                titleKey: "aiProviderSettings.capability.chat",
                statusKey: "aiProviderSettings.capability.enabled"
            )
            Toggle(isOn: $imageUnderstandingEnabled) {
                localizedText("aiProviderSettings.capability.image")
                    .font(.callout.weight(.semibold))
            }
            .disabled(!supportsImageUnderstanding)
            if !supportsImageUnderstanding {
                localizedText("aiProviderSettings.capability.unsupported")
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
    }
}

private struct AIProviderLockedCapabilityRow: View {
    let titleKey: String
    let statusKey: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            localizedText(titleKey)
                .font(.callout.weight(.semibold))
            Spacer(minLength: 0)
            localizedText(statusKey)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
    }
}

struct AIProviderAPIKeyField: View {
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText("aiProviderSettings.apiKey.title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            HStack(spacing: 8) {
                Group {
                    if isVisible {
                        TextField(localizedString("aiProviderSettings.apiKey.placeholder"), text: $text)
                    } else {
                        SecureField(localizedString("aiProviderSettings.apiKey.placeholder"), text: $text)
                    }
                }
                .langoProviderTextInput(keyboardHint: .plain)
                .font(.body.monospaced())

                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .frame(
                            width: LangoTraceDesign.Density.minimumTouchTarget,
                            height: LangoTraceDesign.Density.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .accessibilityLabel(localizedText(visibilityLabelKey))
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            .background(LangoTraceDesign.ColorToken.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        }
    }

    private var visibilityLabelKey: String {
        isVisible ? "aiProviderSettings.apiKey.hide" : "aiProviderSettings.apiKey.show"
    }
}

struct AIProviderSectionTitle: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        localizedText(key)
            .font(.caption.weight(.bold))
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
    }
}

struct AIProviderSettingsTextField: View {
    let titleKey: String
    @Binding var text: String
    let keyboardHint: AIProviderKeyboardHint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            localizedText(titleKey)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            TextField("", text: $text)
                .langoProviderTextInput(keyboardHint: keyboardHint)
                .font(.body.monospaced())
                .padding(12)
                .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
                .background(LangoTraceDesign.ColorToken.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        }
    }
}

extension View {
    @ViewBuilder
    func langoProviderTextInput(keyboardHint: AIProviderKeyboardHint) -> some View {
        #if os(iOS)
            textInputAutocapitalization(.never)
                .keyboardType(keyboardHint.keyboardType)
                .autocorrectionDisabled()
        #else
            self
        #endif
    }
}

enum AIProviderKeyboardHint {
    case plain
    case url

    #if os(iOS)
        var keyboardType: UIKeyboardType {
            switch self {
            case .plain:
                .default
            case .url:
                .URL
            }
        }
    #endif
}
