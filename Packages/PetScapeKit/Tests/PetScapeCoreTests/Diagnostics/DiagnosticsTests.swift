import Testing

@testable import PetScapeCore

@Suite("Diagnostics smoke tests")
struct DiagnosticsTests {
    @Test func subsystemIsTheBundleIdentifierOrTheDefault() {
        #expect(!Log.subsystem.isEmpty)
        #expect(Log.defaultSubsystem == "io.github.danielcbdev.petscape")
    }

    /// Category names are used in `log stream` predicates (docs/development/debugging.md).
    @Test func categoryNamesMatchTheConventions() {
        let expected = [
            "app", "overlay", "rendering", "animation", "assets", "simulation", "behavior", "physics",
            "surfaces", "dock", "windowTracking", "permissions", "performance",
        ]
        #expect(Log.Category.allCases.map(\.rawValue) == expected)
    }

    @Test func measureReturnsTheBodyResult() {
        let result = Signposts.measure(Signposts.Interval.frame) { 6 * 7 }
        #expect(result == 42)
    }

    @Test func measureRethrowsTheBodyError() {
        struct SampleError: Error {}
        #expect(throws: SampleError.self) {
            try Signposts.measure(Signposts.Interval.characterLoad) { throw SampleError() }
        }
    }

    @Test func eventsCanBeEmitted() {
        Signposts.event(Signposts.Event.runStateChanged)
    }
}
