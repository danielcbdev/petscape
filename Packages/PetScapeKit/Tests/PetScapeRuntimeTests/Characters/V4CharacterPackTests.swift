import CoreGraphics
import Foundation
import ImageIO
import PetScapeCore
import PetScapeRendering
import Testing

@testable import PetScapeRuntime

@Suite("Cat V4 production pack")
struct V4CharacterPackTests {
    static let phaseNames = ["idle", "jump-start", "jump", "fall", "landing"]

    @Test func productionPhasesLoadWithoutFallbackAndFitTheApprovedBudget() async throws {
        let character = await CharacterLoader().load(packURL: TestPacks.catPackURL)
        #expect(character.failure == nil)
        #expect(character.issues.isEmpty)
        #expect(character.definition.displaySize == .init(width: 96, height: 96))
        #expect(character.decodedByteCount <= 16 * 1024 * 1024)
        for name in Self.phaseNames {
            let clip = try #require(character.definition.clips[name], "Missing production clip \(name)")
            #expect(clip.frames.count > 1)
            #expect(clip.anchor == .init(x: 0.5, y: 0.074))
            #expect(character.frames[name]?.count == clip.frames.count)
            #expect(clip.next == nil, "Physical phase changes remain simulation-owned")
        }
    }

    @Test func semanticRestAndExpressionFallbacksUseTheExistingIdlePose() async throws {
        let character = await CharacterLoader().load(packURL: TestPacks.catPackURL)
        #expect(character.failure == nil)
        #expect(character.decodedByteCount == 10_616_832)
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

    @Test func productionArtDoesNotChangeTheExecutedTrajectory() async throws {
        let character = await CharacterLoader().load(packURL: TestPacks.catPackURL)
        let data = try Data(contentsOf: TestPacks.catPackURL.appending(path: "character.json"))
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
        let data = try Data(contentsOf: TestPacks.catPackURL.appending(path: "character.json"))
        let manifest = try JSONDecoder().decode(CharacterManifest.self, from: data)
        for name in Self.phaseNames {
            let frames = try #require(manifest.animations[name]?.frames, "Missing \(name)")
            for frame in frames {
                let path = try #require(frame.image)
                guard !path.hasPrefix("walk/") else { continue }  // Immutable legacy neutral pose, audited separately.
                let url = TestPacks.catPackURL.appending(path: path)
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
