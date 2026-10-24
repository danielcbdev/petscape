import Foundation
import Testing

@testable import PetScapePlatform

@Suite("M17 language selection")
struct PetScapeLanguageTests {
    @MainActor private final class PreferredLanguagesState {
        var values: [String]

        init(_ values: [String]) {
            self.values = values
        }
    }

    @Test func englishAndRegionalEnglishUseTheEnglishSource() {
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: ["en"]) == .english)
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: ["en-GB"]) == .english)
    }

    @Test func brazilianPortugueseAndOtherPortugueseRegionsUseBrazilianPortuguese() {
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: ["pt-BR"]) == .brazilianPortuguese)
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: ["pt-PT"]) == .brazilianPortuguese)
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: ["pt-AO"]) == .brazilianPortuguese)
    }

    @Test func firstSupportedLanguageWinsAfterUnsupportedPreferences() {
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: ["es-MX", "pt-PT", "en-US"]) == .brazilianPortuguese)
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: ["es-MX", "en-GB", "pt-BR"]) == .english)
    }

    @Test func unsupportedOrEmptyPreferencesFallBackToEnglish() {
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: ["es-MX", "fr-FR"]) == .english)
        #expect(PetScapeLanguage.bestMatch(preferredLanguages: []) == .english)
    }

    @Test func monitorRefreshesWhenTheLocaleChanges() {
        let notifications = NotificationCenter()
        let preferredLanguages = PreferredLanguagesState(["en-US"])
        let monitor = SystemLanguageMonitor(
            preferredLanguages: { preferredLanguages.values }, notificationCenter: notifications)
        monitor.start()
        #expect(monitor.language == .english)

        preferredLanguages.values = ["pt-PT"]
        notifications.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        #expect(monitor.language == .brazilianPortuguese)
        monitor.stop()
    }
}
