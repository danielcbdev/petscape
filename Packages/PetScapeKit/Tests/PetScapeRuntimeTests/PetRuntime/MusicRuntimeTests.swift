import AppKit
import PetScapePlatform
import Testing

@testable import PetScapeCore
@testable import PetScapeRuntime

extension PetRuntimeTests {
    @Suite("M16 runtime and consent", .serialized)
    struct MusicRuntimeTests {
        final class Source: MusicScoreSource {
            var onScore: ((Double, Double) -> Void)?
            var onFailure: (() -> Void)?
            var starts = 0
            var stops = 0
            var failedStartsRemaining = 0
            func start() throws {
                starts += 1
                if failedStartsRemaining > 0 {
                    failedStartsRemaining -= 1
                    throw MusicCaptureError.unavailable
                }
            }
            func stop() { stops += 1 }
        }

        private static func harness(_ detector: MusicDetectionController) -> PetRuntimeTests.Harness {
            PetRuntimeTests.Harness(
                musicDetector: detector,
                readScreens: { [PetRuntimeTests.syntheticScreen()] },
                readWindowList: {
                    [WindowListEntry(ownerName: "Dock", layer: Int(CGWindowLevelForKey(.dockWindow)))]
                })
        }

        @Test func consentIsExplicitManualNeedsNoCaptureAndRestoreDisablesIt() async throws {
            let source = Source()
            let detector = MusicDetectionController(source: source)
            let h = Self.harness(detector)
            let model = SettingsModel(
                runtime: h.runtime, preferences: h.preferences,
                loginService: SettingsModelTests.LoginService())
            h.runtime.start()
            h.runtime.show(await CharacterLoader().load(packURL: TestPacks.catPackURL))
            h.frames(2)
            let petID = try #require(h.runtime.pets.first?.id)
            #expect(!model.isSpecialArtworkPending, "The cat pack ships dance and cleanup")
            model.setAutonomyEnabled(true)
            h.runtime.setActivity(.idle)
            #expect(model.canDance)
            model.dance(petID)
            #expect(h.runtime.pets[0].state == .grounded(.dancing(.manual)))
            #expect(!model.canDance)
            #expect(model.canStopDance)
            model.stopDance(petID)
            #expect(!model.canStopDance)
            #expect(model.canDance)
            #expect(h.runtime.pets[0].state == .grounded(.idle))
            #expect(source.starts == 0)
            model.setMusicDancingEnabled(true)
            #expect(model.isMusicConsentPresented)
            #expect(source.starts == 0)
            model.cancelMusicConsent()
            #expect(!model.isMusicDancingEnabled)
            model.setMusicDancingEnabled(true)
            model.confirmMusicConsent()
            #expect(source.starts == 1)
            #expect(h.preferences.isMusicDancingEnabled)
            model.retryMusicDetection()
            #expect(source.starts == 2)
            #expect(h.preferences.isMusicDancingEnabled)
            model.restoreDefaults()
            #expect(!h.preferences.isMusicDancingEnabled)
            #expect(source.stops == 2)
            #expect(model.musicStatus == .off)
            h.runtime.stop()
        }

        @Test func pauseHideSuspendAutonomyAndQuitStopAudioAndCancelDance() async {
            let source = Source()
            let h = Self.harness(MusicDetectionController(source: source))
            h.runtime.start()
            h.runtime.show(await CharacterLoader().load(packURL: TestPacks.catPackURL))
            h.frames(2)
            h.runtime.setPetSettings(PetSettings())
            h.runtime.setActivity(.idle)
            h.runtime.setMusicDancingEnabled(true)
            source.onScore?(1, 1)
            #expect(h.runtime.pets[0].state == .grounded(.dancing(.automatic)))
            h.runtime.setPaused(true)
            #expect(h.runtime.pets[0].state == .grounded(.idle))
            #expect(source.stops == 1)
            #expect(!h.runtime.canDance)
            h.runtime.setPaused(false)
            #expect(source.starts == 2)
            source.onScore?(1, 1)
            #expect(h.runtime.pets[0].state != .grounded(.dancing(.automatic)))
            h.runtime.setHidden(true)
            #expect(source.stops == 2)
            h.runtime.setHidden(false)
            #expect(source.starts == 3)
            h.workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
            #expect(source.stops == 3)
            h.workspaceCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
            #expect(source.starts == 4)
            h.runtime.setPetSettings(PetSettings(behavior: AutonomySettings(isEnabled: false)))
            #expect(source.stops == 4)
            h.runtime.setPetSettings(PetSettings())
            #expect(source.starts == 5)
            h.runtime.stop()
            #expect(source.stops == 5)
            #expect(source.onScore == nil)
        }

        @Test func persistedOptInRecoversAfterOneStartupCaptureFailure() async {
            let source = Source()
            source.failedStartsRemaining = 1
            let h = Self.harness(MusicDetectionController(source: source))
            h.preferences.isMusicDancingEnabled = true

            h.runtime.start()
            h.runtime.show(await CharacterLoader().load(packURL: TestPacks.catPackURL))
            h.frames(2)
            h.runtime.setPetSettings(PetSettings())
            h.runtime.setActivity(.idle)
            #expect(source.starts == 1)
            #expect(h.runtime.musicStatus == .unavailable)

            h.runtime.retryUnavailableMusicDetection()

            #expect(source.starts == 2)
            #expect(h.runtime.musicStatus == .monitoring)
            source.onScore?(0.9, 1)
            #expect(h.runtime.pets[0].state == .grounded(.dancing(.automatic)))
            h.runtime.retryUnavailableMusicDetection()
            #expect(source.starts == 2, "App activation does not restart healthy monitoring")
            #expect(h.runtime.pets[0].state == .grounded(.dancing(.automatic)))
            h.runtime.stop()
        }

        @Test func sharedMusicStartsIndependentDancesAndManualStopTargetsOnePet() async throws {
            func pack(_ id: String) throws -> URL {
                let frames = ["walk.png"]
                let manifest = TestPacks.manifest(walkFrames: frames).replacingOccurrences(
                    of: "\"fixture\"", with: "\"\(id)\"")
                return try TestPacks.make(manifest: manifest, images: frames)
            }
            let firstURL = try pack("first")
            let secondURL = try pack("second")
            defer {
                try? FileManager.default.removeItem(at: firstURL)
                try? FileManager.default.removeItem(at: secondURL)
            }
            let source = Source()
            let h = Self.harness(MusicDetectionController(source: source))
            h.runtime.start()
            h.runtime.show(await CharacterLoader().loadForSelection(packURL: firstURL))
            h.frames(3)
            let firstID = try #require(h.runtime.pets.first?.id)
            let secondCharacter = await CharacterLoader().loadForSelection(packURL: secondURL)
            let secondID = try #require(h.runtime.addCharacter(secondCharacter))
            h.frames(3)
            h.runtime.setPetSettings(PetSettings(behavior: AutonomySettings(isEnabled: true)))
            h.runtime.setActivity(.idle, for: firstID)
            h.runtime.setActivity(.idle, for: secondID)

            #expect(h.runtime.canDance(for: firstID) && h.runtime.canDance(for: secondID))
            h.runtime.requestDance(for: firstID)
            #expect(h.runtime.pets.first(where: { $0.id == firstID })?.state == .grounded(.dancing(.manual)))
            #expect(h.runtime.pets.first(where: { $0.id == secondID })?.state == .grounded(.idle))
            h.runtime.stopDance(for: firstID)

            h.runtime.setMusicDancingEnabled(true)
            source.onScore?(1, 1)
            #expect(h.runtime.pets.first(where: { $0.id == firstID })?.state == .grounded(.dancing(.automatic)))
            #expect(h.runtime.pets.first(where: { $0.id == secondID })?.state == .grounded(.dancing(.automatic)))
            let firstDuration = try #require(h.runtime.pets.first(where: { $0.id == firstID })?.specialBehaviorDuration)
            let secondDuration = try #require(
                h.runtime.pets.first(where: { $0.id == secondID })?.specialBehaviorDuration)
            #expect((5...30).contains(firstDuration) && (5...30).contains(secondDuration))
            #expect(firstDuration != secondDuration)

            h.runtime.stopDance(for: firstID)
            #expect(h.runtime.pets.first(where: { $0.id == firstID })?.state == .grounded(.idle))
            #expect(h.runtime.pets.first(where: { $0.id == secondID })?.state == .grounded(.dancing(.automatic)))
            h.runtime.setPaused(true)
            #expect(h.runtime.pets.first(where: { $0.id == secondID })?.state == .grounded(.idle))
            h.runtime.stop()
        }
    }

}
