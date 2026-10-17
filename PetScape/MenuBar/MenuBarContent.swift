import AppKit
import SwiftUI

/// Items of the menu bar menu (FR-02 grows this list in M5).
struct MenuBarContent: View {
    #if DEBUG
        let debugModel: DebugOverlayModel
    #endif

    var body: some View {
        #if DEBUG
            DebugMenu(model: debugModel)
            Divider()
        #endif
        Button("Quit PetScape") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
