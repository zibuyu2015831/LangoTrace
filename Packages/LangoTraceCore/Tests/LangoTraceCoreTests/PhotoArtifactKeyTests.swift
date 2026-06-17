import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Photo artifact key and model (E2 Phase 1)")
struct PhotoArtifactKeyTests {
    // MARK: - MediaArtifactType photo cases

    @Test("entryPhotoOriginal type exists in MediaArtifactType")
    func entryPhotoOriginalTypeExists() {
        let rawValues = MediaArtifactType.allCases.map(\.rawValue)
        #expect(rawValues.contains("entryPhotoOriginal"))
    }

    @Test("entryPhotoThumbnail type exists in MediaArtifactType")
    func entryPhotoThumbnailTypeExists() {
        let rawValues = MediaArtifactType.allCases.map(\.rawValue)
        #expect(rawValues.contains("entryPhotoThumbnail"))
    }

    @Test("photoImage derivation kind exists in MediaArtifactDerivationKind")
    func photoImageDerivationKindExists() {
        let rawValues = MediaArtifactDerivationKind.allCases.map(\.rawValue)
        #expect(rawValues.contains("photoImage"))
    }

    // MARK: - Photo original default policy (primary asset semantics)

    @Test("photo original default policy is localOnly excluded excluded")
    func photoOriginalDefaultPolicyIsLocalOnlyExcludedExcluded() {
        let policy = MediaArtifactPolicy.photoOriginalPolicy
        #expect(policy.syncPolicy == .localOnly)
        #expect(policy.backupPolicy == .excludedFromSystemBackup)
        #expect(policy.exportPolicy == .excludedByDefault)
    }

    // MARK: - PhotoArtifactKey

    @Test("PhotoArtifactKey derivation kind is photoImage")
    func photoArtifactKeyDerivationKind() {
        let key = PhotoArtifactKey(
            entryID: "entry-1",
            contentHash: "abc123",
            importedAtBucket: "2026-06-17",
            exifStripped: true
        )
        #expect(key.derivationKind == .photoImage)
    }

    @Test("PhotoArtifactKey derivation key hash is stable across equal keys")
    func photoArtifactKeyHashStable() {
        let key1 = PhotoArtifactKey(
            entryID: "entry-1",
            contentHash: "abc123",
            importedAtBucket: "2026-06-17",
            exifStripped: true
        )
        let key2 = PhotoArtifactKey(
            entryID: "entry-1",
            contentHash: "abc123",
            importedAtBucket: "2026-06-17",
            exifStripped: true
        )
        #expect(key1.derivationKeyHash == key2.derivationKeyHash)
    }

    @Test("PhotoArtifactKey derivation key hash differs when content hash differs")
    func photoArtifactKeyHashDiffersForDifferentContent() {
        let key1 = PhotoArtifactKey(
            entryID: "entry-1",
            contentHash: "abc123",
            importedAtBucket: "2026-06-17",
            exifStripped: true
        )
        let key2 = PhotoArtifactKey(
            entryID: "entry-1",
            contentHash: "xyz789",
            importedAtBucket: "2026-06-17",
            exifStripped: true
        )
        #expect(key1.derivationKeyHash != key2.derivationKeyHash)
    }

    @Test("PhotoArtifactKey derivation key hash differs when exifStripped differs")
    func photoArtifactKeyHashDiffersForExifVariant() {
        let stripped = PhotoArtifactKey(
            entryID: "entry-1",
            contentHash: "abc123",
            importedAtBucket: "2026-06-17",
            exifStripped: true
        )
        let notStripped = PhotoArtifactKey(
            entryID: "entry-1",
            contentHash: "abc123",
            importedAtBucket: "2026-06-17",
            exifStripped: false
        )
        #expect(stripped.derivationKeyHash != notStripped.derivationKeyHash)
    }

    // MARK: - EntryPhotoAttachment model

    @Test("EntryPhotoAttachment initializes with all expected fields")
    func entryPhotoAttachmentFields() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let attachment = EntryPhotoAttachment(
            id: "attach-1",
            entryID: "entry-1",
            spaceID: "space-1",
            originalArtifactID: "artifact-orig",
            thumbnailArtifactID: "artifact-thumb",
            width: 1920,
            height: 1080,
            createdAt: now,
            sortOrder: 0
        )
        #expect(attachment.id == "attach-1")
        #expect(attachment.entryID == "entry-1")
        #expect(attachment.spaceID == "space-1")
        #expect(attachment.originalArtifactID == "artifact-orig")
        #expect(attachment.thumbnailArtifactID == "artifact-thumb")
        #expect(attachment.width == 1920)
        #expect(attachment.height == 1080)
        #expect(attachment.createdAt == now)
        #expect(attachment.sortOrder == 0)
    }

    @Test("EntryPhotoAttachment thumbnailArtifactID can be nil")
    func entryPhotoAttachmentNilThumbnail() {
        let attachment = EntryPhotoAttachment(
            id: "attach-2",
            entryID: "entry-1",
            spaceID: "space-1",
            originalArtifactID: "artifact-orig",
            thumbnailArtifactID: nil,
            width: nil,
            height: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            sortOrder: 0
        )
        #expect(attachment.thumbnailArtifactID == nil)
        #expect(attachment.width == nil)
        #expect(attachment.height == nil)
    }
}
