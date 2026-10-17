import CoreGraphics
import Foundation
import ImageIO
import PetScapeCore

/// Why an image file could not be turned into a `CGImage`. Paths are pack-relative for logs.
public enum ImageDecodingError: Error, Equatable, Sendable {
    case missingFile(String)
    case undecodable(String)
}

/// A decoded image plus the pixel size of the file it came from (before downsampling).
public struct DecodedImage: Sendable {
    public let image: CGImage
    public let sourcePixelWidth: Int
    public let sourcePixelHeight: Int
}

/// ImageIO decoding with downsampling at load (docs/architecture/animation-system.md#loading-caching-memory).
///
/// Runs off the main actor (`@concurrent`), so decoding a pack never blocks the UI. The returned image is
/// fully decoded (`kCGImageSourceShouldCacheImmediately`), so Core Animation only uploads it once.
nonisolated public struct ImageDecoder: Sendable {
    public init() {}

    /// Decodes `url` so that neither side exceeds `maxPixelSize` (never upscales).
    @concurrent
    public func decode(contentsOf url: URL, maxPixelSize: Int, label: String) async throws(ImageDecodingError)
        -> DecodedImage
    {
        try Self.decodeNow(contentsOf: url, maxPixelSize: maxPixelSize, label: label)
    }

    /// Decodes a sprite sheet so each of its `columns` × `rows` cells fits `cellMaxPixelSize`, then crops the
    /// cells (row-major). The cells share the sheet's backing store, so memory is counted once per sheet.
    @concurrent
    public func decodeSheet(
        contentsOf url: URL,
        columns: Int,
        rows: Int,
        cellMaxPixelSize: Int,
        label: String
    ) async throws(ImageDecodingError) -> (sheet: DecodedImage, cells: [CGImage]) {
        guard columns > 0, rows > 0 else { throw .undecodable(label) }
        let size = try Self.sourcePixelSize(of: url, label: label)
        let cellSide = max(Double(size.width) / Double(columns), Double(size.height) / Double(rows))
        let scale = min(1, Double(cellMaxPixelSize) / cellSide)
        let sheetMax = Int((Double(max(size.width, size.height)) * scale).rounded(.up))
        let decoded = try Self.decodeNow(contentsOf: url, maxPixelSize: sheetMax, label: label)

        let cellWidth = decoded.image.width / columns
        let cellHeight = decoded.image.height / rows
        var cells: [CGImage] = []
        cells.reserveCapacity(columns * rows)
        for index in 0..<(columns * rows) {
            // CGImage cropping uses a top-left origin, matching the row-major cell order.
            let rect = CGRect(
                x: (index % columns) * cellWidth, y: (index / columns) * cellHeight, width: cellWidth,
                height: cellHeight)
            guard let cell = decoded.image.cropping(to: rect) else { throw .undecodable(label) }
            cells.append(cell)
        }
        return (decoded, cells)
    }

    static func decodeNow(contentsOf url: URL, maxPixelSize: Int, label: String) throws(ImageDecodingError)
        -> DecodedImage
    {
        try Signposts.measure(Signposts.Interval.imageDecode) { () -> Result<DecodedImage, ImageDecodingError> in
            Result { () throws(ImageDecodingError) in
                let size = try sourcePixelSize(of: url, label: label)
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw .undecodable(label) }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
                    kCGImageSourceShouldCacheImmediately: true,
                ]
                guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    throw .undecodable(label)
                }
                return DecodedImage(image: image, sourcePixelWidth: size.width, sourcePixelHeight: size.height)
            }
        }.get()
    }

    /// Pixel size from the file's properties, without decoding pixels.
    static func sourcePixelSize(of url: URL, label: String) throws(ImageDecodingError) -> (width: Int, height: Int) {
        guard FileManager.default.fileExists(atPath: url.path) else { throw .missingFile(label) }
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0
        else { throw .undecodable(label) }
        return (width, height)
    }
}
