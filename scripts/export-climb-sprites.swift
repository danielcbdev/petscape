// Deterministic export of newly generated M11 climbing poses; source files are never modified.
// Usage: swift scripts/export-climb-sprites.swift <source-directory> <new-output-directory>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ExportError: Error, CustomStringConvertible {
    let description: String
}

struct Bounds {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { throw ExportError(description: "Expected source and output directories") }
let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
guard !FileManager.default.fileExists(atPath: output.path) else {
    throw ExportError(description: "Refusing to overwrite existing output: \(output.path)")
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    throw ExportError(description: "sRGB is unavailable")
}
let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

func decode(_ url: URL) throws -> (CGImage, [UInt8]) {
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    else { throw ExportError(description: "Cannot decode \(url.path)") }
    var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let succeeded = pixels.withUnsafeMutableBytes { bytes -> Bool in
        guard let context = CGContext(
            data: bytes.baseAddress, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: colorSpace, bitmapInfo: bitmapInfo)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    guard succeeded else { throw ExportError(description: "Cannot read \(url.path)") }
    return (image, pixels)
}

func bounds(_ pixels: [UInt8], width: Int, height: Int, threshold: UInt8) -> Bounds? {
    var result = Bounds(minX: width, minY: height, maxX: -1, maxY: -1)
    for y in 0..<height {
        for x in 0..<width where pixels[(y * width + x) * 4 + 3] >= threshold {
            result.minX = min(result.minX, x); result.maxX = max(result.maxX, x)
            result.minY = min(result.minY, y); result.maxY = max(result.maxY, y)
        }
    }
    return result.maxX >= result.minX ? result : nil
}

let names = (1...2).map { String(format: "climb_%02d-source.png", $0) }
let frames = try names.map { name -> (CGImage, Bounds, Bounds, Double, CGRect) in
    let (image, pixels) = try decode(source.appending(path: name))
    guard let body = bounds(pixels, width: image.width, height: image.height, threshold: 128),
        let alpha = bounds(pixels, width: image.width, height: image.height, threshold: 1)
    else { throw ExportError(description: "No visible body in \(name)") }
    let sampleStart = body.minX + (body.maxX - body.minX) * 4 / 5
    var sampleY = [Int]()
    for y in body.minY...body.maxY {
        for x in sampleStart...body.maxX where pixels[(y * image.width + x) * 4 + 3] >= 128 {
            sampleY.append(y)
        }
    }
    guard !sampleY.isEmpty else { throw ExportError(description: "Cannot find wall paw region in \(name)") }
    sampleY.sort()
    let pawCenterY = Double(sampleY[sampleY.count / 2])
    let padding = 8
    let cropBounds = CGRect(
        x: max(0, body.minX - padding), y: max(0, body.minY - padding),
        width: min(image.width, body.maxX + padding + 1) - max(0, body.minX - padding),
        height: min(image.height, body.maxY + padding + 1) - max(0, body.minY - padding))
    guard let cropped = image.cropping(to: cropBounds) else {
        throw ExportError(description: "Cannot isolate the character silhouette in \(name)")
    }
    return (cropped, body, alpha, pawCenterY, cropBounds)
}

let largestWidth = frames.map(\.0.width).max() ?? 1
let largestHeight = frames.map(\.0.height).max() ?? 1
let scale = min(460 / Double(largestWidth), 460 / Double(largestHeight))
let folder = output.appending(path: "frames", directoryHint: .isDirectory)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
var report: [[String: Any]] = []
for (index, frame) in frames.enumerated() {
    let (image, body, alpha, pawCenterY, cropBounds) = frame
    let width = Double(image.width) * scale
    let height = Double(image.height) * scale
    let targetSolidX = 500.0
    let destinationX = targetSolidX - (Double(body.maxX) - cropBounds.minX) * scale
    let targetPawY = 256.0
    let localPawY = pawCenterY - cropBounds.minY
    let destinationMaxY = targetPawY + (Double(image.height) - localPawY) * scale
    // Keep the tallest generated ear inside the runtime canvas while leaving the wall paw
    // registered horizontally. The original placement clipped alpha at the top edge.
    let destinationY = destinationMaxY - height - 30
    var pixels = [UInt8](repeating: 0, count: 512 * 512 * 4)
    let succeeded = pixels.withUnsafeMutableBytes { bytes -> Bool in
        guard let context = CGContext(
            data: bytes.baseAddress, width: 512, height: 512,
            bitsPerComponent: 8, bytesPerRow: 512 * 4, space: colorSpace, bitmapInfo: bitmapInfo)
        else { return false }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: destinationX, y: destinationY, width: width, height: height))
        return true
    }
    guard succeeded, let cgImage = pixels.withUnsafeMutableBytes({ bytes in
        CGContext(
            data: bytes.baseAddress, width: 512, height: 512,
            bitsPerComponent: 8, bytesPerRow: 512 * 4, space: colorSpace, bitmapInfo: bitmapInfo)?.makeImage()
    }) else { throw ExportError(description: "Cannot create output frame") }
    let url = folder.appending(path: String(format: "climb_%02d.png", index + 1))
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw ExportError(description: "Cannot write \(url.path)") }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else { throw ExportError(description: "PNG export failed") }
    report.append([
        "frame": index + 1, "sourceSolidBounds": [body.minX, body.minY, body.maxX + 1, body.maxY + 1],
        "sourceAlphaBounds": [alpha.minX, alpha.minY, alpha.maxX + 1, alpha.maxY + 1],
        "sourceCropBounds": [Int(cropBounds.minX), Int(cropBounds.minY), Int(cropBounds.maxX), Int(cropBounds.maxY)],
        "scale": scale, "solidRight": targetSolidX,
    ])
}
let reportData = try JSONSerialization.data(withJSONObject: ["scale": scale, "frames": report], options: [.prettyPrinted, .sortedKeys])
try reportData.write(to: output.appending(path: "export-report.json"))
