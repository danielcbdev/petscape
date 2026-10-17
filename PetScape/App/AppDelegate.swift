import AppKit

/// Owns the composition root for the app's lifetime and forwards lifecycle events to it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Created with the delegate (no side effects) so the menu can reach its models from the first render.
    let container = AppContainer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        container.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container.stop()
    }
}
