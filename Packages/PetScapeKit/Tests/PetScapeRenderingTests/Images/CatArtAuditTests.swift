import CoreGraphics
import Foundation
import Testing

@testable import PetScapeRendering

/// Re-checks the asset audit (docs/specifications/asset-format.md#current-asset-audit-2026-10-16) on all
/// eight original walk frames, read in place (never modified).
@Suite("Cat walk art audit")
struct CatArtAuditTests {
    private static func fullResolutionAlpha(frame number: Int) async throws -> (alpha: [UInt8], width: Int, height: Int)
    {
        let url = TestImages.catPackURL.appending(path: TestImages.catWalkFrame(number))
        let decoded = try await ImageDecoder().decode(contentsOf: url, maxPixelSize: 512, label: "walk_0\(number)")
        return (try TestImages.alphaChannel(of: decoded.image), decoded.image.width, decoded.image.height)
    }

    /// F8: one connected body (alpha > 32, 8-connected). Frame 03 has a known 4 px speck at x 493,
    /// y 248–251 (max alpha 41, found by this test); the original is read-only, so specks are tolerated
    /// only while they stay tiny and below the hit-mask threshold (no effect on hit testing).
    @Test(arguments: 1...8)
    func hasNoStrayIslands(frame number: Int) async throws {
        let (alpha, width, height) = try await Self.fullResolutionAlpha(frame: number)
        var visited = [Bool](repeating: false, count: alpha.count)
        var components: [(size: Int, maxAlpha: UInt8)] = []
        for start in alpha.indices where alpha[start] > 32 && !visited[start] {
            var size = 0
            var maxAlpha: UInt8 = 0
            var stack = [start]
            visited[start] = true
            while let index = stack.popLast() {
                size += 1
                maxAlpha = max(maxAlpha, alpha[index])
                let x = index % width
                let y = index / width
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx
                        let ny = y + dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let neighbor = ny * width + nx
                        if alpha[neighbor] > 32, !visited[neighbor] {
                            visited[neighbor] = true
                            stack.append(neighbor)
                        }
                    }
                }
            }
            components.append((size, maxAlpha))
        }
        components.sort { $0.size > $1.size }

        let body = try #require(components.first)
        #expect(body.size > 50_000, "frame \(number): the body is the large component")
        let specks = components.dropFirst()
        #expect(specks.count == (number == 3 ? 1 : 0), "frame \(number): \(specks.map(\.size))")
        for speck in specks {
            #expect(speck.size <= 16, "frame \(number): island of \(speck.size) px")
            #expect(speck.maxAlpha < HitMask.alphaThreshold, "frame \(number): island is visible to hit testing")
        }
    }

    /// F9: the lowest solid row (alpha > 128) is y ≈ 473–474 from the top, so the manifest anchor
    /// y = 0.074 (38 px from the bottom) puts the paws on the surface.
    @Test(arguments: 1...8)
    func pawsSitOnTheAnchorBaseline(frame number: Int) async throws {
        let (alpha, width, height) = try await Self.fullResolutionAlpha(frame: number)
        let lowestSolidRow = try #require(
            (0..<height).last { row in (0..<width).contains { alpha[row * width + $0] > 128 } })
        let anchorRowFromTop = Double(height) * (1 - 0.074)
        #expect(abs(Double(lowestSolidRow + 1) - anchorRowFromTop) <= 2, "frame \(number): row \(lowestSolidRow)")
    }
}
