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
    static let defaultCharacterID = "cat"

    private let model: AppModel
    private let runtime: PetRuntime
    private let characterLoader = CharacterLoader()
    private var loadTask: Task<Void, Never>?
    private(set) var character: LoadedCharacter?
    #if DEBUG
        let debugModel: DebugOverlayModel
        private var animationPreview: AnimationPreviewController?
        private var opensPreviewWhenLoaded = false
    #endif

    init(model: AppModel) {
        self.model = model
        runtime = PetRuntime(
            screenProvider: ScreenProvider(),
            cursorSampler: CursorSampler(),
            systemEvents: SystemEventsMonitor(),
            fullScreenDetector: FullScreenSpaceDetector(),
            preferences: UserDefaultsPreferencesStore())
        #if DEBUG
            debugModel = DebugOverlayModel(runtime: runtime)
        #endif
    }

    func start() {
        Log.app.notice("PetScape started")
        runtime.start()
        let runtime = runtime
        model.bind(
            isPaused: runtime.userIntent.isPaused, isHidden: runtime.userIntent.isHidden,
            setPaused: { runtime.setPaused($0) }, setHidden: { runtime.setHidden($0) })
        #if DEBUG
            model.openAnimationPreviewAction = { [weak self] in self?.openAnimationPreview() }
            opensPreviewWhenLoaded = LaunchOptions.opensAnimationPreview
        #endif
        let loader = characterLoader
        let packURL = Self.characterPackURL()
        loadTask = Task { [weak self] in
            let character = await loader.load(packURL: packURL)
            self?.characterDidLoad(character)
        }
    }

    /// Tears everything down before the process exits (FR-13: observers removed, windows closed).
    func stop() {
        loadTask?.cancel()
        loadTask = nil
        #if DEBUG
            animationPreview?.close()
            animationPreview = nil
        #endif
        runtime.stop()
        Log.app.notice("PetScape stopped")
    }

    private func characterDidLoad(_ character: LoadedCharacter) {
        self.character = character
        runtime.show(character)
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

    private static func characterPackURL() -> URL {
        #if DEBUG
            if let override = LaunchOptions.characterPackPath {
                return URL(fileURLWithPath: override, isDirectory: true)
            }
        #endif
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        return resources.appending(path: charactersFolder).appending(path: defaultCharacterID)
    }

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
