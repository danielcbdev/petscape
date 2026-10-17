import AppKit

/// Owns the composition root for the app's lifetime and forwards lifecycle events to it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Both exist before launch finishes so the menu scene can bind to them from the first render;
    /// neither initializer has side effects (windows, observers and loading start in `start()`).
    let model: AppModel
    let container: AppContainer

    override init() {
        let model = AppModel()
        self.model = model
        container = AppContainer(model: model)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        container.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container.stop()
    }
}
