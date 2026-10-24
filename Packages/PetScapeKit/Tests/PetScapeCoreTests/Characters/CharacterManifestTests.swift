import Foundation
import Testing

@testable import PetScapeCore

@Suite("CharacterManifest decoding and bundled packs")
struct CharacterManifestTests {
    @Test func decodesTheValidCatFixture() throws {
        let decoded = try Fixtures.decoded("valid-cat")
        let manifest = decoded.manifest

        #expect(decoded.unknownFields.isEmpty)
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.id == "cat")
        #expect(manifest.displayName == "Cat")
        #expect(manifest.defaultAnimation == "walk")
        #expect(manifest.defaultFacing == .right)
        #expect(manifest.canvas == .init(width: 512, height: 512))
        #expect(manifest.displaySize == .init(width: 96, height: 96))
        #expect(manifest.anchor == .init(x: 0.5, y: 0.074))
        #expect(manifest.fallbacks == ["idle": "walk", "fall": "walk", "land": "walk"])

        let walk = try #require(manifest.animations["walk"])
        #expect(walk.playback == .loop)
        #expect(walk.fps == 9)
        #expect(walk.nominalSpeed == 40)
        #expect(walk.frames?.count == 8)
        #expect(walk.frames?.first?.image == "walk/frames/walk_01.png")
        #expect(walk.frames?[2].events == ["footstep"])
        #expect(walk.frames?[6].events == ["footstep"])
    }

    @Test func optionalFieldsStayAbsentUntilResolution() throws {
        let walk = try #require(try Fixtures.manifest("missingFile").animations["walk"])
        #expect(walk.playback == nil)
        #expect(walk.facing == nil)
        #expect(walk.mirrorable == nil)
        #expect(walk.anchor == nil)
        #expect(walk.interruptible == nil)
    }

    @Test func malformedJSONIsRejected() throws {
        #expect {
            try CharacterManifest.decode(try Fixtures.manifestData("malformed"))
        } throws: { error in
            guard case .malformedJSON = error as? ManifestDecodingError else { return false }
            return true
        }
    }

    @Test func aTopLevelArrayIsMalformed() {
        #expect {
            try CharacterManifest.decode(Data("[1, 2]".utf8))
        } throws: { error in
            guard case .malformedJSON = error as? ManifestDecodingError else { return false }
            return true
        }
    }

    @Test func aMissingRequiredFieldIsASchemaMismatchNamingTheField() throws {
        #expect {
            try CharacterManifest.decode(try Fixtures.manifestData("schema-mismatch"))
        } throws: { error in
            guard case .schemaMismatch(let detail) = error as? ManifestDecodingError else { return false }
            return detail.contains("displaySize")
        }
    }

    @Test func aBadEnumValueIsASchemaMismatch() throws {
        var json = try #require(String(data: try Fixtures.manifestData("valid-cat"), encoding: .utf8))
        json = json.replacingOccurrences(of: "\"playback\": \"loop\"", with: "\"playback\": \"bounce\"")
        #expect(throws: ManifestDecodingError.self) { try CharacterManifest.decode(Data(json.utf8)) }
    }

    @Test func aNewerSchemaVersionIsRejectedBeforeAnythingElse() throws {
        #expect(throws: ManifestDecodingError.unsupportedSchemaVersion(2)) {
            try CharacterManifest.decode(try Fixtures.manifestData("unsupportedSchemaVersion"))
        }
        #expect(throws: ManifestDecodingError.unsupportedSchemaVersion(nil)) {
            try CharacterManifest.decode(Data(#"{"id": "cat"}"#.utf8))
        }
    }

    @Test func unknownFieldsAreToleratedAndListed() throws {
        let decoded = try Fixtures.decoded("unknownField")
        #expect(
            decoded.unknownFields == [
                "animations.walk.frames.0.tint", "animations.walk.loopStart", "author", "canvas.depth",
            ])
        #expect(decoded.manifest.animations["walk"]?.fps == 8)
    }

    @Test func roundTripsThroughJSONEncoding() throws {
        let manifest = try Fixtures.manifest("full-featured")
        let encoded = try JSONEncoder().encode(manifest)
        #expect(try CharacterManifest.decode(encoded).manifest == manifest)
    }

    // MARK: - Bundled packs (T4.8)

    /// Every `assets/characters/<id>/character.json` must decode and validate with no errors or warnings,
    /// including the file checks, so a broken manifest fails CI instead of reaching users.
    @Test func everyBundledPackValidates() throws {
        let charactersURL = Fixtures.repositoryRoot.appending(path: "assets/characters")
        let packIDs = try FileManager.default.contentsOfDirectory(atPath: charactersURL.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
        #expect(packIDs.contains("cat"))

        for packID in packIDs {
            let packURL = charactersURL.appending(path: packID)
            let manifestURL = packURL.appending(path: "character.json")
            let decoded = try CharacterManifest.decode(try Data(contentsOf: manifestURL))
            let manifest = decoded.manifest
            #expect(manifest.id == packID, "The pack folder must be named after the character id")

            var probes: [String: ImageProbe] = [:]
            for path in manifest.imagePaths(ofClips: manifest.animations.keys) {
                let url = packURL.appending(path: path)
                if !FileManager.default.fileExists(atPath: url.path) {
                    probes[path] = .missing
                } else if let size = Fixtures.pngPixelSize(at: url) {
                    probes[path] = .decoded(pixelWidth: size.width, pixelHeight: size.height)
                } else {
                    probes[path] = .undecodable
                }
            }

            let report = ManifestValidator.validate(decoded, images: probes)
            #expect(report.issues.isEmpty, "\(packID): \(report.issues.map(\.description))")
            let definition = try CharacterDefinition.resolve(manifest, report: report)
            #expect(definition.clips.count == manifest.animations.count)
        }
    }

    @Test func theOriginalCatMatchesTheAssetAudit() throws {
        let url = Fixtures.repositoryRoot.appending(path: "assets/characters/cat/v7/baseline-character.json")
        let manifest = try CharacterManifest.decode(try Data(contentsOf: url)).manifest
        let walk = try #require(manifest.animations["walk"])

        #expect(manifest.defaultAnimation == "walk")
        #expect(manifest.defaultFacing == .right)  // F12
        #expect(manifest.canvas == .init(width: 512, height: 512))  // F1
        #expect(manifest.anchor == .init(x: 0.5, y: 0.074))  // F9, F10
        #expect(walk.fps == 9)  // F3, F4
        #expect(walk.frames?.map(\.image) == (1...8).map { "walk/frames/walk_0\($0).png" })
    }
}
