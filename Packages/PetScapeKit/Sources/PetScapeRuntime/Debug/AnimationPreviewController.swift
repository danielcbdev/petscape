#if DEBUG
    import AppKit
    import PetScapeCore
    import PetScapeRendering
    import QuartzCore

    /// DEBUG "Animation Preview" window (T4.10): plays a clip in place, driven by the display link and the same
    /// `AnimationController` the pets use, so the declared fps, the anchor and mirroring can be checked by eye.
    ///
    /// The baseline and cross mark the manifest anchor: the paws must rest on the line and the sprite must not
    /// slide when mirrored. Not a production renderer (that is `PetLayer`, M5).
    public final class AnimationPreviewController: NSObject, NSWindowDelegate {
        private static let scales: [Double] = [1, 1.5, 2]
        private static let groundY: CGFloat = 56

        private let character: LoadedCharacter
        private var controller: AnimationController
        private let window: NSWindow
        private let canvas = PreviewCanvasView()
        private let petLayer = CALayer()
        private let baselineLayer = CAShapeLayer()
        private let anchorLayer = CAShapeLayer()
        private let infoLabel = NSTextField(labelWithString: "")
        private let clipPopUp = NSPopUpButton()
        private let scaleControl = NSSegmentedControl()
        private let mirrorCheckbox = NSButton(checkboxWithTitle: "Face the other way", target: nil, action: nil)
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval?
        private var events: [AnimationEvent] = []
        private var shownFrame: AnimationFrameRef?
        private var scale = 2.0
        private var frameChangeTimes: [CFTimeInterval] = []
        private var hasLoggedMeasurement = false

        public init(character: LoadedCharacter) {
            self.character = character
            self.controller = AnimationController(definition: character.definition)
            self.window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 380), styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: true)
            super.init()
            buildWindow()
        }

        /// Shows the window and starts playback.
        public func show() {
            if displayLink == nil { startDisplayLink() }
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }

        public func close() {
            window.close()
        }

        public func windowWillClose(_ notification: Notification) {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = nil
        }

        // MARK: - Frame loop

        private func startDisplayLink() {
            let link = canvas.displayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func step(_ link: CADisplayLink) {
            // Clamp the step so a stall (debugger, sleep) does not fast-forward the clip.
            let dt = lastTimestamp.map { min(max(0, link.timestamp - $0), 0.25) } ?? 0
            lastTimestamp = link.timestamp
            controller.advance(by: dt, into: &events)
            events.removeAll(keepingCapacity: true)

            let frame = controller.currentFrame
            guard frame != shownFrame else { return }
            if frame.clip == shownFrame?.clip, frame.frameIndex != shownFrame?.frameIndex {
                recordFrameChange(at: link.timestamp)
            }
            shownFrame = frame
            show(frame)
        }

        private func show(_ frame: AnimationFrameRef) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            petLayer.contents = character.frame(frame)?.image
            petLayer.anchorPoint = CGPoint(x: frame.anchor.x, y: frame.anchor.y)
            petLayer.setAffineTransform(frame.mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
            CATransaction.commit()
            updateInfo()
        }

        private func recordFrameChange(at time: CFTimeInterval) {
            frameChangeTimes.append(time)
            if frameChangeTimes.count > 37 { frameChangeTimes.removeFirst(frameChangeTimes.count - 37) }
            if !hasLoggedMeasurement, frameChangeTimes.count == 37, let rate = measuredRate {
                hasLoggedMeasurement = true
                Log.animation.notice(
                    "Animation preview '\(self.controller.player.clip.name, privacy: .public)': measured \(rate, format: .fixed(precision: 2)) frame changes/s over 36 changes"
                )
            }
        }

        /// Frame changes per second over the recent window (≈ 4 s at 9 fps).
        private var measuredRate: Double? {
            guard let first = frameChangeTimes.first, let last = frameChangeTimes.last, last > first else { return nil }
            return Double(frameChangeTimes.count - 1) / (last - first)
        }

        // MARK: - UI

        private func buildWindow() {
            window.title = "Animation Preview — \(character.definition.displayName)"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.minSize = NSSize(width: 360, height: 320)

            for name in character.definition.clips.keys.sorted() { clipPopUp.addItem(withTitle: name) }
            clipPopUp.selectItem(withTitle: character.definition.defaultClipName)
            clipPopUp.target = self
            clipPopUp.action = #selector(clipChanged)

            scaleControl.segmentCount = Self.scales.count
            for (index, value) in Self.scales.enumerated() {
                scaleControl.setLabel(value.formatted() + "×", forSegment: index)
            }
            scaleControl.selectedSegment = Self.scales.firstIndex(of: scale) ?? 0
            scaleControl.target = self
            scaleControl.action = #selector(scaleChanged)

            mirrorCheckbox.target = self
            mirrorCheckbox.action = #selector(mirrorChanged)

            infoLabel.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            infoLabel.lineBreakMode = .byWordWrapping
            infoLabel.maximumNumberOfLines = 0

            canvas.wantsLayer = true
            canvas.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            canvas.layer?.borderColor = NSColor.separatorColor.cgColor
            canvas.layer?.borderWidth = 1
            canvas.onLayout = { [weak self] in self?.layoutCanvas() }

            for layer in [baselineLayer, anchorLayer] {
                layer.fillColor = nil
                layer.lineWidth = 1
                layer.actions = ["path": NSNull(), "position": NSNull()]
            }
            baselineLayer.strokeColor = NSColor.systemRed.withAlphaComponent(0.7).cgColor
            baselineLayer.lineDashPattern = [4, 3]
            anchorLayer.strokeColor = NSColor.systemRed.cgColor

            petLayer.contentsGravity = .resize
            petLayer.minificationFilter = .linear
            petLayer.magnificationFilter = .linear
            petLayer.actions = [
                "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "transform": NSNull(),
                "anchorPoint": NSNull(),
            ]
            petLayer.borderColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            petLayer.borderWidth = 1
            canvas.layer?.addSublayer(baselineLayer)
            canvas.layer?.addSublayer(petLayer)
            canvas.layer?.addSublayer(anchorLayer)

            let controls = NSStackView(views: [clipPopUp, scaleControl, mirrorCheckbox])
            controls.orientation = .horizontal
            let stack = NSStackView(views: [controls, canvas, infoLabel])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            stack.translatesAutoresizingMaskIntoConstraints = false
            canvas.translatesAutoresizingMaskIntoConstraints = false

            let content = NSView()
            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                canvas.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 12),
                canvas.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -12),
                canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            ])
            window.contentView = content
            layoutCanvas()
        }

        private func layoutCanvas() {
            let bounds = canvas.bounds
            let size = character.definition.displaySize
            let ground = CGPoint(x: bounds.midX.rounded(), y: Self.groundY)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // Bounds come from the manifest displaySize, never from the image's pixel size.
            petLayer.bounds = CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)
            petLayer.position = ground

            let baseline = CGMutablePath()
            baseline.move(to: CGPoint(x: 8, y: ground.y))
            baseline.addLine(to: CGPoint(x: bounds.width - 8, y: ground.y))
            baselineLayer.path = baseline

            let cross = CGMutablePath()
            cross.move(to: CGPoint(x: ground.x - 8, y: ground.y))
            cross.addLine(to: CGPoint(x: ground.x + 8, y: ground.y))
            cross.move(to: CGPoint(x: ground.x, y: ground.y - 8))
            cross.addLine(to: CGPoint(x: ground.x, y: ground.y + 8))
            anchorLayer.path = cross
            CATransaction.commit()
        }

        private func updateInfo() {
            let clip = controller.player.clip
            let fps = clip.frames.first.map { 1 / $0.duration } ?? 0
            var lines = [
                "\(clip.name) · frame \(controller.player.frameIndex + 1)/\(clip.frames.count) · \(clip.playback.rawValue)"
                    + " · declared \(fps.formatted(.number.precision(.fractionLength(0...2)))) fps",
                "measured \(measuredRate.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "…") frame changes/s"
                    + " · anchor (\(clip.anchor.x.formatted()), \(clip.anchor.y.formatted()))"
                    + " · \(controller.isMirrored ? "mirrored" : "as authored")",
                "\(character.pixelSize) px frames · \(ByteCountFormatter.string(fromByteCount: Int64(character.decodedByteCount), countStyle: .memory)) decoded",
            ]
            if let failure = character.failure {
                lines.append("PLACEHOLDER — \(failure.description)")
            } else if character.isDegraded {
                lines.append(
                    "Degraded: \(character.issues.filter { $0.severity == .error }.count) clip error(s), see the log")
            }
            infoLabel.stringValue = lines.joined(separator: "\n")
        }

        @objc private func clipChanged() {
            guard let name = clipPopUp.titleOfSelectedItem else { return }
            controller.request(AnimationRequest(clip: name, priority: AnimationRequest.criticalPriority, restart: true))
            resetMeasurement()
        }

        @objc private func scaleChanged() {
            scale = Self.scales[max(0, scaleControl.selectedSegment)]
            layoutCanvas()
        }

        @objc private func mirrorChanged() {
            let facing = character.definition.defaultFacing
            controller.setFacing(mirrorCheckbox.state == .on ? facing.opposite : facing)
        }

        private func resetMeasurement() {
            frameChangeTimes.removeAll()
            hasLoggedMeasurement = false
        }
    }

    /// Layer-backed, non-flipped canvas that reports layout passes (window resizes) to the controller.
    private final class PreviewCanvasView: NSView {
        var onLayout: (() -> Void)?

        override func layout() {
            super.layout()
            onLayout?()
        }
    }
#endif
