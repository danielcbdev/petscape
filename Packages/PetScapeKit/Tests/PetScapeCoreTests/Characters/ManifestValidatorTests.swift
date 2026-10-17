import Foundation
import Testing

@testable import PetScapeCore

/// One focused test per validation code (docs/specifications/animation-schema.md#validation), plus a
/// table test that fails when a new code is added without a fixture.
@Suite("ManifestValidator")
struct ManifestValidatorTests {
    @Test func theValidCatHasNoIssues() throws {
        let manifest = try Fixtures.manifest("valid-cat")
        let report = ManifestValidator.validate(manifest, images: Fixtures.probes(for: manifest, pixelSize: 512))
        #expect(report.issues.isEmpty)
        #expect(report.isPackValid)
        #expect(report.invalidClips.isEmpty)
        #expect(report.resolvedDefaultClip == "walk")
    }

    @Test(arguments: ManifestIssueCode.allCases)
    func everyCodeHasAFixtureThatReportsIt(_ code: ManifestIssueCode) throws {
        let report = try Self.report(for: code)
        #expect(report.contains(code))
    }

    // MARK: Pack errors

    @Test func unsupportedSchemaVersion() throws {
        var manifest = try Fixtures.manifest("valid-cat")
        manifest.schemaVersion = 2
        let report = ManifestValidator.validate(manifest)
        #expect(report.issues.map(\.code) == [.unsupportedSchemaVersion])
        #expect(!report.isPackValid)
    }

    @Test func invalidIdentifier() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("invalidIdentifier"))
        let scopes = Set(report.issues.filter { $0.code == .invalidIdentifier }.map(\.scope))
        #expect(scopes == [.pack, .clip("Jump!"), .clip("walk")])
        #expect(report.invalidClips == ["Jump!", "walk"])
        #expect(!report.isPackValid)
    }

    @Test func missingDefaultAnimation() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("missingDefaultAnimation"))
        let issue = try #require(report.issues.first { $0.code == .missingDefaultAnimation })
        #expect(issue.scope == .pack)
        #expect(issue.detail.contains("sleep"))
        #expect(report.resolvedDefaultClip == nil)

        var absent = try Fixtures.manifest("valid-cat")
        absent.defaultAnimation = nil
        #expect(ManifestValidator.validate(absent).contains(.missingDefaultAnimation))
    }

    @Test func anInvalidDefaultClipResolvesThroughItsFallback() throws {
        var manifest = try Fixtures.manifest("missingFile")
        manifest.defaultAnimation = "sit"
        manifest.fallbacks = ["sit": "walk"]
        let images = Fixtures.probes(for: manifest, overriding: ["sit/sit_01.png": .missing])
        let report = ManifestValidator.validate(manifest, images: images)
        #expect(report.isPackValid)
        #expect(report.resolvedDefaultClip == "walk")
    }

    @Test func fallbackCycle() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("fallbackCycle"))
        let cycles = report.issues.filter { $0.code == .fallbackCycle }
        #expect(cycles.count == 1)
        #expect(cycles.first?.detail == "Fallback cycle fall → land → idle → fall")
        #expect(!report.isPackValid)
    }

    @Test func aSelfReferencingFallbackIsACycle() throws {
        var manifest = try Fixtures.manifest("valid-cat")
        manifest.fallbacks = ["idle": "idle"]
        #expect(ManifestValidator.validate(manifest).contains(.fallbackCycle))
    }

    @Test func invalidAnchor() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("invalidAnchor"))
        let scopes = Set(report.issues.filter { $0.code == .invalidAnchor }.map(\.scope))
        #expect(scopes == [.pack, .clip("climb")])
        #expect(!report.isPackValid)
    }

    @Test func invalidSize() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("invalidSize"))
        let scopes = Set(report.issues.filter { $0.code == .invalidSize }.map(\.scope))
        #expect(scopes == [.pack, .clip("stretch")])
        #expect(!report.isPackValid)
    }

    // MARK: Clip errors (the pack stays valid; the clip resolves through fallbacks)

    @Test func emptyFrames() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("emptyFrames"))
        #expect(report.issues.map(\.code) == [.emptyFrames])
        #expect(report.invalidClips == ["sit"])
        #expect(report.isPackValid)
    }

    @Test func invalidTiming() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("invalidTiming"))
        #expect(Set(report.issues.map(\.code)) == [.invalidTiming])
        #expect(report.invalidClips == ["sit", "nap", "yawn"])
        #expect(report.isPackValid)
    }

    @Test func invalidFrameSource() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("invalidFrameSource"))
        #expect(Set(report.issues.map(\.code)) == [.invalidFrameSource])
        #expect(
            report.invalidClips == [
                "both", "neither", "escape", "absolute", "not-png", "unknown-sheet", "out-of-range",
            ])
        #expect(report.isPackValid)
        #expect(report.resolvedDefaultClip == "walk")
    }

    @Test func missingFile() throws {
        let manifest = try Fixtures.manifest("missingFile")
        #expect(ManifestValidator.validate(manifest).issues.isEmpty, "File checks need probes")

        let images = Fixtures.probes(for: manifest, overriding: ["sit/sit_01.png": .missing])
        let report = ManifestValidator.validate(manifest, images: images)
        #expect(report.issues.map(\.code) == [.missingFile])
        #expect(report.issues.first?.scope == .clip("sit"))
        #expect(report.isPackValid)

        var withoutEntry = images
        withoutEntry["sit/sit_01.png"] = nil
        #expect(ManifestValidator.validate(manifest, images: withoutEntry).contains(.missingFile))
    }

    @Test func undecodableImage() throws {
        let manifest = try Fixtures.manifest("undecodableImage")
        let images = Fixtures.probes(for: manifest, overriding: ["sit/corrupt.png": .undecodable])
        let report = ManifestValidator.validate(manifest, images: images)
        #expect(report.issues.map(\.code) == [.undecodableImage])
        #expect(report.invalidClips == ["sit"])
        #expect(report.isPackValid)
    }

    @Test func aMissingDefaultClipFileInvalidatesThePack() throws {
        let manifest = try Fixtures.manifest("missingFile")
        let images = Fixtures.probes(for: manifest, overriding: ["walk/walk_01.png": .missing])
        let report = ManifestValidator.validate(manifest, images: images)
        #expect(report.contains(.missingFile))
        #expect(report.contains(.missingDefaultAnimation))
        #expect(!report.isPackValid)
    }

    @Test func invalidNext() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("invalidNext"))
        #expect(Set(report.issues.map(\.code)) == [.invalidNext])
        #expect(report.invalidClips == ["looping-next", "missing-next"])
    }

    // MARK: Warnings

    @Test func canvasMismatch() throws {
        let manifest = try Fixtures.manifest("canvasMismatch")
        let images = Fixtures.probes(
            for: manifest, overriding: ["walk/walk_01.png": .decoded(pixelWidth: 128, pixelHeight: 128)])
        let report = ManifestValidator.validate(manifest, images: images)
        #expect(report.issues.map(\.code) == [.canvasMismatch])
        #expect(report.warnings.count == 1)
        #expect(report.invalidClips.isEmpty)
        #expect(report.isPackValid)
    }

    @Test func sheetCellsAreComparedWithTheCanvas() throws {
        let manifest = try Fixtures.manifest("full-featured")
        func mismatchedClips(atlasSize: Int) -> Set<ManifestIssueScope> {
            let images = Fixtures.probes(
                for: manifest,
                overriding: ["sit/sit_atlas.png": .decoded(pixelWidth: atlasSize, pixelHeight: atlasSize)])
            let report = ManifestValidator.validate(manifest, images: images)
            return Set(report.issues.filter { $0.code == .canvasMismatch }.map(\.scope))
        }
        // atlas: 2 × 2 cells of 64 px → 128 × 128 matches; 100 × 100 does not. ("climb" has its own
        // 64 × 96 canvas, so the 64 px probes always mismatch there.)
        #expect(mismatchedClips(atlasSize: 128) == [.clip("climb")])
        #expect(mismatchedClips(atlasSize: 100) == [.clip("climb"), .clip("sit"), .clip("sit-down")])
    }

    @Test func unusedSheet() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("unusedSheet"))
        #expect(report.issues.map(\.code) == [.unusedSheet])
        #expect(report.issues.first?.severity == .warning)
        #expect(report.isPackValid)
    }

    @Test func unknownField() throws {
        let report = ManifestValidator.validate(try Fixtures.decoded("unknownField"))
        #expect(report.issues.count == 4)
        #expect(report.issues.allSatisfy { $0.code == .unknownField && $0.severity == .warning })
        #expect(report.isPackValid)
    }

    // MARK: Rules

    @Test(arguments: ["cat", "walk", "sit-down", "a", "0", "footstep-2"])
    func validIdentifiers(_ value: String) {
        #expect(ManifestValidator.isValidIdentifier(value))
    }

    @Test(arguments: ["", "Cat", "-walk", "walk_left", "walk left", "é", "jump!"])
    func invalidIdentifiers(_ value: String) {
        #expect(!ManifestValidator.isValidIdentifier(value))
    }

    @Test(arguments: ["walk/frames/walk_01.png", "a.png", "sit/SIT.PNG"])
    func validImagePaths(_ value: String) {
        #expect(ManifestValidator.isValidImagePath(value))
    }

    @Test(arguments: ["", "/abs.png", "~/a.png", "../a.png", "a/../b.png", "a//b.png", "a.jpg", ".png", "a\\b.png"])
    func invalidImagePaths(_ value: String) {
        #expect(!ManifestValidator.isValidImagePath(value))
    }

    @Test func timingLimitsAreInclusiveAtTheTop() throws {
        var manifest = try Fixtures.manifest("valid-cat")
        manifest.animations["walk"]?.fps = 60
        manifest.animations["walk"]?.frames?[0].duration = 10
        #expect(ManifestValidator.validate(manifest).issues.isEmpty)
        manifest.animations["walk"]?.frames?[0].duration = 10.01
        #expect(ManifestValidator.validate(manifest).contains(.invalidTiming))
    }

    // MARK: - Table

    /// A report that must contain `code`, built from that code's fixture.
    static func report(for code: ManifestIssueCode) throws -> ManifestValidationReport {
        switch code {
        case .unsupportedSchemaVersion:
            // The decoder rejects the fixture outright; the validator covers programmatic manifests.
            #expect(throws: ManifestDecodingError.self) {
                try CharacterManifest.decode(try Fixtures.manifestData(code.rawValue))
            }
            var manifest = try Fixtures.manifest("valid-cat")
            manifest.schemaVersion = 2
            return ManifestValidator.validate(manifest)
        case .missingFile:
            let manifest = try Fixtures.manifest(code.rawValue)
            return ManifestValidator.validate(
                manifest, images: Fixtures.probes(for: manifest, overriding: ["sit/sit_01.png": .missing]))
        case .undecodableImage:
            let manifest = try Fixtures.manifest(code.rawValue)
            return ManifestValidator.validate(
                manifest, images: Fixtures.probes(for: manifest, overriding: ["sit/corrupt.png": .undecodable]))
        case .canvasMismatch:
            let manifest = try Fixtures.manifest(code.rawValue)
            return ManifestValidator.validate(manifest, images: Fixtures.probes(for: manifest, pixelSize: 65))
        case .invalidIdentifier, .missingDefaultAnimation, .emptyFrames, .invalidTiming, .invalidFrameSource,
            .invalidNext, .fallbackCycle, .invalidAnchor, .invalidSize, .unusedSheet, .unknownField:
            return ManifestValidator.validate(try Fixtures.decoded(code.rawValue))
        }
    }
}
