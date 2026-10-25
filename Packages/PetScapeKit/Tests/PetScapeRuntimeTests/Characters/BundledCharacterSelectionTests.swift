import Foundation
import PetScapeCore
import PetScapePlatform
import Testing

@testable import PetScapeRuntime

@Suite("M20 character roster", .serialized)
struct BundledCharacterSelectionTests {
    private func pack(_ id: String) throws -> URL {
        try TestPacks.make(
            manifest: TestPacks.manifest(walkFrames: ["walk.png"]).replacingOccurrences(
                of: "\"fixture\"", with: "\"\(id)\""), images: ["walk.png"])
    }

    private func entry(_ id: String, at url: URL) async -> CharacterCatalogEntry {
        let loaded = await CharacterLoader().loadForSelection(packURL: url)
        return CharacterCatalogEntry(character: loaded, packURL: url)
    }

    @Test func catalogUsesManifestIdentityRejectsInvalidAndDuplicatePacksWithoutRecursing() async throws {
        let root = try TestPacks.makeFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        for (folder, id) in [("renamed-folder", "cat"), ("other", "second"), ("duplicate", "second")] {
            let source = try pack(id)
            try FileManager.default.moveItem(at: source, to: root.appending(path: folder))
        }
        let broken = try TestPacks.make(manifest: "{}", images: [])
        try FileManager.default.moveItem(at: broken, to: root.appending(path: "broken"))
        let nested = try TestPacks.makeFolder()
        try FileManager.default.moveItem(at: nested, to: root.appending(path: "container"))
        let hidden = try pack("nested")
        try FileManager.default.moveItem(at: hidden, to: root.appending(path: "container/nested"))
        let catalog = await CharacterCatalog.discover(in: root)
        #expect(catalog.characters.map(\.id) == [CharacterID("cat")])
        #expect(catalog.unavailableCount == 4)
        #expect(catalog.characters.first?.packURL.lastPathComponent == "renamed-folder")
    }

    @Test func actualShippingSourceContainsOnlyOneCompleteCatWithLazyInitialResidency() async {
        let root = TestPacks.catPackURL.deletingLastPathComponent()
        let catalog = await CharacterCatalog.discover(in: root)
        #expect(catalog.characters.map(\.id) == [CharacterID("cat")])
        #expect(catalog.unavailableCount == 0)
        let cat = await CharacterLoader().loadForSelection(packURL: TestPacks.catPackURL)
        #expect(!cat.isPlaceholder && !cat.isDegraded)
        #expect(cat.definition.clips.count == 12)
        #expect(cat.decodedByteCount <= 16 * 1024 * 1024)
        #expect(cat.frames["dance"] == nil)
    }

    @Test func strictSelectionRejectsMissingOptionalResourcesInsteadOfPresentingADegradedOption() async throws {
        let url = try TestPacks.make(
            manifest: TestPacks.manifest(walkFrames: ["walk.png"], sitFrames: ["missing.png"]),
            images: ["walk.png"])
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(await CharacterLoader().loadForSelection(packURL: url).isPlaceholder)
    }

    @Test func startupAddsSavedRosterInOrderAndRestoreDefaultsKeepsIt() async throws {
        let firstURL = try pack("cat")
        let secondURL = try pack("second")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let catalog = CharacterCatalog(characters: [
            await entry("second", at: secondURL), await entry("cat", at: firstURL),
        ])
        let prefs = InMemoryPreferencesStore(isPaused: true, isHidden: true)
        prefs.isMusicDancingEnabled = true
        let firstHarness = PetRuntimeTests.Harness(preferences: prefs)
        firstHarness.runtime.start()
        let firstModel = CharacterRosterModel(preferences: prefs, runtime: firstHarness.runtime)
        await firstModel.start(catalog: catalog)
        #expect(firstModel.activeCharacters.map { $0.character.id } == [CharacterID("cat")])
        await firstModel.add(CharacterID("second"))
        #expect(firstModel.activeCharacters.map { $0.character.id } == [CharacterID("cat"), CharacterID("second")])
        #expect(prefs.activeCharacterIDs == ["cat", "second"])
        #expect(firstHarness.runtime.pets.map(\.id) == firstModel.activeCharacters.map(\.petID))

        let secondHarness = PetRuntimeTests.Harness(preferences: prefs)
        secondHarness.runtime.start()
        let restarted = CharacterRosterModel(preferences: prefs, runtime: secondHarness.runtime)
        await restarted.start(catalog: catalog)
        #expect(restarted.activeCharacters.map { $0.character.id } == [CharacterID("cat"), CharacterID("second")])
        #expect(restarted.activeCharacters.map(\.petID) == secondHarness.runtime.pets.map(\.id))

        #expect(restarted.remove(restarted.activeCharacters[0].petID))
        #expect(restarted.activeCharacters.map { $0.character.id } == [CharacterID("second")])
        #expect(prefs.activeCharacterIDs == ["second"])
        prefs.restoreDefaults()
        #expect(prefs.activeCharacterIDs == ["second"])
        #expect(prefs.isPaused == false && prefs.isHidden == false && !prefs.isMusicDancingEnabled)
        secondHarness.runtime.stop()
        firstHarness.runtime.stop()
    }

    @Test func explicitEmptyRosterSurvivesRestartWithoutPlaceholderOrDefaultPet() async throws {
        let url = try pack("cat")
        defer { try? FileManager.default.removeItem(at: url) }
        let catalog = CharacterCatalog(characters: [await entry("cat", at: url)])
        let prefs = InMemoryPreferencesStore()
        prefs.activeCharacterIDs = []
        let harness = PetRuntimeTests.Harness(preferences: prefs)
        harness.runtime.start()
        let model = CharacterRosterModel(preferences: prefs, runtime: harness.runtime)
        await model.start(catalog: catalog)
        #expect(model.activeCharacters.isEmpty)
        #expect(harness.runtime.pets.isEmpty)
        #expect(!harness.runtime.hasPlaceholderCharacter)
        #expect(prefs.activeCharacterIDs == [])
        harness.runtime.stop()
    }

    @Test func startupFiltersDuplicateAndMissingIDsThenUsesAvailableSavedCharacter() async throws {
        let firstURL = try pack("alpha")
        let secondURL = try pack("zeta")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let catalog = CharacterCatalog(characters: [
            await entry("zeta", at: secondURL), await entry("alpha", at: firstURL),
        ])
        let prefs = InMemoryPreferencesStore()
        prefs.activeCharacterIDs = ["removed", "zeta", "zeta"]
        let harness = PetRuntimeTests.Harness(preferences: prefs)
        harness.runtime.start()
        let model = CharacterRosterModel(preferences: prefs, runtime: harness.runtime)
        await model.start(catalog: catalog)
        #expect(model.activeCharacters.map { $0.character.id } == [CharacterID("zeta")])
        #expect(prefs.activeCharacterIDs == ["zeta"])
        harness.runtime.stop()
    }

    @Test func startupFallsBackLexicallyWhenNoSavedRosterIDIsUsable() async throws {
        let zetaURL = try pack("zeta")
        let alphaURL = try pack("alpha")
        defer {
            try? FileManager.default.removeItem(at: zetaURL)
            try? FileManager.default.removeItem(at: alphaURL)
        }
        let catalog = CharacterCatalog(
            characters: [await entry("zeta", at: zetaURL), await entry("alpha", at: alphaURL)])
        let prefs = InMemoryPreferencesStore()
        prefs.activeCharacterIDs = ["", "missing"]
        let harness = PetRuntimeTests.Harness(preferences: prefs)
        harness.runtime.start()

        let model = CharacterRosterModel(preferences: prefs, runtime: harness.runtime)
        await model.start(catalog: catalog)

        #expect(model.activeCharacters.map { $0.character.id } == [CharacterID("alpha")])
        #expect(prefs.activeCharacterIDs == ["alpha"])
        harness.runtime.stop()
    }

    @Test func addRejectsConcurrentDuplicateRequestsAndCancelledLateResult() async throws {
        let url = try pack("second")
        defer { try? FileManager.default.removeItem(at: url) }
        let candidate = await entry("second", at: url)
        let prefs = InMemoryPreferencesStore()
        prefs.activeCharacterIDs = []
        let harness = PetRuntimeTests.Harness(preferences: prefs)
        harness.runtime.start()
        var loadCount = 0
        var continuation: CheckedContinuation<LoadedCharacter, Never>?
        let model = CharacterRosterModel(
            preferences: prefs, runtime: harness.runtime,
            load: { _ in
                loadCount += 1
                return await withCheckedContinuation { continuation = $0 }
            })
        await model.start(catalog: CharacterCatalog(characters: [candidate]))
        let task = Task { await model.add(CharacterID("second")) }
        while continuation == nil { await Task.yield() }
        await model.add(CharacterID("second"))
        #expect(loadCount == 1)
        model.cancelAdd(CharacterID("second"))
        continuation?.resume(returning: await CharacterLoader().loadForSelection(packURL: url))
        await task.value
        #expect(model.activeCharacters.isEmpty)
        #expect(prefs.activeCharacterIDs == [])
        harness.runtime.stop()
    }

    @Test func changedManifestIdentityIsNotAddedUnderItsOldCatalogID() async throws {
        let url = try pack("cat")
        defer { try? FileManager.default.removeItem(at: url) }
        let candidate = await entry("cat", at: url)
        let manifestURL = url.appending(path: "character.json")
        let data = try String(contentsOf: manifestURL, encoding: .utf8).replacingOccurrences(
            of: "\"cat\"", with: "\"changed\"")
        try data.write(to: manifestURL, atomically: true, encoding: .utf8)
        let prefs = InMemoryPreferencesStore()
        prefs.activeCharacterIDs = ["cat"]
        let harness = PetRuntimeTests.Harness(preferences: prefs)
        harness.runtime.start()
        let model = CharacterRosterModel(preferences: prefs, runtime: harness.runtime)
        await model.start(catalog: CharacterCatalog(characters: [candidate]))
        #expect(model.characters.isEmpty)
        #expect(model.activeCharacters.isEmpty)
        #expect(harness.runtime.hasPlaceholderCharacter)
        #expect(prefs.activeCharacterIDs == ["cat"])
        harness.runtime.stop()
    }

    @Test func catalogDoesNotFollowDirectoryOrResourceSymlinksOutsideItsRoot() async throws {
        let root = try TestPacks.makeFolder()
        let outside = try pack("outside")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createSymbolicLink(at: root.appending(path: "external"), withDestinationURL: outside)
        let inside = try pack("inside")
        let moved = root.appending(path: "inside")
        try FileManager.default.moveItem(at: inside, to: moved)
        try FileManager.default.removeItem(at: moved.appending(path: "walk.png"))
        try FileManager.default.createSymbolicLink(
            at: moved.appending(path: "walk.png"), withDestinationURL: outside.appending(path: "walk.png"))
        let catalog = await CharacterCatalog.discover(in: root)
        #expect(catalog.characters.isEmpty && catalog.unavailableCount == 1)
    }
}
