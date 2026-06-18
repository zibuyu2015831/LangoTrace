import LangoTraceCore
import SwiftUI

/// Read seam for the request log list. App Shell backs it with the real
/// `GRDBAIRequestLogRepository`; the disabled default returns an empty list so
/// the surface is honest (no fabricated rows) when no store is wired.
public struct AIRequestLogActions: Sendable {
    public var recentEntries: @Sendable () async -> [AIRequestLogEntry]

    public init(recentEntries: @escaping @Sendable () async -> [AIRequestLogEntry]) {
        self.recentEntries = recentEntries
    }

    public static let disabled = AIRequestLogActions(recentEntries: { [] })
}

public extension EnvironmentValues {
    @Entry var aiRequestLogActions = AIRequestLogActions.disabled
}

/// Content-free presentation row for one logged request. There is no content
/// body to display — only time, capability, service, status and (if failed) a
/// coarse failure label.
struct AIRequestLogRowModel: Equatable, Identifiable {
    let id: String
    let capabilityLabel: String
    let providerLabel: String
    let statusLabel: String
    let failureLabel: String?
    let createdAt: Date

    init(entry: AIRequestLogEntry) {
        id = entry.id
        capabilityLabel = Self.capabilityLabel(entry.capability)
        providerLabel = entry.providerPresetID ?? "—"
        statusLabel = Self.statusLabel(entry.status)
        failureLabel = entry.failureBucket.map(Self.failureLabel)
        createdAt = entry.createdAt
    }

    static func capabilityLabel(_ capability: AIRequestCapability) -> String {
        switch capability {
        case .learningMaterialGeneration: localizedString("aiRequestLog.capability.learningMaterialGeneration")
        case .readingSelectionExplanation: localizedString("aiRequestLog.capability.readingSelectionExplanation")
        case .practiceBacktranslationReview: localizedString("aiRequestLog.capability.practiceBacktranslationReview")
        }
    }

    static func statusLabel(_ status: AIRequestLogStatus) -> String {
        switch status {
        case .success: localizedString("aiRequestLog.status.success")
        case .failed: localizedString("aiRequestLog.status.failed")
        case .cancelled: localizedString("aiRequestLog.status.cancelled")
        }
    }

    static func failureLabel(_ bucket: AIRequestLogFailureBucket) -> String {
        switch bucket {
        case .providerNotConfigured: localizedString("aiRequestLog.failure.providerNotConfigured")
        case .credentialMissing: localizedString("aiRequestLog.failure.credentialMissing")
        case .network: localizedString("aiRequestLog.failure.network")
        case .timeout: localizedString("aiRequestLog.failure.timeout")
        case .providerRejected: localizedString("aiRequestLog.failure.providerRejected")
        case .unsupported: localizedString("aiRequestLog.failure.unsupported")
        case .invalidResponse: localizedString("aiRequestLog.failure.invalidResponse")
        case .persistence: localizedString("aiRequestLog.failure.persistence")
        case .unknown: localizedString("aiRequestLog.failure.unknown")
        }
    }
}

/// Shared, real-data-driven request log list. Reachable from settings AI
/// Provider detail and the iPad/macOS inspectors. Renders only the content-free
/// row model; an empty store shows an explicit empty state, never placeholder
/// rows.
struct AIRequestLogListView: View {
    @Environment(\.aiRequestLogActions) private var actions
    @State private var rows: [AIRequestLogRowModel] = []
    @State private var hasLoaded = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                localizedText("aiRequestLog.title")
            } icon: {
                Image(systemName: "list.bullet.rectangle")
            }
            .font(.headline)

            if rows.isEmpty {
                localizedText("aiRequestLog.empty")
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            } else {
                ForEach(rows) { row in
                    rowView(row)
                }
            }
        }
        .langoPanel()
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            let entries = await actions.recentEntries()
            rows = entries.map(AIRequestLogRowModel.init)
        }
    }

    private func rowView(_ row: AIRequestLogRowModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(row.capabilityLabel)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(row.statusLabel)
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            HStack(spacing: 8) {
                Text(row.providerLabel)
                Text(Self.timeFormatter.string(from: row.createdAt))
                if let failureLabel = row.failureLabel {
                    Text(failureLabel)
                }
            }
            .font(.caption)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
