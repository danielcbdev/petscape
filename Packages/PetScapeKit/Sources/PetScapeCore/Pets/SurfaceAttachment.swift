/// Where an attached pet stands: a surface and a parameter from its first to second endpoint. Horizontal
/// segments map left→right; vertical wall segments map bottom→top, so the pet follows moved geometry.
public struct SurfaceAttachment: Equatable, Sendable {
    public var surfaceID: SurfaceID
    public var parameter: Double

    public init(surfaceID: SurfaceID, parameter: Double) {
        self.surfaceID = surfaceID
        self.parameter = parameter
    }
}
