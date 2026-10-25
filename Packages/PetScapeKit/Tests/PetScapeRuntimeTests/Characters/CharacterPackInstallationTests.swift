import CoreGraphics
import Darwin
import Foundation
import ImageIO
import PetScapeCore
import PetScapePlatform
import Testing
import UniformTypeIdentifiers

@testable import PetScapeRuntime

@Suite("M19 user character pack installation", .serialized)
struct CharacterPackInstallationTests {
    private func pack(_ id: String, frames: [String] = ["walk.png"]) throws -> URL {
        try TestPacks.make(
            manifest: TestPacks.manifest(walkFrames: frames).replacingOccurrences(
                of: "\"fixture\"", with: "\"\(id)\""),
            images: Array(Set(frames)).sorted())
    }

    private func encodedPNG(_ image: CGImage) throws -> Data {
        try encoded(image, type: UTType.png, frameCount: 1)
    }

    private func encoded(_ image: CGImage, type: UTType, frameCount: Int) throws -> Data {
        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output, type.identifier as CFString, frameCount, nil)
        else { throw TestPacks.PackError() }
        for _ in 0..<frameCount { CGImageDestinationAddImage(destination, image, nil) }
        guard CGImageDestinationFinalize(destination) else { throw TestPacks.PackError() }
        return output as Data
    }

    private func expectImportError(
        _ expected: CharacterPackImportError,
        source: URL,
        root: URL,
        bundledIDs: Set<CharacterID> = [],
        installedIDs: Set<CharacterID> = []
    ) async {
        do {
            _ = try await CharacterPackInstaller(rootURL: root).install(
                from: source, bundledIDs: bundledIDs, installedIDs: installedIDs, shouldContinue: { true })
            Issue.record("Expected character pack import to fail with \(expected).")
        } catch let error as CharacterPackImportError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected import error: \(error)")
        }
    }

    @Test func applicationSupportPathIsNamespacedUnderPetScapeCharacters() {
        let support = URL(fileURLWithPath: "/tmp/isolated-support", isDirectory: true)
        #expect(
            CharacterPackLocations.userCharactersRoot(applicationSupportDirectory: support).path
                == "/tmp/isolated-support/PetScape/Characters")
    }

    @Test func absentAndEmptyCharacterRootsReturnAnEmptyCatalog() async throws {
        let empty = try TestPacks.makeFolder()
        defer { try? FileManager.default.removeItem(at: empty) }
        let missing = empty.appending(path: "not-created", directoryHint: .isDirectory)

        let catalog = await CharacterCatalog.discover(bundledRoot: missing, installedRoot: empty)

        #expect(catalog.characters.isEmpty)
        #expect(catalog.unavailableCount == 0)
    }

    @Test func validInstallCopiesOnlyRuntimeInputsAndDuplicateNeverOverwrites() async throws {
        let source = try pack("custom")
        let root = try TestPacks.makeFolder()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: root)
        }
        try Data("ignored user data".utf8).write(to: source.appending(path: "notes.txt"))
        let installer = CharacterPackInstaller(rootURL: root)
        let installed = try await installer.install(
            from: source, bundledIDs: [], installedIDs: [], shouldContinue: { true })
        let destination = root.appending(path: "custom", directoryHint: .isDirectory)
        #expect(installed.id == CharacterID("custom") && installed.origin == .installed)
        #expect(installed.packURL == destination)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: destination.path).sorted()
                == ["character.json", "walk.png"])
        let originalManifest = try Data(contentsOf: destination.appending(path: "character.json"))

        await expectImportError(.duplicateInstalledID, source: source, root: root)

        #expect(try Data(contentsOf: destination.appending(path: "character.json")) == originalManifest)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["custom"])
    }

    @Test func bundledIDCollisionIsRejectedAndDoesNotCreateStaging() async throws {
        let source = try pack("cat")
        let root = try TestPacks.makeFolder()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: root)
        }
        await expectImportError(
            .duplicateBundledID, source: source, root: root, bundledIDs: [CharacterID("cat")])
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func missingInvalidAndUnsafeResourcesAreRejectedBeforePromotion() async throws {
        let root = try TestPacks.makeFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = try TestPacks.make(manifest: TestPacks.manifest(walkFrames: ["missing.png"]), images: [])
        defer { try? FileManager.default.removeItem(at: missing) }
        await expectImportError(.invalidPack, source: missing, root: root)

        let malformed = try pack("malformed")
        defer { try? FileManager.default.removeItem(at: malformed) }
        try Data("not a PNG".utf8).write(to: malformed.appending(path: "walk.png"))
        await expectImportError(.invalidPack, source: malformed, root: root)

        let traversal = try TestPacks.make(
            manifest: TestPacks.manifest(walkFrames: ["../outside.png"]), images: [])
        defer { try? FileManager.default.removeItem(at: traversal) }
        await expectImportError(.invalidPack, source: traversal, root: root)

        let invalidID = try pack("bad_id")
        defer { try? FileManager.default.removeItem(at: invalidID) }
        await expectImportError(.invalidPack, source: invalidID, root: root)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func extensionDoesNotSubstituteForPNGFormatAndAnimatedImageIsRejected() async throws {
        let root = try TestPacks.makeFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let image = try TestPacks.opaqueImage(side: 64)

        let jpeg = try pack("jpeg")
        defer { try? FileManager.default.removeItem(at: jpeg) }
        try encoded(image, type: UTType.jpeg, frameCount: 1).write(to: jpeg.appending(path: "walk.png"))
        await expectImportError(.invalidPack, source: jpeg, root: root)

        let animated = try pack("animated")
        defer { try? FileManager.default.removeItem(at: animated) }
        try encoded(image, type: UTType.gif, frameCount: 2).write(to: animated.appending(path: "walk.png"))
        await expectImportError(.invalidPack, source: animated, root: root)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func symlinksExecutableFilesAndNormalizedDuplicatePathsAreRejected() async throws {
        let root = try TestPacks.makeFolder()
        let outside = try pack("outside")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }

        let linked = try pack("linked")
        defer { try? FileManager.default.removeItem(at: linked) }
        try FileManager.default.createSymbolicLink(
            at: linked.appending(path: "extra.png"), withDestinationURL: outside.appending(path: "walk.png"))
        await expectImportError(.unsafePack, source: linked, root: root)

        let executable = try pack("executable")
        defer { try? FileManager.default.removeItem(at: executable) }
        let executableURL = executable.appending(path: "extra.sh")
        try Data("ignored".utf8).write(to: executableURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executableURL.path)
        await expectImportError(.unsafePack, source: executable, root: root)

        let ambiguous = try TestPacks.make(
            manifest: TestPacks.manifest(walkFrames: ["walk.png", "WALK.png"]), images: ["walk.png"])
        defer { try? FileManager.default.removeItem(at: ambiguous) }
        await expectImportError(.unsafePack, source: ambiguous, root: root)

        let special = try pack("special")
        defer { try? FileManager.default.removeItem(at: special) }
        let fifoPath = special.appending(path: "pipe").path
        let fifoStatus = fifoPath.withCString { Darwin.mkfifo($0, mode_t(0o600)) }
        #expect(fifoStatus == 0)
        await expectImportError(.unsafePack, source: special, root: root)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func selectedTreeEntryAndDepthBoundsAreEnforced() async throws {
        let root = try TestPacks.makeFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let tooManyEntries = try pack("entry-limit")
        defer { try? FileManager.default.removeItem(at: tooManyEntries) }
        for index in 0..<2_050 {
            FileManager.default.createFile(
                atPath: tooManyEntries.appending(path: "extra-\(index).txt").path, contents: Data())
        }
        await expectImportError(.resourceLimit, source: tooManyEntries, root: root)

        let tooDeep = try pack("depth-limit")
        defer { try? FileManager.default.removeItem(at: tooDeep) }
        var nested = tooDeep
        for _ in 0...CharacterPackPolicy.maximumTreeDepth {
            nested.append(path: "nested")
        }
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        await expectImportError(.resourceLimit, source: tooDeep, root: root)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func sourceDimensionsAndAggregateDecodedBytesAreBounded() async throws {
        let root = try TestPacks.makeFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let tooWide = try pack("dimension-limit")
        defer { try? FileManager.default.removeItem(at: tooWide) }
        let wideContext = CGContext(
            data: nil, width: CharacterPackPolicy.maximumSourceImageDimension + 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        let wideImage = try #require(wideContext?.makeImage())
        try TestPacks.writePNG(wideImage, to: tooWide.appending(path: "walk.png"))
        await expectImportError(.resourceLimit, source: tooWide, root: root)

        let imageCount = 29
        let paths = (0..<imageCount).map { "frame-\($0).png" }
        let manifest = TestPacks.manifest(walkFrames: paths)
            .replacingOccurrences(of: "\"fixture\"", with: "\"decode-limit\"")
            .replacingOccurrences(
                of: #""displaySize": { "width": 32, "height": 32 }"#,
                with: #""displaySize": { "width": 256, "height": 256 }"#)
        let decodedLimit = try TestPacks.make(manifest: manifest, images: [])
        defer { try? FileManager.default.removeItem(at: decodedLimit) }
        let largeImageData = try encodedPNG(
            TestPacks.opaqueImage(side: CharacterPackPolicy.maximumSourceImageDimension))
        for path in paths {
            try largeImageData.write(to: decodedLimit.appending(path: path))
        }
        await expectImportError(.resourceLimit, source: decodedLimit, root: root)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func manifestFrameAndFileByteBudgetsAreEnforced() async throws {
        let root = try TestPacks.makeFolder()
        defer { try? FileManager.default.removeItem(at: root) }

        let tooManyFrames = try pack("frames", frames: Array(repeating: "walk.png", count: 513))
        defer { try? FileManager.default.removeItem(at: tooManyFrames) }
        await expectImportError(.resourceLimit, source: tooManyFrames, root: root)

        let hugeManifest = try TestPacks.make(manifest: nil, images: [])
        defer { try? FileManager.default.removeItem(at: hugeManifest) }
        try Data(repeating: 32, count: CharacterPackPolicy.maximumManifestBytes + 1)
            .write(to: hugeManifest.appending(path: "character.json"))
        await expectImportError(.resourceLimit, source: hugeManifest, root: root)

        let hugeImage = try pack("large-file")
        defer { try? FileManager.default.removeItem(at: hugeImage) }
        try Data(repeating: 0, count: CharacterPackPolicy.maximumImageFileBytes + 1)
            .write(to: hugeImage.appending(path: "walk.png"))
        await expectImportError(.resourceLimit, source: hugeImage, root: root)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test func catalogCombinesRealBundledAndInstalledEntriesAndOmitsLaterCorruption() async throws {
        let root = try TestPacks.makeFolder()
        let source = try pack("custom")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: source)
        }
        _ = try await CharacterPackInstaller(rootURL: root).install(
            from: source, bundledIDs: [], installedIDs: [], shouldContinue: { true })

        let catalog = await CharacterCatalog.discover(
            bundledRoot: TestPacks.catPackURL.deletingLastPathComponent(), installedRoot: root)
        #expect(catalog.characters.map(\.id) == [CharacterID("cat"), CharacterID("custom")])
        #expect(catalog.characters.first?.origin == .bundled)
        #expect(catalog.characters.last?.origin == .installed)
        #expect(catalog.unavailableCount == 0)

        try Data("corrupt".utf8).write(to: root.appending(path: "custom/walk.png"))
        let rediscovered = await CharacterCatalog.discover(
            bundledRoot: TestPacks.catPackURL.deletingLastPathComponent(), installedRoot: root)
        #expect(rediscovered.characters.map(\.id) == [CharacterID("cat")])
        #expect(rediscovered.unavailableCount == 1)
    }

    @Test func realDimasPackInstallsAndRunsBesideTheBundledCat() async throws {
        let root = try TestPacks.makeFolder()
        let dimasURL = TestPacks.repositoryRoot.appending(path: "packs/human-programmer")
        defer { try? FileManager.default.removeItem(at: root) }

        let validatedDimas = await CharacterLoader().loadForSelection(packURL: dimasURL)
        #expect(!validatedDimas.isPlaceholder && !validatedDimas.isDegraded)
        #expect(validatedDimas.definition.id == CharacterID("human-programmer"))
        #expect(validatedDimas.definition.displayName == "Dimas")
        #expect(validatedDimas.definition.clips["dance"] != nil)
        #expect(validatedDimas.definition.clips["cleanup"] != nil)

        _ = try await CharacterPackInstaller(rootURL: root).install(
            from: dimasURL, bundledIDs: [CharacterID("cat")], installedIDs: [], shouldContinue: { true })
        let catalog = await CharacterCatalog.discover(
            bundledRoot: TestPacks.catPackURL.deletingLastPathComponent(), installedRoot: root)
        #expect(catalog.characters.map(\.id) == [CharacterID("cat"), CharacterID("human-programmer")])
        #expect(catalog.characters.last?.origin == .installed)
        #expect(catalog.unavailableCount == 0)

        let preferences = InMemoryPreferencesStore()
        let harness = PetRuntimeTests.Harness(preferences: preferences)
        harness.runtime.start()
        let roster = CharacterRosterModel(preferences: preferences, runtime: harness.runtime, installedPacksRoot: root)
        await roster.start(catalog: catalog)
        await roster.add(CharacterID("human-programmer"))

        #expect(
            roster.activeCharacters.map { $0.character.id } == [CharacterID("cat"), CharacterID("human-programmer")])
        #expect(roster.activeCharacters.last?.character.origin == .installed)
        #expect(harness.runtime.pets.count == 2)
        #expect(harness.runtime.pets.map(\.characterID) == [CharacterID("cat"), CharacterID("human-programmer")])
        #expect(preferences.activeCharacterIDs == ["cat", "human-programmer"])
        let catID = try #require(harness.runtime.pets.first?.id)
        let dimasID = try #require(harness.runtime.pets.last?.id)
        let cat = try #require(harness.runtime.loadedCharacter(for: catID))
        let dimas = try #require(harness.runtime.loadedCharacter(for: dimasID))
        let aggregateInitialBytes = cat.decodedByteCount + dimas.decodedByteCount
        print("M20 Cat + Dimas initial decoded frame bytes: \(aggregateInitialBytes)")
        #expect(cat.decodedByteCount <= 16 * 1024 * 1024)
        #expect(dimas.decodedByteCount <= 16 * 1024 * 1024)
        #expect(aggregateInitialBytes <= 32 * 1024 * 1024)
        harness.runtime.stop()
    }

    @Test func installationDoesNotActivateUntilTheUserAddsItFromTheRoster() async throws {
        let source = try pack("custom")
        let root = try TestPacks.makeFolder()
        let bundledURL = try pack("cat")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: bundledURL)
            try? FileManager.default.removeItem(at: root)
        }
        let bundled = await CharacterLoader().loadForSelection(packURL: bundledURL)
        let prefs = InMemoryPreferencesStore()
        let harness = PetRuntimeTests.Harness(preferences: prefs)
        harness.runtime.start()
        let model = CharacterRosterModel(preferences: prefs, runtime: harness.runtime, installedPacksRoot: root)
        await model.start(
            catalog: CharacterCatalog(characters: [
                CharacterCatalogEntry(character: bundled, packURL: bundledURL)
            ]))
        #expect(model.activeCharacters.map { $0.character.id } == [CharacterID("cat")])
        #expect(prefs.activeCharacterIDs == ["cat"])

        await model.installPack(from: source)
        #expect(model.installationSucceeded && model.installIssue == nil)
        #expect(model.characters.map(\.id) == [CharacterID("cat"), CharacterID("custom")])
        #expect(model.activeCharacters.map { $0.character.id } == [CharacterID("cat")])
        #expect(prefs.activeCharacterIDs == ["cat"])

        await model.add(CharacterID("custom"))
        #expect(model.activeCharacters.map { $0.character.id } == [CharacterID("cat"), CharacterID("custom")])
        #expect(prefs.activeCharacterIDs == ["cat", "custom"])
        #expect(model.activeCharacters.last?.character.origin == .installed)
        harness.runtime.stop()
    }

    @Test func removedInstalledPreferenceFallsBackOnlyAfterBundledCharacterApplies() async throws {
        let root = try TestPacks.makeFolder()
        let bundledRoot = try TestPacks.makeFolder()
        let externalSource = try pack("external")
        let bundledSource = try pack("cat")
        let bundledURL = bundledRoot.appending(path: "cat", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: bundledSource, to: bundledURL)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: bundledRoot)
            try? FileManager.default.removeItem(at: externalSource)
        }
        _ = try await CharacterPackInstaller(rootURL: root).install(
            from: externalSource, bundledIDs: [], installedIDs: [], shouldContinue: { true })
        let preferences = InMemoryPreferencesStore()
        preferences.activeCharacterIDs = ["external"]
        let firstHarness = PetRuntimeTests.Harness(preferences: preferences)
        firstHarness.runtime.start()
        let selection = CharacterRosterModel(
            preferences: preferences, runtime: firstHarness.runtime, installedPacksRoot: root)
        let present = await CharacterCatalog.discover(bundledRoot: bundledRoot, installedRoot: root)
        await selection.start(catalog: present)
        #expect(selection.activeCharacters.map { $0.character.id } == [CharacterID("external")])
        #expect(preferences.activeCharacterIDs == ["external"])

        try FileManager.default.removeItem(at: root.appending(path: "external"))
        let afterRemoval = await CharacterCatalog.discover(bundledRoot: bundledRoot, installedRoot: root)
        #expect(afterRemoval.characters.map(\.id) == [CharacterID("cat")])
        let restartedHarness = PetRuntimeTests.Harness(preferences: preferences)
        restartedHarness.runtime.start()
        let restarted = CharacterRosterModel(preferences: preferences, runtime: restartedHarness.runtime)
        await restarted.start(catalog: afterRemoval)
        #expect(restarted.activeCharacters.map { $0.character.id } == [CharacterID("cat")])
        #expect(preferences.activeCharacterIDs == ["cat"])
        firstHarness.runtime.stop()
        restartedHarness.runtime.stop()
    }

    @Test func interruptedSelectionNeverStartsAnImportOrChangesPreferences() async throws {
        let source = try pack("custom")
        let root = try TestPacks.makeFolder()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: root)
        }
        let prefs = InMemoryPreferencesStore()
        prefs.activeCharacterIDs = ["persisted"]
        let harness = PetRuntimeTests.Harness(preferences: prefs)
        harness.runtime.start()
        let model = CharacterRosterModel(preferences: prefs, runtime: harness.runtime, installedPacksRoot: root)
        model.stop()
        await model.installPack(from: source)
        #expect(model.characters.isEmpty && prefs.activeCharacterIDs == ["persisted"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        harness.runtime.stop()
    }

    @Test func cancellationAfterStagingRemovesTemporaryDirectory() async throws {
        let source = try pack("cancelled")
        let root = try TestPacks.makeFolder()
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: root)
        }
        var continuationChecks = 0
        do {
            _ = try await CharacterPackInstaller(rootURL: root).install(
                from: source, bundledIDs: [], installedIDs: [],
                shouldContinue: {
                    continuationChecks += 1
                    return continuationChecks < 4
                })
            Issue.record("Expected the cancelled import to stop after staging.")
        } catch let error as CharacterPackImportError {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Unexpected import error: \(error)")
        }
        #expect(continuationChecks == 4)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
}
