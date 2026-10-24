import CoreGraphics
import Foundation
import PetScapeCore
import PetScapePlatform
import PetScapeRendering
import Testing

@testable import PetScapeRuntime

@Suite("M18 runtime transaction", .serialized)
struct CharacterSwitchRuntimeTests {
    private let screen = ScreenDescriptor(
        id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 800), backingScale: 2, isPrimary: true)

    private func pack(_ id: String) throws -> URL {
        try TestPacks.make(
            manifest: TestPacks.manifest(walkFrames: ["walk.png"]).replacingOccurrences(
                of: "\"fixture\"", with: "\"\(id)\""), images: ["walk.png"])
    }

    @Test(arguments: ["running", "paused", "hidden", "both"])
    func swappingKeepsPositionGlobalSettingsAndRunGatesAndReplacesLayers(_ mode: String) async throws {
        let firstURL = try pack("first")
        let secondURL = try pack("second")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = await CharacterLoader().loadForSelection(packURL: firstURL)
        let second = await CharacterLoader().loadForSelection(packURL: secondURL)
        let h = PetRuntimeTests.Harness(readScreens: { [screen] }, readWindowList: { [] })
        h.runtime.start()
        h.runtime.show(first)
        h.frames(2)
        let previous = try #require(h.runtime.pets.first)
        let oldLayer = h.runtime.overlay.hostContentView?.petLayerHost.sublayers?.first
        h.runtime.setPaused(mode == "paused" || mode == "both")
        h.runtime.setHidden(mode == "hidden" || mode == "both")
        let beforeSettings = h.preferences.petSettings
        let beforeIntent = h.preferences.userIntent
        #expect(h.runtime.replaceCharacter(second))
        let pet = try #require(h.runtime.pets.first)
        #expect(pet.characterID == CharacterID("second") && pet.id != previous.id)
        #expect(pet.position == previous.position && pet.attachment == previous.attachment)
        #expect(pet.facing == previous.facing)
        #expect(h.preferences.petSettings == beforeSettings && h.preferences.userIntent == beforeIntent)
        #expect(h.runtime.currentSnapshot.pets.map(\.id) == [pet.id])
        #expect(oldLayer?.superlayer == nil)
        #expect(h.runtime.overlay.hostContentView?.petLayerHost.sublayers?.count == 1)
        #expect(h.driver.isPaused == (mode != "running"))
        h.frames(3)
        #expect(h.runtime.currentSnapshot.pets.allSatisfy { $0.characterID == CharacterID("second") })
        h.runtime.stop()
        #expect(h.runtime.currentSnapshot.pets.isEmpty)
        #expect(!h.runtime.replaceCharacter(first))
    }

    @Test func flightAndFailedCandidateDoNotDiscardTheCurrentPet() async throws {
        let url = try pack("first")
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = await CharacterLoader().loadForSelection(packURL: url)
        let h = PetRuntimeTests.Harness(readScreens: { [screen] }, readWindowList: { [] })
        h.runtime.start()
        h.runtime.show(loaded)
        h.frames(2)
        let snapshot = h.runtime.currentSnapshot
        #expect(!h.runtime.replaceCharacter(CharacterLoader.placeholder(failure: .manifestMissing)))
        #expect(h.runtime.currentSnapshot == snapshot)
        #expect(h.runtime.requestJump(to: .vertical))
        let preparing = h.runtime.currentSnapshot
        #expect(!h.runtime.replaceCharacter(loaded))
        #expect(h.runtime.currentSnapshot == preparing)
        h.frames(15)
        let flying = h.runtime.currentSnapshot
        #expect(!h.runtime.replaceCharacter(loaded))
        #expect(h.runtime.currentSnapshot == flying)
    }

    @Test(arguments: [false, true])
    func failingOldLazyCompletionCannotPublishAfterReplacementOrStop(_ stopping: Bool) async throws {
        let url = try pack("first")
        let secondURL = try pack("second")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let base = await CharacterLoader().loadForSelection(packURL: url)
        let old = LoadedCharacter(
            definition: base.definition, pixelSize: base.pixelSize,
            catalog: CharacterFrameCatalog(
                definition: base.definition, packURL: url.appending(path: "missing"), pixelSize: base.pixelSize,
                store: FrameImageStore(), loadedFamilies: []))
        let second = await CharacterLoader().loadForSelection(packURL: secondURL)
        let h = PetRuntimeTests.Harness(readScreens: { [screen] }, readWindowList: { [] })
        h.runtime.start()
        h.runtime.show(old)
        h.frames(2)
        var staleIssues = 0
        h.runtime.onCharacterIssuesChange = { _ in staleIssues += 1 }
        // Capture the actual runtime task before yielding. Missing resources guarantee an observable failure.
        let pending = Array(h.runtime.behaviorFamilyTasks.values)
        #expect(!pending.isEmpty)
        if stopping {
            h.runtime.stop()
        } else {
            #expect(h.runtime.replaceCharacter(second))
        }
        let expected = h.runtime.currentSnapshot
        for task in pending { await task.value }
        #expect(old.isDegraded, "The old family really failed; callbacks would be observable without the guard")
        #expect(h.runtime.currentSnapshot == expected && staleIssues == 0)
        #expect(h.runtime.behaviorFamilyTasks.isEmpty)
        if stopping { #expect(expected.pets.isEmpty) }
    }
}
