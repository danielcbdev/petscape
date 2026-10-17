import AppKit
import SwiftUI

/// Items of the menu bar menu (FR-02 grows this list in M5).
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
