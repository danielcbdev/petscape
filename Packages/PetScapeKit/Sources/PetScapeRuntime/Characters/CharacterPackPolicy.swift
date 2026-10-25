import CoreGraphics
import Foundation
import ImageIO
import PetScapeCore
import PetScapeRendering

public enum CharacterPackImportError: Error, Equatable, Sendable {
    case cancelled
    case invalidPack
    case unsafePack
    case resourceLimit
    case duplicateBundledID
    case duplicateInstalledID
    case storageUnavailable
    case installationFailed
}

struct CharacterPackSnapshot: Sendable {
    let manifestData: Data
    let images: [String: Data]
}

struct ValidatedCharacterPack: Sendable {
    let id: CharacterID
    let displayName: String
    let definition: CharacterDefinition
    let manifestData: Data
    let images: [String: Data]
}

/// The stricter resource profile applied to user-selected packs. Bundled packs retain their existing policy.
enum CharacterPackPolicy {
    nonisolated static let maximumManifestBytes = 256 * 1024
    nonisolated static let maximumTreeEntries = 2_048
    nonisolated static let maximumTreeDepth = 32
    nonisolated static let maximumClipCount = 64
    nonisolated static let maximumFrameCount = 512
    nonisolated static let maximumSheetCount = 64
    nonisolated static let maximumSheetColumns = 16
    nonisolated static let maximumSheetRows = 16
    nonisolated static let maximumReferencedImageCount = 256
    nonisolated static let maximumImageFileBytes = 4 * 1024 * 1024
    nonisolated static let maximumReferencedBytes = 64 * 1024 * 1024
    nonisolated static let maximumSourceImageDimension = 4_096
    nonisolated static let maximumTargetPixelSide = 768
    nonisolated static let maximumDecodedBytes = 64 * 1024 * 1024
    nonisolated static let maximumIDLength = 64
    nonisolated static let maximumDisplayNameLength = 80
    nonisolated static let maximumPathBytes = 512
    nonisolated static let maximumPathComponentBytes = 128

    nonisolated private enum ImageRole: Equatable, Sendable {
        case frame
        case sheet(columns: Int, rows: Int)
    }

    nonisolated static func resourcePaths(in manifestData: Data) throws(CharacterPackImportError) -> [String] {
        guard manifestData.count <= maximumManifestBytes else { throw .resourceLimit }
        let decoded = try decodeManifest(manifestData)
        return try imageRoles(in: decoded.manifest).keys.sorted()
    }

    static func validate(_ snapshot: CharacterPackSnapshot) async throws(CharacterPackImportError)
        -> ValidatedCharacterPack
    {
        let decoded = try decodeManifest(snapshot.manifestData)
        let manifest = decoded.manifest
        guard ManifestValidator.isValidIdentifier(manifest.id),
            manifest.id.utf8.count <= maximumIDLength
        else { throw .invalidPack }
        let roles = try imageRoles(in: manifest)

        guard !roles.isEmpty, roles.count <= maximumReferencedImageCount,
            snapshot.images.count == roles.count,
            Set(snapshot.images.keys) == Set(roles.keys)
        else { throw .resourceLimit }

        let normalizedPaths = roles.keys.map { $0.precomposedStringWithCanonicalMapping.lowercased() }
        guard Set(normalizedPaths).count == normalizedPaths.count else { throw .unsafePack }

        let structural = ManifestValidator.validate(decoded)
        guard !structural.issues.contains(where: { $0.severity == .error }) else { throw .invalidPack }

        let targetPixelSide = FrameImageStore.targetPixelSize(for: manifest.displaySize)
        guard targetPixelSide > 0, targetPixelSide <= maximumTargetPixelSide else { throw .resourceLimit }

        let decoder = ImageDecoder()
        var probes: [String: ImageProbe] = [:]
        var referencedBytes = 0
        var decodedBytes = 0
        for path in roles.keys.sorted() {
            guard let data = snapshot.images[path] else { throw .invalidPack }
            guard data.count <= maximumImageFileBytes else { throw .resourceLimit }
            referencedBytes += data.count
            guard referencedBytes <= maximumReferencedBytes else { throw .resourceLimit }

            let dimensions = try sourceDimensions(in: data)
            guard dimensions.width <= maximumSourceImageDimension,
                dimensions.height <= maximumSourceImageDimension
            else { throw .resourceLimit }
            let decodeSide = try decodeSide(for: roles[path] ?? .frame, data: data, targetPixelSide: targetPixelSide)
            let decodedImage: DecodedImage
            do {
                decodedImage = try await decoder.decodePNG(
                    data: data, maxPixelSize: decodeSide,
                    maxSourceDimension: maximumSourceImageDimension, label: path)
            } catch {
                throw .invalidPack
            }
            probes[path] = .decoded(
                pixelWidth: decodedImage.sourcePixelWidth, pixelHeight: decodedImage.sourcePixelHeight)
            let imageBytes = decodedImage.image.bytesPerRow.multipliedReportingOverflow(by: decodedImage.image.height)
            guard !imageBytes.overflow else { throw .resourceLimit }
            let nextTotal = decodedBytes.addingReportingOverflow(imageBytes.partialValue)
            guard !nextTotal.overflow, nextTotal.partialValue <= maximumDecodedBytes else { throw .resourceLimit }
            decodedBytes = nextTotal.partialValue
        }

        let report = ManifestValidator.validate(decoded, images: probes)
        guard !report.issues.contains(where: { $0.severity == .error }) else { throw .invalidPack }

        let definition: CharacterDefinition
        do {
            definition = try CharacterDefinition.resolve(manifest, report: report)
        } catch {
            throw .invalidPack
        }

        return ValidatedCharacterPack(
            id: definition.id, displayName: definition.displayName, definition: definition,
            manifestData: snapshot.manifestData, images: snapshot.images)
    }

    nonisolated private static func decodeManifest(_ manifestData: Data) throws(CharacterPackImportError)
        -> DecodedManifest
    {
        guard manifestData.count <= maximumManifestBytes else { throw .resourceLimit }
        do {
            return try CharacterManifest.decode(manifestData)
        } catch {
            throw .invalidPack
        }
    }

    nonisolated private static func imageRoles(in manifest: CharacterManifest) throws(CharacterPackImportError)
        -> [String: ImageRole]
    {
        guard ManifestValidator.isValidIdentifier(manifest.id),
            manifest.id.utf8.count <= maximumIDLength,
            manifest.id != "placeholder",
            !manifest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            manifest.displayName.unicodeScalars.count <= maximumDisplayNameLength,
            !manifest.displayName.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
            manifest.animations.count <= maximumClipCount,
            (manifest.sheets ?? [:]).count <= maximumSheetCount
        else { throw .invalidPack }

        var frameCount = 0
        for clip in manifest.animations.values {
            frameCount += clip.frames?.count ?? 0
            guard frameCount <= maximumFrameCount else { throw .resourceLimit }
        }

        var roles: [String: ImageRole] = [:]
        for (name, sheet) in manifest.sheets ?? [:] {
            guard ManifestValidator.isValidIdentifier(name),
                sheet.columns > 0, sheet.columns <= maximumSheetColumns,
                sheet.rows > 0, sheet.rows <= maximumSheetRows,
                ManifestValidator.isValidImagePath(sheet.image),
                isSafeResourcePath(sheet.image)
            else { throw .invalidPack }
            try register(.sheet(columns: sheet.columns, rows: sheet.rows), for: sheet.image, in: &roles)
        }
        for clip in manifest.animations.values {
            for frame in clip.frames ?? [] {
                if let image = frame.image {
                    guard isSafeResourcePath(image) else { throw .invalidPack }
                    try register(.frame, for: image, in: &roles)
                }
            }
        }
        guard !roles.isEmpty, roles.count <= maximumReferencedImageCount else { throw .resourceLimit }
        let normalizedPaths = roles.keys.map { $0.precomposedStringWithCanonicalMapping.lowercased() }
        guard Set(normalizedPaths).count == normalizedPaths.count else { throw .unsafePack }
        return roles
    }

    nonisolated static func isSafeResourcePath(_ path: String) -> Bool {
        guard path.utf8.count <= maximumPathBytes, path.hasSuffix(".png"),
            !path.hasPrefix("/"), !path.hasPrefix("~"), !path.contains("\\")
        else { return false }

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return false }
        return components.allSatisfy { component in
            let bytes = Array(component.utf8)
            guard !bytes.isEmpty, bytes.count <= maximumPathComponentBytes,
                component != ".", component != "..",
                let first = bytes.first, isASCIIAlphaNumeric(first)
            else { return false }
            return bytes.allSatisfy { isASCIIAlphaNumeric($0) || $0 == 45 || $0 == 46 || $0 == 95 }
        }
    }

    nonisolated private static func register(
        _ role: ImageRole, for path: String, in roles: inout [String: ImageRole]
    ) throws(CharacterPackImportError) {
        guard let existing = roles[path] else {
            roles[path] = role
            return
        }
        guard existing == role else { throw .unsafePack }
    }

    nonisolated private static func decodeSide(
        for role: ImageRole, data: Data, targetPixelSide: Int
    ) throws(CharacterPackImportError) -> Int {
        switch role {
        case .frame:
            return targetPixelSide
        case .sheet(let columns, let rows):
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                let width = properties[kCGImagePropertyPixelWidth] as? Int,
                let height = properties[kCGImagePropertyPixelHeight] as? Int,
                width > 0, height > 0,
                width <= maximumSourceImageDimension, height <= maximumSourceImageDimension
            else { throw .invalidPack }
            let cellSide = max(Double(width) / Double(columns), Double(height) / Double(rows))
            let scale = min(1, Double(targetPixelSide) / cellSide)
            let side = Int((Double(max(width, height)) * scale).rounded(.up))
            guard side > 0, side <= maximumSourceImageDimension else { throw .resourceLimit }
            return side
        }
    }

    nonisolated private static func sourceDimensions(in data: Data) throws(CharacterPackImportError)
        -> (width: Int, height: Int)
    {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) == 1,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0
        else { throw .invalidPack }
        return (width, height)
    }

    nonisolated private static func isASCIIAlphaNumeric(_ byte: UInt8) -> Bool {
        (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
    }
}
