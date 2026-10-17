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
        let preferences: InMemoryPreferencesStore
        let runtime: PetRuntime
        var time: TimeInterval = 1000

        init(preferences: InMemoryPreferencesStore = InMemoryPreferencesStore()) {
            self.preferences = preferences
            let driver = driver
            runtime = PetRuntime(
                screenProvider: ScreenProvider(notificationCenter: NotificationCenter()),
                cursorSampler: CursorSampler(monitoring: NoMouseMonitoring()),
                systemEvents: SystemEventsMonitor(
                    workspaceCenter: workspaceCenter, distributedCenter: distributedCenter),
                fullScreenDetector: FullScreenSpaceDetector(workspaceCenter: NotificationCenter()),
                preferences: preferences,
                overlays: OverlayWindowManager(notificationCenter: NotificationCenter()),
                makeFrameDriver: { _ in driver },
                random: SeededRandomSource(seed: 5))
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
}
