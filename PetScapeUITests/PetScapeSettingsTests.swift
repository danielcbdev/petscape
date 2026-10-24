import XCTest

/// Uses an isolated preferences suite AND a fake login service; Restore Defaults never changes the owner.
final class PetScapeSettingsTests: XCTestCase {
    @MainActor
    private func setLanguage(_ preferredLanguages: String, for app: XCUIApplication) {
        var arguments = app.launchArguments
        while let index = arguments.firstIndex(of: "--preferred-languages") {
            let end = min(index + 2, arguments.count)
            arguments.removeSubrange(index..<end)
        }
        app.launchArguments = arguments + ["--preferred-languages", preferredLanguages]
    }

    @MainActor
    private func integerValue(of element: XCUIElement) -> Int? {
        if let number = element.value as? NSNumber { return number.intValue }
        if let string = element.value as? String { return Int(string) }
        return nil
    }

    /// Fixture packs live in a temporary directory that is passed to the DEBUG app. No shipping
    /// resources, original art or owner preferences are changed.
    @MainActor
    private func fixtureApplication(characterCount: Int) throws -> (app: XCUIApplication, root: URL, suite: String) {
        var products = Bundle(for: Self.self).bundleURL
        for _ in 0..<4 { products.deleteLastPathComponent() }
        let root = FileManager.default.temporaryDirectory.appending(path: "PetScapeUIFixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do {
            let characters = root.appending(path: "characters")
            let source = products.appending(path: "PetScape.app/Contents/Resources/characters/cat")
            let manifest = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: source.appending(path: "character.json")))
                    as? [String: Any])
            let animations = try XCTUnwrap(manifest["animations"] as? [String: [String: Any]])
            let frames = try XCTUnwrap(animations["walk"]?["frames"] as? [[String: Any]])
            let path = try XCTUnwrap(frames.first?["image"] as? String)
            let image = try Data(contentsOf: source.appending(path: path))
            try FileManager.default.createDirectory(at: characters, withIntermediateDirectories: true)
            for index in 0..<characterCount {
                let id = index == 0 ? "fixture-a" : "fixture-b"
                let folder = characters.appending(path: id)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let fixture: [String: Any] = [
                    "schemaVersion": 1, "id": id,
                    "displayName": index == 0 ? "Fixture A" : "Fixture B",
                    "canvas": try XCTUnwrap(manifest["canvas"]),
                    "displaySize": try XCTUnwrap(manifest["displaySize"]),
                    "anchor": try XCTUnwrap(manifest["anchor"]),
                    "defaultAnimation": "walk",
                    "animations": ["walk": ["fps": 8, "frames": [["image": "frame.png"]]]],
                ]
                try JSONSerialization.data(withJSONObject: fixture).write(to: folder.appending(path: "character.json"))
                try image.write(to: folder.appending(path: "frame.png"))
            }
            let suite = "PetScapeUITests.\(UUID().uuidString)"
            // Start paused and nonautonomous: initial attached Spawning is a safe character boundary.
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defaults.set(true, forKey: "petscape.isPaused")
            defaults.set(false, forKey: "petscape.autonomy")
            let app = XCUIApplication()
            app.launchArguments = ["--settings-test-suite", suite, "--characters-folder", characters.path]
            setLanguage("en", for: app)
            return (app, root, suite)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    @MainActor
    func testNoBundledCharactersShowsAnHonestAccessibleEmptyState() throws {
        let fixture = try fixtureApplication(characterCount: 0)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }
        fixture.app.launch()
        fixture.app.activate()
        fixture.app.typeKey(",", modifierFlags: .command)
        let window = fixture.app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["settings.noCharacters"].waitForExistence(timeout: 15))
        XCTAssertFalse(window.popUpButtons["settings.character"].exists)
        XCTAssertTrue(window.staticTexts["settings.characterError"].exists)
    }

    @MainActor
    func testBundledPickerHasAccessibleLabelKeyboardSelectionAndRestoresAfterRelaunch() throws {
        let fixture = try fixtureApplication(characterCount: 2)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }
        let app = fixture.app
        app.launch()
        app.activate()
        app.typeKey(",", modifierFlags: .command)
        let picker = app.windows.firstMatch.popUpButtons["settings.character"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        XCTAssertEqual(picker.label, "Character")
        XCTAssertEqual(picker.value as? String, "Fixture A")
        XCTAssertTrue(picker.isEnabled)
        picker.click()
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        let selected = NSPredicate(format: "value == %@", "Fixture B")
        expectation(for: selected, evaluatedWith: picker)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.windows.firstMatch.staticTexts["settings.characterError"].exists)
        app.terminate()
        app.launch()
        app.activate()
        app.typeKey(",", modifierFlags: .command)
        let restored = app.windows.firstMatch.popUpButtons["settings.character"]
        XCTAssertTrue(restored.waitForExistence(timeout: 15))
        XCTAssertEqual(restored.value as? String, "Fixture B")
    }

    @MainActor
    func testSettingsApplyRestoreCloseAndQuit() throws {
        let suiteName = "PetScapeUITests.\(UUID().uuidString)"
        let app = XCUIApplication()
        app.launchArguments = ["--settings-test-suite", suiteName]
        setLanguage("en", for: app)
        defer {
            if app.state != .notRunning { app.terminate() }
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        app.launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        // The same Settings title is exposed in the status menu and the system app menu.
        app.activate()
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let singleCharacter = window.staticTexts["settings.singleCharacter"]
        XCTAssertTrue(singleCharacter.waitForExistence(timeout: 15))
        XCTAssertEqual(singleCharacter.value as? String, "This is the only character included with this app.")
        XCTAssertTrue(window.descendants(matching: .any)["settings.activeCharacter"].exists)
        XCTAssertFalse(window.popUpButtons["settings.character"].exists)
        XCTAssertFalse(window.staticTexts["settings.characterError"].exists)
        let windowInteraction = window.switches["settings.windowInteraction"]
        XCTAssertTrue(windowInteraction.waitForExistence(timeout: 5))
        XCTAssertEqual(windowInteraction.label, "Interact with windows")
        XCTAssertEqual(integerValue(of: windowInteraction), 0)
        XCTAssertTrue(window.staticTexts["settings.windowInteractionExplanation"].exists)
        let autonomy = window.switches["settings.autonomy"]
        XCTAssertTrue(autonomy.waitForExistence(timeout: 5))
        XCTAssertEqual(autonomy.label, "Autonomous activities")
        XCTAssertEqual(integerValue(of: autonomy), 1)
        autonomy.click()
        XCTAssertEqual(integerValue(of: autonomy), 0)
        let dance = window.buttons["settings.dance"]
        XCTAssertTrue(dance.exists)
        XCTAssertFalse(dance.isEnabled)
        let stopDance = window.buttons["settings.stopDance"]
        XCTAssertTrue(stopDance.exists)
        XCTAssertFalse(stopDance.isEnabled)
        let music = window.switches["settings.musicDancing"]
        XCTAssertTrue(music.exists)
        XCTAssertEqual(integerValue(of: music), 0)
        music.click()
        let enableMusic = app.buttons["Enable Music Detection"]
        XCTAssertTrue(enableMusic.waitForExistence(timeout: 3))
        window.sheets.firstMatch.buttons["Cancel"].click()
        XCTAssertEqual(integerValue(of: music), 0)
        let cursor = window.switches["settings.cursorReactions"]
        XCTAssertTrue(cursor.waitForExistence(timeout: 3))
        XCTAssertEqual(integerValue(of: cursor), 1)
        cursor.click()
        XCTAssertEqual(integerValue(of: cursor), 0)
        let direct = window.switches["settings.directInteraction"]
        XCTAssertTrue(direct.waitForExistence(timeout: 3))
        XCTAssertEqual(integerValue(of: direct), 1)
        direct.click()
        XCTAssertEqual(integerValue(of: direct), 0)
        window.buttons["Restore Defaults"].click()
        XCTAssertEqual(integerValue(of: autonomy), 1)
        XCTAssertEqual(integerValue(of: cursor), 1)
        XCTAssertEqual(integerValue(of: direct), 1)
        XCTAssertEqual(integerValue(of: window.switches["settings.login"]), 0)
        window.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(window.exists)
        statusItem.click()
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

    @MainActor
    func testBrazilianPortugueseMenuSettingsAndMusicConsent() throws {
        let fixture = try fixtureApplication(characterCount: 1)
        setLanguage("pt-BR", for: fixture.app)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }

        let app = fixture.app
        app.launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        XCTAssertTrue(app.menuItems["Ocultar pet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Pausar"].exists)
        XCTAssertTrue(app.menuItems["Encerrar PetScape"].exists)

        app.activate()
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows.firstMatch
        let singleCharacter = window.staticTexts["settings.singleCharacter"]
        XCTAssertTrue(singleCharacter.waitForExistence(timeout: 15))
        XCTAssertEqual(singleCharacter.value as? String, "Este é o único personagem incluído no app.")
        XCTAssertEqual(window.switches["settings.windowInteraction"].label, "Interagir com janelas")
        XCTAssertEqual(window.switches["settings.musicDancing"].label, "Dançar ao som da música")
        XCTAssertEqual(
            window.staticTexts["settings.musicStatus"].value as? String, "A detecção de música está desativada.")
        XCTAssertTrue(
            (window.staticTexts["settings.windowInteractionExplanation"].value as? String)?.contains(
                "posições das janelas") == true)

        window.switches["settings.musicDancing"].click()
        let enableMusic = app.buttons["Ativar detecção de música"]
        XCTAssertTrue(enableMusic.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "value CONTAINS %@", "não usa o microfone")).firstMatch
                .exists)
        window.sheets.firstMatch.buttons["Cancelar"].click()
    }

    @MainActor
    func testBrazilianPortugueseEmptyCharacterAndPlaceholderStates() throws {
        let fixture = try fixtureApplication(characterCount: 0)
        setLanguage("pt-BR", for: fixture.app)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }

        let app = fixture.app
        app.launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        XCTAssertTrue(
            app.menuItems["Não foi possível carregar o pet. Exibindo um personagem provisório."]
                .waitForExistence(timeout: 10))

        app.activate()
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows.firstMatch
        XCTAssertEqual(
            window.staticTexts["settings.noCharacters"].value as? String, "Nenhum personagem incluído está disponível.")
        XCTAssertEqual(
            window.staticTexts["settings.characterError"].value as? String,
            "Não foi possível carregar nenhum personagem incluído no app.")
    }
}
