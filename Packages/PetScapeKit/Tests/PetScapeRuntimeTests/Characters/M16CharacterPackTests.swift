import CoreGraphics
import Foundation
import ImageIO
import PetScapeCore
import Testing

@testable import PetScapeRuntime

/// V9 art (M16, owner-approved V8 rig method 2026-10-23): `dance` and `cleanup` as real manifest clips, held to
/// the same pixel contract as V8 and to the contracts in animation-assets-v9.md.
@Suite("M16 V9 dance and cleanup art")
struct M16CharacterPackTests {
    private let root = TestPacks.catPackURL
    private let clips:
        [(name: String, count: Int, playback: CharacterManifest.Playback, fps: Double, seconds: Double)] =
            [("dance", 30, .loop, 30, 1), ("cleanup", 36, .once, 12, 3)]

    private func manifest() throws -> CharacterManifest {
        try CharacterManifest.decode(Data(contentsOf: root.appending(path: "character.json"))).manifest
    }

    @Test func manifestDeclaresBothClipsWithTheProposedTiming() throws {
        let manifest = try manifest()
        for expected in clips {
            let clip = try #require(manifest.animations[expected.name], "\(expected.name) declared")
            let frames = try #require(clip.frames)
            #expect(frames.count == expected.count)
            #expect(clip.playback == expected.playback)
            #expect(clip.fps == expected.fps)
            #expect(clip.nominalSpeed == nil && clip.next == nil && clip.anchor == nil && clip.canvas == nil)
            #expect(clip.alignment == .bottom && clip.mirrorable == true && clip.interruptible == true)
            #expect(frames.allSatisfy { $0.duration == nil && $0.events == nil }, "No physical events")
            #expect(abs(Double(frames.count) / expected.fps - expected.seconds) < 0.000_001)
            #expect((60 / expected.fps).rounded() == 60 / expected.fps, "Whole simulation steps")
            for (index, frame) in frames.enumerated() {
                let path = String(format: "v9/%@/frames/%@_%02d.png", expected.name, expected.name, index + 1)
                #expect(frame.image == path)
                #expect(FileManager.default.fileExists(atPath: root.appending(path: path).path))
            }
            #expect(manifest.fallbacks?[expected.name] == nil, "No alias for a delivered clip")
        }
        let definition = try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
        for expected in clips { #expect(definition.resolvedClipName(for: expected.name) == expected.name) }
    }

    @Test func plantedPawsNeverMoveAndDurationsMatchTheReport() throws {
        struct Paw: Decodable {
            let x: Double
            let y: Double
            let planted: Bool
        }
        struct Entry: Decodable {
            let image: String
            let duration: Double
            let paws: [String: Paw]
        }
        struct Report: Decodable {
            let source: String
            let dance: [Entry]
            let cleanup: [Entry]
        }
        let report = try JSONDecoder().decode(
            Report.self, from: Data(contentsOf: root.appending(path: "v9/rig-report.json")))
        #expect(report.source == "assets/characters/cat/walk/frames/walk_01.png")
        let manifest = try manifest()
        for expected in clips {
            let entries = expected.name == "dance" ? report.dance : report.cleanup
            let frames = try #require(manifest.animations[expected.name]?.frames)
            #expect(entries.count == frames.count)
            var contacts: [String: Set<[Double]>] = [:]
            for (index, entry) in entries.enumerated() {
                #expect(frames[index].image == "v9/\(expected.name)/frames/\(entry.image)")
                #expect(abs(entry.duration - 1 / expected.fps) < 0.000_001)
                #expect(entry.paws.values.filter(\.planted).count >= 3, "Supported stance: \(entry.image)")
                for (leg, paw) in entry.paws where paw.planted { contacts[leg, default: []].insert([paw.x, paw.y]) }
            }
            #expect(contacts.count == 4)
            for (leg, positions) in contacts {
                #expect(positions.count == 1, "\(expected.name): planted \(leg) slides")
                #expect(positions.first?[1] == 472, "\(expected.name): \(leg) on the ground line")
            }
        }
    }

    @Test func drawingsAreDistinctOpaqueContainedAndRegistered() throws {
        let manifest = try manifest()
        var known: Set<Data> = []
        for path in manifest.animations.values.flatMap({ $0.frames ?? [] }).compactMap(\.image)
        where path.hasPrefix("v8/") {
            known.insert(try Self.pixels(root.appending(path: path)))
        }
        for expected in clips {
            for frame in try #require(manifest.animations[expected.name]?.frames) {
                let path = try #require(frame.image)
                let pixels = try Self.pixels(root.appending(path: path))
                #expect(known.insert(pixels).inserted, "Distinct drawing: \(path)")
                let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
                let solid = alpha.indices.filter { alpha[$0] >= 128 }
                #expect(solid.count > 30_000, "Readable body: \(path)")
                // Same seam rule as the V8 pack test: a pixel whose 4 px neighbourhood is opaque is itself opaque.
                let interior = alpha.indices.filter { i in
                    let x = i % 512
                    let y = i / 512
                    guard x >= 4, x < 508, y >= 4, y < 508 else { return false }
                    return [i - 4, i + 4, i - 4 * 512, i + 4 * 512].allSatisfy { alpha[$0] == 255 }
                }
                let translucent = interior.filter { alpha[$0] < 235 }
                #expect(translucent.count <= 3 && translucent.allSatisfy { alpha[$0] >= 160 }, "Opaque body: \(path)")
                #expect(
                    alpha.indices.allSatisfy { i in
                        alpha[i] == 0 || (i % 512 >= 8 && i % 512 < 504 && i / 512 >= 8 && i / 512 < 504)
                    }, "8 px transparent margin: \(path)")
                #expect(Self.componentCount(alpha) == 1, "No detached visible islands: \(path)")
                #expect(solid.map { $0 / 512 }.max() == 474, "Paw baseline at the anchor row: \(path)")
            }
        }
    }

    @Test func clipsLoadAsTheirOwnLazyFamilies() async throws {
        let character = await CharacterLoader().load(packURL: root)
        #expect(character.failure == nil)
        #expect(character.issues.isEmpty)
        let before = character.decodedByteCount
        for expected in clips {
            #expect(character.frames[expected.name] == nil, "Not loaded with the locomotion family")
            #expect(await character.loadBehaviorFamily(containing: expected.name))
            #expect(character.frames[expected.name]?.count == expected.count, "No silent fallback")
        }
        // Measured cost of both families at the existing 288 px decode policy; no budget is implied.
        let expectedAdditionalBytes: Int = 66 * 288 * 288 * 4
        let additionalDecodedBytes = character.decodedByteCount - before
        #expect(additionalDecodedBytes == expectedAdditionalBytes)
    }

    private static func pixels(_ url: URL) throws -> Data {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 512 && image.height == 512 && image.bitsPerComponent == 8)
        #expect((image.colorSpace?.name as String?) == (CGColorSpace.sRGB as String))
        var pixels = [UInt8](repeating: 0, count: 512 * 512 * 4)
        let drew = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard
                let context = CGContext(
                    data: bytes.baseAddress, width: 512, height: 512, bitsPerComponent: 8, bytesPerRow: 512 * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 512, height: 512))
            return true
        }
        #expect(drew)
        return Data(pixels)
    }

    private static func componentCount(_ alpha: [UInt8]) -> Int {
        var visited = [Bool](repeating: false, count: alpha.count)
        var count = 0
        for start in alpha.indices where alpha[start] > 32 && !visited[start] {
            count += 1
            var stack = [start]
            visited[start] = true
            while let index = stack.popLast() {
                let x = index % 512
                let y = index / 512
                for ny in max(0, y - 1)...min(511, y + 1) {
                    for nx in max(0, x - 1)...min(511, x + 1) {
                        let neighbor = ny * 512 + nx
                        if !visited[neighbor] && alpha[neighbor] > 32 {
                            visited[neighbor] = true
                            stack.append(neighbor)
                        }
                    }
                }
            }
        }
        return count
    }
}
