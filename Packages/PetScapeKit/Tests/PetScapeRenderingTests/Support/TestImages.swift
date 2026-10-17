import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Synthetic PNG fixtures, written to a fresh temporary folder per test (no binary files in the repo).
enum TestImages {
    struct ImageError: Error {}

    /// An RGBA image whose alpha at pixel (x, y), y = 0 at the top, is `alpha(x, y)`; color is grey.
    static func make(width: Int, height: Int, alpha: (Int, Int) -> UInt8) throws -> CGImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let a = alpha(x, y)
                let offset = (y * width + x) * 4
                let grey = UInt8((Int(a) * 128) / 255)  // premultiplied
                pixels[offset] = grey
                pixels[offset + 1] = grey
                pixels[offset + 2] = grey
                pixels[offset + 3] = a
            }
        }
        let image = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                .makeImage()
        }
        guard let image else { throw ImageError() }
        return image
    }

    static func opaque(width: Int, height: Int) throws -> CGImage {
        try make(width: width, height: height) { _, _ in 255 }
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw ImageError() }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ImageError() }
    }

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "PetScapeRenderingTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The repository checkout (…/Packages/PetScapeKit/Tests/PetScapeRenderingTests/Support/TestImages.swift).
    static let repositoryRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    static var catPackURL: URL { repositoryRoot.appending(path: "assets/characters/cat") }

    static func catWalkFrame(_ number: Int) -> String { "walk/frames/walk_0\(number).png" }

    /// Full-resolution alpha channel, row 0 = top.
    static func alphaChannel(of image: CGImage) throws -> [UInt8] {
        var alpha = [UInt8](repeating: 0, count: image.width * image.height)
        let drawn = alpha.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                    bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { throw ImageError() }
        return alpha
    }
}
