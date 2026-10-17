import AppKit
import QuartzCore

/// `FrameDriver` backed by the overlay view's `CADisplayLink` (`NSView.displayLink(target:selector:)`,
/// macOS 14+), which follows the display the view is on. Starts paused; paused means no callbacks and no
/// wakeups (NFR-02).
public final class DisplayLinkFrameDriver: FrameDriver {
    public var onFrame: ((TimeInterval) -> Void)?

    public var isPaused: Bool {
        get { link?.isPaused ?? true }
        set { link?.isPaused = newValue }
    }

    public var preferredFramesPerSecond: Float {
        didSet { applyFrameRate() }
    }

    private var link: CADisplayLink?
    /// The display link retains its target; the proxy breaks the cycle with a weak reference.
    private let target = Target()

    public init(view: NSView, preferredFramesPerSecond: Float = 60) {
        self.preferredFramesPerSecond = preferredFramesPerSecond
        let link = view.displayLink(target: target, selector: #selector(Target.step(_:)))
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        self.link = link
        target.driver = self
        applyFrameRate()
    }

    /// Asks for the preferred rate, accepting down to half of it (a busy or low-power display).
    private func applyFrameRate() {
        let rate = max(1, preferredFramesPerSecond)
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: rate / 2, maximum: rate, preferred: rate)
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
