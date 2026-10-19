import SwiftUI

/// SwiftUI entry point. Menu bar only (`LSUIElement`), no main window (FR-01).
@main
struct PetScapeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("PetScape", systemImage: "pawprint") {
            #if DEBUG
                MenuBarContent(model: appDelegate.model, debugModel: appDelegate.container.debugModel)
            #else
                MenuBarContent(model: appDelegate.model)
            #endif
        }
        Settings {
            SettingsView(model: appDelegate.container.settingsModel)
        }
    }
}
