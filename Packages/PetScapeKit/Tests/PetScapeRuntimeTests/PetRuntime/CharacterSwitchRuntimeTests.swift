import CoreGraphics
import Foundation
import PetScapeCore
import PetScapePlatform
import PetScapeRendering
import Testing

@testable import PetScapeRuntime

@Suite("M20 multi-character runtime", .serialized)
struct CharacterSwitchRuntimeTests {
    private let screen = ScreenDescriptor(
        id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 800), backingScale: 2, isPrimary: true)

    private func pack(_ id: String, frameCount: Int = 1, fps: Double = 8, displaySize: Int = 32) throws -> URL {
        let frames = (0..<frameCount).map { "walk-\($0).png" }
        let manifest = TestPacks.manifest(walkFrames: frames, fps: fps)
            .replacingOccurrences(of: "\"fixture\"", with: "\"\(id)\"")
            .replacingOccurrences(
                of: "\"width\": 32, \"height\": 32",
                with: "\"width\": \(displaySize), \"height\": \(displaySize)")
        return try TestPacks.make(manifest: manifest, images: frames)
    }

    @Test(arguments: ["running", "paused", "hidden", "both"])
    func addingAndRemovingOnePetPreservesOthersAndSharedRunGates(_ mode: String) async throws {
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
        let firstPet = try #require(h.runtime.pets.first)
        let firstLayer = h.runtime.overlay.hostContentView?.petLayerHost.sublayers?.first
        h.runtime.setPaused(mode == "paused" || mode == "both")
        h.runtime.setHidden(mode == "hidden" || mode == "both")
        let beforeSettings = h.preferences.petSettings
        let beforeIntent = h.preferences.userIntent

        let secondID = try #require(h.runtime.addCharacter(second))
        #expect(secondID != firstPet.id)
        #expect(h.runtime.pets.count == 2)
        #expect(
            h.runtime.pets.map(\.characterID).sorted { $0.rawValue < $1.rawValue }
                == [CharacterID("first"), CharacterID("second")])
        #expect(h.runtime.pets.first(where: { $0.id == firstPet.id })?.position == firstPet.position)
        #expect(h.runtime.pets.first(where: { $0.id == firstPet.id })?.state == firstPet.state)
        #expect(
            h.runtime.pets.first(where: { $0.id == firstPet.id })?.animation.currentFrame
                == firstPet.animation.currentFrame)
        #expect(h.preferences.petSettings == beforeSettings && h.preferences.userIntent == beforeIntent)
        #expect(h.runtime.currentSnapshot.pets.count == 2)
        #expect(h.runtime.addCharacter(second) == nil)
        #expect(h.runtime.pets.count == 2)
        #expect(h.driver.isPaused == (mode != "running"))

        #expect(h.runtime.removeCharacter(firstPet.id))
        #expect(h.runtime.pets.map(\.id) == [secondID])
        #expect(h.runtime.currentSnapshot.pets.map(\.id) == [secondID])
        #expect(firstLayer?.superlayer == nil)
        #expect(h.runtime.overlay.hostContentView?.petLayerHost.sublayers?.count == 1)
        h.frames(3)
        #expect(h.runtime.currentSnapshot.pets.map(\.characterID) == [CharacterID("second")])
        #expect(!h.runtime.removeCharacter(firstPet.id))
    }

    @Test func removingAFlyingPetLeavesTheOtherPetUntouched() async throws {
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
        h.frames(3)
        let firstID = try #require(h.runtime.pets.first?.id)
        let secondID = try #require(h.runtime.addCharacter(second))
        h.runtime.setActivity(.idle, for: firstID)
        #expect(h.runtime.requestJump(to: .vertical, for: firstID))
        h.frames(20)
        let otherBefore = try #require(h.runtime.pets.first(where: { $0.id == secondID }))
        let otherSnapshot = h.runtime.currentSnapshot.pets.first(where: { $0.id == secondID })

        #expect(h.runtime.removeCharacter(firstID))
        #expect(h.runtime.pets.count == 1)
        #expect(h.runtime.pets[0].id == secondID)
        #expect(h.runtime.pets[0].position == otherBefore.position)
        #expect(h.runtime.pets[0].state == otherBefore.state)
        #expect(h.runtime.currentSnapshot.pets.first?.id == otherSnapshot?.id)
        h.frames(4)
        #expect(h.runtime.currentSnapshot.pets.count == 1)
        #expect(h.runtime.pets[0].characterID == CharacterID("second"))
    }

    @Test func eachActivePetUsesItsOwnFrameSequenceAndDisplaySize() async throws {
        let firstURL = try pack("first", frameCount: 4, fps: 4, displaySize: 32)
        let secondURL = try pack("second", frameCount: 12, fps: 15, displaySize: 48)
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = await CharacterLoader().loadForSelection(packURL: firstURL)
        let second = await CharacterLoader().loadForSelection(packURL: secondURL)
        let h = PetRuntimeTests.Harness(readScreens: { [screen] }, readWindowList: { [] })
        h.runtime.start()
        h.runtime.show(first)
        h.frames(3)
        let firstID = try #require(h.runtime.pets.first?.id)
        let secondID = try #require(h.runtime.addCharacter(second))
        h.frames(30)

        let firstPet = try #require(h.runtime.pets.first(where: { $0.id == firstID }))
        let secondPet = try #require(h.runtime.pets.first(where: { $0.id == secondID }))
        #expect(firstPet.size == CGSize(width: 32, height: 32))
        #expect(secondPet.size == CGSize(width: 48, height: 48))
        #expect(firstPet.animation.currentFrame.frameIndex != secondPet.animation.currentFrame.frameIndex)
        #expect(
            h.runtime.currentSnapshot.pets.first(where: { $0.id == firstID })?.size == CGSize(width: 32, height: 32))
        #expect(
            h.runtime.currentSnapshot.pets.first(where: { $0.id == secondID })?.size == CGSize(width: 48, height: 48))
        h.runtime.stop()
    }

    @Test func removedPetCannotPublishALateLazyFamilyResultOrIssues() async throws {
        let firstURL = try pack("first")
        let secondURL = try pack("second")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let base = await CharacterLoader().loadForSelection(packURL: firstURL)
        let old = LoadedCharacter(
            definition: base.definition, pixelSize: base.pixelSize,
            catalog: CharacterFrameCatalog(
                definition: base.definition, packURL: firstURL.appending(path: "missing"), pixelSize: base.pixelSize,
                store: FrameImageStore(), loadedFamilies: []))
        let second = await CharacterLoader().loadForSelection(packURL: secondURL)
        let h = PetRuntimeTests.Harness(readScreens: { [screen] }, readWindowList: { [] })
        h.runtime.start()
        h.runtime.show(old)
        let oldID = try #require(h.runtime.pets.first?.id)
        let secondID = try #require(h.runtime.addCharacter(second))
        var staleIssues = 0
        h.runtime.onCharacterIssuesChange = { _, issues in
            if !issues.isEmpty { staleIssues += 1 }
        }

        let pending = h.runtime.behaviorFamilyTasks.values.flatMap(\.values)
        #expect(!pending.isEmpty)
        #expect(h.runtime.removeCharacter(oldID))
        let expected = h.runtime.currentSnapshot
        for task in pending { await task.value }
        #expect(old.isDegraded, "The old family really failed; an unguarded callback would be observable")
        #expect(h.runtime.currentSnapshot == expected && staleIssues == 0)
        #expect(h.runtime.behaviorFamilyTasks[oldID] == nil)
        #expect(h.runtime.pets.map(\.id) == [secondID])
    }
}
