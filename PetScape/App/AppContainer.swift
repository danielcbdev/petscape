import AppKit
import Foundation
import PetScapeCore
import PetScapePlatform
import PetScapeRuntime

/// Composition root: creates and wires the long-lived objects (ADR-0002, conventions: no singletons).
/// Creating it has no side effects; windows, observers, monitors and the character load start in `start()`.
/// The pet runtime owns the overlay and the simulation; the loaded character is handed to it, and the menu's
/// pause/hide intents go to it through `AppModel`.
final class AppContainer {
    /// The bundled pack folder inside `Contents/Resources` (folder reference to `assets/characters`, T4.9).
    static let charactersFolder = "characters"

    private let model: AppModel
    private let runtime: PetRuntime
    let settingsModel: SettingsModel
    private var activationObserver: (any NSObjectProtocol)?
    private let characterSelection: CharacterSelectionModel
    private var loadTask: Task<Void, Never>?
    private(set) var character: LoadedCharacter?
    #if DEBUG
        let debugModel: DebugOverlayModel
        private var animationPreview: AnimationPreviewController?
        private var opensPreviewWhenLoaded = false
    #endif

    init(model: AppModel) {
        self.model = model
        let preferences = Self.makePreferences()
        let runtime = PetRuntime(
            screenProvider: ScreenProvider(),
            cursorSampler: CursorSampler(),
            systemEvents: SystemEventsMonitor(),
            fullScreenDetector: FullScreenSpaceDetector(),
            preferences: preferences)
        self.runtime = runtime
        runtime.onCharacterIssuesChange = { [weak model] issues in
            if issues.contains(where: { $0.severity == .error }) {
                model?.characterStatus = String(localized: "Some pet animations could not be loaded.")
            }
        }
        let selection = CharacterSelectionModel(preferences: preferences) { [weak runtime] character in
            guard let runtime else { return false }
            if character.isPlaceholder {
                runtime.show(character)
                return true
            }
            return runtime.replaceCharacter(character)
        }
        characterSelection = selection
        settingsModel = SettingsModel(
            runtime: runtime, preferences: preferences, loginService: Self.makeLoginService(),
            characterSelection: selection)
        runtime.onWindowPermissionRevoked = { [weak settingsModel] in settingsModel?.windowPermissionWasRevoked() }
        model.settings = settingsModel
        #if DEBUG
            debugModel = DebugOverlayModel(runtime: runtime, settings: settingsModel)
        #endif
        selection.onApplied = { [weak self] character in self?.characterDidLoad(character) }
    }

    func start() {
        Log.app.notice("PetScape started")
        runtime.start()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.settingsModel.refreshLoginStatus()
                self?.settingsModel.refreshWindowPermissionStatus()
            }
        }
        #if DEBUG
            model.openAnimationPreviewAction = { [weak self] in self?.openAnimationPreview() }
            opensPreviewWhenLoaded = LaunchOptions.opensAnimationPreview
        #endif
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let root = resources.appending(path: Self.charactersFolder)
        loadTask = Task { [weak self] in
            #if DEBUG
                if let path = LaunchOptions.characterPackPath {
                    let character = await CharacterLoader().load(packURL: URL(fileURLWithPath: path, isDirectory: true))
                    guard !Task.isCancelled, let self else { return }
                    self.characterSelection.stop()
                    self.runtime.show(character)
                    self.characterDidLoad(character)
                    return
                }
            #endif
            let catalog = await BundledCharacterCatalog.discover(in: root)
            guard !Task.isCancelled, let self else { return }
            await self.characterSelection.start(catalog: catalog)
        }
    }

    /// Tears everything down before the process exits (FR-13: observers removed, windows closed).
    func stop() {
        characterSelection.stop()
        loadTask?.cancel()
        loadTask = nil
        #if DEBUG
            animationPreview?.close()
            animationPreview = nil
        #endif
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        activationObserver = nil
        runtime.stop()
        Log.app.notice("PetScape stopped")
    }

    private func characterDidLoad(_ character: LoadedCharacter) {
        #if DEBUG
            animationPreview?.close()
            animationPreview = nil
        #endif
        self.character = character
        if character.isPlaceholder {
            model.characterStatus = String(localized: "The pet could not be loaded. Showing a placeholder.")
        } else if character.isDegraded {
            model.characterStatus = String(localized: "Some pet animations could not be loaded.")
        } else {
            model.characterStatus = nil
        }
        #if DEBUG
            if opensPreviewWhenLoaded {
                opensPreviewWhenLoaded = false
                openAnimationPreview()
            }
        #endif
    }

    private static func makePreferences() -> any PreferencesStore {
        #if DEBUG
            if let suite = LaunchOptions.settingsTestSuite {
                // A failed test-suite allocation stays in memory; never fall back to the owner's domain.
                guard let defaults = UserDefaults(suiteName: suite) else { return InMemoryPreferencesStore() }
                return UserDefaultsPreferencesStore(defaults: defaults)
            }
        #endif
        return UserDefaultsPreferencesStore()
    }

    private static func makeLoginService() -> any LaunchAtLoginService {
        #if DEBUG
            if LaunchOptions.settingsTestSuite != nil { return IsolatedLoginService() }
        #endif
        return SystemLaunchAtLoginService()
    }

    #if DEBUG
        /// UI-test isolation also covers OS login state, independent of the preferences suite.
        private final class IsolatedLoginService: LaunchAtLoginService {
            var status: LaunchAtLoginStatus = .enabled
            func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError) {
                status = enabled ? .enabled : .disabled
            }
        }
    #endif

    #if DEBUG
        private func openAnimationPreview() {
            guard let character else {
                opensPreviewWhenLoaded = true
                return
            }
            let preview = animationPreview ?? AnimationPreviewController(character: character)
            animationPreview = preview
            preview.show()
        }

        /// DEBUG-only launch arguments for manual checks (docs/development/debugging.md):
        /// `--animation-preview` opens the preview at launch; `--character-pack <folder>` loads another pack.
        private enum LaunchOptions {
            static var settingsTestSuite: String? {
                let arguments = ProcessInfo.processInfo.arguments
                guard let index = arguments.firstIndex(of: "--settings-test-suite"),
                    arguments.indices.contains(index + 1)
                else { return nil }
                let name = arguments[index + 1]
                let prefix = "PetScapeUITests."
                guard name.hasPrefix(prefix), UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
                else { return nil }
                return name
            }

            static var opensAnimationPreview: Bool {
                ProcessInfo.processInfo.arguments.contains("--animation-preview")
            }

            static var characterPackPath: String? {
                let arguments = ProcessInfo.processInfo.arguments
                guard let index = arguments.firstIndex(of: "--character-pack"), arguments.indices.contains(index + 1)
                else { return nil }
                return arguments[index + 1]
            }
        }
    #endif
}
