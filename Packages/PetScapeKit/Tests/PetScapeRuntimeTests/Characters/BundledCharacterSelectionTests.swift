import Foundation
import PetScapeCore
import PetScapePlatform
import Testing

@testable import PetScapeRuntime

@Suite("M18 bundled character selection", .serialized)
struct BundledCharacterSelectionTests {
    private func pack(_ id: String) throws -> URL {
        try TestPacks.make(
            manifest: TestPacks.manifest(walkFrames: ["walk.png"]).replacingOccurrences(
                of: "\"fixture\"", with: "\"\(id)\""), images: ["walk.png"])
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
        let catalog = await BundledCharacterCatalog.discover(in: root)
        #expect(catalog.characters.map(\.id) == [CharacterID("cat")])
        #expect(catalog.unavailableCount == 4)
        #expect(catalog.characters.first?.packURL.lastPathComponent == "renamed-folder")
    }

    @Test func actualShippingSourceContainsOnlyOneCompleteCatWithLazyInitialResidency() async {
        let root = TestPacks.catPackURL.deletingLastPathComponent()
        let catalog = await BundledCharacterCatalog.discover(in: root)
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

    @Test func defaultsPersistenceRestartUnknownRemovedAndFailurePreserveGlobalPreferences() async throws {
        let first = try pack("cat")
        let second = try pack("second")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let cat = await CharacterLoader().loadForSelection(packURL: first)
        let other = await CharacterLoader().loadForSelection(packURL: second)
        let entries = [
            BundledCharacter(character: cat, packURL: first), BundledCharacter(character: other, packURL: second),
        ]
        let catalog = BundledCharacterCatalog(characters: entries)
        let prefs = InMemoryPreferencesStore(isPaused: true, isHidden: true)
        prefs.isMusicDancingEnabled = true
        let before = prefs.petSettings
        var applied: LoadedCharacter?
        let model = CharacterSelectionModel(
            preferences: prefs,
            apply: {
                applied = $0; return true
            })
        await model.start(catalog: catalog)
        #expect(model.activeID == CharacterID("cat"))
        #expect(model.canSelect)
        await model.select(CharacterID("second"))
        #expect(applied !== other)  // Loading uses an independent image cache.
        #expect(applied?.definition.id == CharacterID("second"))
        #expect(prefs.selectedCharacterID == "second")
        let restarted = CharacterSelectionModel(preferences: prefs, apply: { _ in true })
        await restarted.start(catalog: catalog)
        #expect(restarted.activeID == CharacterID("second"))
        await restarted.start(catalog: BundledCharacterCatalog(characters: [entries[0]]))
        #expect(restarted.activeID == CharacterID("cat"))
        prefs.selectedCharacterID = "removed"
        await restarted.start(catalog: catalog)
        #expect(prefs.selectedCharacterID == "cat")
        try FileManager.default.removeItem(at: second.appending(path: "walk.png"))
        let previous = applied
        await model.select(CharacterID("second"))  // Already active: no reload.
        await model.select(CharacterID("cat"))
        let working = applied
        await model.select(CharacterID("second"))
        #expect(applied === working)
        #expect(previous !== working)
        #expect(model.activeID == CharacterID("cat"))
        #expect(model.issue == .characterCouldNotLoad)
        #expect(prefs.selectedCharacterID == "cat")
        #expect(prefs.petSettings == before)
        #expect(prefs.isPaused && prefs.isHidden && prefs.isMusicDancingEnabled)
    }

    @Test func zeroOneAndMultipleStatesAndBusyRuntimeRejectionAreHonest() async throws {
        let url = try pack("only")
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = await CharacterLoader().loadForSelection(packURL: url)
        let entry = BundledCharacter(character: loaded, packURL: url)
        let prefs = InMemoryPreferencesStore()
        prefs.selectedCharacterID = "removed"
        var accepts = true
        let model = CharacterSelectionModel(preferences: prefs, apply: { _ in accepts })
        #expect(model.isLoading, "Settings must not show an empty catalog while initial discovery is running")
        await model.start(catalog: BundledCharacterCatalog())
        #expect(model.characters.isEmpty && !model.canSelect && model.activeID == nil)
        #expect(model.issue == .noBundledCharacters)
        #expect(prefs.selectedCharacterID == "removed")
        await model.start(catalog: BundledCharacterCatalog(characters: [entry]))
        #expect(!model.canSelect && model.activeID == CharacterID("only"))
        #expect(prefs.selectedCharacterID == "only")
        accepts = false
        await model.select(CharacterID("unknown"))
        #expect(model.activeID == CharacterID("only"))
        #expect(prefs.selectedCharacterID == "only")
    }

    @Test func rejectedRuntimeCommitKeepsSelectionAndAllowsExplicitRetry() async throws {
        let firstURL = try pack("cat")
        let secondURL = try pack("second")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = await CharacterLoader().loadForSelection(packURL: firstURL)
        let second = await CharacterLoader().loadForSelection(packURL: secondURL)
        let catalog = BundledCharacterCatalog(characters: [
            BundledCharacter(character: first, packURL: firstURL),
            BundledCharacter(character: second, packURL: secondURL),
        ])
        let prefs = InMemoryPreferencesStore()
        var accepts = true
        let model = CharacterSelectionModel(preferences: prefs, apply: { _ in accepts })
        await model.start(catalog: catalog)
        accepts = false
        await model.select(CharacterID("second"))
        #expect(model.activeID == CharacterID("cat") && prefs.selectedCharacterID == "cat")
        #expect(model.characters.count == 2 && model.issue == .waitForSafeBoundary && model.canSelect)
        accepts = true
        await model.select(CharacterID("second"))
        #expect(model.activeID == CharacterID("second") && model.issue == nil)
    }

    @Test func startupSkipsACandidateThatBecameInvalidAndUsesLexicalIDWhenCatIsAbsent() async throws {
        let firstURL = try pack("alpha")
        let secondURL = try pack("zeta")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = await CharacterLoader().loadForSelection(packURL: firstURL)
        let second = await CharacterLoader().loadForSelection(packURL: secondURL)
        let catalog = BundledCharacterCatalog(characters: [
            BundledCharacter(character: second, packURL: secondURL),
            BundledCharacter(character: first, packURL: firstURL),
        ])
        let prefs = InMemoryPreferencesStore()
        let model = CharacterSelectionModel(preferences: prefs, apply: { _ in true })
        await model.start(catalog: catalog)
        #expect(model.activeID == CharacterID("alpha"))
        try FileManager.default.removeItem(at: firstURL.appending(path: "character.json"))
        await model.start(catalog: catalog)
        #expect(model.activeID == CharacterID("zeta") && prefs.selectedCharacterID == "zeta")
        #expect(model.characters.count == 1 && model.unavailableCount == 1)
    }

    @Test func changedManifestIdentityIsNotCommittedUnderTheOldCatalogID() async throws {
        let url = try pack("cat")
        defer { try? FileManager.default.removeItem(at: url) }
        let cat = await CharacterLoader().loadForSelection(packURL: url)
        let entry = BundledCharacter(character: cat, packURL: url)
        let manifestURL = url.appending(path: "character.json")
        let data = try String(contentsOf: manifestURL, encoding: .utf8).replacingOccurrences(
            of: "\"cat\"", with: "\"changed\"")
        try data.write(to: manifestURL, atomically: true, encoding: .utf8)
        let prefs = InMemoryPreferencesStore()
        var IDs: [CharacterID] = []
        let model = CharacterSelectionModel(
            preferences: prefs,
            apply: {
                IDs.append($0.definition.id); return true
            })
        await model.start(catalog: BundledCharacterCatalog(characters: [entry]))
        #expect(IDs == [CharacterID("placeholder")])
        #expect(prefs.selectedCharacterID == nil && model.characters.isEmpty)
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
        let catalog = await BundledCharacterCatalog.discover(in: root)
        #expect(catalog.characters.isEmpty && catalog.unavailableCount == 1)
    }

    @Test(arguments: [false, true])
    func stoppedOrCancelledLoadingCannotApplyOrPersistALateResult(_ cancel: Bool) async throws {
        let url = try pack("cat")
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = await CharacterLoader().loadForSelection(packURL: url)
        let catalog = BundledCharacterCatalog(characters: [BundledCharacter(character: loaded, packURL: url)])
        let prefs = InMemoryPreferencesStore()
        var commits = 0
        var resume: CheckedContinuation<LoadedCharacter, Never>?
        let model = CharacterSelectionModel(
            preferences: prefs,
            apply: { _ in
                commits += 1; return true
            },
            load: { _ in await withCheckedContinuation { resume = $0 } })
        let task = Task { await model.start(catalog: catalog) }
        while resume == nil { await Task.yield() }
        if cancel { task.cancel() } else { model.stop() }
        resume?.resume(returning: loaded)
        await task.value
        #expect(commits == 0 && prefs.selectedCharacterID == nil)
        #expect(!model.isLoading)
    }
}
