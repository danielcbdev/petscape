import AppKit

/// Owns the composition root for the app's lifetime and forwards lifecycle events to it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = AppContainer()
        container.start()
        self.container = container
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.stop()
        container = nil
    }
}
