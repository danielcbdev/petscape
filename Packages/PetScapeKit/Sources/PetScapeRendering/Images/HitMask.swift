import CoreGraphics

/// Coarse alpha mask of a frame for hit testing (docs/specifications/asset-format.md#hit-masks-derived-not-authored).
///
/// One cell per `downscale` × `downscale` pixels of the decoded image; a cell is set when any covered pixel
/// has alpha ≥ `alphaThreshold`, then the mask is dilated by one cell so the pet is easier to grab.
/// The threshold is deliberately not 255: the cat's body alpha is 250–254 (audit F6).
nonisolated public struct HitMask: Equatable, Sendable {
    public static let alphaThreshold: UInt8 = 128
    public static let downscale = 4

    /// Size in cells.
    public let width: Int
    public let height: Int
    /// Row-major, row 0 = top of the image.
    private let cells: [Bool]

    /// Builds the mask from a decoded image; `nil` only if a bitmap context cannot be created.
    public init?(image: CGImage) {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var alpha = [UInt8](repeating: 0, count: width * height)
        let drawn = alpha.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.init(alpha: alpha, pixelWidth: width, pixelHeight: height)
    }

    /// Builds the mask from an 8-bit alpha buffer (row-major, row 0 = top).
    init(alpha: [UInt8], pixelWidth: Int, pixelHeight: Int) {
        precondition(alpha.count == pixelWidth * pixelHeight, "Alpha buffer does not match the pixel size")
        let step = Self.downscale
        let width = (pixelWidth + step - 1) / step
        let height = (pixelHeight + step - 1) / step
        var solid = [Bool](repeating: false, count: width * height)
        for y in 0..<pixelHeight {
            let rowStart = y * pixelWidth
            for x in 0..<pixelWidth where alpha[rowStart + x] >= Self.alphaThreshold {
                solid[(y / step) * width + x / step] = true
            }
        }
        var dilated = solid
        for cy in 0..<height {
            for cx in 0..<width where solid[cy * width + cx] {
                for ny in max(0, cy - 1)...min(height - 1, cy + 1) {
                    for nx in max(0, cx - 1)...min(width - 1, cx + 1) {
                        dilated[ny * width + nx] = true
                    }
                }
            }
        }
        self.width = width
        self.height = height
        self.cells = dilated
    }

    /// Whether the normalized point (0…1, origin bottom-left, like the manifest anchor) hits the pet.
    /// Points outside the canvas never hit. Mirroring and scale are applied by the caller.
    public func contains(normalizedX x: Double, y: Double) -> Bool {
        guard x >= 0, x < 1, y >= 0, y < 1 else { return false }
        let column = min(Int(x * Double(width)), width - 1)
        let row = min(Int((1 - y) * Double(height)), height - 1)
        return cells[row * width + column]
    }

    /// Whether the cell at (`column`, `row`), row 0 = top, is set.
    public func isSet(column: Int, row: Int) -> Bool {
        guard (0..<width).contains(column), (0..<height).contains(row) else { return false }
        return cells[row * width + column]
    }

    public var setCellCount: Int { cells.reduce(0) { $0 + ($1 ? 1 : 0) } }

    /// Approximate memory used by the mask.
    public var byteCount: Int { cells.count }
}
