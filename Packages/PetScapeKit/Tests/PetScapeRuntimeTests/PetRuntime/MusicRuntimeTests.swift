import AppKit
import PetScapeCore
import PetScapePlatform
import Testing

@testable import PetScapeRuntime

extension PetRuntimeTests {
    @Suite("M16 runtime and consent", .serialized)
    struct MusicRuntimeTests {
        final class Source: MusicScoreSource {
            var onScore: ((Double, Double) -> Void)?
            var onFailure: (() -> Void)?
            var starts = 0
            var stops = 0
            func start() throws { starts += 1 }
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

        @Test func consentIsExplicitManualNeedsNoCaptureAndRestoreDisablesIt() async {
            let source = Source()
            let detector = MusicDetectionController(source: source)
            let h = Self.harness(detector)
            let model = SettingsModel(
                runtime: h.runtime, preferences: h.preferences,
                loginService: SettingsModelTests.LoginService())
            h.runtime.start()
            h.runtime.show(await CharacterLoader().load(packURL: TestPacks.catPackURL))
            h.frames(2)
            #expect(!model.isSpecialArtworkPending, "The cat pack ships dance and cleanup")
            model.setAutonomyEnabled(true)
            h.runtime.setActivity(.idle)
            #expect(model.canDance)
            model.dance()
            #expect(h.runtime.pets[0].state == .grounded(.dancing(.manual)))
            #expect(!model.canDance)
            #expect(model.canStopDance)
            model.stopDance()
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
            model.restoreDefaults()
            #expect(!h.preferences.isMusicDancingEnabled)
            #expect(source.stops == 1)
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
    }

}
