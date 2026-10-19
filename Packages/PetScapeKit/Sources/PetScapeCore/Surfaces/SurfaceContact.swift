import CoreGraphics

/// First supported descending foot crossing within a fixed step.
struct SurfaceContact: Equatable, Sendable {
    let surfaceID: SurfaceID
    let position: CGPoint
    let fraction: CGFloat
}
