import Testing

@testable import PetScapeCore
@testable import PetScapeRuntime

@Suite("RunStateController")
struct RunStateControllerTests {
    @Test func startsRunningAndReportsOnlyChanges() {
        let controller = RunStateController()
        #expect(controller.status.state == .running)
        var reported: [RunState] = []
        controller.onChange = { reported.append($0.state) }

        controller.setCondition(.overlayOccluded, isActive: false)  // already off: no change
        controller.setPaused(false)
        #expect(reported.isEmpty)

        controller.setCondition(.systemSleep, isActive: true)
        controller.setCondition(.systemSleep, isActive: true)
        controller.setCondition(.systemSleep, isActive: false)
        #expect(reported == [.suspended([.systemSleep]), .running])
    }

    @Test func persistedIntentIsTheStartingPoint() {
        let controller = RunStateController(intent: UserIntent(isPaused: true))
        #expect(controller.status.state == .paused)
        #expect(controller.status.isIdleCursorMonitorNeeded)
    }

    @Test func pausedPetStaysPausedThroughSleepAndLock() {
        let controller = RunStateController()
        controller.setPaused(true)
        controller.setCondition(.systemSleep, isActive: true)
        controller.setCondition(.screenLocked, isActive: true)
        #expect(controller.status.state == .paused)
        #expect(!controller.status.isOverlayVisible)
        controller.setCondition(.systemSleep, isActive: false)
        controller.setCondition(.screenLocked, isActive: false)
        #expect(controller.status.state == .paused)
        #expect(controller.status.isOverlayVisible)
    }

    @Test func overlappingReasonsResumeOnlyWhenAllCleared() {
        let controller = RunStateController()
        controller.setCondition(.displaySleep, isActive: true)
        controller.setCondition(.screenLocked, isActive: true)
        controller.setCondition(.displaySleep, isActive: false)
        #expect(controller.status.state == .suspended([.screenLocked]))
        controller.setCondition(.screenLocked, isActive: false)
        #expect(controller.status.state == .running)
    }

    @Test func fullScreenSpaceHidesTheOverlayAndReturnRestoresIt() {
        let controller = RunStateController()
        var visibility: [Bool] = []
        controller.onChange = { visibility.append($0.isOverlayVisible) }
        controller.setCondition(.fullScreenSpace, isActive: true)
        controller.setCondition(.fullScreenSpace, isActive: false)
        #expect(visibility == [false, true])
    }

    @Test func hideAndShowReturnToThePreviousState() {
        let controller = RunStateController()
        controller.setPaused(true)
        controller.setHidden(true)
        #expect(controller.status.state == .hidden)
        controller.setHidden(false)
        #expect(controller.status.state == .paused)
        controller.setPaused(false)
        #expect(controller.status.state == .running)
    }
}
