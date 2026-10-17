import AppKit

/// Owns the composition root for the app's lifetime and forwards lifecycle events to it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Exists before launch finishes so the menu scene can bind to it.
    let model = AppModel()
    private var container: AppContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = AppContainer(model: model)
        container.start()
        self.container = container
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.stop()
        container = nil
    }
}
