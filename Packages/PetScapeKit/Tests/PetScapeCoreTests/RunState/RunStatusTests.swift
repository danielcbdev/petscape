import Testing

@testable import PetScapeCore

/// Every combination of user intent × system state (AC-M3-03, testing.md "Run state").
@Suite("RunStatus.resolve")
struct RunStatusTests {
    static let intents: [UserIntent] = [
        UserIntent(),
        UserIntent(isPaused: true),
        UserIntent(isHidden: true),
        UserIntent(isPaused: true, isHidden: true),
    ]

    /// No reason, then each reason alone.
    static let singleConditions: [Set<SuspensionReason>] = [[]] + SuspensionReason.allCases.map { [$0] }

    /// Expected outcome for one intent with zero or one suspension reason, written out by hand.
    static func expected(intent: UserIntent, reason: SuspensionReason?) -> RunStatus {
        let reasons: Set<SuspensionReason> = reason.map { [$0] } ?? []
        let hidesOverlay: Bool =
            switch reason {
            case nil, .overlayOccluded: false
            case .systemSleep, .displaySleep, .sessionInactive, .screenLocked, .fullScreenSpace, .noScreens: true
            }
        switch (intent.isPaused, intent.isHidden) {
        case (_, true):
            return RunStatus(
                state: .hidden, isOverlayVisible: false, isFrameDriverRunning: false, isIdleCursorMonitorNeeded: false)
        case (true, false):
            return RunStatus(
                state: .paused, isOverlayVisible: !hidesOverlay, isFrameDriverRunning: false,
                isIdleCursorMonitorNeeded: reason == nil)
        case (false, false):
            if reason == nil {
                return RunStatus(
                    state: .running, isOverlayVisible: true, isFrameDriverRunning: true,
                    isIdleCursorMonitorNeeded: false)
            }
            return RunStatus(
                state: .suspended(reasons), isOverlayVisible: !hidesOverlay, isFrameDriverRunning: false,
                isIdleCursorMonitorNeeded: false)
        }
    }

    @Test(arguments: intents, singleConditions)
    func intentTimesSingleCondition(intent: UserIntent, reasons: Set<SuspensionReason>) {
        let status = RunStatus.resolve(intent: intent, reasons: reasons)
        #expect(status == Self.expected(intent: intent, reason: reasons.first))
    }

    /// All 4 intents × all 128 subsets of reasons: the invariants of data-flow.md#run-state.
    @Test func everySubsetOfReasonsKeepsTheInvariants() {
        let all = SuspensionReason.allCases
        for intent in Self.intents {
            for mask in 0..<(1 << all.count) {
                let reasons = Set(all.indices.filter { mask & (1 << $0) != 0 }.map { all[$0] })
                let status = RunStatus.resolve(intent: intent, reasons: reasons)
                let label = "\(intent) \(reasons)"

                // Precedence: hidden > paused > suspended > running.
                if intent.isHidden {
                    #expect(status.state == .hidden, "\(label)")
                } else if intent.isPaused {
                    #expect(status.state == .paused, "\(label)")
                } else if reasons.isEmpty {
                    #expect(status.state == .running, "\(label)")
                } else {
                    #expect(status.state == .suspended(reasons), "\(label)")
                }
                // Frames only when running.
                #expect(status.isFrameDriverRunning == (status.state == .running), "\(label)")
                // Never cover a full-screen app, never draw while locked/asleep or without screens.
                if reasons.contains(where: \.hidesOverlay) || intent.isHidden {
                    #expect(!status.isOverlayVisible, "\(label)")
                } else {
                    #expect(status.isOverlayVisible, "\(label)")
                }
                // Monitor only while visible, not occluded and without frames; never alongside the frame driver.
                #expect(
                    status.isIdleCursorMonitorNeeded
                        == (status.isOverlayVisible && !status.isFrameDriverRunning
                            && !reasons.contains(.overlayOccluded)),
                    "\(label)")
                #expect(!(status.isIdleCursorMonitorNeeded && status.isFrameDriverRunning), "\(label)")
            }
        }
    }

    @Test func pausedPetDisappearsInAFullScreenSpaceAndStaysPaused() {
        let status = RunStatus.resolve(intent: UserIntent(isPaused: true), reasons: [.fullScreenSpace])
        #expect(status.state == .paused)
        #expect(!status.isOverlayVisible)
        #expect(!status.isIdleCursorMonitorNeeded)
    }

    @Test func occlusionStopsFramesButKeepsTheOverlayOrderedIn() {
        let status = RunStatus.resolve(intent: UserIntent(), reasons: [.overlayOccluded])
        #expect(status.state == .suspended([.overlayOccluded]))
        #expect(status.isOverlayVisible)
        #expect(!status.isFrameDriverRunning)
    }
}
