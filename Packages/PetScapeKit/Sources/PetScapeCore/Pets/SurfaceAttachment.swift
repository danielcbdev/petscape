/// Where an attached pet stands: a surface and a parameter along it (0 = left end, 1 = right end), so the pet
/// follows the surface when it moves or resizes (physics-engine.md).
public struct SurfaceAttachment: Equatable, Sendable {
    public var surfaceID: SurfaceID
    public var parameter: Double

    public init(surfaceID: SurfaceID, parameter: Double) {
        self.surfaceID = surfaceID
        self.parameter = parameter
    }
}
