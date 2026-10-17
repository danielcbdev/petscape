import CoreGraphics
import Foundation
import Testing

@testable import PetScapeRendering

@Suite("HitMask")
struct HitMaskTests {
    private func mask(width: Int, height: Int, pixels: [(x: Int, y: Int, alpha: UInt8)]) -> HitMask {
        var alpha = [UInt8](repeating: 0, count: width * height)
        for pixel in pixels { alpha[pixel.y * width + pixel.x] = pixel.alpha }
        return HitMask(alpha: alpha, pixelWidth: width, pixelHeight: height)
    }

    @Test func usesAQuarterOfTheDecodedResolution() throws {
        #expect(mask(width: 288, height: 288, pixels: []).width == 72)
        let odd = mask(width: 10, height: 6, pixels: [])
        #expect(odd.width == 3)
        #expect(odd.height == 2)
    }

    @Test func alpha128IsSolidAnd127IsNot() {
        #expect(mask(width: 40, height: 40, pixels: [(20, 20, 127)]).setCellCount == 0)
        #expect(mask(width: 40, height: 40, pixels: [(20, 20, 128)]).setCellCount == 9)
    }

    @Test func theNearlyOpaqueCatBodyCounts() {
        // Audit F6: the cat body has alpha 250–254, never 255.
        #expect(mask(width: 40, height: 40, pixels: [(20, 20, 250)]).setCellCount == 9)
    }

    @Test func dilatesByOneCellAndClipsAtTheEdges() {
        let center = mask(width: 40, height: 40, pixels: [(21, 22, 255)])  // cell (5, 5)
        for row in 4...6 {
            for column in 4...6 { #expect(center.isSet(column: column, row: row)) }
        }
        #expect(!center.isSet(column: 7, row: 5))
        #expect(!center.isSet(column: 5, row: 3))

        let corner = mask(width: 40, height: 40, pixels: [(0, 0, 255)])
        #expect(corner.setCellCount == 4)
    }

    @Test func lookupsUseABottomLeftOrigin() throws {
        // Opaque bottom-left quadrant (image rows 20…39 are the bottom half).
        let image = try TestImages.make(width: 40, height: 40) { x, y in x < 20 && y >= 20 ? 255 : 0 }
        let mask = try #require(HitMask(image: image))
        #expect(mask.contains(normalizedX: 0.1, y: 0.1))
        #expect(!mask.contains(normalizedX: 0.9, y: 0.9))
        #expect(!mask.contains(normalizedX: 0.1, y: 0.9))
        #expect(!mask.contains(normalizedX: 0.9, y: 0.1))
    }

    @Test(arguments: [(-0.01, 0.5), (1.0, 0.5), (0.5, -0.01), (0.5, 1.0)])
    func pointsOutsideTheCanvasNeverHit(_ point: (Double, Double)) throws {
        let mask = try #require(HitMask(image: try TestImages.opaque(width: 16, height: 16)))
        #expect(!mask.contains(normalizedX: point.0, y: point.1))
    }

    @Test func buildingFromAnImageMatchesBuildingFromItsAlpha() throws {
        let image = try TestImages.make(width: 33, height: 17) { x, y in UInt8((x * 7 + y * 13) % 256) }
        let fromImage = try #require(HitMask(image: image))
        let fromAlpha = HitMask(alpha: try TestImages.alphaChannel(of: image), pixelWidth: 33, pixelHeight: 17)
        #expect(fromImage == fromAlpha)
    }

    @Test func theCatMaskCoversTheBodyButNotTheCorners() async throws {
        let url = TestImages.catPackURL.appending(path: TestImages.catWalkFrame(1))
        let decoded = try await ImageDecoder().decode(contentsOf: url, maxPixelSize: 288, label: "walk_01")
        let mask = try #require(HitMask(image: decoded.image))
        #expect(mask.width == 72)
        #expect(mask.contains(normalizedX: 0.5, y: 0.5))
        for corner in [(0.01, 0.01), (0.99, 0.01), (0.01, 0.99), (0.99, 0.99)] {
            #expect(!mask.contains(normalizedX: corner.0, y: corner.1))
        }
        // Nothing below the paws: the bottom ~7% of the canvas is transparent (audit F9).
        #expect(!mask.contains(normalizedX: 0.5, y: 0.02))
    }
}
