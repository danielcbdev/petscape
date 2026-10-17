import Foundation
import Testing

@testable import PetScapeCore

@Suite("CharacterDefinition resolution")
struct CharacterDefinitionTests {
    @Test func theFullFeaturedFixtureOnlyFailsItsBrokenClip() throws {
        let report = ManifestValidator.validate(try Fixtures.manifest("full-featured"))
        #expect(report.issues.map(\.code) == [.invalidTiming])
        #expect(report.invalidClips == ["broken"])
    }

    @Test func appliesTopLevelDefaults() throws {
        let definition = try Fixtures.definition("full-featured")
        let walk = try #require(definition.clips["walk"])

        #expect(definition.id == CharacterID("fixture-cat"))
        #expect(definition.displayName == "Fixture Cat")
        #expect(definition.displaySize == .init(width: 32, height: 32))
        #expect(definition.defaultFacing == .left)
        #expect(definition.personality?.curiosity == 0.7)
        #expect(walk.playback == .loop)
        #expect(walk.facing == .left)
        #expect(walk.mirrorable)
        #expect(walk.interruptible)
        #expect(walk.alignment == .bottom)
        #expect(walk.anchor == .init(x: 0.5, y: 0.1))
        #expect(walk.canvas == .init(width: 64, height: 64))
        #expect(walk.nominalSpeed == 40)
        #expect(walk.next == nil)
    }

    @Test func durationsComeFromFPSUnlessAFrameOverridesThem() throws {
        let definition = try Fixtures.definition("full-featured")
        let walk = try #require(definition.clips["walk"])
        #expect(walk.frames.map(\.duration) == Array(repeating: 1.0 / 8, count: 4))
        #expect(walk.duration == 0.5)
        #expect(walk.frames.map(\.events) == [[], ["footstep"], [], ["footstep"]])

        let sitDown = try #require(definition.clips["sit-down"])
        #expect(sitDown.frames.map(\.duration) == [0.1, 0.2])
        #expect(sitDown.frames[1].events == ["contact"])
    }

    @Test func appliesClipOverrides() throws {
        let definition = try Fixtures.definition("full-featured")
        let climb = try #require(definition.clips["climb"])
        #expect(climb.anchor == .init(x: 0.2, y: 0.5))
        #expect(climb.canvas == .init(width: 64, height: 96))
        #expect(climb.alignment == .left)
        #expect(!climb.mirrorable)
        #expect(climb.variants == [.right: "walk-right"])

        let sitDown = try #require(definition.clips["sit-down"])
        #expect(sitDown.playback == .once)
        #expect(!sitDown.interruptible)
        #expect(sitDown.next == "sit")
    }

    @Test func sheetFramesKeepTheirCell() throws {
        let sit = try #require(try Fixtures.definition("full-featured").clips["sit"])
        let atlas = AnimationClip.Sheet(image: "sit/sit_atlas.png", columns: 2, rows: 2)
        #expect(sit.frames.map(\.source) == [.sheetCell(atlas, cell: 2), .sheetCell(atlas, cell: 3)])
        #expect(sit.frames.map(\.source.imagePath) == ["sit/sit_atlas.png", "sit/sit_atlas.png"])
    }

    @Test func invalidClipsAreDropped() throws {
        let definition = try Fixtures.definition("full-featured")
        #expect(definition.clips["broken"] == nil)
        #expect(definition.clips.count == 6)
    }

    // MARK: Fallbacks

    @Test func theDefaultClipResolvesThroughFallbacks() throws {
        let definition = try Fixtures.definition("full-featured")
        #expect(definition.defaultClipName == "walk")  // "idle" → "walk"
        #expect(definition.resolvedClipName(for: "idle") == "walk")
    }

    @Test func fallbackChainsAreFollowed() throws {
        let definition = try Fixtures.definition("full-featured")
        #expect(definition.resolvedClipName(for: "fall") == "walk")  // fall → jump → walk
        #expect(definition.resolvedClipName(for: "jump") == "walk")
    }

    @Test func anInvalidClipResolvesThroughItsFallback() throws {
        let definition = try Fixtures.definition("full-featured")
        #expect(definition.resolvedClipName(for: "broken") == "sit")
        #expect(definition.clip(named: "broken").name == "sit")
    }

    @Test func unknownNamesResolveToTheDefaultClip() throws {
        let definition = try Fixtures.definition("full-featured")
        #expect(definition.clip(named: "dance").name == "walk")
    }

    @Test func validClipsResolveToThemselves() throws {
        let definition = try Fixtures.definition("full-featured")
        for name in definition.clips.keys {
            #expect(definition.resolvedClipName(for: name) == name)
        }
    }

    @Test func missingFilesInvalidateClipsThatThenFallBack() throws {
        let manifest = try Fixtures.manifest("full-featured")
        let images = Fixtures.probes(for: manifest, overriding: ["sit/sit_atlas.png": .missing])
        let report = ManifestValidator.validate(manifest, images: images)
        let definition = try CharacterDefinition.resolve(manifest, report: report)

        #expect(report.invalidClips == ["broken", "sit", "sit-down"])
        #expect(definition.resolvedClipName(for: "sit") == "walk")
        #expect(definition.resolvedClipName(for: "broken") == "walk")  // broken → sit (invalid) → default
    }

    @Test func nextResolvesThroughFallbacks() throws {
        var manifest = try Fixtures.manifest("full-featured")
        manifest.animations["sit-down"]?.next = "broken"
        let definition = try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
        #expect(definition.clips["sit-down"]?.next == "sit")
    }

    @Test func aPackWithErrorsCannotBeResolved() throws {
        let manifest = try Fixtures.manifest("fallbackCycle")
        let report = ManifestValidator.validate(manifest)
        #expect(throws: CharacterDefinitionError.invalidPack(report.errors)) {
            try CharacterDefinition.resolve(manifest, report: report)
        }
    }

    // MARK: Facing and variants

    @Test func aClipFacingTheRequestedWayIsNotMirrored() throws {
        let selection = try Fixtures.definition("full-featured").clip(named: "walk", facing: .left)
        #expect(selection.clip.name == "walk")
        #expect(!selection.mirrored)
    }

    @Test func aMirrorableClipIsMirroredForTheOtherDirection() throws {
        let selection = try Fixtures.definition("full-featured").clip(named: "walk", facing: .right)
        #expect(selection.clip.name == "walk")
        #expect(selection.mirrored)
    }

    @Test func aVariantReplacesMirroring() throws {
        let selection = try Fixtures.definition("full-featured").clip(named: "climb", facing: .right)
        #expect(selection.clip.name == "walk-right")
        #expect(!selection.mirrored)
    }

    @Test func aNonMirrorableClipWithoutVariantIsShownAsAuthored() throws {
        let selection = try Fixtures.definition("full-featured").clip(named: "walk-right", facing: .left)
        #expect(selection.clip.name == "walk-right")
        #expect(!selection.mirrored)
    }

    @Test func imagePathsCoverOnlyValidClips() throws {
        let paths = try Fixtures.definition("full-featured").imagePaths
        #expect(paths.contains("sit/sit_atlas.png"))
        #expect(paths.contains("walk/walk_01.png"))
        #expect(!paths.contains("broken/broken_01.png"))
        #expect(paths.count == 4 + 4 + 2 + 1 + 2)
    }
}
