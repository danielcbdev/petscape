import Foundation
import os

/// Per-category loggers for the whole app. See docs/development/conventions.md#logging.
///
/// The subsystem is the bundle identifier of the running app, so `log stream` and Console.app can
/// filter on it; processes without a bundle identifier (e.g. `swift test`) use `defaultSubsystem`.
public enum Log {
    /// Logging categories. The raw values are part of the debugging contract (log predicates in docs).
    public enum Category: String, CaseIterable, Sendable {
        case app
        case overlay
        case rendering
        case animation
        case assets
        case simulation
        case behavior
        case physics
        case surfaces
        case dock
        case windowTracking
        case permissions
        case performance
    }

    /// Keep in sync with `PETSCAPE_BUNDLE_ID` in Config/Base.xcconfig.
    public static let defaultSubsystem = "io.github.danielcbdev.petscape"

    public static let subsystem = Bundle.main.bundleIdentifier ?? defaultSubsystem

    public static let app = logger(.app)
    public static let overlay = logger(.overlay)
    public static let rendering = logger(.rendering)
    public static let animation = logger(.animation)
    public static let assets = logger(.assets)
    public static let simulation = logger(.simulation)
    public static let behavior = logger(.behavior)
    public static let physics = logger(.physics)
    public static let surfaces = logger(.surfaces)
    public static let dock = logger(.dock)
    public static let windowTracking = logger(.windowTracking)
    public static let permissions = logger(.permissions)
    public static let performance = logger(.performance)

    public static func logger(_ category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
