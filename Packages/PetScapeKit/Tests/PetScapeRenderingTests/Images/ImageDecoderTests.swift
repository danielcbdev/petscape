import CoreGraphics
import Foundation
import Testing

@testable import PetScapeRendering

@Suite("ImageDecoder")
struct ImageDecoderTests {
    let decoder = ImageDecoder()

    @Test func downsamplesToTheTargetPixelSize() async throws {
        let folder = try TestImages.temporaryDirectory()
        let url = folder.appending(path: "big.png")
        try TestImages.writePNG(try TestImages.opaque(width: 512, height: 512), to: url)

        let decoded = try await decoder.decode(contentsOf: url, maxPixelSize: 288, label: "big.png")
        #expect(decoded.image.width == 288)
        #expect(decoded.image.height == 288)
        #expect(decoded.sourcePixelWidth == 512)
        #expect(decoded.sourcePixelHeight == 512)
    }

    @Test func keepsTheAspectRatio() async throws {
        let url = try TestImages.temporaryDirectory().appending(path: "wide.png")
        try TestImages.writePNG(try TestImages.opaque(width: 200, height: 100), to: url)
        let decoded = try await decoder.decode(contentsOf: url, maxPixelSize: 50, label: "wide.png")
        #expect(decoded.image.width == 50)
        #expect(decoded.image.height == 25)
    }

    @Test func neverUpscales() async throws {
        let url = try TestImages.temporaryDirectory().appending(path: "small.png")
        try TestImages.writePNG(try TestImages.opaque(width: 64, height: 64), to: url)
        let decoded = try await decoder.decode(contentsOf: url, maxPixelSize: 288, label: "small.png")
        #expect(decoded.image.width == 64)
    }

    @Test func aMissingFileIsReportedWithItsLabel() async throws {
        let url = try TestImages.temporaryDirectory().appending(path: "nope.png")
        await #expect(throws: ImageDecodingError.missingFile("walk/nope.png")) {
            try await decoder.decode(contentsOf: url, maxPixelSize: 64, label: "walk/nope.png")
        }
    }

    @Test func aCorruptFileIsUndecodable() async throws {
        let url = try TestImages.temporaryDirectory().appending(path: "corrupt.png")
        try Data("definitely not a png".utf8).write(to: url)
        await #expect(throws: ImageDecodingError.undecodable("corrupt.png")) {
            try await decoder.decode(contentsOf: url, maxPixelSize: 64, label: "corrupt.png")
        }
    }

    @Test func decodesTheCatWalkFrameAt288Pixels() async throws {
        let url = TestImages.catPackURL.appending(path: TestImages.catWalkFrame(1))
        let decoded = try await decoder.decode(contentsOf: url, maxPixelSize: 288, label: "walk_01")
        #expect(decoded.image.width == 288)
        #expect(decoded.image.height == 288)
        #expect(decoded.sourcePixelWidth == 512)
        #expect(decoded.image.bitsPerComponent == 8)
    }

    // MARK: Sheets (T4.6b)

    @Test func slicesASheetRowMajorAtTheCellTargetSize() async throws {
        // 4 × 2 cells of 64 px; even cells opaque, odd cells transparent.
        let sheet = try TestImages.make(width: 256, height: 128) { x, y in
            let cell = (y / 64) * 4 + x / 64
            return cell.isMultiple(of: 2) ? 255 : 0
        }
        let url = try TestImages.temporaryDirectory().appending(path: "atlas.png")
        try TestImages.writePNG(sheet, to: url)

        let decoded = try await decoder.decodeSheet(
            contentsOf: url, columns: 4, rows: 2, cellMaxPixelSize: 32, label: "atlas.png")
        #expect(decoded.sheet.image.width == 128)
        #expect(decoded.sheet.image.height == 64)
        #expect(decoded.cells.count == 8)
        for (index, cell) in decoded.cells.enumerated() {
            #expect(cell.width == 32)
            #expect(cell.height == 32)
            let mask = try #require(HitMask(image: cell))
            #expect(mask.setCellCount == (index.isMultiple(of: 2) ? mask.width * mask.height : 0), "cell \(index)")
        }
    }

    @Test func aSheetIsNeverUpscaled() async throws {
        let url = try TestImages.temporaryDirectory().appending(path: "atlas.png")
        try TestImages.writePNG(try TestImages.opaque(width: 64, height: 32), to: url)
        let decoded = try await decoder.decodeSheet(
            contentsOf: url, columns: 2, rows: 1, cellMaxPixelSize: 288, label: "atlas.png")
        #expect(decoded.cells.map(\.width) == [32, 32])
    }
}
