import Foundation
import SwiftUI

enum SyncSettingsLayoutMode: Equatable {
    case stacked
    case regularColumns

    static func resolve(
        availableWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> SyncSettingsLayoutMode {
        if horizontalSizeClass == .compact {
            return .stacked
        }

        return availableWidth >= 760 ? .regularColumns : .stacked
    }
}

enum SyncSettingsStatus: Equatable {
    case previewOnly

    var titleKey: String {
        switch self {
        case .previewOnly:
            "syncSettings.status.previewOnly"
        }
    }
}

enum SyncMethodKind: Equatable {
    case iCloud
    case s3Compatible
}

enum SyncMethodBadge: Equatable {
    case recommended
    case advanced

    var titleKey: String {
        switch self {
        case .recommended:
            "syncSettings.badge.recommended"
        case .advanced:
            "syncSettings.badge.advanced"
        }
    }
}

struct SyncMethodOption: Equatable, Identifiable {
    let kind: SyncMethodKind
    let badge: SyncMethodBadge
    let titleKey: String
    let summaryKey: String
    let actionKey: String
    let systemImage: String

    var id: SyncMethodKind {
        kind
    }
}

enum SyncScopeKind: Equatable {
    case lifeEntries
    case learningProgress
    case promptPresets
    case aiGeneratedContent
    case photoAttachments
    case audioAttachments
    case vectorIndex
    case credentials

    var isUserToggleableDraft: Bool {
        switch self {
        case .photoAttachments, .audioAttachments:
            true
        case .lifeEntries, .learningProgress, .promptPresets, .aiGeneratedContent, .vectorIndex, .credentials:
            false
        }
    }

    var systemImage: String {
        switch self {
        case .lifeEntries:
            "doc.text"
        case .learningProgress:
            "chart.line.uptrend.xyaxis"
        case .promptPresets:
            "text.badge.star"
        case .aiGeneratedContent:
            "sparkles"
        case .photoAttachments:
            "photo"
        case .audioAttachments:
            "waveform"
        case .vectorIndex:
            "arrow.clockwise"
        case .credentials:
            "lock.fill"
        }
    }
}

enum SyncScopeState: Equatable {
    case included
    case offByDefault
    case localRebuild
    case localKeychainOnly

    var titleKey: String {
        switch self {
        case .included:
            "syncSettings.scope.state.included"
        case .offByDefault:
            "syncSettings.scope.state.offByDefault"
        case .localRebuild:
            "syncSettings.scope.state.localRebuild"
        case .localKeychainOnly:
            "syncSettings.scope.state.localOnly"
        }
    }

    var systemImage: String {
        switch self {
        case .included:
            "checkmark.circle.fill"
        case .offByDefault:
            "circle"
        case .localRebuild:
            "arrow.clockwise"
        case .localKeychainOnly:
            "lock.fill"
        }
    }
}

struct SyncScopeItem: Equatable, Identifiable {
    let kind: SyncScopeKind
    let titleKey: String
    let summaryKey: String
    var state: SyncScopeState

    var id: SyncScopeKind {
        kind
    }
}

struct SyncSettingsDraft: Equatable {
    var status: SyncSettingsStatus
    var methods: [SyncMethodOption]
    var scopeItems: [SyncScopeItem]

    init() {
        status = .previewOnly
        methods = Self.defaultMethods
        scopeItems = Self.defaultScopeItems
    }

    mutating func setScopeInclusion(_ kind: SyncScopeKind, isIncluded: Bool) {
        guard kind.isUserToggleableDraft,
              let index = scopeItems.firstIndex(where: { $0.kind == kind })
        else {
            return
        }

        scopeItems[index].state = isIncluded ? .included : .offByDefault
    }

    private static let defaultMethods = [
        SyncMethodOption(
            kind: .iCloud,
            badge: .recommended,
            titleKey: "syncSettings.method.iCloud.title",
            summaryKey: "syncSettings.method.iCloud.summary",
            actionKey: "syncSettings.method.iCloud.action",
            systemImage: "icloud"
        ),
        SyncMethodOption(
            kind: .s3Compatible,
            badge: .advanced,
            titleKey: "syncSettings.method.s3.title",
            summaryKey: "syncSettings.method.s3.summary",
            actionKey: "syncSettings.method.s3.action",
            systemImage: "externaldrive.connected.to.line.below"
        ),
    ]

    private static let defaultScopeItems = [
        scopeItem(.lifeEntries, state: .included),
        scopeItem(.learningProgress, state: .included),
        scopeItem(.promptPresets, state: .included),
        scopeItem(.aiGeneratedContent, state: .included),
        scopeItem(.photoAttachments, state: .offByDefault),
        scopeItem(.audioAttachments, state: .offByDefault),
        scopeItem(.vectorIndex, state: .localRebuild),
        scopeItem(.credentials, state: .localKeychainOnly),
    ]

    private static func scopeItem(_ kind: SyncScopeKind, state: SyncScopeState) -> SyncScopeItem {
        SyncScopeItem(
            kind: kind,
            titleKey: "syncSettings.scope.\(kind.keyPathComponent).title",
            summaryKey: "syncSettings.scope.\(kind.keyPathComponent).summary",
            state: state
        )
    }
}

private extension SyncScopeKind {
    var keyPathComponent: String {
        switch self {
        case .lifeEntries:
            "lifeEntries"
        case .learningProgress:
            "learningProgress"
        case .promptPresets:
            "promptPresets"
        case .aiGeneratedContent:
            "aiGeneratedContent"
        case .photoAttachments:
            "photoAttachments"
        case .audioAttachments:
            "audioAttachments"
        case .vectorIndex:
            "vectorIndex"
        case .credentials:
            "credentials"
        }
    }
}

enum S3SyncProvider: String, CaseIterable, Identifiable, Equatable {
    case awsS3
    case cloudflareR2
    case minIO
    case custom

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .awsS3:
            "AWS S3"
        case .cloudflareR2:
            "Cloudflare R2"
        case .minIO:
            "MinIO"
        case .custom:
            "Custom S3-compatible"
        }
    }

    var defaultPathStyleAccess: Bool {
        switch self {
        case .minIO, .custom:
            true
        case .awsS3, .cloudflareR2:
            false
        }
    }
}

enum S3DraftSecretStorage: Equatable {
    case keychainUnavailableInMock
}

enum S3DraftValidationState: Equatable {
    case missingRequiredFields
    case completeLocalDraft

    var titleKey: String {
        switch self {
        case .missingRequiredFields:
            "syncSettings.s3.validation.missing"
        case .completeLocalDraft:
            "syncSettings.s3.validation.complete"
        }
    }
}

struct S3SyncDraft: Equatable {
    var provider: S3SyncProvider
    var endpoint: String
    var region: String
    var bucket: String
    var pathPrefix: String
    var accessKeyID: String
    var secretAccessKey: String
    var usesHTTPS: Bool
    var usesPathStyleAccess: Bool
    let secretStorage: S3DraftSecretStorage

    init(provider: S3SyncProvider = .cloudflareR2) {
        self.provider = provider
        endpoint = ""
        region = provider == .cloudflareR2 ? "auto" : ""
        bucket = ""
        pathPrefix = "langotrace/"
        accessKeyID = ""
        secretAccessKey = ""
        usesHTTPS = true
        usesPathStyleAccess = provider.defaultPathStyleAccess
        secretStorage = .keychainUnavailableInMock
    }

    var validationState: S3DraftValidationState {
        let requiredFields = [endpoint, bucket, accessKeyID, secretAccessKey]
        return requiredFields.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            ? .completeLocalDraft
            : .missingRequiredFields
    }

    mutating func updateProvider(_ provider: S3SyncProvider) {
        self.provider = provider
        if provider == .cloudflareR2, region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            region = "auto"
        }
        usesPathStyleAccess = provider.defaultPathStyleAccess
    }
}
