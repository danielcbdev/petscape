import CoreGraphics
import Foundation
import PetScapeCore
import Testing

@testable import PetScapeRendering

@Suite("FrameImageStore")
struct FrameImageStoreTests {
    let character = CharacterID("fixture")

    private func makePack(_ files: [String: CGImage]) throws -> URL {
        let folder = try TestImages.temporaryDirectory()
        for (path, image) in files { try TestImages.writePNG(image, to: folder.appending(path: path)) }
        return folder
    }

    @Test func targetPixelSizeFollowsTheSpec() {
        #expect(FrameImageStore.targetPixelSize(for: .init(width: 96, height: 96)) == 288)
        #expect(FrameImageStore.targetPixelSize(for: .init(width: 96, height: 64), maxUserScale: 1) == 192)
        #expect(FrameImageStore.targetPixelSize(for: .init(width: 33.3, height: 10)) == 100)
    }

    @Test func preloadsCachesAndReportsProbes() async throws {
        let pack = try makePack([
            "a.png": try TestImages.opaque(width: 64, height: 64),
            "b.png": try TestImages.opaque(width: 64, height: 32),
        ])
        let store = FrameImageStore()
        let result = await store.preload(
            character: character, packURL: pack, sources: [.image("a.png"), .image("b.png")], pixelSize: 32)

        #expect(result.failures.isEmpty)
        #expect(result.probes["a.png"] == .decoded(pixelWidth: 64, pixelHeight: 64))
        #expect(result.probes["b.png"] == .decoded(pixelWidth: 64, pixelHeight: 32))
        let a = try #require(store.frame(character: character, source: .image("a.png"), pixelSize: 32))
        #expect(a.image.width == 32)
        #expect(a.hitMask.width == 8)
        #expect(store.cachedFrameCount == 2)

        let again = await store.preload(character: character, packURL: pack, sources: [.image("a.png")], pixelSize: 32)
        #expect(again.probes.isEmpty, "Cached sources are not decoded again")
    }

    @Test func missingAndBrokenFilesAreReportedWhileTheRestLoads() async throws {
        let pack = try makePack(["ok.png": try TestImages.opaque(width: 16, height: 16)])
        try Data("garbage".utf8).write(to: pack.appending(path: "broken.png"))
        let store = FrameImageStore()
        let result = await store.preload(
            character: character, packURL: pack,
            sources: [.image("ok.png"), .image("gone.png"), .image("broken.png")], pixelSize: 16)

        #expect(result.probes["gone.png"] == .missing)
        #expect(result.probes["broken.png"] == .undecodable)
        #expect(result.failures["gone.png"] == .missingFile("gone.png"))
        #expect(result.failures["broken.png"] == .undecodable("broken.png"))
        #expect(store.frame(character: character, source: .image("ok.png"), pixelSize: 16) != nil)
        #expect(store.frame(character: character, source: .image("gone.png"), pixelSize: 16) == nil)
    }

    @Test func thePixelSizeIsPartOfTheCacheKey() async throws {
        let pack = try makePack(["a.png": try TestImages.opaque(width: 64, height: 64)])
        let store = FrameImageStore()
        _ = await store.preload(character: character, packURL: pack, sources: [.image("a.png")], pixelSize: 64)
        _ = await store.preload(character: character, packURL: pack, sources: [.image("a.png")], pixelSize: 16)
        #expect(store.frame(character: character, source: .image("a.png"), pixelSize: 64)?.image.width == 64)
        #expect(store.frame(character: character, source: .image("a.png"), pixelSize: 16)?.image.width == 16)
        #expect(store.cachedFrameCount == 2)
    }

    @Test func accountsDecodedMemoryAndEvicts() async throws {
        let pack = try makePack(["a.png": try TestImages.opaque(width: 32, height: 32)])
        let store = FrameImageStore()
        _ = await store.preload(character: character, packURL: pack, sources: [.image("a.png")], pixelSize: 32)
        let frame = try #require(store.frame(character: character, source: .image("a.png"), pixelSize: 32))
        #expect(store.decodedByteCount == frame.image.bytesPerRow * frame.image.height)
        #expect(store.decodedByteCount >= 32 * 32 * 4)

        store.evict(character: character)
        #expect(store.decodedByteCount == 0)
        #expect(store.cachedFrameCount == 0)
    }

    @Test func aSheetIsDecodedOnceAndCountedOnce() async throws {
        let pack = try makePack(["atlas.png": try TestImages.opaque(width: 128, height: 64)])
        let sheet = AnimationClip.Sheet(image: "atlas.png", columns: 2, rows: 1)
        let store = FrameImageStore()
        let result = await store.preload(
            character: character, packURL: pack,
            sources: [.sheetCell(sheet, cell: 0), .sheetCell(sheet, cell: 1)], pixelSize: 32)

        #expect(result.probes == ["atlas.png": .decoded(pixelWidth: 128, pixelHeight: 64)])
        let cell = try #require(store.frame(character: character, source: .sheetCell(sheet, cell: 1), pixelSize: 32))
        #expect(cell.image.width == 32)
        #expect(store.cachedFrameCount == 2)
        let oneSheet = 64 * 32 * 4
        #expect(store.decodedByteCount < 2 * oneSheet, "One 64 × 32 sheet, not two copies")
    }

    @Test func insertsGeneratedFrames() throws {
        let store = FrameImageStore()
        let image = try #require(PlaceholderArtwork.makeImage(pixelSize: 64))
        store.insert(
            try #require(FrameImage(image: image)), character: character, source: .image("p.png"), pixelSize: 64)
        #expect(store.frame(character: character, source: .image("p.png"), pixelSize: 64) != nil)
        #expect(store.decodedByteCount == image.bytesPerRow * image.height)
    }

    /// AC-M4-02: the decoded cat walk frames fit in 3 MiB at the 288 px target.
    @Test func theDecodedCatFramesFitTheMemoryBudget() async throws {
        let cat = CharacterID("cat")
        let pixelSize = FrameImageStore.targetPixelSize(for: .init(width: 96, height: 96))
        let store = FrameImageStore()
        let sources = (1...8).map { AnimationClip.FrameSource.image(TestImages.catWalkFrame($0)) }
        let result = await store.preload(
            character: cat, packURL: TestImages.catPackURL, sources: sources, pixelSize: pixelSize)

        #expect(result.failures.isEmpty)
        #expect(store.cachedFrameCount == 8)
        #expect(store.decodedByteCount(for: cat) <= 3 * 1024 * 1024, "\(store.decodedByteCount(for: cat)) bytes")
    }
}

@Suite("PlaceholderArtwork")
struct PlaceholderArtworkTests {
    @Test func drawsAVisibleSilhouette() throws {
        let image = try #require(PlaceholderArtwork.makeImage(pixelSize: 288))
        #expect(image.width == 288)
        let mask = try #require(HitMask(image: image))
        #expect(mask.contains(normalizedX: 0.5, y: 0.3))
        #expect(!mask.contains(normalizedX: 0.02, y: 0.98))
        #expect(!mask.contains(normalizedX: 0.5, y: 0.01), "Nothing below the contact point")
    }
}
