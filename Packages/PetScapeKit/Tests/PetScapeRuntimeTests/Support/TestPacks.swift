import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes small character packs (manifest + synthetic PNG frames) into a fresh temporary folder.
enum TestPacks {
    struct PackError: Error {}

    /// The repository checkout (…/Packages/PetScapeKit/Tests/PetScapeRuntimeTests/Support/TestPacks.swift).
    static let repositoryRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    static var catPackURL: URL { repositoryRoot.appending(path: "assets/characters/cat") }

    /// Pins historical V4/V5/V6 contracts without weakening them when the active pack adds art.
    /// Callers remove the temporary folder; immutable originals are linked, never rewritten.
    static func makeBaselineCatPack() throws -> URL {
        let folder = try makeFolder()
        let data = try Data(contentsOf: catPackURL.appending(path: "v7/baseline-character.json"))
        try data.write(to: folder.appending(path: "character.json"))
        for name in ["walk", "idle", "jump-start", "jump", "fall", "landing", "v5", "v6"] {
            try FileManager.default.createSymbolicLink(
                at: folder.appending(path: name), withDestinationURL: catPackURL.appending(path: name))
        }
        return folder
    }

    static func makeFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "PetScapeRuntimeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A pack with `manifest` as `character.json` and an opaque square PNG for each path in `images`.
    static func make(manifest: String?, images: [String], pixelSize: Int = 64) throws -> URL {
        let folder = try makeFolder()
        if let manifest {
            try Data(manifest.utf8).write(to: folder.appending(path: "character.json"))
        }
        let image = try opaqueImage(side: pixelSize)
        for path in images {
            try writePNG(image, to: folder.appending(path: path))
        }
        return folder
    }

    /// A manifest with a `walk` clip (default) and an optional extra `sit` clip, fallbacks `sit → walk`.
    static func manifest(walkFrames: [String], fps: Double = 8, sitFrames: [String]? = nil, schemaVersion: Int = 1)
        -> String
    {
        func frames(_ paths: [String]) -> String {
            paths.map { #"{ "image": "\#($0)" }"# }.joined(separator: ", ")
        }
        let sit = sitFrames.map { #", "sit": { "fps": 4, "frames": [\#(frames($0))] }"# } ?? ""
        return #"""
            {
              "schemaVersion": \#(schemaVersion),
              "id": "fixture",
              "displayName": "Fixture",
              "defaultAnimation": "walk",
              "canvas": { "width": 64, "height": 64 },
              "displaySize": { "width": 32, "height": 32 },
              "anchor": { "x": 0.5, "y": 0.1 },
              "fallbacks": { "sit": "walk" },
              "animations": {
                "walk": { "fps": \#(fps), "frames": [\#(frames(walkFrames))] }\#(sit)
              }
            }
            """#
    }

    static func opaqueImage(side: Int) throws -> CGImage {
        guard
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw PackError() }
        context.setFillColor(CGColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        guard let image = context.makeImage() else { throw PackError() }
        return image
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw PackError() }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PackError() }
    }
}
