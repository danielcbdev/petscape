import AppKit
import PetScapePlatform
import PetScapeRuntime
import SwiftUI

/// Native controls forward intents; the observable model owns all updates and error handling.
struct SettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section("Pet") {
                Slider(value: Binding(get: { model.petSettings.scale }, set: model.setScale), in: 0.5...1.5) {
                    Text("Size")
                } minimumValueLabel: {
                    Text("Small")
                } maximumValueLabel: {
                    Text("Large")
                }
                .accessibilityIdentifier("settings.scale")
                Slider(value: Binding(get: { model.petSettings.speed }, set: model.setSpeed), in: 0.5...2) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text("Slow")
                } maximumValueLabel: {
                    Text("Fast")
                }
                .accessibilityIdentifier("settings.speed")
                Toggle("Pause", isOn: Binding(get: { model.userIntent.isPaused }, set: model.setPaused))
                Toggle("Hide Pet", isOn: Binding(get: { model.userIntent.isHidden }, set: model.setHidden))
                Button("Wake Pet", action: model.wakePet)
            }
            Section("Activities") {
                Toggle(
                    "Autonomous activities",
                    isOn: Binding(
                        get: { model.petSettings.behavior.isEnabled }, set: model.setAutonomyEnabled)
                )
                .accessibilityIdentifier("settings.autonomy")
                Toggle(
                    "Jumping",
                    isOn: Binding(
                        get: { model.petSettings.behavior.jumpsEnabled }, set: model.setJumpsEnabled))
                Toggle(
                    "Resting",
                    isOn: Binding(
                        get: { model.petSettings.behavior.restEnabled }, set: model.setRestEnabled))
                Toggle(
                    "Expressions",
                    isOn: Binding(
                        get: { model.petSettings.behavior.expressionsEnabled }, set: model.setExpressionsEnabled))
            }
            Section("General") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.isLaunchAtLoginEnabled }, set: model.setLaunchAtLogin)
                )
                .accessibilityIdentifier("settings.login")
                loginStatus
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = model.loginError {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("settings.loginError")
                }
            }
            Section("Interaction") {
                Toggle(
                    "Interact with windows",
                    isOn: Binding(get: { model.isWindowInteractionEnabled }, set: model.setWindowInteractionEnabled)
                )
                .accessibilityIdentifier("settings.windowInteraction")
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
                Toggle(
                    "Allow click and drag",
                    isOn: Binding(
                        get: { model.petSettings.interaction.directInteractionEnabled },
                        set: model.setDirectInteractionEnabled)
                )
                .accessibilityIdentifier("settings.directInteraction")
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
                Text("Adjust the paws if they appear above or below the Dock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Restore Defaults", action: model.restoreDefaults)
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .frame(maxHeight: 720, alignment: .top)
        .onAppear {
            model.refreshLoginStatus()
            model.refreshWindowPermissionStatus()
            NSApplication.shared.activate(ignoringOtherApps: true)
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

    @ViewBuilder private var loginStatus: some View {
        switch model.loginStatus {
        case .enabled: Text("Enabled")
        case .disabled: Text("Disabled")
        case .requiresApproval: Text("Approval required in System Settings › General › Login Items.")
        case .notFound: Text("Unavailable. Run PetScape from its installed application to try again.")
        }
    }
}
