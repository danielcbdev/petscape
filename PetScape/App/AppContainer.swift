import PetScapeCore

/// Composition root: creates and wires the long-lived objects (ADR-0002, conventions: no singletons).
/// Empty in M2; platform adapters, renderer and runtime are added from M3 on.
final class AppContainer {
    func start() {
        Log.app.notice("PetScape started")
    }

    /// Tears everything down before the process exits (FR-13: observers removed, windows closed).
    func stop() {
        Log.app.notice("PetScape stopped")
    }
}
