import CoreGraphics

/// The programmatically drawn silhouette shown when a character fails to load (FR-15), so the app stays usable
/// and the failure is visible. Drawn on a square canvas with the contact point at `anchor`.
nonisolated public enum PlaceholderArtwork {
    /// Contact point of the drawing (bottom center, a little above the edge), normalized, origin bottom-left.
    public static let anchor = (x: 0.5, y: 0.08)

    /// A grey, sitting-cat-like silhouette with a dashed outline; `nil` only if drawing fails.
    public static func makeImage(pixelSize: Int) -> CGImage? {
        let side = max(16, pixelSize)
        let s = Double(side)
        guard
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        // Core Graphics: origin bottom-left, like the manifest anchor.
        let ground = s * anchor.y
        let body = CGRect(x: s * 0.22, y: ground, width: s * 0.56, height: s * 0.46)
        let head = CGRect(x: s * 0.3, y: ground + s * 0.38, width: s * 0.4, height: s * 0.36)
        let path = CGMutablePath()
        path.addEllipse(in: body)
        path.addEllipse(in: head)
        for (tipX, baseX) in [(0.32, 0.30), (0.68, 0.58)] {
            path.move(to: CGPoint(x: s * baseX, y: ground + s * 0.66))
            path.addLine(to: CGPoint(x: s * tipX, y: ground + s * 0.84))
            path.addLine(to: CGPoint(x: s * (baseX + 0.12), y: ground + s * 0.7))
            path.closeSubpath()
        }

        context.addPath(path)
        context.setFillColor(CGColor(srgbRed: 0.55, green: 0.58, blue: 0.62, alpha: 0.9))
        context.fillPath()
        context.addPath(path)
        context.setStrokeColor(CGColor(srgbRed: 0.2, green: 0.22, blue: 0.25, alpha: 1))
        context.setLineWidth(max(1, s / 64))
        context.setLineDash(phase: 0, lengths: [s / 24, s / 36])
        context.strokePath()

        // A question mark on the body says "something is missing" without any text resources.
        let mark = CGMutablePath()
        let center = CGPoint(x: s * 0.5, y: ground + s * 0.24)
        mark.addArc(
            center: CGPoint(x: center.x, y: center.y + s * 0.06), radius: s * 0.06, startAngle: .pi, endAngle: -.pi / 2,
            clockwise: true)
        mark.addLine(to: CGPoint(x: center.x, y: center.y - s * 0.02))
        context.addPath(mark)
        context.setLineDash(phase: 0, lengths: [])
        context.setLineWidth(max(1.5, s / 32))
        context.setLineCap(.round)
        context.strokePath()
        context.fillEllipse(
            in: CGRect(x: center.x - s * 0.02, y: center.y - s * 0.1, width: s * 0.04, height: s * 0.04))

        return context.makeImage()
    }
}
