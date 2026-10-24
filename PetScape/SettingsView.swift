import AppKit
import PetScapeCore
import PetScapePlatform
import PetScapeRuntime
import SwiftUI

/// Native controls forward intents; the observable model owns all updates and error handling.
struct SettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            if let selection = model.characterSelection {
                characterSection(selection)
            }
            Section("Pet") {
                Slider(value: Binding(get: { model.petSettings.scale }, set: model.setScale), in: 0.5...1.5) {
                    Text("Size")
                } minimumValueLabel: {
                    Text("Small")
                } maximumValueLabel: {
                    Text("Large")
                }
                .accessibilityIdentifier("settings.scale")
                .accessibilityLabel("Size")
                Slider(
                    value: Binding(get: { model.petSettings.speed }, set: model.setSpeed), in: PetSettings.speedRange
                ) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text("Slow")
                } maximumValueLabel: {
                    Text("Fast")
                }
                .accessibilityIdentifier("settings.speed")
                .accessibilityLabel("Speed")
                Toggle("Pause", isOn: Binding(get: { model.userIntent.isPaused }, set: model.setPaused))
                    .accessibilityLabel("Pause")
                Toggle("Hide Pet", isOn: Binding(get: { model.userIntent.isHidden }, set: model.setHidden))
                    .accessibilityLabel("Hide Pet")
                Button("Wake Pet", action: model.wakePet)
            }
            Section("Activities") {
                Toggle(
                    "Autonomous activities",
                    isOn: Binding(
                        get: { model.petSettings.behavior.isEnabled }, set: model.setAutonomyEnabled)
                )
                .accessibilityIdentifier("settings.autonomy")
                .accessibilityLabel("Autonomous activities")
                Toggle(
                    "Jumping",
                    isOn: Binding(
                        get: { model.petSettings.behavior.jumpsEnabled }, set: model.setJumpsEnabled)
                )
                .accessibilityLabel("Jumping")
                Toggle(
                    "Resting",
                    isOn: Binding(
                        get: { model.petSettings.behavior.restEnabled }, set: model.setRestEnabled)
                )
                .accessibilityLabel("Resting")
                Toggle(
                    "Expressions",
                    isOn: Binding(
                        get: { model.petSettings.behavior.expressionsEnabled }, set: model.setExpressionsEnabled)
                )
                .accessibilityLabel("Expressions")
            }
            Section("Music and dance") {
                HStack {
                    Button("Dance", action: model.dance)
                        .disabled(!model.canDance)
                        .accessibilityIdentifier("settings.dance")
                    Button("Stop Dance", action: model.stopDance)
                        .disabled(!model.canStopDance)
                        .accessibilityIdentifier("settings.stopDance")
                }
                if !model.canDance && !model.canStopDance {
                    Text(
                        "Enable autonomous activities, show and resume your pet, then wait until it is walking or idle."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Toggle(
                    "Dance to music",
                    isOn: Binding(
                        get: { model.isMusicDancingEnabled }, set: model.setMusicDancingEnabled)
                )
                .accessibilityIdentifier("settings.musicDancing")
                .accessibilityLabel("Dance to music")
                Text(
                    "Optional system audio access detects music from your Mac, including headphones. Audio is analyzed on this Mac, never saved or sent. Requires macOS 14.2 or later. Manual dance needs no audio access."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                musicStatus
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.musicStatus")
                if model.isSpecialArtworkPending {
                    Text("Dance and cleanup artwork is pending. Your pet holds a still pose during these activities.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("General") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.isLaunchAtLoginEnabled }, set: model.setLaunchAtLogin)
                )
                .accessibilityIdentifier("settings.login")
                .accessibilityLabel("Launch at login")
                loginStatus
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = model.loginError {
                    loginErrorText(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("settings.loginError")
                }
                Text(
                    "The interface follows your Mac’s preferred languages. Restart PetScape if a language change is not reflected."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section("Interaction") {
                Toggle(
                    "Interact with windows",
                    isOn: Binding(get: { model.isWindowInteractionEnabled }, set: model.setWindowInteractionEnabled)
                )
                .accessibilityIdentifier("settings.windowInteraction")
                .accessibilityLabel("Interact with windows")
                Text(
                    "PetScape reads window positions so pets can walk on them. It never moves, clicks, closes, resizes, or activates windows, and never reads window titles or contents. Accessibility access is optional."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.windowInteractionExplanation")
                if model.isWindowPermissionMissing {
                    Text("Window interaction paused — permission missing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.windowPermissionStatus")
                }
                Toggle(
                    "React to cursor",
                    isOn: Binding(
                        get: { model.petSettings.interaction.cursorReactionsEnabled },
                        set: model.setCursorReactionsEnabled)
                )
                .accessibilityIdentifier("settings.cursorReactions")
                .accessibilityLabel("React to cursor")
                Toggle(
                    "Allow click and drag",
                    isOn: Binding(
                        get: { model.petSettings.interaction.directInteractionEnabled },
                        set: model.setDirectInteractionEnabled)
                )
                .accessibilityIdentifier("settings.directInteraction")
                .accessibilityLabel("Allow click and drag")
                Text(
                    "Click to get your pet's attention. Drag to pick it up. Pause stops interactions. Optional reactions follow system Reduce Motion."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section("Advanced") {
                Slider(
                    value: Binding(get: { model.dockOffsetAdjustment }, set: model.setDockOffsetAdjustment),
                    in: -40...40, step: 1
                ) {
                    Text("Dock offset")
                } minimumValueLabel: {
                    Text("−40 pt")
                } maximumValueLabel: {
                    Text("+40 pt")
                }
                .accessibilityLabel("Dock offset")
                Text("Adjust the paws if they appear above or below the Dock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Restore Defaults", action: model.restoreDefaults)
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(maxHeight: 720, alignment: .top)
        .onAppear {
            model.refreshLoginStatus()
            model.refreshWindowPermissionStatus()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .confirmationDialog(
            "Allow music detection?",
            isPresented: Binding(
                get: { model.isMusicConsentPresented },
                set: { if !$0 { model.cancelMusicConsent() } }),
            titleVisibility: .visible
        ) {
            Button("Enable Music Detection") { model.confirmMusicConsent() }
            Button("Cancel", role: .cancel) { model.cancelMusicConsent() }
        } message: {
            Text(
                "PetScape will ask macOS for system audio recording access to recognize music locally. It does not use your microphone or capture your screen. No audio is saved or sent. You can turn this off at any time."
            )
        }
        .confirmationDialog(
            "Allow PetScape to use Accessibility?",
            isPresented: Binding(
                get: { model.isWindowPermissionConfirmationPresented },
                set: { if !$0 { model.cancelWindowPermissionRequest() } }),
            titleVisibility: .visible
        ) {
            Button("Open Accessibility Settings") { model.confirmWindowPermissionRequest() }
            Button("Cancel", role: .cancel) { model.cancelWindowPermissionRequest() }
        } message: {
            Text(
                "PetScape reads window positions so pets can walk on them. It does not move, click, close, resize, or activate windows, and does not read titles or contents. You can allow access in Privacy & Security › Accessibility."
            )
        }
    }

    private func characterSection(_ selection: CharacterSelectionModel) -> some View {
        Section("Character") {
            if selection.characters.count > 1, let activeID = selection.activeID {
                Picker(
                    "Character",
                    selection: Binding(
                        get: { selection.activeID ?? activeID },
                        set: { id in Task { await selection.select(id) } })
                ) {
                    ForEach(selection.characters) { character in
                        if character.id.rawValue == "cat" {
                            Text("Cat").tag(character.id)
                        } else {
                            Text(verbatim: character.displayName).tag(character.id)
                        }
                    }
                }
                .disabled(!selection.canSelect)
                .accessibilityIdentifier("settings.character")
                .accessibilityLabel("Character")
            } else if let name = selection.activeName {
                LabeledContent("Character") {
                    if selection.activeID?.rawValue == "cat" {
                        Text("Cat")
                    } else {
                        Text(verbatim: name)
                    }
                }
                .accessibilityIdentifier("settings.activeCharacter")
                Text("This is the only character included with this app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("This is the only character included with this app."))
                    .accessibilityIdentifier("settings.singleCharacter")
            } else if !selection.isLoading {
                Text("No bundled characters are available.")
                    .accessibilityLabel(Text("No bundled characters are available."))
                    .accessibilityIdentifier("settings.noCharacters")
            }
            if selection.isLoading {
                Text("Loading characters…")
                    .accessibilityIdentifier("settings.characterLoading")
            }
            if selection.unavailableCount > 0 {
                Text("Some included characters are unavailable because their files are invalid.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let issue = selection.issue {
                characterSelectionIssueText(issue)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel(characterSelectionIssueLabel(issue))
                    .accessibilityIdentifier("settings.characterError")
            }
        }
    }

    @ViewBuilder private func characterSelectionIssueText(_ issue: CharacterSelectionIssue) -> some View {
        switch issue {
        case .noBundledCharacters: Text("No bundled characters could be loaded.")
        case .characterCouldNotLoad: Text("This character could not be loaded. Your current pet is unchanged.")
        case .waitForSafeBoundary:
            Text("Wait until your pet is walking or idle with enough room, then try again.")
        }
    }

    private func characterSelectionIssueLabel(_ issue: CharacterSelectionIssue) -> Text {
        switch issue {
        case .noBundledCharacters: Text("No bundled characters could be loaded.")
        case .characterCouldNotLoad: Text("This character could not be loaded. Your current pet is unchanged.")
        case .waitForSafeBoundary: Text("Wait until your pet is walking or idle with enough room, then try again.")
        }
    }

    @ViewBuilder private func loginErrorText(_ error: LaunchAtLoginError) -> some View {
        switch error {
        case .registrationFailed: Text("Could not enable launch at login. Check System Settings and try again.")
        case .unregistrationFailed: Text("Could not disable launch at login. Check System Settings and try again.")
        }
    }

    @ViewBuilder private var musicStatus: some View {
        switch model.musicStatus {
        case .off: Text("Music detection is off.")
        case .suspended:
            Text("Music detection is paused while your pet is unavailable or autonomous activities are off.")
        case .monitoring:
            Text(
                "Waiting for music. If detection is silent, check PetScape's system audio access in Privacy & Security. After a pause, music must stop and start again."
            )
        case .unavailable:
            Text(
                "Music detection is unavailable. Check system audio access and your output device, then turn detection off and on to retry. Manual dance remains available."
            )
        }
    }

    @ViewBuilder private var loginStatus: some View {
        switch model.loginStatus {
        case .enabled: Text("Enabled")
        case .disabled: Text("Disabled")
        case .requiresApproval: Text("Approval required in System Settings › General › Login Items.")
        case .notFound: Text("Unavailable. Run PetScape from its installed application to try again.")
        }
    }
}
