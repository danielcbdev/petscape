import AppKit
import PetScapeCore
import PetScapePlatform
import PetScapeRendering
import Testing

@testable import PetScapeRuntime

/// T5.5–T5.8, T6.2–T6.5 integration: `PetRuntime` on the real screens (and the real Dock reservation) with a
/// fake frame driver, isolated notification centers and in-memory preferences.
@Suite("PetRuntime", .serialized)
struct PetRuntimeTests {
    final class FakeFrameDriver: FrameDriver {
        var onFrame: ((TimeInterval) -> Void)?
        var isPaused = true
        var preferredFramesPerSecond: Float = 0
        private(set) var isInvalidated = false

        func invalidate() {
            isInvalidated = true
            onFrame = nil
        }

        /// Delivers a frame like the display link: only while unpaused.
        func fire(at timestamp: TimeInterval) {
            guard !isPaused else { return }
            onFrame?(timestamp)
        }
    }

    final class NoMouseMonitoring: GlobalMouseMonitoring {
        func addMouseMovedMonitor(_ handler: @escaping @MainActor (CursorSample) -> Void) -> Any? { NSObject() }
        func removeMonitor(_ monitor: Any) {}
    }

    final class Harness {
        let driver = FakeFrameDriver()
        let workspaceCenter = NotificationCenter()
        let distributedCenter = NotificationCenter()
        let sampler = CursorSampler(monitoring: NoMouseMonitoring())
        let preferences: InMemoryPreferencesStore
        let runtime: PetRuntime
        var time: TimeInterval = 1000

        init(
            preferences: InMemoryPreferencesStore = InMemoryPreferencesStore(
                petSettings: PetSettings(behavior: AutonomySettings(isEnabled: false))),
            tuning: BehaviorTuning = BehaviorTuning(),
            readScreens: (@MainActor () -> [ScreenDescriptor])? = nil,
            screenCenter: NotificationCenter = NotificationCenter()
        ) {
            self.preferences = preferences
            let driver = driver
            runtime = PetRuntime(
                screenProvider: ScreenProvider(notificationCenter: screenCenter, readScreens: readScreens),
                cursorSampler: sampler,
                systemEvents: SystemEventsMonitor(
                    workspaceCenter: workspaceCenter, distributedCenter: distributedCenter),
                fullScreenDetector: FullScreenSpaceDetector(workspaceCenter: NotificationCenter()),
                preferences: preferences,
                overlays: OverlayWindowManager(notificationCenter: NotificationCenter()),
                makeFrameDriver: { _ in driver },
                random: SeededRandomSource(seed: 5), tuning: tuning)
        }

        /// Starts the runtime with an opaque 32 pt test character.
        func start() async throws {
            runtime.start()
            let frames = (1...4).map { "walk/\($0).png" }
            let pack = try TestPacks.make(manifest: TestPacks.manifest(walkFrames: frames), images: frames)
            runtime.show(await CharacterLoader().load(packURL: pack))
        }

        func frames(_ count: Int) {
            for _ in 0..<count {
                time += 1.0 / 60
                driver.fire(at: time)
            }
        }

        var pet: PetRenderState? { runtime.currentSnapshot.pets.first }

        deinit {
            MainActor.assumeIsolated { runtime.stop() }
        }
    }

    @Test func withoutACharacterNoFramesRun() throws {
        let h = Harness()
        h.runtime.start()
        try #require(h.runtime.overlay.hostScreen != nil, "needs a display")
        #expect(h.driver.isPaused)
        #expect(h.driver.preferredFramesPerSecond == 60)
    }

    @Test func showingACharacterPlacesThePetOnTheDockWalkwayAndRendersIt() async throws {
        let h = Harness()
        try await h.start()
        let screen = try #require(h.runtime.overlay.hostScreen)
        let pet = try #require(h.pet)
        #expect(pet.isVisible)
        // This machine's Dock decides the walkway: its top when at the bottom, else the screen bottom.
        let dock = h.runtime.overlay.dock
        let walkway = try #require(dock.surface)
        #expect(pet.position.y == walkway.y)
        #expect(dock.hostScreenID == screen.id)
        switch dock.estimate.position {
        case .bottom: #expect(walkway.kind == .dockTop && walkway.y == screen.visibleFrame.minY)
        case .left, .right, .hiddenOrUnknown: #expect(walkway.y == screen.frame.minY)
        }
        #expect(pet.spriteRect.minX >= screen.frame.minX && pet.spriteRect.maxX <= screen.frame.maxX)
        let layers = try #require(h.runtime.overlay.hostContentView?.petLayerHost.sublayers)
        #expect(layers.count == 1)
        #expect(layers[0].contents != nil)
        #expect(layers[0].bounds.size == CGSize(width: 32, height: 32))
        #expect(!h.driver.isPaused)  // running and a pet is on screen
    }

    @Test func trackedWindowSurfaceEntersWorldAndBecomesAJumpDestination() async throws {
        let h = Harness()
        try await h.start()
        h.frames(2)
        let screen = try #require(h.runtime.overlay.hostScreen)
        let pet = try #require(h.runtime.pets.first)
        let frame = CGRect(
            x: screen.frame.minX, y: screen.frame.minY + 20, width: screen.frame.width, height: 100)
        let window = TrackedWindow(id: 902, ownerPID: 123, frame: frame, zIndex: 0)
        h.runtime.receiveTrackedWindows([window])
        let targetSurface = try #require(h.runtime.trackedWindowSurfaces.first)
        let targetX = pet.position.x + 30 < screen.frame.maxX - 48 ? pet.position.x + 30 : pet.position.x - 30
        #expect(h.runtime.requestJump(to: .surface(targetSurface.id, x: targetX)))
    }

    @Test(arguments: [DockEstimate.Position.left, .right])
    func movingDockToASideKeepsFramesRunningThroughFallAndLanding(_ position: DockEstimate.Position) async throws {
        let h = Harness()
        try await h.start()
        h.frames(2)
        let screen = try #require(h.runtime.overlay.hostScreen)
        let frame = screen.frame
        let visibleFrame: CGRect
        switch position {
        case .left:
            visibleFrame = CGRect(
                x: frame.minX + 50, y: frame.minY, width: frame.width - 50, height: frame.height - 36)
        case .right:
            visibleFrame = CGRect(
                x: frame.minX, y: frame.minY, width: frame.width - 50, height: frame.height - 36)
        case .bottom, .hiddenOrUnknown:
            Issue.record("This regression test only covers a side Dock")
            return
        }
        let sideScreen = ScreenDescriptor(
            id: screen.id, frame: frame, visibleFrame: visibleFrame,
            backingScale: screen.backingScale, isPrimary: true)

        h.runtime.overlay.dock.update(screens: [sideScreen])
        h.runtime.overlay.onScreensChange?()
        #expect(h.runtime.overlay.dock.estimate.position == position)
        #expect(h.runtime.overlay.dock.surface?.kind == .screenBottom)

        for _ in 0..<60 {
            #expect(!h.driver.isPaused)
            h.frames(1)
            #expect(h.pet?.isVisible == true)
        }

        let pet = try #require(h.pet)
        #expect(pet.isVisible)
        #expect(pet.position.y == frame.minY)
        #expect(!h.driver.isPaused)
    }

    @Test func framesStepTheWorldAtTheFixedRateAndMoveTheLayer() async throws {
        let h = Harness()
        try await h.start()
        let start = try #require(h.pet).position
        h.frames(1)  // first frame only records the timestamp
        #expect(h.pet?.position == start)
        h.frames(60)
        let moved = try #require(h.pet)
        // fallbackWalkSpeed 20 pt/s for one second (or a turn at an edge on the way).
        let distance = abs(moved.position.x - start.x)
        #expect(distance > 0 && distance <= 20 + 1e-6)
        let screen = try #require(h.runtime.overlay.hostScreen)
        let layer = try #require(h.runtime.overlay.hostContentView?.petLayerHost.sublayers?.first)
        #expect(abs(layer.position.x - (moved.position.x - screen.frame.minX)) < 1e-9)
    }

    @Test func passThroughUsesTheRealMask() async throws {
        let h = Harness()
        try await h.start()
        let pet = try #require(h.pet)
        let rect = pet.spriteRect
        let tester = try #require(h.runtime.overlay.passthrough.hitTester as? PetHitTester)
        #expect(tester.petID(at: CGPoint(x: rect.midX, y: rect.midY)) == pet.id)
        #expect(!tester.containsPet(at: CGPoint(x: rect.maxX + 5, y: rect.midY)))
    }

    @Test func runtimeWiresPrimaryClickThroughWorldAcknowledgement() async throws {
        let h = Harness()
        try await h.start()
        h.frames(2)
        let pet = try #require(h.pet)
        #expect(pet.isVisible)
        let location = CGPoint(x: pet.spriteRect.midX, y: pet.spriteRect.midY)
        h.runtime.overlay.onMouseEvent?(
            OverlayMouseEvent(kind: .down, location: location, timestamp: h.time))
        #expect(h.runtime.pets.first?.state == .walking)
        h.runtime.overlay.onMouseEvent?(
            OverlayMouseEvent(kind: .up, location: location, timestamp: h.time + 0.01))
        #expect(h.runtime.pets.first?.state == .grounded(.reactingToClick))
    }

    @Test func pauseClearsWorldReservationBeforeFramesStop() async throws {
        let h = Harness()
        try await h.start()
        h.frames(2)
        let pet = try #require(h.pet)
        let location = CGPoint(x: pet.spriteRect.midX, y: pet.spriteRect.midY)
        h.runtime.overlay.onMouseEvent?(
            OverlayMouseEvent(kind: .down, location: location, timestamp: h.time))

        h.runtime.setPaused(true)
        #expect(h.driver.isPaused)
        h.runtime.setPaused(false)
        h.runtime.overlay.onMouseEvent?(
            OverlayMouseEvent(kind: .up, location: location, timestamp: h.time + 0.01))
        h.runtime.overlay.onMouseEvent?(
            OverlayMouseEvent(kind: .down, location: location, timestamp: h.time + 0.02))
        h.runtime.overlay.onMouseEvent?(
            OverlayMouseEvent(kind: .up, location: location, timestamp: h.time + 0.03))
        #expect(h.runtime.pets.first?.state == .grounded(.reactingToClick))
    }

    @Test func pauseFreezesStopsFramesPersistsAndResumesWithoutCatchingUp() async throws {
        let h = Harness()
        try await h.start()
        h.frames(30)
        let before = try #require(h.pet)

        h.runtime.setPaused(true)
        #expect(h.preferences.isPaused)
        #expect(h.driver.isPaused)
        h.time += 100  // a long pause
        h.frames(10)  // the paused display link delivers nothing
        #expect(h.pet == before)

        h.runtime.setPaused(false)
        #expect(!h.driver.isPaused)
        h.frames(1)  // first frame after resume: no catch-up for the 100 s
        #expect(h.pet == before)
        h.frames(1)
        let after = try #require(h.pet)
        #expect(abs(after.position.x - before.position.x) <= 20.0 / 60 + 1e-9)
    }

    @Test func hideOrdersTheOverlayOutStopsFramesAndPersists() async throws {
        let h = Harness()
        try await h.start()
        h.runtime.setHidden(true)
        #expect(h.preferences.isHidden)
        #expect(h.driver.isPaused)
        #expect(h.runtime.overlay.hostContentView?.window?.isVisible == false)
        h.runtime.setHidden(false)
        #expect(h.runtime.overlay.hostContentView?.window?.isVisible == true)
        #expect(!h.driver.isPaused)
    }

    @Test func persistedPauseAndHideAreRestoredAtLaunch() async throws {
        let h = Harness(preferences: InMemoryPreferencesStore(isPaused: true, isHidden: false))
        try await h.start()
        #expect(h.runtime.userIntent == UserIntent(isPaused: true, isHidden: false))
        #expect(h.driver.isPaused)
        #expect(h.pet?.isVisible == true)  // a paused pet is still drawn, frozen
        #expect(h.runtime.overlay.hostContentView?.petLayerHost.sublayers?.first?.contents != nil)
    }

    @Test func dockOffsetMovesTheWalkwayAndThePetAndPersists() async throws {
        let h = Harness()
        try await h.start()
        let y = try #require(h.pet).position.y
        let isDockTop = h.runtime.overlay.dock.surface?.kind == .dockTop
        h.runtime.setDockOffsetAdjustment(-3)
        #expect(h.preferences.dockOffsetAdjustment == -3)
        #expect(h.runtime.dockOffsetAdjustment == -3)
        // The offset applies to the Dock top only; the screen-bottom fallback ignores it.
        #expect(h.pet?.position.y == (isDockTop ? y - 3 : y))
        h.runtime.setDockOffsetAdjustment(100)
        #expect(h.preferences.dockOffsetAdjustment == 40)
    }

    @Test func persistedDockOffsetIsAppliedAtLaunch() async throws {
        let h = Harness(preferences: InMemoryPreferencesStore(dockOffsetAdjustment: 7))
        try await h.start()
        #expect(h.runtime.dockOffsetAdjustment == 7)
    }

    /// T6.5: sleep and lock stop frames; on return the simulation continues where it was, without catching up.
    @Test(arguments: [
        (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, false),
        (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, false),
        (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, false),
        (Notification.Name("com.apple.screenIsLocked"), Notification.Name("com.apple.screenIsUnlocked"), true),
    ])
    func suspensionStopsFramesHidesTheOverlayAndResumesWithoutAJump(
        start: Notification.Name, end: Notification.Name, isDistributed: Bool
    ) async throws {
        let h = Harness()
        try await h.start()
        h.frames(30)
        let before = try #require(h.pet)
        let center = isDistributed ? h.distributedCenter : h.workspaceCenter

        center.post(name: start, object: nil)
        #expect(h.driver.isPaused)
        #expect(h.runtime.overlay.hostContentView?.window?.isVisible == false)
        h.time += 3600  // away for an hour
        h.frames(10)
        #expect(h.pet == before)

        center.post(name: end, object: nil)
        #expect(!h.driver.isPaused)
        #expect(h.runtime.overlay.hostContentView?.window?.isVisible == true)
        h.frames(1)  // only records the timestamp
        #expect(h.pet == before)
        h.frames(1)
        let after = try #require(h.pet)
        #expect(abs(after.position.x - before.position.x) <= 20.0 / 60 + 1e-9)
    }
    @Test func idleDemandKeepsCursorMonitoringWithoutPollingFrames() async throws {
        let h = Harness()
        try await h.start()
        #expect(!h.sampler.isMonitoring)
        h.runtime.overlay.needsFrames = false
        #expect(h.driver.isPaused)
        #expect(h.sampler.isMonitoring)
        h.runtime.overlay.needsFrames = true
        #expect(!h.driver.isPaused)
        #expect(!h.sampler.isMonitoring)
    }
    final class ScreenValues {
        var screens: [ScreenDescriptor]
        init(_ screens: [ScreenDescriptor]) { self.screens = screens }
    }
    static func syntheticScreen(_ id: UInt32 = 1, bottomInset: CGFloat = 64) -> ScreenDescriptor {
        ScreenDescriptor(
            id: ScreenID(id), frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: bottomInset, width: 1000, height: 764 - bottomInset),
            backingScale: 2, isPrimary: true)
    }
    @Test func syntheticDockChangeWhilePausedFallsOnlyAfterResume() async throws {
        let values = ScreenValues([Self.syntheticScreen()])
        let center = NotificationCenter()
        let h = Harness(readScreens: { values.screens }, screenCenter: center)
        try await h.start()
        h.frames(3)
        h.runtime.setPaused(true)
        let old = try #require(h.pet)
        values.screens = [Self.syntheticScreen(bottomInset: 0)]
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        h.frames(600)
        #expect(h.pet?.position == old.position)
        #expect(h.driver.isPaused)
        h.runtime.setPaused(false)
        h.frames(1)
        #expect(h.pet?.position == old.position)
        h.frames(60)
        #expect(h.pet?.position.y == 0)
        #expect(!h.driver.isPaused)
    }
    @Test func replacementDriverStartsWithoutCatchup() async throws {
        let values = ScreenValues([Self.syntheticScreen()])
        let center = NotificationCenter()
        let h = Harness(readScreens: { values.screens }, screenCenter: center)
        try await h.start()
        h.frames(3)
        values.screens = [Self.syntheticScreen(2)]
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let afterEnvironment = try #require(h.pet)
        h.time += 1000
        h.frames(1)
        #expect(h.pet == afterEnvironment)
        h.frames(10)
        #expect(h.pet?.isVisible == true)
    }
    @Test func jumpCommandsRespectPauseAndFreezeMidairWithoutCatchup() async throws {
        let h = Harness(readScreens: { [Self.syntheticScreen()] })
        try await h.start()
        h.frames(3)
        h.runtime.setPaused(true)
        #expect(!h.runtime.requestJump(JumpRequest()))
        h.runtime.setPaused(false)
        #expect(h.runtime.requestJump(JumpRequest()))
        h.frames(15)
        let airborne = try #require(h.pet)
        #expect(airborne.position.y > 64)
        h.runtime.setPaused(true)
        h.time += 3600
        h.frames(120)
        #expect(h.pet == airborne)
        h.runtime.setPaused(false)
        h.frames(1)
        #expect(h.pet == airborne)
        h.frames(120)
        #expect(h.pet?.position.y == 64)
    }
    @Test func heldIdleStopsFramesAndJumpWakesTheSameDriver() async throws {
        let h = Harness(readScreens: { [Self.syntheticScreen()] })
        try await h.start()
        h.frames(3)
        h.runtime.setActivity(.idle)
        #expect(h.driver.isPaused)
        #expect(h.sampler.isMonitoring)
        #expect(h.runtime.requestJump(JumpRequest(returnActivity: .idle)))
        #expect(!h.driver.isPaused)
        #expect(h.driver.preferredFramesPerSecond == 60)
        h.frames(210)
        #expect(h.driver.isPaused)
        #expect(h.sampler.isMonitoring)
        #expect(h.runtime.requestJump(JumpRequest()))
        #expect(!h.driver.isPaused)
    }
    @Test func debugTargetCommandPreservesIdleIntent() async throws {
        let h = Harness(readScreens: { [Self.syntheticScreen()] })
        try await h.start()
        h.frames(3)
        h.runtime.setActivity(.idle)
        #expect(h.runtime.requestJump(to: .vertical))
        h.frames(210)
        #expect(h.driver.isPaused)
    }
    @Test(arguments: [15, 30])
    func realIdleLoopAtLowerCallbackRatesKeepsSimulationTime(callbackRate: Int) async throws {
        let h = Harness(readScreens: { [Self.syntheticScreen()] })
        h.runtime.start()
        let frames = ["a.png", "b.png", "c.png", "d.png"]
        let json = TestPacks.manifest(walkFrames: ["a.png"], sitFrames: frames)
            .replacingOccurrences(of: "sit", with: "idle")
        let pack = try TestPacks.make(manifest: json, images: frames)
        defer { try? FileManager.default.removeItem(at: pack) }
        h.runtime.show(await CharacterLoader().load(packURL: pack))
        h.frames(3)
        h.runtime.setActivity(.idle)
        #expect(!h.driver.isPaused)
        #expect(h.driver.preferredFramesPerSecond == 30)
        let position = h.pet?.position
        for _ in 0..<callbackRate {
            h.time += 1.0 / Double(callbackRate)
            h.driver.fire(at: h.time)
        }
        #expect(h.pet?.position == position)
        #expect(h.pet?.frame.clip == "idle")
        #expect(h.pet?.frame.frameIndex == 0)  // 4 fps / four frames: exactly one loop.
    }
    @Test func duplicateRuntimeJumpReturnsFalse() async throws {
        let h = Harness(readScreens: { [Self.syntheticScreen()] })
        try await h.start()
        h.frames(3)
        #expect(h.runtime.requestJump(JumpRequest()))
        #expect(!h.runtime.requestJump(JumpRequest()))
    }
    @Test func productionDefaultsEnableAutonomyAndRestoreScaleBeforeSpawn() async throws {
        let preferences = InMemoryPreferencesStore(petSettings: PetSettings(scale: 1.5, speed: 2))
        let h = Harness(
            preferences: preferences, tuning: BehaviorTuning(activityWeights: [.sleep: 1]),
            readScreens: { [Self.syntheticScreen()] })
        try await h.start()
        #expect(h.pet?.spriteRect.width == 48)
        h.frames(30)
        #expect(h.runtime.pets.first?.state == .grounded(.sleeping))
        #expect(h.driver.preferredFramesPerSecond == 4)
        #expect(!h.driver.isPaused)
    }

    @Test func settingsApplyWhilePausedHiddenAndAirborneWithoutMovingFeet() async throws {
        let h = Harness(readScreens: { [Self.syntheticScreen()] })
        try await h.start()
        h.frames(3)
        #expect(h.runtime.requestJump(JumpRequest()))
        h.frames(15)
        let before = try #require(h.runtime.pets.first)
        #expect(before.state == .airborne(.rising) || before.state == .airborne(.falling))
        h.runtime.setPaused(true)
        h.runtime.setHidden(true)
        let settings = PetSettings(
            scale: 1.5, speed: 2,
            behavior: AutonomySettings(
                isEnabled: false,
                jumpsEnabled: false, restEnabled: false, expressionsEnabled: false))
        h.runtime.setPetSettings(settings)
        let after = try #require(h.runtime.pets.first)
        #expect(after.position == before.position)
        #expect(after.velocity == before.velocity)
        #expect(after.facing == before.facing)
        #expect(after.size.width == 48)
        #expect(h.preferences.petSettings == settings)
        #expect(h.runtime.petSettings == settings)
        #expect(h.driver.isPaused)
        h.runtime.setHidden(false)
        h.runtime.setPaused(false)
        h.frames(1)
        #expect(h.runtime.pets.first?.position == before.position)
        h.frames(120)
        #expect(h.runtime.pets.first?.position.y == 64)
    }

    @Test func speedSettingChangesSupportedWalkingDistance() async throws {
        let slow = Harness(readScreens: { [Self.syntheticScreen()] })
        let fast = Harness(readScreens: { [Self.syntheticScreen()] })
        try await slow.start()
        try await fast.start()
        slow.frames(3)
        fast.frames(3)
        slow.runtime.setPetSettings(PetSettings(behavior: AutonomySettings(isEnabled: false)))
        fast.runtime.setPetSettings(PetSettings(speed: 2, behavior: AutonomySettings(isEnabled: false)))
        slow.frames(1)
        fast.frames(1)
        let start = try #require(slow.pet?.position.x)
        slow.frames(30)
        fast.frames(30)
        #expect(abs(abs(try #require(slow.pet?.position.x) - start) - 10) < 1e-6)
        #expect(abs(abs(try #require(fast.pet?.position.x) - start) - 20) < 1e-6)
    }

    @Test(arguments: [1.0, 2, 4])
    func passiveSleepPreservesSixtyHertzTimeAndPauseDoesNotCatchUp(rate: Double) async throws {
        let h = Harness(
            preferences: InMemoryPreferencesStore(),
            tuning: BehaviorTuning(activityWeights: [.sleep: 1]), readScreens: { [Self.syntheticScreen()] })
        try await h.start()
        h.frames(30)
        #expect(h.runtime.pets.first?.state == .grounded(.sleeping))
        let before = h.runtime.simulationTime
        let energy = try #require(h.runtime.pets.first?.needs.energy)
        for _ in 0..<Int(rate * 5) {
            h.time += 1 / rate
            h.driver.fire(at: h.time)
        }
        #expect(abs(h.runtime.simulationTime - before - 5) < 1e-6)
        #expect(abs(try #require(h.runtime.pets.first?.needs.energy) - energy - 5.0 / 45) < 1e-6)
        h.runtime.setPaused(true)
        let paused = h.runtime.simulationTime
        h.time += 3600
        h.runtime.setPaused(false)
        h.driver.fire(at: h.time)
        #expect(h.runtime.simulationTime == paused)
        h.time += 1 / rate
        h.driver.fire(at: h.time)
        #expect(abs(h.runtime.simulationTime - paused - 1 / rate) < 1e-6)
    }

    @Test func passiveBatchStopsAtWakeAndDoesNotFastForwardWalking() async throws {
        let h = Harness(
            preferences: InMemoryPreferencesStore(),
            tuning: BehaviorTuning(activityWeights: [.sleep: 1]), readScreens: { [Self.syntheticScreen()] })
        try await h.start()
        h.frames(30)
        var iterations = 0
        while h.runtime.pets.first?.state == .grounded(.sleeping), iterations < 70 {
            let before = h.runtime.simulationTime
            h.time += 2
            h.driver.fire(at: h.time)
            if h.runtime.pets.first?.state != .grounded(.sleeping) {
                #expect(h.runtime.pets.first?.state == .grounded(.wakingUp))
                #expect(h.runtime.simulationTime - before <= 2 + 1e-6)
                #expect(h.runtime.pets.first?.stateElapsed == 0)
                #expect(h.driver.preferredFramesPerSecond == 60)
            }
            iterations += 1
        }
        #expect(iterations < 70)
    }

    @Test func wakeAndSupportLossLeavePassiveRateWithoutFastForwardingPhysics() async throws {
        let values = ScreenValues([Self.syntheticScreen()])
        let center = NotificationCenter()
        let h = Harness(
            preferences: InMemoryPreferencesStore(),
            tuning: BehaviorTuning(activityWeights: [.sleep: 1]),
            readScreens: { values.screens }, screenCenter: center)
        try await h.start()
        h.frames(30)
        #expect(h.runtime.pets.first?.state == .grounded(.sleeping))
        h.runtime.wakePet()
        #expect(h.runtime.pets.first?.state == .grounded(.wakingUp))
        #expect(h.driver.preferredFramesPerSecond == 60)
        h.frames(120)
        // Re-enter sleep after its cooldown using the same deterministic weighting.
        h.frames(1500)
        #expect(h.runtime.pets.first?.state == .grounded(.sleeping))
        values.screens = [Self.syntheticScreen(bottomInset: 0)]
        center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let y = try #require(h.pet?.position.y)
        h.time += 1
        h.driver.fire(at: h.time)
        #expect(try #require(h.pet?.position.y) > 0)
        #expect(try #require(h.pet?.position.y) <= y)
        #expect(h.runtime.pets.first?.state == .airborne(.falling))
        #expect(h.driver.preferredFramesPerSecond == 60)
    }

    #if DEBUG
        @Test func diagnosticCountsZeroSeedFullPassiveBatchAndOneSafetyTick() async throws {
            let values = ScreenValues([Self.syntheticScreen()])
            let center = NotificationCenter()
            let h = Harness(
                preferences: InMemoryPreferencesStore(),
                tuning: BehaviorTuning(activityWeights: [.sleep: 1]),
                readScreens: { values.screens }, screenCenter: center)
            try await h.start()
            h.frames(1)
            #expect(h.runtime.lastFrameStepCount == 0)
            #expect(h.runtime.simulationTime == 0)
            h.frames(29)
            #expect(h.runtime.pets.first?.state == .grounded(.sleeping))
            let sleepingTime = h.runtime.simulationTime
            h.time += 0.25
            h.driver.fire(at: h.time)
            #expect(h.runtime.lastFrameStepCount == 15)
            #expect(abs(h.runtime.simulationTime - sleepingTime - 0.25) < 1e-6)
            values.screens = [Self.syntheticScreen(bottomInset: 0)]
            center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            #expect(h.runtime.pets.first?.state == .grounded(.sleeping))
            let beforeSafety = h.runtime.simulationTime
            h.time += 0.25
            h.driver.fire(at: h.time)
            #expect(h.runtime.lastFrameStepCount == 1)
            #expect(abs(h.runtime.simulationTime - beforeSafety - 1.0 / 60) < 1e-6)
            #expect(h.runtime.pets.first?.state == .airborne(.falling))
            #expect(h.driver.preferredFramesPerSecond == 60)
        }
    #endif

}
