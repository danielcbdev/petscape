import XCTest

/// Runs against isolated preferences and temporary bundled/installed character roots.
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

    @MainActor
    private func settingControl(_ identifier: String, in window: XCUIElement) -> XCUIElement {
        window.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func fixtureApplication(characterCount: Int) throws -> (app: XCUIApplication, root: URL, suite: String) {
        var products = Bundle(for: Self.self).bundleURL
        for _ in 0..<4 { products.deleteLastPathComponent() }
        let root = FileManager.default.temporaryDirectory.appending(path: "PetScapeUIFixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do {
            let characters = root.appending(path: "characters")
            let userCharacters = root.appending(path: "user-characters")
            let source = products.appending(path: "PetScape.app/Contents/Resources/characters/cat")
            let manifest = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: source.appending(path: "character.json")))
                    as? [String: Any])
            let animations = try XCTUnwrap(manifest["animations"] as? [String: [String: Any]])
            let frames = try XCTUnwrap(animations["walk"]?["frames"] as? [[String: Any]])
            let path = try XCTUnwrap(frames.first?["image"] as? String)
            let image = try Data(contentsOf: source.appending(path: path))
            try FileManager.default.createDirectory(at: characters, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: userCharacters, withIntermediateDirectories: true)
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
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defaults.set(false, forKey: "petscape.isPaused")
            defaults.set(false, forKey: "petscape.autonomy")
            let app = XCUIApplication()
            app.launchArguments = [
                "--settings-test-suite", suite, "--characters-folder", characters.path,
                "--user-characters-folder", userCharacters.path,
            ]
            setLanguage("en", for: app)
            return (app, root, suite)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) -> XCUIElement {
        app.activate()
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15))
        return window
    }

    @MainActor
    private func select(_ section: String, in window: XCUIElement) {
        let row = window.descendants(matching: .any)["settings.navigation.\(section)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing Settings section \(section)")
        row.click()
    }

    @MainActor
    func testNoCharactersShowsAnHonestAccessibleEmptyState() throws {
        let fixture = try fixtureApplication(characterCount: 0)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }
        fixture.app.launch()
        let window = openSettings(fixture.app)
        XCTAssertTrue(window.staticTexts["settings.emptyRoster"].waitForExistence(timeout: 15))
        XCTAssertTrue(window.staticTexts["settings.noCharacters"].exists)
        XCTAssertTrue(window.staticTexts["settings.characterError"].exists)
        XCTAssertTrue(window.buttons["settings.installCharacterPack"].exists)
        XCTAssertFalse(window.popUpButtons["settings.character"].exists)
    }

    @MainActor
    func testRosterAddsRemovesAndRestoresMultiplePetsAfterRelaunch() throws {
        let fixture = try fixtureApplication(characterCount: 2)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }
        let app = fixture.app
        app.launch()
        var window = openSettings(app)
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-a"].waitForExistence(timeout: 15))
        window.buttons["settings.addCharacter.fixture-b"].click()
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-b"].waitForExistence(timeout: 10))
        XCTAssertTrue(window.buttons["settings.removeCharacter.fixture-a"].exists)
        XCTAssertTrue(window.buttons["settings.dance.fixture-a"].exists)
        XCTAssertTrue(window.buttons["settings.stopDance.fixture-b"].exists)

        window.buttons["settings.removeCharacter.fixture-a"].click()
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-a"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-b"].exists)
        app.terminate()
        app.launch()
        window = openSettings(app)
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-b"].waitForExistence(timeout: 15))
        XCTAssertFalse(window.staticTexts["settings.activeCharacter.fixture-a"].exists)
    }

    @MainActor
    func testInstalledCharacterCanBeAddedAlongsideBundledCharacter() throws {
        let fixture = try fixtureApplication(characterCount: 1)
        let bundleFolder = fixture.root.appending(path: "characters/fixture-a")
        let sourceManifest = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: bundleFolder.appending(path: "character.json")))
                as? [String: Any])
        var installedManifest = sourceManifest
        installedManifest["id"] = "zz-external"
        installedManifest["displayName"] = "External Fixture"
        let installed = fixture.root.appending(path: "user-characters/zz-external")
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: installedManifest)
            .write(to: installed.appending(path: "character.json"))
        try FileManager.default.copyItem(
            at: bundleFolder.appending(path: "frame.png"), to: installed.appending(path: "frame.png"))
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }

        fixture.app.launch()
        let window = openSettings(fixture.app)
        window.buttons["settings.addCharacter.zz-external"].click()
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.zz-external"].waitForExistence(timeout: 10))
        XCTAssertEqual(window.staticTexts["settings.characterOrigin.zz-external"].value as? String, "Installed")
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-a"].exists)
    }

    @MainActor
    func testCancellingPackPickerLeavesRosterUntouched() throws {
        let fixture = try fixtureApplication(characterCount: 1)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }
        fixture.app.launch()
        let window = openSettings(fixture.app)
        let active = window.staticTexts["settings.activeCharacter.fixture-a"]
        XCTAssertTrue(active.waitForExistence(timeout: 15))
        window.buttons["settings.installCharacterPack"].click()
        let cancel = fixture.app.buttons["CancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.click()
        XCTAssertTrue(active.exists)
        XCTAssertFalse(window.staticTexts["settings.characterPackInstalled"].exists)
        XCTAssertFalse(window.staticTexts["settings.characterPackError"].exists)
        XCTAssertTrue(
            (try FileManager.default.contentsOfDirectory(
                atPath: fixture.root.appending(path: "user-characters").path)).isEmpty)
    }

    @MainActor
    func testSettingsNavigationControlsAndRestoreDefaultsKeepTheRoster() throws {
        let fixture = try fixtureApplication(characterCount: 1)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }
        fixture.app.launch()
        let window = openSettings(fixture.app)
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-a"].waitForExistence(timeout: 15))

        select("behavior", in: window)
        let autonomy = settingControl("settings.autonomy", in: window)
        XCTAssertTrue(autonomy.waitForExistence(timeout: 5))
        XCTAssertEqual(autonomy.label, "Autonomous activities")
        let initialAutonomy = integerValue(of: autonomy)
        XCTAssertNotNil(initialAutonomy)
        autonomy.click()
        XCTAssertEqual(integerValue(of: autonomy), initialAutonomy == 0 ? 1 : 0)
        for identifier in ["settings.jumping", "settings.resting", "settings.expressions"] {
            XCTAssertTrue(settingControl(identifier, in: window).exists, "Missing behavior control \(identifier)")
        }
        let music = settingControl("settings.musicDancing", in: window)
        XCTAssertEqual(integerValue(of: music), 0)
        music.click()
        XCTAssertTrue(fixture.app.buttons["Enable Music Detection"].waitForExistence(timeout: 5))
        window.sheets.firstMatch.buttons["Cancel"].click()
        XCTAssertEqual(integerValue(of: music), 0)

        select("interaction", in: window)
        let windowInteraction = settingControl("settings.windowInteraction", in: window)
        XCTAssertTrue(windowInteraction.waitForExistence(timeout: 5))
        XCTAssertEqual(windowInteraction.label, "Interact with windows")
        XCTAssertTrue(window.staticTexts["settings.windowInteractionExplanation"].exists)
        let cursor = settingControl("settings.cursorReactions", in: window)
        cursor.click()
        XCTAssertEqual(integerValue(of: cursor), 0)
        let direct = settingControl("settings.directInteraction", in: window)
        direct.click()
        XCTAssertEqual(integerValue(of: direct), 0)

        select("appearance", in: window)
        XCTAssertTrue(window.sliders["settings.scale"].exists)
        XCTAssertTrue(window.sliders["settings.speed"].exists)
        XCTAssertTrue(window.sliders["settings.dockOffset"].exists)

        select("general", in: window)
        let login = settingControl("settings.login", in: window)
        XCTAssertTrue(login.waitForExistence(timeout: 5))
        let pause = settingControl("settings.pause", in: window)
        let hide = settingControl("settings.hidePet", in: window)
        XCTAssertTrue(pause.exists)
        XCTAssertTrue(hide.exists)
        XCTAssertTrue(window.buttons["settings.wakePet"].exists)
        pause.click()
        hide.click()
        XCTAssertEqual(integerValue(of: pause), 1)
        XCTAssertEqual(integerValue(of: hide), 1)
        window.buttons["Restore Defaults"].click()
        XCTAssertEqual(integerValue(of: pause), 0)
        XCTAssertEqual(integerValue(of: hide), 0)
        XCTAssertEqual(integerValue(of: login), 0)
        select("behavior", in: window)
        XCTAssertEqual(integerValue(of: settingControl("settings.autonomy", in: window)), 1)
        select("interaction", in: window)
        XCTAssertEqual(integerValue(of: settingControl("settings.cursorReactions", in: window)), 1)
        XCTAssertEqual(integerValue(of: settingControl("settings.directInteraction", in: window)), 1)
        select("pets", in: window)
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-a"].exists)
    }

    @MainActor
    func testPortugueseLocalizationCoversNavigationAndRosterLabels() throws {
        let fixture = try fixtureApplication(characterCount: 1)
        setLanguage("pt-BR", for: fixture.app)
        defer {
            fixture.app.terminate()
            UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
            try? FileManager.default.removeItem(at: fixture.root)
        }
        fixture.app.launch()
        let window = openSettings(fixture.app)
        XCTAssertTrue(window.staticTexts["settings.activeCharacter.fixture-a"].waitForExistence(timeout: 15))
        XCTAssertEqual(window.staticTexts["settings.characterOrigin.fixture-a"].value as? String, "Incluído")
        XCTAssertTrue(window.buttons["settings.installCharacterPack"].label.contains("Instalar pacote"))
        select("behavior", in: window)
        XCTAssertEqual(settingControl("settings.musicDancing", in: window).label, "Dançar ao som da música")
        XCTAssertEqual(
            window.staticTexts["settings.musicStatus"].value as? String, "A detecção de música está desativada.")
    }
}
