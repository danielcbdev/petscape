import AppKit
import SwiftUI

/// Items of the menu bar menu (FR-02 grows this list in M5).
struct MenuBarContent: View {
    var body: some View {
        Button("Quit PetScape") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
