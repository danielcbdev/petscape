import Foundation
import Observation

/// A supported app language. Portuguese variants share the Brazilian Portuguese translation.
public enum PetScapeLanguage: String, CaseIterable, Equatable, Sendable {
    case english = "en"
    case brazilianPortuguese = "pt-BR"

    public var locale: Locale { Locale(identifier: rawValue) }

    /// Returns the first supported language in the user's ordered system preferences.
    public static func bestMatch(preferredLanguages: [String]) -> Self {
        for identifier in preferredLanguages {
            guard let code = Locale(identifier: identifier).language.languageCode?.identifier.lowercased()
            else { continue }
            switch code {
            case "en": return .english
            case "pt": return .brazilianPortuguese
            default: continue
            }
        }
        return .english
    }
}

/// Tracks preferred-language changes using Foundation's public locale-change notification.
@Observable
public final class SystemLanguageMonitor {
    public private(set) var language: PetScapeLanguage

    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private let preferredLanguages: @MainActor () -> [String]
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    public init(
        preferredLanguages: @escaping @MainActor () -> [String] = { Locale.preferredLanguages },
        notificationCenter: NotificationCenter = .default
    ) {
        self.preferredLanguages = preferredLanguages
        self.notificationCenter = notificationCenter
        language = PetScapeLanguage.bestMatch(preferredLanguages: preferredLanguages())
    }

    public func start() {
        guard observer == nil else { return }
        observer = notificationCenter.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    public func stop() {
        guard let observer else { return }
        notificationCenter.removeObserver(observer)
        self.observer = nil
    }

    public func refresh() {
        let updated = PetScapeLanguage.bestMatch(preferredLanguages: preferredLanguages())
        guard language != updated else { return }
        language = updated
    }

}
