import AppKit
import QuartzCore

/// `FrameDriver` backed by the overlay view's `CADisplayLink` (`NSView.displayLink(target:selector:)`,
/// macOS 14+), which follows the display the view is on. Starts paused. Skeleton for M3: the frame
/// callback samples the cursor; the simulation is added in M5, adaptive rate in T5.7.
public final class DisplayLinkFrameDriver: FrameDriver {
    public var onFrame: ((TimeInterval) -> Void)?

    public var isPaused: Bool {
        get { link?.isPaused ?? true }
        set { link?.isPaused = newValue }
    }

    private var link: CADisplayLink?
    /// The display link retains its target; the proxy breaks the cycle with a weak reference.
    private let target = Target()

    public init(view: NSView, preferredFramesPerSecond: Float = 60) {
        let link = view.displayLink(target: target, selector: #selector(Target.step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: preferredFramesPerSecond / 2, maximum: preferredFramesPerSecond,
            preferred: preferredFramesPerSecond)
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        self.link = link
        target.driver = self
    }

    public func invalidate() {
        link?.invalidate()
        link = nil
        onFrame = nil
    }

    fileprivate func step(_ link: CADisplayLink) {
        onFrame?(link.timestamp)
    }

    private final class Target: NSObject {
        weak var driver: DisplayLinkFrameDriver?

        @objc func step(_ link: CADisplayLink) {
            driver?.step(link)
        }
    }
}
