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
        case .invalidVoice:
            "aiProviderSettings.probeCapabilityError.invalidVoice"
        case .unsupportedLanguage:
            "aiProviderSettings.probeCapabilityError.unsupportedLanguage"
        case .unsupportedAudioFormat:
            "aiProviderSettings.probeCapabilityError.unsupportedAudioFormat"
        case .audioDecodeFailed:
            "aiProviderSettings.probeCapabilityError.audioDecodeFailed"
        case .rateLimited:
            "aiProviderSettings.probeCapabilityError.rateLimited"
        case .quotaExceeded:
            "aiProviderSettings.probeCapabilityError.quotaExceeded"
        case .invalidEmbeddingResponse:
            "aiProviderSettings.probeCapabilityError.invalidEmbeddingResponse"
        }
    }
}

struct AIProviderProbeResultPanelContent: View {
    let result: AIProviderConfigurationProbeResult?
    let isTesting: Bool
    let activeCapabilities: [AIProviderProbeCapability]
    let displayedCapabilities: [AIProviderProbeCapability]
    let onRetry: () -> Void
    let onClose: () -> Void
    var onPlaySpeechPreview: @MainActor (TTSAudioPreviewResource) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AIProviderProbeResultChrome(
                titleKey: titleKey,
                iconName: iconName,
                tone: tone,
                isTesting: isTesting,
                onClose: onClose
            )

            AIProviderProbeCapabilityList(
                result: result,
                isTesting: isTesting,
                activeCapabilities: activeCapabilities,
                displayedCapabilities: displayedCapabilities,
                onPlaySpeechPreview: onPlaySpeechPreview
            )

            if !isTesting {
                retryButton
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 20)
        .padding(.bottom, isTesting ? 24 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var retryButton: some View {
        Button(action: onRetry) {
            Label {
                localizedText("aiProviderSettings.probeResult.retry")
            } icon: {
                Image(systemName: "arrow.clockwise")
            }
            .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
            .frame(maxWidth: .infinity, minHeight: LangoTraceDesign.Density.minimumTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(LangoTraceDesign.ColorToken.primaryActionFill)
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

private struct AIProviderProbeResultChrome: View {
    let titleKey: String
    let iconName: String
    let tone: Color
    let isTesting: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(LangoTraceDesign.ColorToken.hairline)
                .frame(width: 42, height: 5)
                .accessibilityHidden(true)

            ZStack {
                HStack {
                    Spacer(minLength: 0)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .frame(
                                width: LangoTraceDesign.Density.minimumTouchTarget,
                                height: LangoTraceDesign.Density.minimumTouchTarget
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    .accessibilityLabel(localizedText("aiProviderSettings.probeResult.close"))
                }

                HStack(spacing: 8) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(tone)
                    } else {
                        Image(systemName: iconName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(tone)
                    }
                    localizedText(titleKey)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AIProviderProbeCapabilityList: View {
    let result: AIProviderConfigurationProbeResult?
    let isTesting: Bool
    let activeCapabilities: [AIProviderProbeCapability]
    let displayedCapabilities: [AIProviderProbeCapability]
    var onPlaySpeechPreview: @MainActor (TTSAudioPreviewResource) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayedCapabilities.enumerated()), id: \.element.rawValue) { index, capability in
                AIProviderProbeCapabilityRow(
                    capability: capability,
                    result: result?.capabilities.first { $0.capability == capability },
                    isTesting: isTesting && activeCapabilities.contains(capability),
                    onPlaySpeechPreview: onPlaySpeechPreview
                )
                if index < displayedCapabilities.count - 1 {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(LangoTraceDesign.ColorToken.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.panel, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
        }
    }
}

private struct AIProviderProbeCapabilityRow: View {
    let capability: AIProviderProbeCapability
    let result: AIProviderProbeCapabilityResult?
    let isTesting: Bool
    var onPlaySpeechPreview: @MainActor (TTSAudioPreviewResource) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tone)
                .frame(width: 24, height: 24)
            localizedText(titleKey)
                .font(.callout.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.ink)
            Spacer(minLength: 0)
            localizedText(statusKey)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            if let previewResource = speechPreviewResource {
                Button {
                    onPlaySpeechPreview(previewResource)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("aiProviderSettings.probeCapability.speechPreview"))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }

    private var speechPreviewResource: TTSAudioPreviewResource? {
        guard capability == .speechSynthesis,
              result?.status == .succeeded
        else {
            return nil
        }
        return result?.audioPreviewResource
    }

    private var titleKey: String {
        switch capability {
        case .textReply:
            "aiProviderSettings.probeCapability.textReply"
        case .structuredJSON:
            "aiProviderSettings.probeCapability.structuredJSON"
        case .languageSupport:
            "aiProviderSettings.probeCapability.languageSupport"
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
                .toggleStyle(.switch)
                .tint(LangoTraceDesign.ColorToken.switchOnFill)
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
                if configuration.purpose == .speech {
                    speechTTSFields
                }
            }
        }
        .langoPanel()
    }

    private var speechTTSFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            AIProviderSectionTitle("aiProviderSettings.speechModel.parametersTitle")
            VStack(alignment: .leading, spacing: 10) {
                speechVoiceControl
                speechFormatControl
                speechSpeedControl
            }
            AIProviderSettingsTextField(
                titleKey: "aiProviderSettings.speechModel.instructionsTitle",
                text: instructionsBinding,
                keyboardHint: .plain
            )
            localizedText("aiProviderSettings.speechModel.instructionsHelp")
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
    }

    @ViewBuilder
    private var speechVoiceControl: some View {
        if configuration.endpoint.provider == .openAI {
            TTSMenuSettingRow(
                titleKey: "aiProviderSettings.speechModel.voiceTitle",
                detailKey: "aiProviderSettings.speechModel.voiceHelp",
                value: configuration.voiceID
            ) {
                ForEach(openAIVoiceIDs, id: \.self) { voiceID in
                    Button {
                        configuration.voiceID = voiceID
                    } label: {
                        Text(voiceID)
                    }
                }
            }
        } else {
            AIProviderSettingsTextField(
                titleKey: "aiProviderSettings.speechModel.voiceTitle",
                text: voiceIDBinding,
                keyboardHint: .plain
            )
        }
    }

    private var speechFormatControl: some View {
        TTSMenuSettingRow(
            titleKey: "aiProviderSettings.speechModel.formatTitle",
            detailKey: "aiProviderSettings.speechModel.formatHelp",
            value: configuration.outputFormat.rawValue.uppercased()
        ) {
            ForEach(TTSAudioFormat.allCases, id: \.rawValue) { format in
                Button {
                    configuration.outputFormat = format
                } label: {
                    Text(format.rawValue.uppercased())
                }
            }
        }
    }

    private var speechSpeedControl: some View {
        TTSSpeedSettingRow(
            titleKey: "aiProviderSettings.speechModel.speedTitle",
            detailKey: "aiProviderSettings.speechModel.speedHelp",
            speed: speedBinding
        )
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

    private var voiceIDBinding: Binding<String> {
        Binding(
            get: { configuration.voiceID },
            set: { configuration.voiceID = $0 }
        )
    }

    private var outputFormatBinding: Binding<TTSAudioFormat> {
        Binding(
            get: { configuration.outputFormat },
            set: { configuration.outputFormat = $0 }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { configuration.speed ?? 1.0 },
            set: { configuration.speed = $0 }
        )
    }

    private var instructionsBinding: Binding<String> {
        Binding(
            get: { configuration.instructions ?? "" },
            set: { configuration.instructions = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    private var openAIVoiceIDs: [String] {
        [
            "alloy",
            "ash",
            "ballad",
            "coral",
            "echo",
            "fable",
            "nova",
            "onyx",
            "sage",
            "shimmer",
            "verse",
            "marin",
            "cedar",
        ]
    }
}

private struct TTSMenuSettingRow<MenuContent: View>: View {
    let titleKey: String
    let detailKey: String
    let value: String
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                localizedText(titleKey)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                localizedText(detailKey)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            Spacer(minLength: 12)
            Menu {
                menuContent()
            } label: {
                HStack(spacing: 5) {
                    Text(value)
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .frame(minHeight: LangoTraceDesign.Density.minimumTouchTarget)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel(localizedText(titleKey))
            .accessibilityValue(Text(value))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(LangoTraceDesign.ColorToken.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
    }
}

private struct TTSSpeedSettingRow: View {
    let titleKey: String
    let detailKey: String
    @Binding var speed: Double

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                localizedText(titleKey)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                localizedText(detailKey)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            Spacer(minLength: 12)
            HStack(spacing: 0) {
                speedButton(systemName: "minus", delta: -0.05)
                Text(String(format: "%.2fx", speed))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    .frame(width: 64, height: LangoTraceDesign.Density.minimumTouchTarget)
                    .accessibilityHidden(true)
                speedButton(systemName: "plus", delta: 0.05)
            }
            .background(LangoTraceDesign.ColorToken.elevatedPaper)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(localizedText(titleKey))
            .accessibilityValue(Text(String(format: "%.2fx", speed)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(LangoTraceDesign.ColorToken.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
    }

    private func speedButton(systemName: String, delta: Double) -> some View {
        Button {
            speed = min(4.0, max(0.25, ((speed + delta) * 100).rounded() / 100))
        } label: {
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .frame(
                    width: LangoTraceDesign.Density.minimumTouchTarget,
                    height: LangoTraceDesign.Density.minimumTouchTarget
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
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
    let imageInputDecision: AIProviderCapabilityDecision
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
            .toggleStyle(.switch)
            .tint(LangoTraceDesign.ColorToken.switchOnFill)
            .disabled(!imageInputDecision.canToggle)
            localizedText(imageInputDecision.explanationKey)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
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
