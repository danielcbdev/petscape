import CoreGraphics
import Foundation
import ImageIO
import PetScapeCore
import PetScapeRendering
import Testing

@testable import PetScapeRuntime

@Suite("Cat V4, V5 and V6 production pack")
struct V4CharacterPackTests {
    static let phaseNames = ["idle", "jump-start", "jump", "fall", "landing"]

    @Test func productionPhasesLoadWithoutFallbackAndFitTheApprovedBudget() async throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let character = await CharacterLoader().load(packURL: baselinePackURL)
        #expect(character.failure == nil)
        #expect(character.issues.isEmpty)
        #expect(character.definition.displaySize == .init(width: 96, height: 96))
        #expect(character.decodedByteCount <= 16 * 1024 * 1024)
        #expect(await character.loadBehaviorFamily(containing: "jump"))
        for name in Self.phaseNames {
            let clip = try #require(character.definition.clips[name], "Missing production clip \(name)")
            #expect(clip.frames.count > 1)
            #expect(clip.anchor == .init(x: 0.5, y: 0.074))
            #expect(clip.mirrorable)
            #expect(character.frames[name]?.count == clip.frames.count)
            #expect(clip.next == nil, "Physical phase changes remain simulation-owned")
        }
    }

    @Test func semanticRestAndExpressionFallbacksUseTheExistingIdlePose() async throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let character = await CharacterLoader().load(packURL: baselinePackURL)
        #expect(character.failure == nil)
        #expect(await character.loadBehaviorFamily(containing: "curious"))
        #expect(character.decodedByteCount <= 16 * 1024 * 1024)
        let idle = character.definition.clip(named: "idle")
        for name in [
            "sit-down", "sit", "stand-up", "lie-down", "sleep", "wake-up", "stretch", "observe", "look-around",
        ] {
            #expect(character.definition.clips[name] == nil, "Aliases do not claim authored art")
            #expect(character.definition.clip(named: name) == idle)
            var animation = AnimationController(definition: character.definition)
            animation.request(AnimationRequest(clip: name))
            #expect(animation.currentFrame.clip == "idle")
            #expect(character.frame(animation.currentFrame) != nil)
        }
    }

    @Test func productionV5InteractionClipsLoadWithoutFallbackAndFitTheBudget() async throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let character = await CharacterLoader().load(packURL: baselinePackURL)
        let initiallyDecodedBytes = character.decodedByteCount
        #expect(character.failure == nil)
        #expect(character.issues.isEmpty)
        #expect(await character.loadBehaviorFamily(containing: "curious"))
        #expect(await character.loadBehaviorFamily(containing: "jump"))
        #expect(character.decodedByteCount <= 16 * 1024 * 1024)
        #expect(initiallyDecodedBytes < character.decodedByteCount)
        #expect(character.decodedByteCount == 16_588_800)
        let expected: [(String, Int, Double, AnimationClip.Playback)] = [
            ("curious", 6, 6, .loop),
            ("picked-up", 4, 20, .once),
            ("held", 6, 6, .loop),
        ]
        for (name, frameCount, fps, playback) in expected {
            let clip = try #require(character.definition.clips[name])
            #expect(clip.frames.count == frameCount)
            #expect(abs(clip.frames[0].duration - (1 / fps)) < 0.000_001)
            #expect(clip.playback == playback)
            #expect(clip.anchor == .init(x: 0.5, y: 0.074))
            #expect(character.frames[name]?.count == frameCount)
            #expect(character.definition.resolvedClipName(for: name) == name)
            #expect(clip.next == nil, "Art timing cannot control held physics")
        }
    }

    @Test func productionClimbClipUsesWallAlignmentAndKeepsPawsWithinThreePoints() async throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let character = await CharacterLoader().load(packURL: baselinePackURL)
        #expect(character.failure == nil)
        let clip = try #require(character.definition.clips["climb"])
        #expect(clip.frames.count == 2)
        #expect(clip.playback == .loop)
        #expect(clip.alignment == .right)
        #expect(clip.anchor == .init(x: 0.977, y: 0.5))
        #expect(clip.interruptible == false)
        #expect(character.definition.resolvedClipName(for: "climb") == "climb")
        #expect(character.decodedByteCount < 17 * 1024 * 1024)

        let manifestData = try Data(contentsOf: baselinePackURL.appending(path: "character.json"))
        let manifest = try CharacterManifest.decode(manifestData).manifest
        for (index, frame) in try #require(manifest.animations["climb"]?.frames).enumerated() {
            let path = try #require(frame.image)
            let source = try #require(
                CGImageSourceCreateWithURL(baselinePackURL.appending(path: path) as CFURL, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == 512 && image.height == 512)
            var alpha = [UInt8](repeating: 0, count: 512 * 512)
            let drew = alpha.withUnsafeMutableBytes { bytes -> Bool in
                guard
                    let context = CGContext(
                        data: bytes.baseAddress, width: 512, height: 512, bitsPerComponent: 8,
                        bytesPerRow: 512, space: CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
                else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: 512, height: 512))
                return true
            }
            #expect(drew)
            let borderWidth = 8
            #expect(alpha[0..<borderWidth * 512].allSatisfy { $0 == 0 }, "First edge margin, frame \(index + 1)")
            #expect(
                alpha[(512 - borderWidth) * 512..<512 * 512].allSatisfy { $0 == 0 },
                "Opposite edge margin, frame \(index + 1)")
            #expect(
                (0..<512).allSatisfy { y in
                    (0..<borderWidth).allSatisfy { x in alpha[y * 512 + x] == 0 }
                        && (512 - borderWidth..<512).allSatisfy { x in alpha[y * 512 + x] == 0 }
                }, "Side margins, frame \(index + 1)")
            let solid = alpha.indices.filter { alpha[$0] >= 128 }
            #expect(!solid.isEmpty)
            let rightmost = try #require(solid.map { $0 % 512 }.max())
            #expect(abs(Double(rightmost) - clip.anchor.x * 512) * 96 / 512 <= 3, "Frame \(index + 1)")
        }
    }

    @Test func missingClimbFrameFallsBackToIdle() async throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let packURL = FileManager.default.temporaryDirectory.appending(
            path: "PetScapeClimbFallback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: packURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: packURL) }
        let idleFrame = baselinePackURL.appending(path: "idle/frames/idle_01.png")
        try Data(contentsOf: idleFrame).write(to: packURL.appending(path: "idle.png"))

        let manifest = CharacterManifest(
            id: "climb-fallback", displayName: "Climb fallback", defaultAnimation: "walk",
            canvas: .init(width: 512, height: 512), displaySize: .init(width: 96, height: 96),
            anchor: .init(x: 0.5, y: 0.074), fallbacks: ["climb": "idle"],
            animations: [
                "walk": .init(fps: 1, frames: [.init(image: "idle.png")]),
                "idle": .init(fps: 1, frames: [.init(image: "idle.png")]),
                "climb": .init(
                    fps: 8, frames: [.init(image: "missing-climb.png")], anchor: .init(x: 0.977, y: 0.5),
                    alignment: .right),
            ])
        try JSONEncoder().encode(manifest).write(to: packURL.appending(path: "character.json"))

        let character = await CharacterLoader().load(packURL: packURL)
        #expect(character.failure == nil)
        #expect(character.definition.resolvedClipName(for: "climb") == "idle")
        #expect(character.definition.clip(named: "climb").name == "idle")
    }

    @Test func productionV5FramesHaveTransparentMarginsAndAlignedVirtualFootRows() throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let data = try Data(contentsOf: baselinePackURL.appending(path: "character.json"))
        let manifest = try JSONDecoder().decode(CharacterManifest.self, from: data)
        for name in ["curious", "picked-up", "held"] {
            let frames = try #require(manifest.animations[name]?.frames)
            for frame in frames {
                let path = try #require(frame.image)
                let url = baselinePackURL.appending(path: path)
                let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
                let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
                #expect(image.width == 512 && image.height == 512)
                var alpha = [UInt8](repeating: 0, count: 512 * 512)
                let drew = alpha.withUnsafeMutableBytes { bytes -> Bool in
                    guard
                        let context = CGContext(
                            data: bytes.baseAddress, width: 512, height: 512,
                            bitsPerComponent: 8, bytesPerRow: 512, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
                    else { return false }
                    context.draw(image, in: CGRect(x: 0, y: 0, width: 512, height: 512))
                    return true
                }
                #expect(drew)
                #expect(alpha.allSatisfy { $0 == 0 } == false)
                #expect(
                    alpha.indices.allSatisfy { index in
                        let x = index % 512
                        let y = index / 512
                        return alpha[index] == 0 || (x >= 8 && x < 504 && y >= 8 && y < 504)
                    }, "Every V5 frame retains at least an 8 px transparent border: \(path)")
                let solid = alpha.indices.filter { alpha[$0] >= 128 }
                #expect(solid.count > 30_000)
                #expect(alpha.filter { $0 == 255 }.count > solid.count * 95 / 100)
                let lowest = try #require(solid.map { $0 / 512 }.max())
                #expect(abs(lowest - 474) <= 1, "Virtual foot row drift: \(path), row \(lowest)")
            }
        }
    }

    @Test func missingV5InteractionClipsStillResolveToIdle() throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let data = try Data(contentsOf: baselinePackURL.appending(path: "character.json"))
        var manifest = try JSONDecoder().decode(CharacterManifest.self, from: data)
        for name in ["curious", "picked-up", "held"] {
            manifest.animations[name] = nil
        }
        let definition = try CharacterDefinition.resolve(
            manifest, report: ManifestValidator.validate(manifest))
        let idle = definition.clip(named: "idle")
        for name in ["curious", "picked-up", "held"] {
            #expect(definition.resolvedClipName(for: name) == "idle")
            #expect(definition.clip(named: name) == idle)
        }
    }

    @Test func productionArtDoesNotChangeTheExecutedTrajectory() async throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let character = await CharacterLoader().load(packURL: baselinePackURL)
        let data = try Data(contentsOf: baselinePackURL.appending(path: "character.json"))
        var manifest = try JSONDecoder().decode(CharacterManifest.self, from: data)
        manifest.animations = manifest.animations.filter { $0.key == "walk" }
        manifest.fallbacks = ["idle": "walk", "fall": "walk", "land": "walk"]
        let baseline = try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
        let screen = ScreenDescriptor(
            id: ScreenID(1), frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 0, y: 70, width: 1470, height: 853), backingScale: 2, isPrimary: true)
        func world(_ definition: CharacterDefinition) -> PetWorld {
            var world = PetWorld(random: SeededRandomSource(seed: 85))
            world.apply(.screens([screen]))
            world.apply(.surfaces([Surface.screenBottom(of: screen)]))
            let id = world.spawn(definition)
            _ = world.step(dt: 1.0 / 60)
            world.apply(.requestJump(id, JumpRequest(returnActivity: .idle)))
            return world
        }
        var authored = world(character.definition)
        var fallback = world(baseline)
        #expect(await character.loadBehaviorFamily(containing: "jump"))
        var clips: Set<String> = []
        for _ in 0..<150 {
            _ = authored.step(dt: 1.0 / 60)
            _ = fallback.step(dt: 1.0 / 60)
            let actual = try #require(authored.pets.first)
            let expected = try #require(fallback.pets.first)
            #expect(actual.position == expected.position)
            #expect(actual.velocity == expected.velocity)
            #expect(actual.state == expected.state)
            clips.insert(actual.animation.currentFrame.clip)
            #expect(character.frame(actual.animation.currentFrame) != nil)
        }
        #expect(clips.isSuperset(of: ["jump-start", "jump", "fall", "landing", "idle"]))
    }

    @Test func everyAuthoredPhaseFrameIsContainedAndGroundedFeetShareTheBaseline() throws {
        let baselinePackURL = try TestPacks.makeBaselineCatPack()
        defer { try? FileManager.default.removeItem(at: baselinePackURL) }
        let data = try Data(contentsOf: baselinePackURL.appending(path: "character.json"))
        let manifest = try JSONDecoder().decode(CharacterManifest.self, from: data)
        for name in Self.phaseNames {
            let frames = try #require(manifest.animations[name]?.frames, "Missing \(name)")
            for frame in frames {
                let path = try #require(frame.image)
                guard !path.hasPrefix("walk/") else { continue }  // Immutable legacy neutral pose, audited separately.
                let url = baselinePackURL.appending(path: path)
                let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
                let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
                #expect(image.width == 512 && image.height == 512)
                var alpha = [UInt8](repeating: 0, count: 512 * 512)
                let drew = alpha.withUnsafeMutableBytes { bytes -> Bool in
                    guard
                        let context = CGContext(
                            data: bytes.baseAddress, width: 512, height: 512,
                            bitsPerComponent: 8, bytesPerRow: 512, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
                    else { return false }
                    context.draw(image, in: CGRect(x: 0, y: 0, width: 512, height: 512))
                    return true
                }
                #expect(drew)
                #expect(
                    alpha.indices.allSatisfy { i in
                        alpha[i] == 0 || (i % 512 >= 8 && i % 512 < 504 && i / 512 >= 8 && i / 512 < 504)
                    }, "Transparent border includes soft alpha: \(path)")
                let solid = alpha.indices.filter { alpha[$0] >= 128 }
                #expect(solid.count > 50_000)
                #expect(
                    alpha.filter { $0 == 255 }.count > solid.count * 95 / 100,
                    "The body is opaque, not a translucent cutout: \(path)")
                #expect(
                    solid.allSatisfy { i in
                        let x = i % 512; let y = i / 512
                        return x >= 8 && x < 504 && y >= 8 && y < 504
                    }, "Silhouette stays inside its canvas: \(path)")
                if name == "idle" || name == "jump-start" || name == "landing" {
                    var runs: [(Int, Int)] = []
                    var start: Int?
                    for x in 0...512 {
                        let supported = x < 512 && (469...475).contains { alpha[$0 * 512 + x] >= 128 }
                        if supported, start == nil { start = x }
                        if !supported, let first = start {
                            if let previous = runs.last, first - previous.1 <= 8 {
                                runs[runs.count - 1].1 = x - 1
                            } else {
                                runs.append((first, x - 1))
                            }
                            start = nil
                        }
                    }
                    if runs.count == 3 {
                        let far = runs[1]
                        #expect(
                            abs(Double(far.0 + far.1) / 2 - 246.5) <= 1,
                            "Far paw contact must not slide: \(path), \(far)")
                    }
                    let rear = try #require(runs.first)
                    let front = try #require(runs.last)
                    #expect(
                        abs(Double(rear.0 + rear.1) / 2 - 166.5) <= 1,
                        "Rear contact must not slide: \(path), \(rear)")
                    #expect(
                        abs(Double(front.0 + front.1) / 2 - 346.5) <= 1,
                        "Front contact must not slide: \(path), \(front)")
                }
                let lowest = try #require(solid.map { $0 / 512 }.max())
                if name == "idle" || name == "jump-start" || name == "landing" {
                    #expect(abs(lowest - 474) <= 1, "Ground contact: \(path), row \(lowest)")
                } else {
                    #expect(lowest <= 474, "Airborne paws must not extend below the virtual foot: \(path)")
                }
            }
        }
    }
}
