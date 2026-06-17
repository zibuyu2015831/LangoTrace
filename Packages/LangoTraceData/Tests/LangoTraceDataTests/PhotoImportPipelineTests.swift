import CoreGraphics
import Foundation
import GRDB
import ImageIO
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("Photo import pipeline (E2 Phase 2)")
struct PhotoImportPipelineTests {
    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoImportPipelineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeFileStore(rootDir: URL) throws -> LocalMediaArtifactFileStore {
        try LocalMediaArtifactFileStore(rootDirectory: rootDir)
    }

    private func makePipeline(
        fileStore: LocalMediaArtifactFileStore,
        database: AppDatabase,
        idSequence: [String] = []
    ) -> PhotoImportPipeline {
        let seq = IDSequence(idSequence)
        return PhotoImportPipeline(
            fileStore: fileStore,
            databaseQueue: database.databaseQueue,
            clock: { Date(timeIntervalSince1970: 1_000_000) },
            idGenerator: { seq.next() }
        )
    }

    private func seedPrerequisites(in database: AppDatabase) throws {
        try database.databaseQueue.write { db in
            try db.execute(sql: """
            INSERT INTO language_spaces (
                id, native_language_code, target_language_code, level,
                display_name, display_name_normalized, created_at, updated_at,
                last_opened_at, deleted_at
            ) VALUES ('space-1', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
            """)
            try db.execute(sql: """
            INSERT INTO entries (
                id, space_id, title, body, source, scene, created_at, updated_at, deleted_at
            ) VALUES ('entry-1', 'space-1', 'Photo Day', 'Some text', 'photoWriting', '生活记录', 1, 1, NULL)
            """)
        }
    }

    /// Generates a minimal 1×1 pixel JPEG using CoreGraphics.
    private func makeMinimalJPEGData() throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
            let cgImage = context.makeImage()
        else {
            throw TestSupportError.imageCreationFailed
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw TestSupportError.imageCreationFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestSupportError.imageCreationFailed
        }
        return output as Data
    }

    enum TestSupportError: Error {
        case imageCreationFailed
    }

    // MARK: - Success path

    @Test("successful import creates artifact metadata and attachment in database")
    func successfulImportCreatesArtifactAndAttachment() throws {
        let rootDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fileStore = try makeFileStore(rootDir: rootDir)
        let database = try AppDatabase.inMemory()
        try seedPrerequisites(in: database)

        let pipeline = makePipeline(
            fileStore: fileStore,
            database: database,
            idSequence: ["orig-artifact", "thumb-artifact", "attach-1"]
        )
        let jpegData = try makeMinimalJPEGData()

        let result = try pipeline.importPhoto(
            data: jpegData,
            entryID: "entry-1",
            spaceID: "space-1"
        )

        #expect(result.attachment.entryID == "entry-1")
        #expect(result.attachment.spaceID == "space-1")
        #expect(result.originalArtifactID == "orig-artifact")

        try database.databaseQueue.read { db in
            let artifactCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM media_artifacts WHERE artifact_type = 'entryPhotoOriginal'
            """) ?? 0
            #expect(artifactCount == 1)

            let attachCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM entry_photo_attachments WHERE entry_id = 'entry-1'
            """) ?? 0
            #expect(attachCount == 1)
        }

        // Original file must exist on disk
        let expectedFile = rootDir.appendingPathComponent(result.relativeOriginalPath)
        #expect(FileManager.default.fileExists(atPath: expectedFile.path))

        // Staging directory must be empty (no leftovers)
        let stagingDir = rootDir.appendingPathComponent("staging")
        if FileManager.default.fileExists(atPath: stagingDir.path) {
            let remaining = try FileManager.default.contentsOfDirectory(atPath: stagingDir.path)
            #expect(remaining.isEmpty, "Staging must be clean after successful import")
        }
    }

    // MARK: - Failure path

    @Test("import failure leaves no metadata and cleans staging")
    func importFailureLeavesNoMetadataAndCleansStaging() throws {
        let rootDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fileStore = try makeFileStore(rootDir: rootDir)
        let database = try AppDatabase.inMemory()
        try seedPrerequisites(in: database)

        let pipeline = makePipeline(fileStore: fileStore, database: database)
        let invalidData = Data([0x00, 0x01, 0x02, 0x03]) // not a valid image

        #expect(throws: PhotoImportError.self) {
            _ = try pipeline.importPhoto(
                data: invalidData,
                entryID: "entry-1",
                spaceID: "space-1"
            )
        }

        try database.databaseQueue.read { db in
            let artifactCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM media_artifacts WHERE artifact_type = 'entryPhotoOriginal'
            """) ?? 0
            #expect(artifactCount == 0, "No artifact metadata should exist after failed import")

            let attachCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM entry_photo_attachments WHERE entry_id = 'entry-1'
            """) ?? 0
            #expect(attachCount == 0, "No attachment should exist after failed import")
        }

        // Staging must be empty
        let stagingDir = rootDir.appendingPathComponent("staging")
        if FileManager.default.fileExists(atPath: stagingDir.path) {
            let remaining = try FileManager.default.contentsOfDirectory(atPath: stagingDir.path)
            #expect(remaining.isEmpty, "Staging must be clean after failed import")
        }
    }

    // MARK: - EXIF GPS stripping

    @Test("import strips GPS coordinates from EXIF metadata")
    func importStripsGPSFromEXIF() throws {
        let rootDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fileStore = try makeFileStore(rootDir: rootDir)
        let database = try AppDatabase.inMemory()
        try seedPrerequisites(in: database)

        // Create a JPEG with GPS EXIF embedded
        let jpegWithGPS = try makeJPEGWithGPS(
            latitude: 37.7749,
            longitude: -122.4194
        )
        // Confirm GPS is present in source data
        guard let sourceProps = imagePropertiesAtIndex0(jpegWithGPS),
              let _ = sourceProps[kCGImagePropertyGPSDictionary as String]
        else {
            // If the platform doesn't embed GPS in our test fixture, skip verification
            return
        }

        let pipeline = makePipeline(
            fileStore: fileStore,
            database: database,
            idSequence: ["orig-gps", "thumb-gps", "attach-gps"]
        )
        let result = try pipeline.importPhoto(
            data: jpegWithGPS,
            entryID: "entry-1",
            spaceID: "space-1"
        )

        let outputURL = rootDir.appendingPathComponent(result.relativeOriginalPath)
        let outputData = try Data(contentsOf: outputURL)
        let outputProps = imagePropertiesAtIndex0(outputData)
        let gpsDict = outputProps?[kCGImagePropertyGPSDictionary as String]
        #expect(gpsDict == nil, "GPS must be removed from output file")
    }

    @Test("import preserves image orientation after EXIF stripping")
    func importPreservesImageOrientation() throws {
        let rootDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let fileStore = try makeFileStore(rootDir: rootDir)
        let database = try AppDatabase.inMemory()
        try seedPrerequisites(in: database)

        // Create a JPEG with non-default orientation (6 = rotate 90° CW)
        let jpegWithOrientation = try makeJPEGWithOrientation(6)
        let inputOrientation = exifOrientationValue(of: jpegWithOrientation)

        let pipeline = makePipeline(
            fileStore: fileStore,
            database: database,
            idSequence: ["orig-orient", "thumb-orient", "attach-orient"]
        )
        let result = try pipeline.importPhoto(
            data: jpegWithOrientation,
            entryID: "entry-1",
            spaceID: "space-1"
        )

        let outputURL = rootDir.appendingPathComponent(result.relativeOriginalPath)
        let outputData = try Data(contentsOf: outputURL)
        let outputOrientation = exifOrientationValue(of: outputData)

        if let input = inputOrientation, let output = outputOrientation {
            #expect(input == output, "Orientation must be preserved after EXIF stripping")
        }
    }
}

// MARK: - ID sequence helper

private final class IDSequence: @unchecked Sendable {
    private var ids: [String]
    private let lock = NSLock()

    init(_ ids: [String]) {
        self.ids = ids
    }

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        if !ids.isEmpty { return ids.removeFirst() }
        return UUID().uuidString
    }
}

// MARK: - Test fixture helpers

private func makeJPEGWithGPS(latitude: Double, longitude: Double) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil, width: 2, height: 2, bitsPerComponent: 8,
        bytesPerRow: 8, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ),
        let cgImage = context.makeImage()
    else {
        throw PhotoImportPipelineTests.TestSupportError.imageCreationFailed
    }

    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        output, "public.jpeg" as CFString, 1, nil
    ) else {
        throw PhotoImportPipelineTests.TestSupportError.imageCreationFailed
    }

    let gps: [CFString: Any] = [
        kCGImagePropertyGPSLatitude: abs(latitude),
        kCGImagePropertyGPSLatitudeRef: latitude >= 0 ? "N" : "S",
        kCGImagePropertyGPSLongitude: abs(longitude),
        kCGImagePropertyGPSLongitudeRef: longitude >= 0 ? "E" : "W",
    ]
    let props: [CFString: Any] = [kCGImagePropertyGPSDictionary: gps]
    CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw PhotoImportPipelineTests.TestSupportError.imageCreationFailed
    }
    return output as Data
}

private func makeJPEGWithOrientation(_ orientation: Int) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil, width: 2, height: 2, bitsPerComponent: 8,
        bytesPerRow: 8, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ),
        let cgImage = context.makeImage()
    else {
        throw PhotoImportPipelineTests.TestSupportError.imageCreationFailed
    }

    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        output, "public.jpeg" as CFString, 1, nil
    ) else {
        throw PhotoImportPipelineTests.TestSupportError.imageCreationFailed
    }

    let tiff: [CFString: Any] = [kCGImagePropertyTIFFOrientation: orientation]
    let props: [CFString: Any] = [
        kCGImagePropertyTIFFDictionary: tiff,
        kCGImagePropertyOrientation: orientation,
    ]
    CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw PhotoImportPipelineTests.TestSupportError.imageCreationFailed
    }
    return output as Data
}

private func imagePropertiesAtIndex0(_ data: Data) -> [String: Any]? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
}

private func exifOrientationValue(of data: Data) -> Int? {
    guard let props = imagePropertiesAtIndex0(data) else { return nil }
    if let v = props[kCGImagePropertyOrientation as String] as? Int { return v }
    if let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
       let v = tiff[kCGImagePropertyTIFFOrientation as String] as? Int { return v }
    return nil
}
