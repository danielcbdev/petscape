import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import PetScapeCore
import PetScapeRendering
import Testing

@testable import PetScapeRuntime

@Suite("M15 authored animation quality")
struct M15CharacterPackTests {
    private let root = TestPacks.catPackURL
    private let expected = [
        "walk": 30, "idle": 11, "jump-start": 5, "jump": 7, "fall": 12,
        "landing": 4, "curious": 36, "picked-up": 6, "held": 15, "climb": 8,
    ]

    private func manifest(_ path: String) throws -> CharacterManifest {
        try CharacterManifest.decode(Data(contentsOf: root.appending(path: path))).manifest
    }

    #if DEBUG
        @Test func enlargedWallPreviewContainsTheEntireSpriteCanvas() {
            for height in [144.0, 192.0] {
                let y = AnimationPreviewController.previewGroundY(canvasHeight: 220, petHeight: height, anchorY: 0.5)
                #expect(y - height * 0.5 >= 8)
                #expect(y + height * 0.5 <= 212)
            }
            #expect(AnimationPreviewController.previewGroundY(canvasHeight: 220, petHeight: 96, anchorY: 0.074) == 56)
        }
    #endif

    /// V8 rework (owner-approved direction 2026-10-23): every clip is a rig pose sequence with revised timing.
    /// Contracts that physics and behavior rely on stay exact: preparation 0.15 s, landing 0.10 s, pickup
    /// presentation 0.2 s, event names and placement, anchors, alignment, playback and fallbacks.
    @Test func reworkedPackKeepsContractsAndPhysicalTimings() throws {
        let old = try manifest("v7/baseline-character.json")
        let new = try manifest("character.json")
        #expect(Set(new.animations.keys) == Set(old.animations.keys))
        #expect(new.schemaVersion == old.schemaVersion)
        #expect(new.anchor == old.anchor)
        #expect(new.displaySize == old.displaySize)
        #expect(new.fallbacks == old.fallbacks)
        let fixed = ["jump-start": 0.15, "landing": 0.1, "picked-up": 0.2]
        for (name, oldClip) in old.animations {
            let clip = try #require(new.animations[name])
            let frames = try #require(clip.frames)
            #expect(frames.count == expected[name])
            #expect(clip.anchor == oldClip.anchor)
            #expect(clip.alignment == oldClip.alignment)
            #expect(clip.playback == oldClip.playback)
            #expect(clip.next == oldClip.next)
            #expect(clip.interruptible == oldClip.interruptible)
            let oldEvents = (oldClip.frames ?? []).flatMap { $0.events ?? [] }
            #expect(frames.flatMap { $0.events ?? [] } == oldEvents, "\(name): same presentation events")
            var total = 0.0
            for frame in frames {
                let path = try #require(frame.image)
                #expect(path.hasPrefix("v8/\(name)/frames/"), "Unexpected source: \(path)")
                #expect(FileManager.default.fileExists(atPath: root.appending(path: path).path))
                let duration = try #require(frame.duration ?? clip.fps.map { 1 / $0 })
                #expect(abs((duration * 60).rounded() - duration * 60) < 0.000_01, "\(name): whole simulation steps")
                total += duration
            }
            if let seconds = fixed[name] {
                #expect(abs(total - seconds) < 0.000_001, "\(name): physical/behavior duration unchanged")
            }
        }
        #expect(new.animations["jump-start"]?.frames?.last?.events == ["takeoff"])
        #expect(new.animations["landing"]?.frames?.first?.events == ["contact"])
        #expect(new.animations["landing"]?.frames?.last?.events == ["settled"])
        #expect(InteractionTuning.default.clickReactionDuration == 1.8, "One complete curious look per click")
    }

    @Test func reworkedClipsKeepPlantedPawsLockedToTheGroundSpeed() throws {
        struct Paw: Decodable {
            let x: Double
            let y: Double
            let planted: Bool
        }
        struct Entry: Decodable {
            let image: String
            let duration: Double
            let events: [String]
            let paws: [String: Paw]?
        }
        struct Report: Decodable {
            let source: String
            let walk: [Entry]
            let curious: [Entry]
        }
        let report = try JSONDecoder().decode(
            Report.self, from: Data(contentsOf: root.appending(path: "v8/rig-report.json")))
        #expect(report.source == "assets/characters/cat/walk/frames/walk_01.png")
        let manifest = try manifest("character.json")
        let pixelsPerPoint = 512.0 / 96

        let walk = try #require(manifest.animations["walk"])
        let walkFrames = try #require(walk.frames)
        let entries = report.walk
        #expect(walk.fps == 30 && walk.playback == .loop && walkFrames.count == entries.count)
        let speed = try #require(walk.nominalSpeed)
        #expect(speed == 13.5)
        let cycle = Double(walkFrames.count) / 30
        #expect(abs(cycle - 1) < 0.000_000_001)
        #expect(walkFrames.indices.filter { walkFrames[$0].events == ["footstep"] } == [8, 23])
        for (index, frame) in walkFrames.enumerated() {
            #expect(frame.image == "v8/walk/frames/\(entries[index].image)")
            let next = entries[(index + 1) % entries.count]
            for (leg, paw) in entries[index].paws ?? [:] {
                guard paw.planted, let after = next.paws?[leg], after.planted else { continue }
                // A planted paw moves back exactly as far as the ground scrolls in one drawing, seam included.
                #expect(abs((paw.x - after.x) - speed / 30 * pixelsPerPoint) < 0.000_001, "\(leg) slides at \(index)")
                #expect(abs(paw.y - after.y) < 0.000_001)
            }
        }

        let curious = try #require(manifest.animations["curious"])
        let frames = try #require(curious.frames)
        #expect(curious.fps == nil && curious.playback == .loop && frames.count == report.curious.count)
        let durations = frames.compactMap(\.duration)
        #expect(durations.count == frames.count)
        #expect(durations.allSatisfy { abs(($0 * 60).rounded() - $0 * 60) < 0.000_01 }, "Whole simulation steps")
        #expect(abs(durations.reduce(0, +) - 3.6) < 0.000_001)
        #expect(frames.filter { $0.events == ["blink"] }.count == 1)
        for (index, frame) in frames.enumerated() {
            #expect(frame.image == "v8/curious/frames/\(report.curious[index].image)")
            #expect(abs((frame.duration ?? 0) - report.curious[index].duration) < 0.000_001)
        }
    }

    @Test func originalAssetFilesRemainByteIdentical() throws {
        let data = try Data(contentsOf: root.appending(path: "v7/original-sha256.json"))
        let hashes = try JSONDecoder().decode([String: String].self, from: data)
        #expect(hashes.count > 50)
        for (path, expectedHash) in hashes {
            let bytes = try Data(contentsOf: TestPacks.repositoryRoot.appending(path: path))
            let actual = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            #expect(actual == expectedHash, "Read-only original changed: \(path)")
        }
    }

    @Test func newDrawingsAreDistinctOpaqueContainedAndRegistered() throws {
        let new = try manifest("character.json")
        let paths = new.animations.values.flatMap { $0.frames ?? [] }.compactMap(\.image)
            .filter { $0.hasPrefix("v8/") }
        #expect(paths.count == 134)
        var drawings: Set<Data> = []
        for path in paths {
            let source = try #require(CGImageSourceCreateWithURL(root.appending(path: path) as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == 512 && image.height == 512)
            var pixels = [UInt8](repeating: 0, count: 512 * 512 * 4)
            let drew = pixels.withUnsafeMutableBytes { bytes -> Bool in
                guard
                    let context = CGContext(
                        data: bytes.baseAddress, width: 512, height: 512, bitsPerComponent: 8,
                        bytesPerRow: 512 * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: 512, height: 512))
                return true
            }
            #expect(drew)
            #expect(drawings.insert(Data(pixels)).inserted, "Duplicated drawing: \(path)")
            let alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
            let solid = alpha.indices.filter { alpha[$0] >= 128 }
            #expect(solid.count > 30_000, "Readable body: \(path)")
            if path.hasPrefix("v8/") {
                // Rig poses keep the source key's soft fur edge (only 93.5% of its solid pixels are >= 248), so a
                // global share cannot separate edge softness from seams. Stricter: every pixel whose 4 px
                // neighbourhood is opaque must itself be opaque (>= 235; the key's own ear-tip and eye-corner
                // pixels reach 243) — no translucent seam anywhere inside the body. Head rotation can expose
                // the key's own outline notch beside the far eye as isolated pixels, so at most 3 may be lower.
                let interior = alpha.indices.filter { i in
                    let x = i % 512
                    let y = i / 512
                    guard x >= 4, x < 508, y >= 4, y < 508 else { return false }
                    return [i - 4, i + 4, i - 4 * 512, i + 4 * 512].allSatisfy { alpha[$0] == 255 }
                }
                #expect(interior.count > 30_000)
                let translucent = interior.filter { alpha[$0] < 235 }
                #expect(translucent.count <= 3, "Opaque body without seams: \(path)")
                #expect(translucent.allSatisfy { alpha[$0] >= 160 }, "No see-through hole: \(path)")
            } else {
                #expect(alpha.filter { $0 == 255 }.count * 100 >= solid.count * 95, "Opaque body: \(path)")
            }
            #expect(
                alpha.indices.allSatisfy { i in
                    alpha[i] == 0 || (i % 512 >= 8 && i % 512 < 504 && i / 512 >= 8 && i / 512 < 504)
                }, "8 px transparent margin including antialiasing: \(path)")
            #expect(Self.componentCount(alpha) == 1, "No detached visible islands: \(path)")
            let clip = path.split(separator: "/")[1]
            if clip != "climb" {
                let bottom = try #require(solid.map { $0 / 512 }.max())
                #expect(abs(bottom - 474) <= 1, "Ground/virtual foot registration: \(path)")
            }
            if clip == "climb" {
                let right = try #require(solid.map { $0 % 512 }.max())
                #expect(abs(right - 500) <= 1, "Wall registration: \(path)")
            }
        }
    }

    @Test func deliveredPackLoadsAllFamiliesWithinTheM15Budget() async throws {
        let character = await CharacterLoader().load(packURL: root)
        #expect(character.failure == nil)
        #expect(character.issues.isEmpty)
        #expect(character.frames["curious"] == nil)
        #expect(character.frames["walk"]?.count == 30)
        #expect(character.decodedByteCount <= 16 * 1024 * 1024, "Initial locomotion family stays bounded")
        #expect(await character.loadBehaviorFamily(containing: "jump"))
        #expect(await character.loadBehaviorFamily(containing: "curious"))
        #expect(character.decodedByteCount == 134 * 288 * 288 * 4)
        // Raised from 32 MiB with the owner-authorized drawing increase; the long-term frame-memory budget is an
        // open owner decision recorded in m15-implementation.md.
        #expect(character.decodedByteCount <= 43 * 1024 * 1024, "134 frames at the existing 288 px policy")
        for (name, count) in expected {
            #expect(character.frames[name]?.count == count, "No silent fallback: \(name)")
            #expect(character.definition.resolvedClipName(for: name) == name)
        }
    }

    @Test func newArtPreservesTheActualJumpTrajectory() throws {
        func definition(_ path: String) throws -> CharacterDefinition {
            let m = try manifest(path)
            return try CharacterDefinition.resolve(m, report: ManifestValidator.validate(m))
        }
        let screen = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 0, y: 70, width: 1470, height: 853), backingScale: 2, isPrimary: true)
        func world(_ definition: CharacterDefinition) -> PetWorld {
            var result = PetWorld(random: SeededRandomSource(seed: 85))
            result.apply(.screens([screen]))
            result.apply(.surfaces([Surface.screenBottom(of: screen)]))
            let id = result.spawn(definition)
            _ = result.step(dt: 1.0 / 60)
            result.apply(.requestJump(id, JumpRequest(returnActivity: .idle)))
            return result
        }
        var old = world(try definition("v7/baseline-character.json"))
        var new = world(try definition("character.json"))
        var visitedStates: Set<PetStateKind> = []
        for _ in 0..<300 {
            _ = old.step(dt: 1.0 / 60)
            _ = new.step(dt: 1.0 / 60)
            let a = try #require(old.pets.first)
            let b = try #require(new.pets.first)
            visitedStates.insert(a.state.kind)
            #expect(a.position == b.position)
            #expect(a.velocity == b.velocity)
            #expect(a.state == b.state)
            #expect(a.attachment == b.attachment)
        }
        #expect(visitedStates.isSuperset(of: [.preparingJump, .rising, .falling, .landing]))
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
