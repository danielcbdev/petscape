/// Real platform seam: confidence windows, never audio samples, cross into the lifecycle controller.
public protocol MusicScoreSource: AnyObject {
    var onScore: ((Double, Double) -> Void)? { get set }
    var onFailure: (() -> Void)? { get set }
    func start() throws
    func stop()
}

public enum MusicCaptureError: Error {
    case unavailable
}

public enum MusicDetectionStatus: Equatable, Sendable {
    case off, suspended, monitoring, unavailable
}
