/// Provenance of a physical flight, retained until contact so Dock cleanup excludes same-Dock jumps
/// and upward jumps. Released pets may clean after an actual descent onto Dock or screen ground.
/// This is a fact on the existing pet, not a second physical controller.
enum FlightOrigin: Equatable, Sendable {
    case fall
    case jump(SurfaceID, sourceY: Double)
    case released
}
