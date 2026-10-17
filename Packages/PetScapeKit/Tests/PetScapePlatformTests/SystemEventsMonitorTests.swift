import AppKit
import Testing

@testable import PetScapeCore
@testable import PetScapePlatform

/// Waits (polling the main actor) until `condition` holds or `timeout` passes; notifications observed on
/// `.main` may be delivered asynchronously.
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition(), clock.now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
}

@Suite("SystemEventsMonitor")
struct SystemEventsMonitorTests {
    struct Event: Equatable {
        var reason: SuspensionReason
        var isActive: Bool
    }

    @Test func everyMappedNotificationReportsItsReason() async {
        let workspace = NotificationCenter()
        let distributed = NotificationCenter()
        let monitor = SystemEventsMonitor(workspaceCenter: workspace, distributedCenter: distributed)
        var events: [Event] = []
        monitor.start { events.append(Event(reason: $0, isActive: $1)) }

        let all =
            SystemEventsMonitor.workspaceMappings.map { (workspace, $0) }
            + SystemEventsMonitor.lockMappings.map { (distributed, $0) }
        for (center, mapping) in all { center.post(name: mapping.name, object: nil) }
        await waitUntil { events.count == all.count }

        #expect(events == all.map { Event(reason: $0.1.reason, isActive: $0.1.isActive) })
        monitor.stop()
    }

    @Test func mappingsCoverEveryReasonOnAndOff() {
        let mappings = SystemEventsMonitor.workspaceMappings + SystemEventsMonitor.lockMappings
        for reason in [SuspensionReason.systemSleep, .displaySleep, .sessionInactive, .screenLocked] {
            #expect(mappings.contains { $0.reason == reason && $0.isActive })
            #expect(mappings.contains { $0.reason == reason && !$0.isActive })
        }
    }

    @Test func stopRemovesObservers() async {
        let workspace = NotificationCenter()
        let monitor = SystemEventsMonitor(workspaceCenter: workspace, distributedCenter: NotificationCenter())
        var count = 0
        monitor.start { _, _ in count += 1 }
        #expect(monitor.isStarted)
        monitor.stop()
        #expect(!monitor.isStarted)
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(count == 0)
    }
}
