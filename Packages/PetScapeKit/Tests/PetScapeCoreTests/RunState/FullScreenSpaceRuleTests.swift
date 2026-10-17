import Testing

@testable import PetScapeCore

@Suite("FullScreenSpaceRule")
struct FullScreenSpaceRuleTests {
    static let dockLevel = 20

    /// Window lists shaped like the PoC S5 snapshots (owner names and layers only).
    static let desktop = [
        WindowListEntry(ownerName: "Window Server", layer: 25),
        WindowListEntry(ownerName: "Dock", layer: 20),
        WindowListEntry(ownerName: "Finder", layer: 0),
        WindowListEntry(ownerName: "PetScape", layer: 19),
    ]
    static let fullScreenSpace = [
        WindowListEntry(ownerName: "Window Server", layer: 25),
        WindowListEntry(ownerName: "Safari", layer: 0),
        WindowListEntry(ownerName: "PetScape", layer: 19),
    ]

    @Test func dockWindowAtTheDockLevelMeansPresent() {
        #expect(FullScreenSpaceRule.reading(of: Self.desktop, dockLevel: Self.dockLevel) == .present)
    }

    @Test func noDockWindowMeansAbsent() {
        #expect(FullScreenSpaceRule.reading(of: Self.fullScreenSpace, dockLevel: Self.dockLevel) == .absent)
    }

    @Test func dockWindowsAtOtherLevelsDoNotCount() {
        // The Dock also owns windows at other layers (e.g. Mission Control, Launchpad); only layer 20 counts.
        let windows = Self.fullScreenSpace + [WindowListEntry(ownerName: "Dock", layer: 18)]
        #expect(FullScreenSpaceRule.reading(of: windows, dockLevel: Self.dockLevel) == .absent)
    }

    @Test func otherOwnersAtTheDockLevelDoNotCount() {
        let windows = Self.fullScreenSpace + [WindowListEntry(ownerName: "Docker", layer: 20)]
        #expect(FullScreenSpaceRule.reading(of: windows, dockLevel: Self.dockLevel) == .absent)
    }

    @Test func missingOrEmptyListIsUnavailable() {
        #expect(FullScreenSpaceRule.reading(of: nil, dockLevel: Self.dockLevel) == .unavailable)
        #expect(FullScreenSpaceRule.reading(of: [], dockLevel: Self.dockLevel) == .unavailable)
    }

    @Test(
        arguments: [
            (DockWindowReading.present, DockWindowReading.present, SpaceKind?.some(.desktop)),
            (.absent, .absent, .fullScreen),
            // A read during the transition can be stale: disagreement keeps the current decision.
            (.present, .absent, nil),
            (.absent, .present, nil),
            // Unavailable is never evidence (would otherwise hide the pet for good, or cover a full-screen app).
            (.unavailable, .unavailable, nil),
            (.unavailable, .absent, nil),
            (.absent, .unavailable, nil),
            (.present, .unavailable, nil),
            (.unavailable, .present, nil),
        ])
    func twoReadsDecide(first: DockWindowReading, second: DockWindowReading, expected: SpaceKind?) {
        #expect(FullScreenSpaceRule.spaceKind(first: first, second: second) == expected)
    }

    @Test func timingMatchesThePoC() {
        #expect(FullScreenSpaceRule.Timing.settleDelay == .milliseconds(600))
        #expect(FullScreenSpaceRule.Timing.confirmationDelay == .milliseconds(400))
    }
}
