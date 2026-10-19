import AppKit
import SwiftUI

/// Items of the menu bar menu (FR-02): Show/Hide Pet, Pause/Resume, Quit; labels follow the current state.
struct MenuBarContent: View {
    let model: AppModel
    #if DEBUG
        let debugModel: DebugOverlayModel
    #endif

    var body: some View {
        if let status = model.characterStatus {
            Text(status)
            Divider()
        }
        Button {
            model.toggleHidden()
        } label: {
            if model.isHidden { Text("Show Pet") } else { Text("Hide Pet") }
        }
        Button {
            model.togglePaused()
        } label: {
            if model.isPaused { Text("Resume") } else { Text("Pause") }
        }
        Divider()
        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")
        Divider()
        #if DEBUG
            DebugMenu(model: debugModel)
            Button("Animation Preview") {
                model.openAnimationPreview()
            }
            Divider()
        #endif
        Button("Quit PetScape") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
