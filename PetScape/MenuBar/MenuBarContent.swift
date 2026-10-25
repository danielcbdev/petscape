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
            switch status {
            case .degraded: Text("Some pet animations could not be loaded.")
            case .placeholder: Text("The pet could not be loaded. Showing a placeholder.")
            }
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
        if let roster = model.settings?.characterRoster {
            Menu("Dance") {
                ForEach(roster.activeCharacters) { pet in
                    Button {
                        roster.dance(pet.petID)
                    } label: {
                        Text(verbatim: pet.character.displayName)
                    }
                    .disabled(!roster.canDance(pet.petID))
                }
            }
            .disabled(!roster.canDanceAny)
            .help("Dance for 5–30 seconds. Requires an active pet with autonomous activities enabled.")
            Menu("Stop Dance") {
                ForEach(roster.activeCharacters) { pet in
                    Button {
                        roster.stopDance(pet.petID)
                    } label: {
                        Text(verbatim: pet.character.displayName)
                    }
                    .disabled(!roster.canStopDance(pet.petID))
                }
            }
            .disabled(!roster.canStopDanceAny)
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
