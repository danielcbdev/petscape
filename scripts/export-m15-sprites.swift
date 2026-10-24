// M15 export of genuinely generated in-between drawings; no motion interpolation or deformation.
// Usage: swift scripts/export-m15-sprites.swift <source-directory> <new-output-directory>
// AI artwork is generated with image_gen. This tool performs deterministic pack export/registration.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ExportError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

struct Bounds {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int
    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}

struct Body {
    let pixels: [Int]
    let bounds: Bounds
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { throw ExportError("Expected source and new output directories") }
let sourceDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw ExportError("sRGB unavailable") }
let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

func decode(_ url: URL) throws -> (pixels: [UInt8], width: Int, height: Int) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ExportError("Cannot decode \(url.path)") }
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
        guard
            let context = CGContext(
                data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard success else { throw ExportError("Cannot read pixels") }
    return (pixels, width, height)
}

func findBodies(_ pixels: [UInt8], width: Int, height: Int) -> [Body] {
    var visited = [Bool](repeating: false, count: width * height)
    var bodies: [Body] = []
    for start in visited.indices where !visited[start] && pixels[start * 4 + 3] >= 128 {
        var queue = [start]
        var indices: [Int] = []
        var bounds = Bounds(minX: width, minY: height, maxX: 0, maxY: 0)
        visited[start] = true
        while let index = queue.popLast() {
            indices.append(index)
            let x = index % width
            let y = index / width
            bounds.minX = min(bounds.minX, x); bounds.maxX = max(bounds.maxX, x)
            bounds.minY = min(bounds.minY, y); bounds.maxY = max(bounds.maxY, y)
            for ny in max(0, y - 1)...min(height - 1, y + 1) {
                for nx in max(0, x - 1)...min(width - 1, x + 1) {
                    let neighbor = ny * width + nx
                    if !visited[neighbor] && pixels[neighbor * 4 + 3] >= 128 {
                        visited[neighbor] = true
                        queue.append(neighbor)
                    }
                }
            }
        }
        if indices.count > 10_000 { bodies.append(Body(pixels: indices, bounds: bounds)) }
    }
    return bodies.sorted {
        let row0 = ($0.bounds.minY + $0.bounds.maxY) / 2 / (height / 2)
        let row1 = ($1.bounds.minY + $1.bounds.maxY) / 2 / (height / 2)
        return row0 == row1 ? $0.bounds.minX < $1.bounds.minX : row0 < row1
    }
}

func makeImage(_ pixels: inout [UInt8], width: Int, height: Int) throws -> CGImage {
    let image = pixels.withUnsafeMutableBytes { bytes -> CGImage? in
        CGContext(
            data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo)?.makeImage()
    }
    guard let image else { throw ExportError("Cannot create image") }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw ExportError("Cannot create \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw ExportError("PNG export failed") }
}

struct Job: Decodable {
    let clip: String
    let source: String
    let afterFrames: [Int]
    let registration: String
    let canvasScale: Double?
}

func median(_ values: [Double]) -> Double {
    values.sorted()[values.count / 2]
}

func landmark(_ body: Body, width: Int, mode: String) -> (Double, Double) {
    let b = body.bounds
    if mode == "air" || mode == "walk" {
        let xs = body.pixels.filter { $0 / width <= b.minY + 4 }.map { Double($0 % width) }
        return (median(xs), Double(mode == "walk" ? b.maxY : b.minY))
    }
    if mode == "wall" {
        let ys = body.pixels.filter { $0 % width >= b.maxX - (b.width / 5) }.map { Double($0 / width) }
        return (Double(b.maxX), median(ys))
    }
    let xs = body.pixels.filter { $0 / width >= b.maxY - 6 }.map { Double($0 % width) }
    guard let first = xs.min(), let last = xs.max() else { return (Double(b.minX), Double(b.maxY)) }
    return ((first + last) / 2, Double(b.maxY))
}

let pack = sourceDirectory.deletingLastPathComponent().deletingLastPathComponent()
let baselineURL = sourceDirectory.deletingLastPathComponent().appending(path: "baseline-character.json")
let baseline = try JSONSerialization.jsonObject(with: Data(contentsOf: baselineURL)) as? [String: Any]
guard let animations = baseline?["animations"] as? [String: [String: Any]] else {
    throw ExportError("Missing baseline animation dictionary")
}
let planURL = sourceDirectory.deletingLastPathComponent().appending(path: "export-plan.json")
let jobs = try JSONDecoder().decode([Job].self, from: Data(contentsOf: planURL))
var report: [[String: Any]] = []
for job in jobs {
    let decoded = try decode(sourceDirectory.appending(path: job.source))
    let bodies = findBodies(decoded.pixels, width: decoded.width, height: decoded.height)
    guard bodies.count == job.afterFrames.count,
        let originalFrames = animations[job.clip]?["frames"] as? [[String: Any]]
    else { throw ExportError("Wrong body count in \(job.source): \(bodies.count)") }
    var targets: [(Double, Double)] = []
    var heights: [Double] = []
    for gap in job.afterFrames {
        var pair: [(Double, Double)] = []
        for index in [gap - 1, gap % originalFrames.count] {
            guard let path = originalFrames[index]["image"] as? String else { throw ExportError("Missing original") }
            let image = try decode(pack.appending(path: path))
            guard let body = findBodies(image.pixels, width: image.width, height: image.height).first else {
                throw ExportError("No original body")
            }
            heights.append(Double(body.bounds.height))
            pair.append(landmark(body, width: image.width, mode: job.registration))
        }
        let root = ((pair[0].0 + pair[1].0) / 2, (pair[0].1 + pair[1].1) / 2)
        targets.append(job.registration == "wall" ? (500, root.1) : root)
    }
    // One common scale per generated sheet, preserving relative pose dimensions.
    // A single-image source instead uses its explicit canvas-resolution conversion.
    let meanHeight = heights.reduce(0, +) / Double(heights.count)
    let sourceMeanHeight = bodies.map { Double($0.bounds.height) }.reduce(0, +) / Double(bodies.count)
    let nominalScale = job.canvasScale ?? meanHeight / sourceMeanHeight
    let scale = min(
        nominalScale, 496 / Double((bodies.map { $0.bounds.width }.max() ?? 1) + 8),
        496 / Double((bodies.map { $0.bounds.height }.max() ?? 1) + 8))
    for (index, body) in bodies.enumerated() {
        let b = body.bounds
        let pad = 4
        let width = b.width + pad * 2
        let height = b.height + pad * 2
        var keep = [Bool](repeating: false, count: width * height)
        // Preserve the drawn silhouette and antialiasing; discard detached generator specks.
        for pixel in body.pixels {
            let x = pixel % decoded.width - b.minX + pad
            let y = pixel / decoded.width - b.minY + pad
            for ny in max(0, y - pad)...min(height - 1, y + pad) {
                for nx in max(0, x - pad)...min(width - 1, x + pad) { keep[ny * width + nx] = true }
            }
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width where keep[y * width + x] {
                let sx = b.minX + x - pad
                let sy = b.minY + y - pad
                guard sx >= 0, sy >= 0, sx < decoded.width, sy < decoded.height else { continue }
                let from = (sy * decoded.width + sx) * 4
                let to = (y * width + x) * 4
                let alpha = Int(decoded.pixels[from + 3])
                guard alpha > 0 else { continue }
                let opaque = alpha >= 248 ? 255 : alpha
                for c in 0..<3 {
                    pixels[to + c] = UInt8(min(255, Int(decoded.pixels[from + c]) * opaque / alpha))
                }
                pixels[to + 3] = UInt8(opaque)
            }
        }
        let image = try makeImage(&pixels, width: width, height: height)
        let root = landmark(body, width: decoded.width, mode: job.registration)
        let target = targets[index]
        let rootX = target.0 - (root.0 - Double(b.minX) + Double(pad)) * scale
        let rootTop = target.1 - (root.1 - Double(b.minY) + Double(pad)) * scale
        // Tiny translation-only containment; never crop or deform a generated drawing.
        let x = min(max(8, rootX), 504 - Double(width) * scale)
        let top = min(max(8, rootTop), 504 - Double(height) * scale)
        var output = [UInt8](repeating: 0, count: 512 * 512 * 4)
        let success = output.withUnsafeMutableBytes { bytes -> Bool in
            guard
                let context = CGContext(
                    data: bytes.baseAddress, width: 512, height: 512, bitsPerComponent: 8,
                    bytesPerRow: 512 * 4, space: colorSpace, bitmapInfo: bitmapInfo)
            else { return false }
            context.interpolationQuality = .high
            context.draw(
                image,
                in: CGRect(
                    x: x, y: 512 - top - Double(height) * scale,
                    width: Double(width) * scale, height: Double(height) * scale))
            return true
        }
        guard success else { throw ExportError("Cannot register \(job.source)") }
        for pixel in stride(from: 0, to: output.count, by: 4) {
            let a = Int(output[pixel + 3])
            if a >= 248 && a < 255 {
                for c in 0..<3 { output[pixel + c] = UInt8(min(255, Int(output[pixel + c]) * 255 / a)) }
                output[pixel + 3] = 255
            }
        }
        let folder = outputDirectory.appending(path: "\(job.clip)/frames", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let frame = job.afterFrames[index] * 2
        let name = String(format: "%@_%02d.png", job.clip, frame)
        let url = folder.appending(path: name)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw ExportError("Refusing overwrite \(url.path)")
        }
        try writePNG(try makeImage(&output, width: 512, height: 512), to: url)
        report.append([
            "clip": job.clip, "afterOriginalFrame": job.afterFrames[index], "output": "\(job.clip)/frames/\(name)",
            "source": job.source, "sourceBody": index + 1, "scale": scale,
            "sourceBounds": [b.minX, b.minY, b.maxX + 1, b.maxY + 1],
            "registration": job.registration, "target": [target.0, target.1],
            "marginTranslation": [x - rootX, top - rootTop],
        ])
    }
}
let reportURL = outputDirectory.appending(path: "export-report.json")
guard !FileManager.default.fileExists(atPath: reportURL.path) else { throw ExportError("Refusing report overwrite") }
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL)
print("Exported \(report.count) drawn in-betweens; no motion synthesis or deformation.")
