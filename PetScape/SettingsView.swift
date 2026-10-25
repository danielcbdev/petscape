import AppKit
import PetScapeCore
import PetScapePlatform
import PetScapeRuntime
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsSection: String, CaseIterable, Identifiable {
    case pets
    case behavior
    case appearance
    case interaction
    case general

    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .pets: "Pets"
        case .behavior: "Behavior"
        case .appearance: "Appearance"
        case .interaction: "Interaction"
        case .general: "General"
        }
    }

    var symbol: String {
        switch self {
        case .pets: "pawprint.fill"
        case .behavior: "waveform.path"
        case .appearance: "paintbrush.pointed"
        case .interaction: "cursorarrow.rays"
        case .general: "gearshape"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .pets: "Choose which characters live on your desktop."
        case .behavior: "Tune autonomous activities and music detection."
        case .appearance: "Adjust pet size, pace, and Dock placement."
        case .interaction: "Choose how pets respond to the cursor and windows."
        case .general: "Control app state, login, language guidance, and defaults."
        }
    }
}

/// Native controls forward intents; the observable models own updates, runtime state, and errors.
struct SettingsView: View {
    let model: SettingsModel
    @State private var selectedSection: SettingsSection? = .pets
    @State private var isPackImporterPresented = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label(section.title, systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedSection == section ? Color.accentColor.opacity(0.18) : Color.clear
                    )
                    .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
                    .accessibilityIdentifier("settings.navigation.\(section.id)")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
            .frame(minWidth: 175)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    pageHeading
                    switch selectedSection ?? .pets {
                    case .pets: petsPage
                    case .behavior: behaviorPage
                    case .appearance: appearancePage
                    case .interaction: interactionPage
                    case .general: generalPage
                    }
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 590, maxHeight: .infinity)
        }
        .frame(minWidth: 790, minHeight: 570)
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
        .fileImporter(
            isPresented: $isPackImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first, let roster = model.characterRoster else { return }
                Task { @MainActor in
                    let startedAccess = url.startAccessingSecurityScopedResource()
                    defer { if startedAccess { url.stopAccessingSecurityScopedResource() } }
                    await roster.installPack(from: url)
                }
            case .failure(let error):
                let nsError = error as NSError
                if nsError.code != NSUserCancelledError {
                    model.characterRoster?.reportImportPickerFailure()
                }
            }
        }
    }

    private var pageHeading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text((selectedSection ?? .pets).title)
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text((selectedSection ?? .pets).subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder private var petsPage: some View {
        if let roster = model.characterRoster {
            settingsCard("Active pets") {
                HStack(alignment: .center) {
                    Text("Pets currently on your desktop")
                        .font(.headline)
                    Spacer(minLength: 12)
                    addCharacterMenu(roster)
                }

                if roster.isLoading {
                    ProgressView("Loading characters…")
                        .accessibilityIdentifier("settings.characterLoading")
                } else if roster.activeCharacters.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No pets are active", systemImage: "pawprint")
                            .font(.headline)
                            .accessibilityIdentifier("settings.emptyRoster")
                        Text("Add a character from the catalog below, or install a local character pack.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 5)
                } else {
                    VStack(spacing: 12) {
                        ForEach(roster.activeCharacters) { pet in
                            activePetRow(pet, roster: roster)
                            if pet.petID != roster.activeCharacters.last?.petID {
                                Divider().padding(.top, 1)
                            }
                        }
                    }
                }
            }

            settingsCard("Character catalog") {
                if roster.characters.isEmpty, !roster.isLoading {
                    Text("No characters are available.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.noCharacters")
                } else {
                    ForEach(roster.characters) { character in
                        catalogRow(character, roster: roster)
                    }
                }

                if roster.unavailableCount > 0 {
                    Text("Some character packs are unavailable because their files are invalid.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let issue = roster.issue {
                    rosterIssueText(issue)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("settings.characterError")
                }
            }

            settingsCard("Install a character pack") {
                Button("Install Character Pack…") { isPackImporterPresented = true }
                    .disabled(roster.isImportDisabled)
                    .accessibilityIdentifier("settings.installCharacterPack")
                Text("Choose a folder containing character.json and its referenced PNG files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if roster.isInstalling {
                    ProgressView("Installing character pack…")
                        .accessibilityIdentifier("settings.characterPackInstalling")
                }
                if roster.installationSucceeded {
                    Text("Character pack installed. Add it from the catalog to use it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.characterPackInstalled")
                }
                if let issue = roster.installIssue {
                    characterPackImportIssueText(issue)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(characterPackImportIssueLabel(issue))
                        .accessibilityIdentifier("settings.characterPackError")
                }
            }
        } else {
            ContentUnavailableView("No characters are available.", systemImage: "pawprint")
        }
    }

    private func activePetRow(_ pet: CharacterRosterEntry, roster: CharacterRosterModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: pet.character.displayName)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.activeCharacter.\(pet.character.id.rawValue)")
                    characterOriginLabel(pet.character.origin)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.characterOrigin.\(pet.character.id.rawValue)")
                }
                Spacer(minLength: 8)
                Button("Dance") { model.dance(pet.petID) }
                    .disabled(!roster.canDance(pet.petID))
                    .help("Dance for 5–30 seconds. Requires an active pet with autonomous activities enabled.")
                    .accessibilityIdentifier("settings.dance.\(pet.character.id.rawValue)")
                Button("Stop Dance") { model.stopDance(pet.petID) }
                    .disabled(!roster.canStopDance(pet.petID))
                    .accessibilityIdentifier("settings.stopDance.\(pet.character.id.rawValue)")
                Button("Remove", role: .destructive) { roster.remove(pet.petID) }
                    .accessibilityIdentifier("settings.removeCharacter.\(pet.character.id.rawValue)")
            }
            if roster.isSpecialArtworkPending(pet.petID) {
                Text("Dance and cleanup artwork is pending. Your pet holds a still pose during these activities.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.activePetRow.\(pet.character.id.rawValue)")
    }

    private func catalogRow(_ character: CharacterCatalogEntry, roster: CharacterRosterModel) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: character.displayName)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                characterOriginLabel(character.origin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if roster.isAdding(character.id) {
                ProgressView("Adding…")
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.addingCharacter.\(character.id.rawValue)")
            } else if roster.isActive(character.id) {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.characterActive.\(character.id.rawValue)")
            } else {
                Button("Add") {
                    Task { await roster.add(character.id) }
                }
                .disabled(!roster.canAdd(character.id))
                .accessibilityIdentifier("settings.addCharacter.\(character.id.rawValue)")
            }
        }
        .padding(.vertical, 4)
    }

    private func addCharacterMenu(_ roster: CharacterRosterModel) -> some View {
        Menu {
            ForEach(roster.characters) { character in
                if roster.isActive(character.id) {
                    Label("\(character.displayName) — Active", systemImage: "checkmark")
                        .disabled(true)
                } else {
                    Button {
                        Task { await roster.add(character.id) }
                    } label: {
                        Label {
                            Text(verbatim: character.displayName)
                        } icon: {
                            Image(systemName: character.origin == .bundled ? "shippingbox" : "externaldrive")
                        }
                    }
                    .disabled(!roster.canAdd(character.id))
                }
            }
        } label: {
            Label("Add Character", systemImage: "plus")
        }
        .disabled(roster.isLoading || roster.characters.isEmpty)
        .accessibilityIdentifier("settings.addCharacter")
    }

    private var behaviorPage: some View {
        Group {
            settingsCard("Autonomous activities") {
                settingToggle("Autonomous activities", identifier: "settings.autonomy") {
                    model.petSettings.behavior.isEnabled
                } set: {
                    model.setAutonomyEnabled($0)
                }
                settingToggle("Jumping", identifier: "settings.jumping") {
                    model.petSettings.behavior.jumpsEnabled
                } set: {
                    model.setJumpsEnabled($0)
                }
                settingToggle("Resting", identifier: "settings.resting") {
                    model.petSettings.behavior.restEnabled
                } set: {
                    model.setRestEnabled($0)
                }
                settingToggle("Expressions", identifier: "settings.expressions") {
                    model.petSettings.behavior.expressionsEnabled
                } set: {
                    model.setExpressionsEnabled($0)
                }
            }
            settingsCard("Dance to music") {
                Toggle(
                    "Dance to music",
                    isOn: Binding(get: { model.isMusicDancingEnabled }, set: { model.setMusicDancingEnabled($0) })
                )
                .accessibilityIdentifier("settings.musicDancing")
                .accessibilityLabel("Dance to music")
                Text(
                    "Optional system audio access detects music from your Mac, including headphones. Audio is analyzed on this Mac, never saved or sent. Requires macOS 14.2 or later. Manual dance needs no audio access."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                musicStatus
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.musicStatus")
                if model.isMusicDancingEnabled {
                    Button("Restart Music Detection", action: model.retryMusicDetection)
                        .disabled(model.characterRoster?.canStopDanceAny == true)
                        .accessibilityIdentifier("settings.retryMusicDetection")
                }
            }
        }
    }

    private var appearancePage: some View {
        Group {
            settingsCard("Pet appearance") {
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
            }
            settingsCard("Dock placement") {
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
                .accessibilityIdentifier("settings.dockOffset")
                Text("Adjust the paws if they appear above or below the Dock.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var interactionPage: some View {
        settingsCard("Interaction") {
            Toggle(
                "Interact with windows",
                isOn: Binding(get: { model.isWindowInteractionEnabled }, set: { model.setWindowInteractionEnabled($0) })
            )
            .accessibilityIdentifier("settings.windowInteraction")
            .accessibilityLabel("Interact with windows")
            Text(
                "PetScape reads window positions so pets can walk on them. It never moves, clicks, closes, resizes, or activates windows, and never reads window titles or contents. Accessibility access is optional."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("settings.windowInteractionExplanation")
            if model.isWindowPermissionMissing {
                Text("Window interaction paused — permission missing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.windowPermissionStatus")
            }
            Divider()
            settingToggle("React to cursor", identifier: "settings.cursorReactions") {
                model.petSettings.interaction.cursorReactionsEnabled
            } set: {
                model.setCursorReactionsEnabled($0)
            }
            settingToggle("Allow click and drag", identifier: "settings.directInteraction") {
                model.petSettings.interaction.directInteractionEnabled
            } set: {
                model.setDirectInteractionEnabled($0)
            }
            Text(
                "Click to get your pet's attention. Drag to pick it up. Pause stops interactions. Optional reactions follow system Reduce Motion."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var generalPage: some View {
        Group {
            settingsCard("App state") {
                Toggle("Pause", isOn: Binding(get: { model.userIntent.isPaused }, set: { model.setPaused($0) }))
                    .accessibilityLabel("Pause")
                    .accessibilityIdentifier("settings.pause")
                Toggle("Hide Pet", isOn: Binding(get: { model.userIntent.isHidden }, set: { model.setHidden($0) }))
                    .accessibilityLabel("Hide Pet")
                    .accessibilityIdentifier("settings.hidePet")
                Button("Wake Pet", action: model.wakePet)
                    .accessibilityIdentifier("settings.wakePet")
            }
            settingsCard("Launch at login") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(get: { model.isLaunchAtLoginEnabled }, set: { model.setLaunchAtLogin($0) })
                )
                .accessibilityIdentifier("settings.login")
                .accessibilityLabel("Launch at login")
                loginStatus
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = model.loginError {
                    loginErrorText(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.loginError")
                }
            }
            settingsCard("Language") {
                Text(
                    "The interface follows your Mac’s preferred languages. Restart PetScape if a language change is not reflected."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            settingsCard("Restore defaults") {
                Text("Reset app settings and turn off optional interaction and music detection.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Restore Defaults", action: model.restoreDefaults)
            }
        }
    }

    private var musicStatus: some View {
        Group {
            switch model.musicStatus {
            case .off: Text("Music detection is off.")
            case .suspended:
                Text("Music detection is paused while your pet is unavailable or autonomous activities are off.")
            case .monitoring:
                Text(
                    "System audio capture started. If no pet dances while music plays, check PetScape's System Audio Recording access in Privacy & Security, then restart music detection. After a pause, music must stop and start again."
                )
            case .unavailable:
                Text(
                    "Music detection stopped. Check PetScape under System Audio Recording in Privacy & Security and your output device, then restart music detection. Manual dance remains available."
                )
            }
        }
    }

    private var loginStatus: some View {
        Group {
            switch model.loginStatus {
            case .enabled: Text("Enabled")
            case .disabled: Text("Disabled")
            case .requiresApproval: Text("Approval required in System Settings › General › Login Items.")
            case .notFound: Text("Unavailable. Run PetScape from its installed application to try again.")
            }
        }
    }

    private func settingsCard<Content: View>(
        _ title: LocalizedStringKey, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func settingToggle(
        _ title: LocalizedStringKey,
        identifier: String,
        get: @escaping @MainActor @Sendable () -> Bool,
        set: @escaping @MainActor @Sendable (Bool) -> Void
    ) -> some View {
        // Swift 6.2 can crash emitting the isolated Bool reabstraction thunk for direct function values.
        Toggle(title, isOn: Binding(get: { get() }, set: { set($0) }))
            .accessibilityLabel(Text(title))
            .accessibilityIdentifier(identifier)
    }

    private func characterOriginLabel(_ origin: CharacterPackOrigin) -> Text {
        switch origin {
        case .bundled: Text("Included")
        case .installed: Text("Installed")
        }
    }

    @ViewBuilder private func rosterIssueText(_ issue: CharacterRosterIssue) -> some View {
        switch issue {
        case .noBundledCharacters: Text("No bundled characters could be loaded.")
        case .noCharactersAvailable: Text("No characters could be loaded.")
        case .characterCouldNotLoad: Text("This character could not be loaded. Your active pets are unchanged.")
        case .characterAlreadyActive: Text("This character is already active.")
        }
    }

    @ViewBuilder private func characterPackImportIssueText(_ issue: CharacterPackImportError) -> some View {
        switch issue {
        case .cancelled: EmptyView()
        case .invalidPack:
            Text("This character pack is invalid. Choose a folder with a valid manifest and every referenced PNG.")
        case .unsafePack:
            Text("This character pack contains an unsafe path, alias, link, or unsupported file.")
        case .resourceLimit:
            Text("This character pack exceeds PetScape’s supported file or image limits.")
        case .duplicateBundledID:
            Text("This pack ID is already used by a character included with PetScape. Choose a different ID.")
        case .duplicateInstalledID:
            Text("A character with this ID is already installed. PetScape never overwrites installed packs.")
        case .storageUnavailable:
            Text("PetScape cannot access its character storage. Check that Application Support is writable.")
        case .installationFailed:
            Text("PetScape could not install this pack. Your active pets and installed packs are unchanged.")
        }
    }

    private func characterPackImportIssueLabel(_ issue: CharacterPackImportError) -> Text {
        switch issue {
        case .cancelled: Text("Import cancelled.")
        case .invalidPack:
            Text("This character pack is invalid. Choose a folder with a valid manifest and every referenced PNG.")
        case .unsafePack:
            Text("This character pack contains an unsafe path, alias, link, or unsupported file.")
        case .resourceLimit:
            Text("This character pack exceeds PetScape’s supported file or image limits.")
        case .duplicateBundledID:
            Text("This pack ID is already used by a character included with PetScape. Choose a different ID.")
        case .duplicateInstalledID:
            Text("A character with this ID is already installed. PetScape never overwrites installed packs.")
        case .storageUnavailable:
            Text("PetScape cannot access its character storage. Check that Application Support is writable.")
        case .installationFailed:
            Text("PetScape could not install this pack. Your active pets and installed packs are unchanged.")
        }
    }

    @ViewBuilder private func loginErrorText(_ error: LaunchAtLoginError) -> some View {
        switch error {
        case .registrationFailed: Text("Could not enable launch at login. Check System Settings and try again.")
        case .unregistrationFailed: Text("Could not disable launch at login. Check System Settings and try again.")
        }
    }
}
