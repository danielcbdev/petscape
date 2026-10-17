import Foundation
import PetScapeCore
import PetScapeRendering
import Testing

@testable import PetScapeRuntime

@Suite("CharacterLoader")
struct CharacterLoaderTests {
    // MARK: The bundled cat

    @Test func loadsTheCatPack() async throws {
        let character = await CharacterLoader().load(packURL: TestPacks.catPackURL)

        #expect(character.failure == nil)
        #expect(character.issues.isEmpty, "\(character.issues.map(\.description))")
        #expect(character.definition.id == CharacterID("cat"))
        #expect(character.pixelSize == 288)
        let walk = try #require(character.frames["walk"])
        #expect(walk.count == 8)
        #expect(walk.allSatisfy { $0.image.width == 288 && $0.image.height == 288 })
        #expect(character.decodedByteCount <= 3 * 1024 * 1024)  // AC-M4-02
    }

    @Test func theCatWalkPlaysAtTheDeclaredRate() async throws {
        let character = await CharacterLoader().load(packURL: TestPacks.catPackURL)
        var controller = AnimationController(definition: character.definition)
        var shown: [Int] = []
        for _ in 0..<60 {  // 1 s at 60 Hz
            _ = controller.advance(by: 1.0 / 60)
            shown.append(controller.currentFrame.frameIndex)
            #expect(character.frame(controller.currentFrame) != nil)
        }
        #expect(shown.last == 9 % 8)
        #expect(Set(shown).count == 8)
    }

    // MARK: AC-05: changing the manifest changes playback without code changes

    @Test func fpsAndFrameListComeFromTheManifest() async throws {
        let frames = ["walk/walk_01.png", "walk/walk_02.png", "walk/walk_03.png"]
        let at12 = try TestPacks.make(manifest: TestPacks.manifest(walkFrames: frames, fps: 12), images: frames)
        let character = await CharacterLoader().load(packURL: at12)
        let walk = try #require(character.definition.clips["walk"])
        #expect(walk.frames.count == 3)
        #expect(walk.frames.allSatisfy { $0.duration == 1.0 / 12 })
        #expect(character.frames["walk"]?.count == 3)

        let shorter = try TestPacks.make(
            manifest: TestPacks.manifest(walkFrames: Array(frames.prefix(2)), fps: 6), images: frames)
        let changed = await CharacterLoader().load(packURL: shorter)
        #expect(changed.definition.clips["walk"]?.frames.count == 2)
        #expect(changed.definition.clips["walk"]?.frames.first?.duration == 1.0 / 6)
    }

    // MARK: AC-15: failures never crash; the placeholder or a fallback clip is used

    @Test func aMissingManifestYieldsThePlaceholder() async throws {
        let pack = try TestPacks.make(manifest: nil, images: [])
        let character = await CharacterLoader().load(packURL: pack)
        #expect(character.failure == .manifestMissing)
        #expect(character.isPlaceholder)
        #expect(character.definition.displaySize == .init(width: 96, height: 96))
        let controller = AnimationController(definition: character.definition)
        #expect(character.frame(controller.currentFrame) != nil, "The placeholder has a drawable frame")
    }

    @Test func aMalformedManifestYieldsThePlaceholder() async throws {
        let pack = try TestPacks.make(manifest: #"{ "schemaVersion": 1, "id": "#, images: [])
        let character = await CharacterLoader().load(packURL: pack)
        guard case .malformedManifest = character.failure else {
            Issue.record("Expected malformedManifest, got \(String(describing: character.failure))")
            return
        }
    }

    @Test func anUnsupportedSchemaVersionYieldsThePlaceholder() async throws {
        let manifest = TestPacks.manifest(walkFrames: ["walk/walk_01.png"], schemaVersion: 2)
        let pack = try TestPacks.make(manifest: manifest, images: ["walk/walk_01.png"])
        #expect(await CharacterLoader().load(packURL: pack).failure == .unsupportedSchemaVersion(2))
    }

    @Test func aMissingDefaultClipFrameYieldsThePlaceholder() async throws {
        let manifest = TestPacks.manifest(walkFrames: ["walk/walk_01.png", "walk/walk_02.png"])
        let pack = try TestPacks.make(manifest: manifest, images: ["walk/walk_01.png"])
        let character = await CharacterLoader().load(packURL: pack)

        guard case .invalidPack(let issues) = character.failure else {
            Issue.record("Expected invalidPack, got \(String(describing: character.failure))")
            return
        }
        #expect(issues.contains { $0.code == .missingFile && $0.detail.contains("walk_02.png") })
        #expect(issues.contains { $0.code == .missingDefaultAnimation })
        #expect(character.isPlaceholder)
    }

    @Test func aMissingFrameOfAnotherClipFallsBack() async throws {
        let manifest = TestPacks.manifest(walkFrames: ["walk/walk_01.png"], sitFrames: ["sit/sit_01.png"])
        let pack = try TestPacks.make(manifest: manifest, images: ["walk/walk_01.png"])
        let character = await CharacterLoader().load(packURL: pack)

        #expect(character.failure == nil)
        #expect(character.isDegraded)
        #expect(character.issues.map(\.code) == [.missingFile])
        #expect(character.definition.resolvedClipName(for: "sit") == "walk")
        #expect(character.frames["sit"] == nil)

        var controller = AnimationController(definition: character.definition)
        controller.request(AnimationRequest(clip: "sit", priority: 10))
        #expect(controller.currentFrame.clip == "walk")
        #expect(character.frame(controller.currentFrame) != nil)
    }

    @Test func anUndecodableFrameFallsBackLikeAMissingOne() async throws {
        let manifest = TestPacks.manifest(walkFrames: ["walk/walk_01.png"], sitFrames: ["sit/sit_01.png"])
        let pack = try TestPacks.make(manifest: manifest, images: ["walk/walk_01.png"])
        try FileManager.default.createDirectory(at: pack.appending(path: "sit"), withIntermediateDirectories: true)
        try Data("not a png".utf8).write(to: pack.appending(path: "sit/sit_01.png"))

        let character = await CharacterLoader().load(packURL: pack)
        #expect(character.failure == nil)
        #expect(character.issues.map(\.code) == [.undecodableImage])
    }

    @Test func canvasMismatchesAreWarningsOnly() async throws {
        let manifest = TestPacks.manifest(walkFrames: ["walk/walk_01.png"])
        let pack = try TestPacks.make(manifest: manifest, images: ["walk/walk_01.png"], pixelSize: 80)
        let character = await CharacterLoader().load(packURL: pack)
        #expect(character.failure == nil)
        #expect(!character.isDegraded)
        #expect(character.issues.map(\.code) == [.canvasMismatch])
    }

    @Test func thePlaceholderIsValidByConstruction() {
        let character = CharacterLoader.placeholder(failure: .manifestMissing)
        #expect(character.definition.defaultClipName == "placeholder")
        #expect(character.frames["placeholder"]?.count == 1)
        #expect(character.pixelSize == 288)
        #expect(character.definition.clip(named: "walk").name == "placeholder")
    }

    @Test func errorsDescribeThemselvesForLogsAndTheMenu() {
        #expect(CharacterLoadError.manifestMissing.description == "character.json is missing")
        #expect(CharacterLoadError.unsupportedSchemaVersion(3).description.contains("3"))
    }
}
