import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Sync settings")
struct SyncSettingsTests {
    @Test("Draft defaults keep iCloud recommended and object storage advanced")
    func draftDefaultsKeepICloudRecommendedAndObjectStorageAdvanced() {
        let draft = SyncSettingsDraft()

        #expect(draft.status == .previewOnly)
        #expect(draft.methods.map(\.kind) == [.iCloud, .s3Compatible])
        #expect(draft.methods.first?.badge == .recommended)
        #expect(draft.methods.last?.badge == .advanced)
        #expect(draft.methods.first?.actionKey == "syncSettings.method.iCloud.action")
        #expect(draft.methods.last?.actionKey == "syncSettings.method.s3.action")
    }

    @Test("Sync scope separates enabled content attachments and local-only secrets")
    func syncScopeSeparatesEnabledContentAttachmentsAndLocalOnlySecrets() {
        let draft = SyncSettingsDraft()
        let scopes = Dictionary(uniqueKeysWithValues: draft.scopeItems.map { ($0.kind, $0) })

        #expect(scopes[.lifeEntries]?.state == .included)
        #expect(scopes[.learningProgress]?.state == .included)
        #expect(scopes[.promptPresets]?.state == .included)
        #expect(scopes[.aiGeneratedContent]?.state == .included)
        #expect(scopes[.photoAttachments]?.state == .offByDefault)
        #expect(scopes[.audioAttachments]?.state == .offByDefault)
        #expect(scopes[.vectorIndex]?.state == .localRebuild)
        #expect(scopes[.credentials]?.state == .localKeychainOnly)
    }

    @Test("Only attachment scopes can be toggled as local UI drafts")
    func onlyAttachmentScopesCanBeToggledAsLocalUIDrafts() {
        var draft = SyncSettingsDraft()

        #expect(SyncScopeKind.photoAttachments.isUserToggleableDraft)
        #expect(SyncScopeKind.audioAttachments.isUserToggleableDraft)
        #expect(!SyncScopeKind.lifeEntries.isUserToggleableDraft)
        #expect(!SyncScopeKind.vectorIndex.isUserToggleableDraft)
        #expect(!SyncScopeKind.credentials.isUserToggleableDraft)

        draft.setScopeInclusion(.photoAttachments, isIncluded: true)
        draft.setScopeInclusion(.audioAttachments, isIncluded: true)
        draft.setScopeInclusion(.lifeEntries, isIncluded: false)
        draft.setScopeInclusion(.credentials, isIncluded: true)

        let scopes = Dictionary(uniqueKeysWithValues: draft.scopeItems.map { ($0.kind, $0) })
        #expect(scopes[.photoAttachments]?.state == .included)
        #expect(scopes[.audioAttachments]?.state == .included)
        #expect(scopes[.lifeEntries]?.state == .included)
        #expect(scopes[.credentials]?.state == .localKeychainOnly)
    }

    @Test("Sync scope UI uses toggles only for attachment drafts")
    func syncScopeUIUsesTogglesOnlyForAttachmentDrafts() throws {
        let source = try String(
            contentsOf: sourceFileURL(named: "SyncSettingsView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("Toggle(isOn:"))
        #expect(source.contains("bindingForScope"))
        #expect(source.contains("item.kind.isUserToggleableDraft"))
    }

    @Test("Object storage draft validates required fields without saving credentials")
    func objectStorageDraftValidatesRequiredFieldsWithoutSavingCredentials() {
        var draft = S3SyncDraft()

        #expect(draft.provider == .cloudflareR2)
        #expect(draft.pathPrefix == "langotrace/")
        #expect(draft.usesHTTPS)
        #expect(draft.validationState == .missingRequiredFields)

        draft.endpoint = "https://account.r2.cloudflarestorage.com"
        draft.bucket = "langotrace-sync"
        draft.accessKeyID = "access"
        draft.secretAccessKey = "secret"

        #expect(draft.validationState == .completeLocalDraft)
        #expect(draft.secretStorage == .keychainUnavailableInMock)
    }

    @Test("Settings detail routes sync to a dedicated mock UI")
    func settingsDetailRoutesSyncToDedicatedMockUI() throws {
        let detailSource = try String(
            contentsOf: sourceFileURL(named: "SettingsCapabilityDetailView.swift"),
            encoding: .utf8
        )

        #expect(detailSource.contains("capability.kind == .sync"))
        #expect(detailSource.contains("SyncSettingsView"))
        #expect(!detailSource.contains("SyncUnavailableCapabilityView"))
    }

    @Test("Sync settings source avoids real sync side effects")
    func syncSettingsSourceAvoidsRealSyncSideEffects() throws {
        let source = try [
            "SyncSettingsView.swift",
            "SyncS3DraftView.swift",
            "SyncSettingsModels.swift",
        ]
        .map { try String(contentsOf: sourceFileURL(named: $0), encoding: .utf8) }
        .joined(separator: "\n")

        #expect(source.contains("syncSettings.method.iCloud.title"))
        #expect(source.contains("syncSettings.method.s3.title"))
        #expect(source.contains("SecureField"))
        #expect(source.contains("eye.slash"))
        #expect(source.contains("syncSettings.mockBoundary.body"))
        #expect(!source.contains("URLSession"))
        #expect(!source.contains("CKContainer"))
        #expect(!source.contains("CKDatabase"))
        #expect(!source.contains("SecItem"))
        #expect(!source.contains("KeychainAccess"))
        #expect(!source.contains("AWSSDK"))
        #expect(!source.contains("S3Signer"))
        #expect(!source.contains("WebDAV"))
    }

    @Test("Sync settings localization keys resolve to display copy")
    func syncSettingsLocalizationKeysResolveToDisplayCopy() {
        let keys = [
            "syncSettings.status.title",
            "syncSettings.status.previewOnly",
            "syncSettings.method.iCloud.title",
            "syncSettings.method.s3.title",
            "syncSettings.scope.photoAttachments.title",
            "syncSettings.scope.audioAttachments.title",
            "syncSettings.scope.vectorIndex.summary",
            "syncSettings.scope.credentials.summary",
            "syncSettings.iCloudPreview.boundary.body",
            "syncSettings.s3.header.body",
            "syncSettings.s3.secretKey.title",
            "syncSettings.s3.validation.complete",
            "syncSettings.mockBoundary.body",
        ]

        withLocalizedChromeLanguageCode("zh-Hans") {
            for key in keys {
                #expect(localizedString(key) != key)
            }
        }

        withLocalizedChromeLanguageCode("en") {
            for key in keys {
                #expect(localizedString(key) != key)
            }
        }
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
