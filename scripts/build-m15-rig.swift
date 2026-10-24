// M15 rework: cut-out rig poses built from one authored original key (walk/frames/walk_01.png).
// Every part keeps its original pixels; poses use rigid rotation/translation only (no warping, no
// frame blending). Gait and gesture timing are computed here so contacts are exact by construction.
// M16 (owner-approved method change) adds the V9 `dance` and `cleanup` clips with the same rig.
// Usage: swiftc -O scripts/build-m15-rig.swift -o /tmp/m15-rig && /tmp/m15-rig <repo-root> <new-output-dir>
// RIG_CLIPS=dance,cleanup selects clips (default: the ten V8 clips).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RigError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

let size = 512
let groundY = 474.0  // canvas row of the manifest anchor (1 - 0.074) * 512
let pointsPerPixel = 96.0 / 512.0

// MARK: - Raster helpers (premultiplied RGBA, Float, row 0 = top)

struct Raster {
    var data: [Float]
    init() { data = [Float](repeating: 0, count: size * size * 4) }

    func sample(_ x: Double, _ y: Double) -> (Float, Float, Float, Float) {
        let fx = x - 0.5
        let fy = y - 0.5
        let x0 = Int(floor(fx))
        let y0 = Int(floor(fy))
        let tx = Float(fx - Double(x0))
        let ty = Float(fy - Double(y0))
        var out: (Float, Float, Float, Float) = (0, 0, 0, 0)
        for (dx, dy, w) in [(0, 0, (1 - tx) * (1 - ty)), (1, 0, tx * (1 - ty)), (0, 1, (1 - tx) * ty), (1, 1, tx * ty)]
        where w > 0 {
            let px = x0 + dx
            let py = y0 + dy
            guard px >= 0, py >= 0, px < size, py < size else { continue }
            let i = (py * size + px) * 4
            out.0 += data[i] * w
            out.1 += data[i + 1] * w
            out.2 += data[i + 2] * w
            out.3 += data[i + 3] * w
        }
        return out
    }
}

func decode(_ url: URL) throws -> Raster {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        image.width == size, image.height == size,
        let space = CGColorSpace(name: CGColorSpace.sRGB)
    else { throw RigError("Cannot decode \(url.path)") }
    var bytes = [UInt8](repeating: 0, count: size * size * 4)
    let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard
            let context = CGContext(
                data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                bytesPerRow: size * 4, space: space, bitmapInfo: info)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        return true
    }
    guard drawn else { throw RigError("Cannot read pixels") }
    var raster = Raster()
    for i in bytes.indices { raster.data[i] = Float(bytes[i]) / 255 }
    return raster
}

func encode(_ raster: Raster, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else { throw RigError("Refusing to overwrite \(url.path)") }
    var bytes = [UInt8](repeating: 0, count: size * size * 4)
    for p in 0..<(size * size) {
        let a = min(1, max(0, raster.data[p * 4 + 3]))
        // Match the existing export convention: near-opaque body becomes opaque, soft edges stay soft; an
        // invisible resampling fringe (< 6/255) is cleared so it cannot reach the transparent margin.
        let alpha: Float = a >= 248 / 255 ? 1 : a < 6 / 255 ? 0 : a
        let scale: Float = a > 0 ? alpha / a : 0
        for c in 0..<3 { bytes[p * 4 + c] = UInt8(min(255, max(0, raster.data[p * 4 + c] * scale * 255 + 0.5))) }
        bytes[p * 4 + 3] = UInt8(alpha * 255 + 0.5)
    }
    removeSpecks(&bytes)
    let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let provider = CGDataProvider(data: Data(bytes) as CFData),
        let image = CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
            space: space, bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw RigError("Cannot encode \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw RigError("Cannot write \(url.path)") }
}

/// Clears resampling specks: visible islands (alpha > 32) smaller than 24 px detached from the body.
func removeSpecks(_ bytes: inout [UInt8]) {
    var visited = [Bool](repeating: false, count: size * size)
    for start in 0..<(size * size) where !visited[start] && bytes[start * 4 + 3] > 32 {
        var island = [start]
        var stack = [start]
        visited[start] = true
        while let index = stack.popLast() {
            let x = index % size
            let y = index / size
            for ny in max(0, y - 1)...min(size - 1, y + 1) {
                for nx in max(0, x - 1)...min(size - 1, x + 1) {
                    let neighbor = ny * size + nx
                    if !visited[neighbor] && bytes[neighbor * 4 + 3] > 32 {
                        visited[neighbor] = true
                        stack.append(neighbor)
                        island.append(neighbor)
                    }
                }
            }
        }
        if island.count < 24 {
            for index in island { for c in 0..<4 { bytes[index * 4 + c] = 0 } }
        }
    }
}

// MARK: - Masks

typealias Point = (x: Double, y: Double)

func polygonMask(_ polygon: [Point], feather: Int) -> [Float] {
    var mask = [Float](repeating: 0, count: size * size)
    let minY = max(0, Int(polygon.map(\.y).min() ?? 0) - 1)
    let maxY = min(size - 1, Int(polygon.map(\.y).max() ?? 0) + 1)
    for y in minY...maxY {
        for x in 0..<size {
            var hits = 0
            for sy in 0..<4 {
                for sx in 0..<4 {
                    let px = Double(x) + (Double(sx) + 0.5) / 4
                    let py = Double(y) + (Double(sy) + 0.5) / 4
                    var inside = false
                    var j = polygon.count - 1
                    for i in polygon.indices {
                        let a = polygon[i]
                        let b = polygon[j]
                        if (a.y > py) != (b.y > py), px < (b.x - a.x) * (py - a.y) / (b.y - a.y) + a.x {
                            inside.toggle()
                        }
                        j = i
                    }
                    if inside { hits += 1 }
                }
            }
            mask[y * size + x] = Float(hits) / 16
        }
    }
    return feather > 0 ? blur(mask, radius: feather) : mask
}

func blur(_ mask: [Float], radius: Int) -> [Float] {
    var current = mask
    for _ in 0..<2 {
        var horizontal = current
        for y in 0..<size {
            for x in 0..<size {
                var sum: Float = 0
                for k in -radius...radius { sum += current[y * size + min(size - 1, max(0, x + k))] }
                horizontal[y * size + x] = sum / Float(2 * radius + 1)
            }
        }
        for y in 0..<size {
            for x in 0..<size {
                var sum: Float = 0
                for k in -radius...radius { sum += horizontal[min(size - 1, max(0, y + k)) * size + x] }
                current[y * size + x] = sum / Float(2 * radius + 1)
            }
        }
    }
    return current
}

func masked(_ source: Raster, _ mask: [Float]) -> Raster {
    var part = Raster()
    for p in 0..<(size * size) {
        for c in 0..<4 { part.data[p * 4 + c] = source.data[p * 4 + c] * mask[p] }
    }
    return part
}

// MARK: - Rig

/// Rigid transform: rotate by `angle` (degrees, clockwise on screen) about `pivot` in rest coordinates,
/// then translate by (dx, dy).
struct Rigid {
    var pivot: Point
    var angle = 0.0
    var dx = 0.0
    var dy = 0.0

    func apply(_ p: Point) -> Point {
        let r = angle * .pi / 180
        let x = p.x - pivot.x
        let y = p.y - pivot.y
        return (pivot.x + x * cos(r) - y * sin(r) + dx, pivot.y + x * sin(r) + y * cos(r) + dy)
    }

    func inverse(_ p: Point) -> Point {
        let r = -angle * .pi / 180
        let x = p.x - dx - pivot.x
        let y = p.y - dy - pivot.y
        return (pivot.x + x * cos(r) - y * sin(r), pivot.y + x * sin(r) + y * cos(r))
    }

    /// Composition: first `inner`, then `self`.
    func after(_ inner: Rigid) -> Rigid {
        let origin = apply(inner.apply(inner.pivot))
        let total = Rigid(pivot: inner.pivot, angle: inner.angle + angle)
        let moved = total.apply(inner.pivot)
        return Rigid(pivot: inner.pivot, angle: total.angle, dx: origin.x - moved.x, dy: origin.y - moved.y)
    }
}

struct Layer {
    let part: Raster
    let transform: Rigid
    var tone: Float = 1
}

func composite(_ layers: [Layer]) -> Raster {
    var out = Raster()
    for layer in layers {
        for y in 0..<size {
            for x in 0..<size {
                let source = layer.transform.inverse((Double(x) + 0.5, Double(y) + 0.5))
                let s = layer.part.sample(source.x, source.y)
                guard s.3 > 0.0005 else { continue }
                let i = (y * size + x) * 4
                let keep = 1 - s.3
                out.data[i] = s.0 * layer.tone + out.data[i] * keep
                out.data[i + 1] = s.1 * layer.tone + out.data[i + 1] * keep
                out.data[i + 2] = s.2 * layer.tone + out.data[i + 2] * keep
                out.data[i + 3] = s.3 + out.data[i + 3] * keep
            }
        }
    }
    return out
}

// MARK: - Part geometry on walk_01 (canvas pixels, y down)

/// Vertical ramp: 0 above `from`, 1 below `to`.
func ramp(_ mask: [Float], from: Double, to: Double) -> [Float] {
    var out = mask
    for y in 0..<size {
        let t = Float(min(1, max(0, (Double(y) + 0.5 - from) / (to - from))))
        let w = t * t * (3 - 2 * t)
        for x in 0..<size { out[y * size + x] *= w }
    }
    return out
}

/// Alpha eroded by a square min filter, so a static copy stays inside a moving part's silhouette.
func erodedAlpha(_ source: Raster, radius: Int) -> [Float] {
    var alpha = [Float](repeating: 0, count: size * size)
    for p in alpha.indices { alpha[p] = source.data[p * 4 + 3] }
    var horizontal = alpha
    for y in 0..<size {
        for x in 0..<size {
            var m: Float = 1
            for k in -radius...radius { m = min(m, alpha[y * size + min(size - 1, max(0, x + k))]) }
            horizontal[y * size + x] = m
        }
    }
    var out = horizontal
    for y in 0..<size {
        for x in 0..<size {
            var m: Float = 1
            for k in -radius...radius { m = min(m, horizontal[min(size - 1, max(0, y + k)) * size + x]) }
            out[y * size + x] = m
        }
    }
    return out
}

// Strict regions removed from the torso.
let headRegion: [Point] = [
    (220, 0), (512, 0), (512, 255), (490, 270), (445, 298), (400, 305), (340, 292), (285, 268), (238, 228),
]
let tailRegion: [Point] = [(0, 0), (220, 0), (220, 272), (182, 316), (163, 350), (146, 384), (0, 384)]
let legRegion: [Point] = [
    (100, 512), (100, 416), (130, 418), (200, 411), (288, 410), (350, 402), (420, 400), (420, 512),
]
// Removed from the torso when the near fore leg is raised: the leg's top below an arched chest line.
let chestArch: [Point] = [
    (274, 512), (276, 420), (284, 402), (298, 390), (318, 384), (336, 388), (344, 396), (350, 420), (350, 512),
]
// Rounded near fore upper arm (an ellipse around the leg axis) for raised poses.
let nearFrontArm: [Point] = (0..<48).map { i in
    let a = 2 * Double.pi * Double(i) / 48
    return (319 + 29 * cos(a), 386 + 50 * sin(a))
}
// Extended part regions; the extension stays hidden under the torso.
let headPart: [Point] = [
    (220, 0), (512, 0), (512, 265), (472, 302), (445, 324), (400, 330), (345, 312), (285, 290), (230, 246),
]
let tailPart: [Point] = [(0, 0), (226, 0), (240, 282), (204, 334), (182, 368), (160, 400), (0, 400)]

struct LegSpec {
    let name: String
    let upper: [Point]?  // thigh / upper arm drawn over the torso, faded where it meets the body
    let upperFade: (from: Double, to: Double)
    let upperFeather: Int
    let lower: [Point]
    let paw: [Point]
    let hip: Point  // hip or shoulder, inside the body
    let joint: Point  // upper/lower joint at rest (the hip when there is no upper part)
    let attach: Point  // lower/paw joint at rest
    let contact: Point  // paw ground contact centre at rest
    let upperShare: Double  // fraction of the leg swing carried by the upper part
    /// Where the torso's static copy is pulled inside the moving upper part's outer silhouette.
    var erosion: [Point]? = nil
}

let nearHind = LegSpec(
    name: "nearHind",
    upper: [(108, 322), (226, 316), (224, 398), (208, 434), (160, 430), (108, 420)],
    upperFade: (330, 362), upperFeather: 8,
    lower: [(108, 404), (203, 404), (203, 426), (190, 440), (200, 446), (200, 452), (108, 452)],
    paw: [(108, 436), (200, 436), (204, 446), (204, 480), (108, 480)],
    hip: (190, 345), joint: (160, 418), attach: (160, 446), contact: (162, 472), upperShare: 0.45,
    erosion: [(100, 316), (172, 316), (172, 432), (100, 432)])
let farHind = LegSpec(
    name: "farHind", upper: nil, upperFade: (0, 0), upperFeather: 0,
    lower: [(201, 402), (287, 402), (287, 452), (201, 452)],
    paw: [(203, 436), (290, 436), (290, 480), (203, 480)],
    hip: (250, 352), joint: (250, 352), attach: (250, 446), contact: (250, 472), upperShare: 0)
let nearFront = LegSpec(
    name: "nearFront",
    upper: [(288, 330), (349, 330), (349, 424), (288, 424)],
    upperFade: (334, 368), upperFeather: 3,
    lower: [(290, 392), (348, 392), (348, 452), (290, 452)],
    paw: [(291, 438), (348, 438), (356, 444), (361, 449), (364, 456), (365, 470), (363, 480), (291, 480)],
    hip: (320, 338), joint: (320, 418), attach: (326, 446), contact: (328, 472), upperShare: 0.6)
// The far fore leg is mostly hidden behind the near one in the key; it reuses the near fore lower parts, toned
// down for distance, at the far paw's original position (standard cut-out practice, not a frame copy).
let farFrontOffset = 58.0

// MARK: - Motion helpers

func smooth(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }  // minimum-jerk ease
func fract(_ x: Double) -> Double { x - floor(x) }
func direction(_ a: Point, _ b: Point) -> Double { atan2(b.x - a.x, b.y - a.y) * 180 / .pi }

struct LegPose {
    var upper: Rigid?
    var lower: Rigid
    var paw: Rigid
    var contactWorld: Point
}

/// Places a leg so the paw contact follows the ground (fixed during stance) and the upper part follows the
/// body; the lower part pivots at the joint and slides along its axis behind the upper part instead of
/// stretching, so limb length and volume never change.
func legPose(_ spec: LegSpec, body: Rigid, xOffset: Double, u: Double, lift: Double, pawAngle: Double) -> LegPose {
    func shifted(_ p: Point) -> Point { (p.x + xOffset, p.y) }
    let contact0 = shifted(spec.contact)
    let attach0 = shifted(spec.attach)
    let hip0 = shifted(spec.hip)
    let joint0 = shifted(spec.joint)
    let paw = Rigid(pivot: contact0, angle: pawAngle, dx: u, dy: -lift)
    let attachWorld = paw.apply(attach0)
    let hipWorld = body.apply(hip0)
    let swing = direction(hip0, attach0) - direction(hipWorld, attachWorld) - body.angle
    var upper: Rigid?
    var jointWorld = body.apply(joint0)
    if spec.upper != nil {
        let part = body.after(Rigid(pivot: hip0, angle: swing * spec.upperShare))
        upper = part
        jointWorld = part.apply(joint0)
    }
    let angle = direction(joint0, attach0) - direction(jointWorld, attachWorld)
    let lower = Rigid(pivot: attach0, angle: angle, dx: attachWorld.x - attach0.x, dy: attachWorld.y - attach0.y)
    return LegPose(upper: upper, lower: lower, paw: paw, contactWorld: paw.apply(contact0))
}

// MARK: - Clips

struct Frame {
    var layers: [Layer]
    var paws: [String: (Point, Bool)] = [:]
    var duration: Double
    var events: [String] = []
}

struct LegParts {
    let upper: Raster?
    let lower: Raster
    let paw: Raster
    /// Upper part with a rounded silhouette, used when a raised leg exposes the straight cut of `upper`.
    var upperRound: Raster? = nil
}

struct Parts {
    let head: Raster
    let tail: Raster
    let torso: Raster
    /// Torso with a rounded chest underside where the near fore leg hangs, for poses that raise that leg.
    let torsoRaised: Raster
    let legs: [String: LegParts]
}

// Walk: lateral-sequence gait (near hind, near fore, far hind, far fore), duty factor 0.62.
let walkPeriod = 1.0
let walkFrames = 30
let walkStride = 72.0  // canvas px travelled per cycle
let walkDuty = 0.62

struct GaitLeg {
    let spec: LegSpec
    let name: String
    let touchdown: Double
    let offset: Double
    let tone: Float
    let liftHeight: Double
}

func walk(_ parts: Parts) -> [Frame] {
    let sweep = walkStride * walkDuty
    let gait = [
        GaitLeg(spec: farHind, name: "farHind", touchdown: 0.5, offset: 0, tone: 1, liftHeight: 12),
        GaitLeg(spec: nearFront, name: "farFront", touchdown: 0.75, offset: farFrontOffset, tone: 0.9, liftHeight: 13),
        GaitLeg(spec: nearHind, name: "nearHind", touchdown: 0, offset: 0, tone: 1, liftHeight: 14),
        GaitLeg(spec: nearFront, name: "nearFront", touchdown: 0.25, offset: 0, tone: 1, liftHeight: 15),
    ]
    var frames: [Frame] = []
    for index in 0..<walkFrames {
        let phase = Double(index) / Double(walkFrames)
        let wave = 2 * Double.pi * phase
        let body = Rigid(pivot: (256, 380), angle: 0.6 * sin(wave), dx: 0, dy: 1.2 * cos(2 * wave))
        let head = body.after(
            Rigid(pivot: (360, 300), angle: -0.5 * sin(wave + 0.3), dx: 0, dy: -0.6 * cos(2 * wave - 0.6)))
        let tail = body.after(Rigid(pivot: (185, 320), angle: 3.5 * sin(wave - 1.2)))
        var legLayers: [String: [Layer]] = [:]
        var paws: [String: (Point, Bool)] = [:]
        var events: [String] = []
        for leg in gait {
            let p = fract(phase - leg.touchdown)
            let planted = p < walkDuty
            var u = sweep / 2 - p / walkDuty * sweep
            var lift = 0.0
            var pawAngle = 0.0
            if !planted {
                let q = (p - walkDuty) / (1 - walkDuty)
                u = -sweep / 2 + sweep * smooth(q)
                lift = leg.liftHeight * pow(sin(Double.pi * pow(q, 0.85)), 1.2)
                pawAngle = -16 * sin(Double.pi * q) * (1 - 0.5 * q)
            }
            // The first planted drawing of each fore paw carries its footstep.
            if p < 1 / Double(walkFrames) - 1e-9, leg.name.hasSuffix("Front") { events.append("footstep") }
            let pose = legPose(leg.spec, body: body, xOffset: leg.offset, u: u, lift: lift, pawAngle: pawAngle)
            // Proven invariant: `makeParts` builds every spec used by the gait.
            let part = parts.legs[leg.spec.name]!
            // Template parts sit at the near leg's rest position; move them to the offset rest position first.
            let placement = Rigid(pivot: (0, 0), dx: leg.offset)
            var layers = [
                Layer(part: part.lower, transform: pose.lower.after(placement), tone: leg.tone),
                Layer(part: part.paw, transform: pose.paw.after(placement), tone: leg.tone),
            ]
            if leg.offset == 0, let upper = part.upper, let transform = pose.upper {
                layers.append(Layer(part: upper, transform: transform, tone: leg.tone))
            }
            legLayers[leg.name] = layers
            paws[leg.name] = (pose.contactWorld, planted)
        }
        let layers =
            (legLayers["farHind"] ?? []) + (legLayers["farFront"] ?? []) + [Layer(part: parts.tail, transform: tail)]
            + [Layer(part: parts.torso, transform: body)] + (legLayers["nearHind"] ?? [])
            + (legLayers["nearFront"] ?? []) + [Layer(part: parts.head, transform: head)]
        frames.append(Frame(layers: layers, paws: paws, duration: walkPeriod / Double(walkFrames), events: events))
    }
    return frames
}

func makeParts(_ key: Raster) -> Parts {
    let strictHead = polygonMask(headRegion, feather: 2)
    let strictTail = polygonMask(tailRegion, feather: 2)
    let strictLegs = polygonMask(legRegion, feather: 2)
    let eroded = erodedAlpha(key, radius: 12)
    var erosionZone = [Float](repeating: 0, count: size * size)
    var legs: [String: LegParts] = [:]
    for spec in [nearHind, farHind, nearFront] {
        var upper: Raster?
        if let polygon = spec.upper {
            let mask = ramp(
                polygonMask(polygon, feather: spec.upperFeather), from: spec.upperFade.from, to: spec.upperFade.to)
            upper = masked(key, mask)
            let zone = polygonMask(spec.erosion ?? polygon, feather: 6)
            for p in erosionZone.indices { erosionZone[p] = max(erosionZone[p], zone[p]) }
        }
        legs[spec.name] = LegParts(
            upper: upper, lower: masked(key, polygonMask(spec.lower, feather: 2)),
            paw: masked(key, polygonMask(spec.paw, feather: 1)),
            upperRound: spec.name == nearFront.name
                ? masked(key, ramp(polygonMask(nearFrontArm, feather: 2), from: 336, to: 354)) : nil)
    }
    var torsoMask = [Float](repeating: 0, count: size * size)
    for p in torsoMask.indices {
        let alpha = key.data[p * 4 + 3]
        let shrink = alpha > 0 ? min(1, eroded[p] / alpha) : 0
        let keep = 1 - erosionZone[p] * (1 - shrink)
        torsoMask[p] = max(0, 1 - max(strictHead[p], strictTail[p], strictLegs[p])) * keep
    }
    return Parts(
        head: masked(key, polygonMask(headPart, feather: 8)), tail: masked(key, polygonMask(tailPart, feather: 4)),
        torso: masked(key, torsoMask),
        torsoRaised: masked(key, zip(torsoMask, polygonMask(chestArch, feather: 2)).map { $0 * (1 - $1) }),
        legs: legs)
}

// MARK: - Eyelids (painted over the key's eyes for blinks)

struct Eye {
    let centre: Point
    let radiusX: Double
    let radiusY: Double
    let cheek: Point  // lower-lid colour sample
    let furOffset: Double  // distance above the rim where lid fur is sampled
    var furSample: Point?  // fixed lid colour sample when the rim borders the brow
}

let nearEye = Eye(centre: (406, 210), radiusX: 26, radiusY: 27, cheek: (405, 248), furOffset: 9)
let farEye = Eye(
    centre: (468, 193), radiusX: 9, radiusY: 21, cheek: (452, 236), furOffset: 0, furSample: (451, 184))

/// Paints a lid inside each eye outline (the key's dark rim stays visible): fur sampled just above the eye at
/// the same column, shaded like a rounded lid, down to a curved lash line. `closure` 0 = open, 1 = closed
/// (lash line at 62% of the eye height, lower lid in cheek colour below it).
func withEyelids(_ head: Raster, closure: Double) -> Raster {
    guard closure > 0.001 else { return head }
    var out = head
    for eye in [nearEye, farEye] {
        let top = eye.centre.y - eye.radiusY
        let height = 2 * eye.radiusY
        let lash = top + height * 0.62 * closure + 1
        let cheek = head.sample(eye.cheek.x, eye.cheek.y)
        for y in Int(top)...Int(eye.centre.y + eye.radiusY) {
            for x in Int(eye.centre.x - eye.radiusX)...Int(eye.centre.x + eye.radiusX) {
                let nx = (Double(x) + 0.5 - eye.centre.x) / eye.radiusX
                let ny = (Double(y) + 0.5 - eye.centre.y) / eye.radiusY
                // Superellipse: the key's eyes are rounder at the corners than an ellipse.
                let r = pow(abs(nx), 2.6) + pow(abs(ny), 2.6)
                guard r < 1 else { continue }
                let edge = Float(min(1, (1 - r) * 6))  // soft rim against the key's outline
                let column = eye.centre.y - (eye.radiusY + eye.furOffset) * (1 - nx * nx).squareRoot()
                let fur = eye.furSample.map { head.sample($0.x, $0.y) } ?? head.sample(Double(x) + 0.5, column)
                let sag = 6 * closure * (1 - nx * nx)  // lid edge bows downward as it closes
                let lineY = lash + sag
                let py = Double(y) + 0.5
                var colour: (Float, Float, Float, Float)? = nil
                if py < lineY - 2 {
                    let depth = (py - top) / max(1, lineY - top)
                    let shade = Float(1.04 - 0.22 * depth * depth - 0.06 * nx * nx)
                    colour = (fur.0 * shade, fur.1 * shade, fur.2 * shade, 1)
                } else if py < lineY + 1.5 {
                    colour = (0.13, 0.11, 0.14, 1)  // lash line
                } else if closure > 0.97 {
                    colour = cheek
                }
                guard let c = colour else { continue }
                let i = (y * size + x) * 4
                // Stay inside the key's silhouette and keep premultiplied colour consistent with alpha.
                let coverage = head.data[i + 3]
                let a = edge * (closure > 0.97 ? 1 : min(1, Float(closure) * 4)) * coverage
                out.data[i] = c.0 * a + out.data[i] * (1 - a)
                out.data[i + 1] = c.1 * a + out.data[i + 1] * (1 - a)
                out.data[i + 2] = c.2 * a + out.data[i + 2] * (1 - a)
                out.data[i + 3] = a + out.data[i + 3] * (1 - a)
            }
        }
    }
    return out
}

// MARK: - Head gesture keys

struct Key {
    let time: Double
    let head: Double  // degrees, negative tips the head back/up
    let lift: Double  // px, positive raises the head
    let lean: Double  // degrees of body lean (negative leans back)
    let tail: Double  // degrees, positive raises the tail
}

/// Minimum-jerk interpolation between consecutive keys (zero velocity at each key).
func value(_ keys: [Key], at time: Double, _ field: (Key) -> Double) -> Double {
    guard let last = keys.last, time < last.time else { return keys.last.map(field) ?? 0 }
    var index = 0
    while index + 1 < keys.count, keys[index + 1].time <= time { index += 1 }
    let a = keys[index]
    let b = keys[index + 1]
    return field(a) + (field(b) - field(a)) * smooth((time - a.time) / (b.time - a.time))
}

func blink(at time: Double, start: Double) -> Double {
    let t = time - start
    if t < 0 || t > 0.24 { return 0 }
    if t < 0.07 { return smooth(t / 0.07) }
    if t < 0.12 { return 1 }
    return 1 - smooth((t - 0.12) / 0.12)
}

/// Curious: anticipation dip, lift-and-tilt toward the point of interest with overshoot, a held look with a
/// blink and a full return to the neutral key by 1.8 s (one complete click reaction); a continued cursor dwell
/// then gets a slower cock to the other side and a settled return before the loop seam.
let curiousKeys = [
    Key(time: 0, head: 0, lift: 0, lean: 0, tail: 0),
    Key(time: 0.20, head: 3, lift: -2, lean: 0.4, tail: -1),
    Key(time: 0.62, head: -15, lift: 7, lean: -1.4, tail: 7),
    Key(time: 0.78, head: -13.5, lift: 6, lean: -1.2, tail: 6),
    Key(time: 1.30, head: -12.5, lift: 5.5, lean: -1.1, tail: 4),
    Key(time: 1.80, head: 0, lift: 0, lean: 0, tail: 0),
    Key(time: 2.35, head: 8, lift: 2.5, lean: -0.5, tail: 5),
    Key(time: 2.95, head: 7, lift: 2.5, lean: -0.5, tail: 3),
    Key(time: 3.40, head: 0, lift: 0, lean: 0, tail: 0),
    Key(time: 3.60, head: 0, lift: 0, lean: 0, tail: 0),
]
let curiousBlink = 0.95

func standingLayers(_ parts: Parts, body: Rigid, head: Rigid, headPart: Raster, tail: Rigid) -> [Layer] {
    let stance = [
        GaitLeg(spec: farHind, name: "farHind", touchdown: 0, offset: 0, tone: 1, liftHeight: 0),
        GaitLeg(spec: nearFront, name: "farFront", touchdown: 0, offset: farFrontOffset, tone: 0.9, liftHeight: 0),
        GaitLeg(spec: nearHind, name: "nearHind", touchdown: 0, offset: 0, tone: 1, liftHeight: 0),
        GaitLeg(spec: nearFront, name: "nearFront", touchdown: 0, offset: 0, tone: 1, liftHeight: 0),
    ]
    var legLayers: [String: [Layer]] = [:]
    for leg in stance {
        let pose = legPose(leg.spec, body: body, xOffset: leg.offset, u: 0, lift: 0, pawAngle: 0)
        let part = parts.legs[leg.spec.name]!  // proven invariant: built in `makeParts`
        let placement = Rigid(pivot: (0, 0), dx: leg.offset)
        var layers = [
            Layer(part: part.lower, transform: pose.lower.after(placement), tone: leg.tone),
            Layer(part: part.paw, transform: pose.paw.after(placement), tone: leg.tone),
        ]
        if leg.offset == 0, let upper = part.upper, let transform = pose.upper {
            layers.append(Layer(part: upper, transform: transform, tone: leg.tone))
        }
        legLayers[leg.name] = layers
    }
    return (legLayers["farHind"] ?? []) + (legLayers["farFront"] ?? []) + [Layer(part: parts.tail, transform: tail)]
        + [Layer(part: parts.torso, transform: body)] + (legLayers["nearHind"] ?? [])
        + (legLayers["nearFront"] ?? []) + [Layer(part: headPart, transform: head)]
}

/// Samples the gesture at 60 Hz and keeps a new drawing only when the pose visibly changes, so slow phases get
/// held drawings and fast phases get closely spaced ones (durations are whole simulation steps).
func curious(_ parts: Parts) -> [Frame] {
    let step = 1.0 / 60
    let total = curiousKeys.last?.time ?? 0
    let steps = Int((total / step).rounded())
    var frames: [Frame] = []
    var last: (head: Double, lift: Double, lean: Double, tail: Double, lid: Double)?
    for index in 0..<steps {
        let t = Double(index) * step
        let pose = (
            head: value(curiousKeys, at: t, \.head), lift: value(curiousKeys, at: t, \.lift),
            lean: value(curiousKeys, at: t, \.lean), tail: value(curiousKeys, at: t, \.tail),
            lid: blink(at: t, start: curiousBlink)
        )
        let previousLid = last?.lid ?? 0
        if let previous = last, let held = frames.indices.last,
            abs(pose.head - previous.head) < 1.4, abs(pose.lift - previous.lift) < 1.0,
            abs(pose.lean - previous.lean) < 0.3, abs(pose.tail - previous.tail) < 1.2,
            abs(pose.lid - previous.lid) < 0.2, (pose.lid > 0.97) == (previous.lid > 0.97)
        {
            frames[held].duration += step
            continue
        }
        last = pose
        let body = Rigid(pivot: (300, 472), angle: pose.lean)
        let head = body.after(Rigid(pivot: (360, 300), angle: pose.head, dx: 0, dy: -pose.lift))
        let tail = body.after(Rigid(pivot: (185, 320), angle: pose.tail))
        let headPart = withEyelids(parts.head, closure: pose.lid)
        var events: [String] = []
        if pose.lid > 0.97, previousLid <= 0.97 { events.append("blink") }  // first fully closed drawing
        frames.append(
            Frame(
                layers: standingLayers(parts, body: body, head: head, headPart: headPart, tail: tail),
                duration: step, events: events))
    }
    return frames
}

// MARK: - Generic poses (idle, jump, fall, landing, pickup, held, climb)

/// How a leg is placed: paw on the ground (inverse kinematics, as in the walk) or joint angles relative to the
/// parent part (forward kinematics, for airborne, held and pickup poses). Angles are degrees, clockwise on
/// screen; for a leg hanging down, negative swings the paw forward.
enum LegCommand {
    case ground(u: Double, lift: Double, paw: Double)
    case swing(upper: Double, lower: Double, paw: Double)
    /// Joint rotations added on top of the planted pose (zero = planted), so a paw leaves the ground continuously.
    case raise(upper: Double, lower: Double, paw: Double)
}

struct Pose {
    var body: Rigid
    var head = 0.0
    var headLift = 0.0
    var tail = 0.0
    var lid = 0.0
    var tongue = 0.0
    var legs: [String: LegCommand] = [:]
    /// Draws the near fore leg over the head (a paw raised in front of the face).
    var foreInFront = false
}

let poseLegs = [
    GaitLeg(spec: farHind, name: "farHind", touchdown: 0, offset: 0, tone: 1, liftHeight: 0),
    GaitLeg(spec: nearFront, name: "farFront", touchdown: 0, offset: farFrontOffset, tone: 0.9, liftHeight: 0),
    GaitLeg(spec: nearHind, name: "nearHind", touchdown: 0, offset: 0, tone: 1, liftHeight: 0),
    GaitLeg(spec: nearFront, name: "nearFront", touchdown: 0, offset: 0, tone: 1, liftHeight: 0),
]

func legSwing(_ spec: LegSpec, body: Rigid, xOffset: Double, upper a1: Double, lower a2: Double, paw a3: Double)
    -> LegPose
{
    func shifted(_ p: Point) -> Point { (p.x + xOffset, p.y) }
    let base = body.after(Rigid(pivot: shifted(spec.hip), angle: a1))
    let lower = base.after(Rigid(pivot: shifted(spec.joint), angle: a2))
    let paw = lower.after(Rigid(pivot: shifted(spec.attach), angle: a3))
    return LegPose(
        upper: spec.upper == nil ? nil : base, lower: lower, paw: paw, contactWorld: paw.apply(shifted(spec.contact)))
}

/// The planted pose with extra shoulder/elbow/wrist rotations about the planted joints' current positions.
func legRaise(_ spec: LegSpec, body: Rigid, xOffset: Double, upper a1: Double, lower a2: Double, paw a3: Double)
    -> LegPose
{
    func shifted(_ p: Point) -> Point { (p.x + xOffset, p.y) }
    let base = legPose(spec, body: body, xOffset: xOffset, u: 0, lift: 0, pawAngle: 0)
    let shoulder = Rigid(pivot: body.apply(shifted(spec.hip)), angle: a1)
    let jointWorld = (base.upper ?? body).apply(shifted(spec.joint))
    let elbow = Rigid(pivot: shoulder.apply(jointWorld), angle: a2).after(shoulder)
    let wrist = Rigid(pivot: elbow.apply(base.paw.apply(shifted(spec.attach))), angle: a3).after(elbow)
    return LegPose(
        upper: base.upper.map { shoulder.after($0) }, lower: elbow.after(base.lower), paw: wrist.after(base.paw),
        contactWorld: wrist.after(base.paw).apply(shifted(spec.contact)))
}

/// Layers for a pose, with `global` applied last (climb rotation, registration shifts).
func poseLayers(_ parts: Parts, _ pose: Pose, global: Rigid) -> (layers: [Layer], paws: [String: (Point, Bool)]) {
    var legLayers: [String: [Layer]] = [:]
    var paws: [String: (Point, Bool)] = [:]
    for leg in poseLegs {
        let command = pose.legs[leg.name] ?? .ground(u: 0, lift: 0, paw: 0)
        let result: LegPose
        var planted = false
        switch command {
        case .ground(let u, let lift, let paw):
            result = legPose(leg.spec, body: pose.body, xOffset: leg.offset, u: u, lift: lift, pawAngle: paw)
            planted = lift == 0
        case .swing(let upper, let lower, let paw):
            result = legSwing(leg.spec, body: pose.body, xOffset: leg.offset, upper: upper, lower: lower, paw: paw)
        case .raise(let upper, let lower, let paw):
            result = legRaise(leg.spec, body: pose.body, xOffset: leg.offset, upper: upper, lower: lower, paw: paw)
            planted = upper == 0 && lower == 0 && paw == 0
        }
        let part = parts.legs[leg.spec.name]!  // proven invariant: built in `makeParts`
        let placement = Rigid(pivot: (0, 0), dx: leg.offset)
        var layers = [
            Layer(part: part.lower, transform: global.after(result.lower.after(placement)), tone: leg.tone),
            Layer(part: part.paw, transform: global.after(result.paw.after(placement)), tone: leg.tone),
        ]
        let raised: Bool
        if case .raise = command { raised = !planted } else { raised = false }
        if leg.offset == 0, let upper = raised ? part.upperRound ?? part.upper : part.upper,
            let transform = result.upper
        {
            layers.append(Layer(part: upper, transform: global.after(transform), tone: leg.tone))
        }
        legLayers[leg.name] = layers
        paws[leg.name] = (global.apply(result.contactWorld), planted)
    }
    let head = pose.body.after(Rigid(pivot: (360, 300), angle: pose.head, dx: 0, dy: -pose.headLift))
    let tail = pose.body.after(Rigid(pivot: (185, 320), angle: pose.tail))
    let headLayer = Layer(
        part: withTongue(withEyelids(parts.head, closure: pose.lid), amount: pose.tongue), transform: global.after(head))
    let front = legLayers["nearFront"] ?? []
    let layers =
        (legLayers["farHind"] ?? []) + (legLayers["farFront"] ?? [])
        + [Layer(part: parts.tail, transform: global.after(tail))]
        + [Layer(part: pose.foreInFront ? parts.torsoRaised : parts.torso, transform: global.after(pose.body))]
        + (legLayers["nearHind"] ?? [])
        + (pose.foreInFront ? [headLayer] + front : front + [headLayer])
    return (layers, paws)
}

/// Opaque bounds (alpha >= 128) of a composited pose: (minX, maxX, maxY).
/// Solid bounds (alpha >= 128) and visible bounds (anything the encoder keeps) of a composited pose.
func bounds(_ raster: Raster) -> (solidMaxX: Int, solidMaxY: Int, minX: Int, maxX: Int) {
    var solidMaxX = 0
    var solidMaxY = 0
    var minX = size
    var maxX = 0
    for y in 0..<size {
        for x in 0..<size {
            let alpha = raster.data[(y * size + x) * 4 + 3]
            if alpha >= 6 / 255 {
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
            if alpha >= 0.5 {
                solidMaxX = max(solidMaxX, x)
                solidMaxY = max(solidMaxY, y)
            }
        }
    }
    return (solidMaxX, solidMaxY, minX, maxX)
}

enum Registration {
    case none  // paws already on the ground line
    case ground  // lowest solid row on the ground line (airborne, held and pickup poses)
    case wall  // rightmost solid column on the climb wall line
}

func frame(
    _ parts: Parts, _ pose: Pose, global: Rigid = Rigid(pivot: (0, 0)), registration: Registration,
    duration: Double, events: [String] = []
) -> Frame {
    var placed = global
    if registration != .none {
        let box = bounds(composite(poseLayers(parts, pose, global: global).layers))
        // Keep the transparent margin: a dangling tail or reaching paw shifts a free (unplanted) drawing back.
        let inside = Double(max(0, 10 - box.minX) - max(0, box.maxX - 501))
        let shift =
            registration == .ground
            ? Rigid(pivot: (0, 0), dx: inside, dy: groundY - Double(box.solidMaxY))
            : Rigid(pivot: (0, 0), dx: 500 - Double(box.solidMaxX))
        placed = shift.after(global)
    }
    let result = poseLayers(parts, pose, global: placed)
    return Frame(layers: result.layers, paws: result.paws, duration: duration, events: events)
}

/// Piecewise minimum-jerk curve through (time, value) keys; holds the last value after the last key.
func curve(_ keys: [(Double, Double)], _ time: Double) -> Double {
    guard let last = keys.last, time < last.0 else { return keys.last?.1 ?? 0 }
    var index = 0
    while index + 1 < keys.count, keys[index + 1].0 <= time { index += 1 }
    let a = keys[index]
    let b = keys[index + 1]
    return a.1 + (b.1 - a.1) * smooth((time - a.0) / (b.0 - a.0))
}

/// Drawings at explicit step counts (1 step = 1/60 s); the pose is evaluated at each drawing's midpoint.
func timed(
    _ steps: [Int], events: [Int: [String]] = [:], registration: Registration, global: Rigid = Rigid(pivot: (0, 0)),
    _ parts: Parts, _ pose: (Double) -> Pose
) -> [Frame] {
    var frames: [Frame] = []
    var start = 0
    for (index, count) in steps.enumerated() {
        frames.append(
            frame(
                parts, pose((Double(start) + Double(count) / 2) / 60), global: global, registration: registration,
                duration: Double(count) / 60, events: events[index] ?? []))
        start += count
    }
    return frames
}

/// Keeps a new drawing only when a pose channel moves past its tolerance (slow phases become held drawings).
func adaptive(
    period: Double, tolerances: [Double], registration: Registration, events: (Double, Double) -> [String],
    _ parts: Parts, channels: (Double) -> [Double], _ pose: ([Double]) -> Pose
) -> [Frame] {
    let step = 1.0 / 60
    var kept: [(start: Double, values: [Double], steps: Int)] = []
    for index in 0..<Int((period / step).rounded()) {
        let t = Double(index) * step
        let values = channels(t)
        if let last = kept.last, zip(zip(values, last.values), tolerances).allSatisfy({ abs($0.0 - $0.1) < $1 }) {
            kept[kept.count - 1].steps += 1
            continue
        }
        kept.append((t, values, 1))
    }
    return kept.map { entry in
        let duration = Double(entry.steps) * step
        return frame(
            parts, pose(entry.values), registration: registration, duration: duration,
            events: events(entry.start, entry.start + duration))
    }
}

func blinkEvents(at closed: Double) -> (Double, Double) -> [String] {
    { start, end in start <= closed && closed < end ? ["blink"] : [] }
}

// Idle: two slow breaths per 3.2 s loop (chest/neck rise, slight pitch), a slow look and tail sway, one blink.
func idle(_ parts: Parts) -> [Frame] {
    let period = 3.2
    let blinkStart = 1.9
    return adaptive(
        period: period, tolerances: [0.36, 1.0, 2.4, 1.3, 3.6, 0.34], registration: .none,
        events: blinkEvents(at: blinkStart + 0.07), parts,
        channels: { time in
            // Starts 0.15 s into the loop so its first drawing differs from the shared standing key.
            let t = time + 0.15
            let breath = (1 - cos(4 * Double.pi * t / period)) / 2
            return [
                0.35 * sin(4 * Double.pi * t / period), 0.9 * breath, -2.5 * sin(2 * Double.pi * t / period),
                0.7 * breath, 5 * sin(2 * Double.pi * t / period), blink(at: time, start: blinkStart),
            ]
        },
        { v in
            Pose(
                body: Rigid(pivot: (300, 472), angle: v[0], dy: -v[1]), head: v[2], headLift: v[3], tail: v[4],
                lid: v[5])
        })
}

// Jump-start (0.15 s, the physical preparation): crouch with the weight sinking, then a fast push that pitches
// the body up and lifts the fore paws; `takeoff` on the extended drawing.
func jumpStart(_ parts: Parts) -> [Frame] {
    let sink = [(0.0, 0.0), (0.067, 18.0), (0.1, 10.0), (0.117, -5.0)]
    let pitch = [(0.0, 0.0), (0.067, 0.0), (0.1, -1.0), (0.117, -5.0)]
    let foreLift = [(0.0, 0.0), (0.1, 0.0), (0.117, 9.0)]
    return timed([2, 2, 2, 1, 2], events: [4: ["takeoff"]], registration: .none, parts) { t in
        let lift = curve(foreLift, t)
        let fore = LegCommand.ground(u: lift * 0.7, lift: lift, paw: -1.6 * lift)
        return Pose(
            body: Rigid(pivot: (160, 472), angle: curve(pitch, t), dy: curve(sink, t)),
            head: curve([(0, 0), (0.067, 2), (0.117, -5)], t), headLift: curve([(0, 0), (0.067, -4), (0.117, 2)], t),
            tail: curve([(0, 0), (0.067, -3), (0.117, 6)], t),
            legs: ["nearFront": fore, "farFront": fore])
    }
}

// Airborne base shared by the end of `jump` and the `fall` loop: fore legs reaching down/forward for the
// landing, hind legs gathered, tail raised for balance, head looking down.
let fallBase = (
    body: 7.0, head: 6.0, tail: 20.0, foreUpper: -24.0, foreLower: -20.0, forePaw: 14.0, hindUpper: -18.0,
    hindLower: 16.0, hindPaw: 24.0
)

func airborne(body: Double, head: Double, tail: Double, fore: (Double, Double, Double), hind: (Double, Double, Double))
    -> Pose
{
    let foreLeg = LegCommand.swing(upper: fore.0, lower: fore.1, paw: fore.2)
    let hindLeg = LegCommand.swing(upper: hind.0, lower: hind.1, paw: hind.2)
    return Pose(
        body: Rigid(pivot: (256, 380), angle: body), head: head, tail: tail,
        legs: ["nearFront": foreLeg, "farFront": foreLeg, "nearHind": hindLeg, "farHind": hindLeg])
}

// Jump (0.333 s, held at its end): stretched takeoff (fore legs up and forward, hind legs extended back),
// leveling while rising, ending on the fall base so the physical apex switch to `fall` does not pop.
func jump(_ parts: Parts) -> [Frame] {
    let b = fallBase
    return timed([2, 2, 2, 2, 2, 2, 8], registration: .ground, parts) { t in
        airborne(
            body: curve([(0, -8), (0.1, -4), (0.2, b.body)], t), head: curve([(0, -5), (0.1, -3), (0.2, b.head)], t),
            tail: curve([(0, 8), (0.1, 12), (0.2, b.tail)], t),
            fore: (
                curve([(0, -30), (0.067, -38), (0.2, b.foreUpper)], t), curve([(0, -22), (0.2, b.foreLower)], t),
                curve([(0, 30), (0.2, b.forePaw)], t)
            ),
            hind: (
                curve([(0, 30), (0.067, 22), (0.2, b.hindUpper)], t), curve([(0, 18), (0.2, b.hindLower)], t),
                curve([(0, 40), (0.2, b.hindPaw)], t)
            ))
    }
}

// Fall (0.8 s loop): the airborne base with gentle leg paddling and tail flutter (balance), no pose jumps.
func fall(_ parts: Parts) -> [Frame] {
    let b = fallBase
    return timed(Array(repeating: 4, count: 12), registration: .ground, parts) { t in
        let w = 2 * Double.pi * t / 0.8
        return airborne(
            body: b.body + 0.8 * sin(w), head: b.head + 1 * sin(w - 0.4), tail: b.tail + 6 * sin(w - 1.0),
            fore: (b.foreUpper + 4 * sin(w), b.foreLower + 3 * sin(w - 0.5), b.forePaw + 4 * sin(w - 0.9)),
            hind: (b.hindUpper + 3 * sin(w + 1.2), b.hindLower + 2 * sin(w + 0.6), b.hindPaw + 3 * sin(w + 0.2)))
    }
}

// Landing (0.1 s, the physical landing): fore paws touch first with the hind still descending, weight
// compresses, rebounds and settles just short of the standing key; `contact` first, `settled` last.
func landing(_ parts: Parts) -> [Frame] {
    let poses: [(dy: Double, pitch: Double, head: Double, tail: Double, foreU: Double, hindLift: Double)] = [
        (0, 2.5, 1, 14, 8, 10), (9, 1.5, 2, 10, 6, 0), (3, 0.5, 1, 5, 2, 0), (0.8, 0, 0.5, 1.5, 0.5, 0),
    ]
    let steps = [1, 2, 2, 1]
    var start = 0
    var frames: [Frame] = []
    for (index, p) in poses.enumerated() {
        let fore = LegCommand.ground(u: p.foreU, lift: 0, paw: 0)
        let hind = LegCommand.ground(u: -p.hindLift * 0.4, lift: p.hindLift, paw: p.hindLift * 1.2)
        let pose = Pose(
            body: Rigid(pivot: (330, 472), angle: p.pitch, dy: p.dy), head: p.head, headLift: -p.dy * 0.2,
            tail: p.tail, legs: ["nearFront": fore, "farFront": fore, "nearHind": hind, "farHind": hind])
        let events = index == 0 ? ["contact"] : index == poses.count - 1 ? ["settled"] : []
        frames.append(frame(parts, pose, registration: .none, duration: Double(steps[index]) / 60, events: events))
        start += steps[index]
    }
    return frames
}

// Held: scooped up under the body (an upright pose would not fit the 512 px canvas without rescaling the key),
// head kept level, legs and paws dangling, tail hanging; a slow pendulum sway with the legs and tail lagging
// behind (secondary motion) and one blink.
let heldBase = (
    body: -10.0, head: 6.0, tail: -32.0, foreUpper: 12.0, foreLower: 18.0, forePaw: 26.0, hindUpper: 14.0,
    hindLower: 20.0, hindPaw: 22.0
)

func heldPose(_ k: Double, sway: Double, lag: Double, lid: Double) -> Pose {
    let b = heldBase
    let fore = LegCommand.swing(upper: k * b.foreUpper - lag * 3, lower: k * b.foreLower, paw: k * b.forePaw)
    let hind = LegCommand.swing(upper: k * b.hindUpper - lag * 4, lower: k * b.hindLower - lag, paw: k * b.hindPaw)
    return Pose(
        body: Rigid(pivot: (300, 380), angle: k * b.body + sway), head: k * b.head - sway * 0.6,
        tail: k * b.tail - lag * 6, lid: lid,
        legs: ["nearFront": fore, "farFront": fore, "nearHind": hind, "farHind": hind])
}

// Picked-up (0.2 s, the interaction phase): from the standing key to the held pose with a fast ease-out and a
// small overshoot, legs trailing.
func pickedUp(_ parts: Parts) -> [Frame] {
    timed([2, 2, 2, 2, 2, 2], registration: .ground, parts) { t in
        let k = curve([(0, 0), (0.15, 1.06), (0.2, 1.0)], t)
        return heldPose(k, sway: 0, lag: curve([(0, 0), (0.1, -2), (0.2, 0)], t), lid: 0)
    }
}

func held(_ parts: Parts) -> [Frame] {
    let period = 2.4
    let blinkStart = 1.1
    return adaptive(
        period: period, tolerances: [0.9, 0.8, 0.34], registration: .ground, events: blinkEvents(at: blinkStart + 0.07),
        parts,
        channels: { t in
            let w = 2 * Double.pi * t / period
            return [2.5 * sin(w), 1.5 * sin(w - 0.9), blink(at: t, start: blinkStart)]
        },
        { v in heldPose(1, sway: v[0], lag: v[1], lid: v[2]) })
}

// Climb (0.267 s loop at the physical 120 pt/s): a bounding scramble drawn as a gait in the key's frame, then
// turned 90° so the paws press the wall on the right. Fore paws reach together, hind paws push together.
let climbFrames = 8
let climbPeriod = Double(climbFrames * 2) / 60
let climbStride = 120 * climbPeriod / pointsPerPixel  // canvas px climbed per cycle
let climbDuty = 0.36

func climb(_ parts: Parts) -> [Frame] {
    let sweep = climbStride * climbDuty
    let touchdowns = ["nearFront": 0.0, "farFront": 0.08, "nearHind": 0.5, "farHind": 0.58]
    let turn = Rigid(pivot: (256, 256), angle: -90)
    return (0..<climbFrames).map { index in
        let phase = Double(index) / Double(climbFrames)
        let wave = 2 * Double.pi * phase
        var legs: [String: LegCommand] = [:]
        for (name, touchdown) in touchdowns {
            let p = fract(phase - touchdown)
            if p < climbDuty {
                legs[name] = .ground(u: sweep / 2 - p / climbDuty * sweep, lift: 0, paw: 0)
            } else {
                let q = (p - climbDuty) / (1 - climbDuty)
                legs[name] = .ground(
                    u: -sweep / 2 + sweep * smooth(q), lift: 14 * sin(Double.pi * q), paw: -20 * sin(Double.pi * q))
            }
        }
        let pose = Pose(
            body: Rigid(pivot: (256, 380), angle: 2 * sin(2 * wave), dy: 1.5 * cos(2 * wave)),
            head: 10 + 1.5 * sin(2 * wave + 0.5), tail: 12 + 4 * sin(wave - 1), legs: legs)
        return frame(parts, pose, global: turn, registration: .wall, duration: 2.0 / 60)
    }
}

// MARK: - V9 (M16): dance and cleanup

/// Paints a small tongue below the key's smile (mouth centre ≈ (456, 247) in rest coordinates); `amount` 0…1
/// pushes it out and down. Stays a painted overlay like the eyelids; the key itself is never edited.
func withTongue(_ head: Raster, amount: Double) -> Raster {
    guard amount > 0.02 else { return head }
    var out = head
    let centre: Point = (459, 248 + 4 * amount)
    let radiusX = 6.5
    let radiusY = 2 + 5.5 * amount
    for y in Int(centre.y - radiusY - 2)...Int(centre.y + radiusY + 2) {
        for x in Int(centre.x - radiusX - 2)...Int(centre.x + radiusX + 2) {
            let nx = (Double(x) + 0.5 - centre.x) / radiusX
            let ny = (Double(y) + 0.5 - centre.y) / radiusY
            // Only the lower half shows: the upper half stays behind the lip line.
            guard ny > -0.15 else { continue }
            let r = nx * nx + ny * ny
            guard r < 1 else { continue }
            let rim = r > 0.62 || (abs(nx) < 0.12 && ny < 0.55)  // outline and centre groove
            let light = Float(1 - 0.25 * max(0, ny))
            let c: (Float, Float, Float) = rim ? (0.62, 0.28, 0.33) : (0.93 * light, 0.5 * light, 0.55 * light)
            let a = Float(min(1, (1 - r) * 8)) * Float(min(1, amount * 3))
            let i = (y * size + x) * 4
            out.data[i] = c.0 * a + out.data[i] * (1 - a)
            out.data[i + 1] = c.1 * a + out.data[i + 1] * (1 - a)
            out.data[i + 2] = c.2 * a + out.data[i + 2] * (1 - a)
            out.data[i + 3] = a + out.data[i + 3] * (1 - a)
        }
    }
    return out
}

/// Monotone cubic (Fritsch–Butland) through equally spaced keys: continuous velocity, no overshoot past a key.
/// `periodic` wraps the ends (loops); otherwise the ends start and stop at rest.
func spline(_ keys: [Double], _ position: Double, periodic: Bool) -> Double {
    let count = keys.count - 1  // segments; for a loop keys.last == keys.first
    let p = periodic ? fract(position / Double(count)) * Double(count) : min(Double(count), max(0, position))
    let k = min(count - 1, Int(floor(p)))
    let t = p - Double(k)
    func slope(_ i: Int) -> Double {
        guard periodic || (i > 0 && i < count) else { return 0 }
        let before = keys[i] - keys[(i - 1 + count) % count]
        let after = keys[(i + 1) % (count + 1)] - keys[i]
        guard before * after > 0 else { return 0 }
        return 2 / (1 / before + 1 / after)
    }
    let m0 = slope(k)
    let m1 = slope(k + 1 == count && periodic ? 0 : k + 1)
    let t2 = t * t
    let t3 = t2 * t
    return (2 * t3 - 3 * t2 + 1) * keys[k] + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * keys[k + 1]
        + (t3 - t2) * m1
}

// Dance (1 s loop at 30 FPS, 30 drawings): in-place rocking sway, weight forward then back, with a bob on each
// beat, head nodding against the sway and the tail counterbalancing with follow-through. The near hind paw taps
// on the forward sway and the near fore paw on the back sway; every paw returns to its own contact (no skating).
// Keys every 5 drawings (neutral, sway, deep sway, centre, other sway, deep, neutral); drawing n sits at n/5.
let danceSway = [0, 0.55, 1, 0, -0.55, -1, 0]

func dance(_ parts: Parts) -> [Frame] {
    (0..<30).map { index in
        let position = Double(index) / 5
        let s = spline(danceSway, position, periodic: true)
        let lagged = spline(danceSway, position - 0.6, periodic: true)
        let beat = 2 * Double.pi * (Double(index) - 10) / 15  // dips at both deep sways
        let pose = Pose(
            body: Rigid(pivot: (256, 430), angle: 5 * s, dx: 4 * s, dy: 4 * (0.5 + 0.5 * cos(beat))),
            head: -8 * s + 3 * sin(beat - 0.8), headLift: 3 * (0.5 - 0.5 * cos(beat)), tail: 4 - 15 * lagged,
            legs: [
                "nearFront": .ground(u: 0, lift: 14 * pow(max(0, -s), 2), paw: -14 * pow(max(0, -s), 2)),
                "nearHind": .ground(u: 0, lift: 11 * pow(max(0, s), 2), paw: 10 * pow(max(0, s), 2)),
            ])
        return frame(parts, pose, registration: .none, duration: 1.0 / 30)
    }
}

// Cleanup (3 s once at 12 FPS, 36 drawings): settle into a supported crouch, lift the near fore paw to the
// muzzle, one lick (eyes closed), wipe the paw up the cheek toward the ear, lower it onto its own contact and
// return to a standing pose a breath away from the key. Keys every 6 drawings; drawing n (1…36) sits at n/6.
struct GroomKey {
    let dy, lean, head, headLift, tail, lid: Double
    let upper, lower, paw: Double  // near fore raise (zero = planted)
}

let groomKeys = [
    GroomKey(dy: 0, lean: 0, head: 0, headLift: 0, tail: 0, lid: 0, upper: 0, lower: 0, paw: 0),
    GroomKey(dy: 7, lean: -2, head: 4, headLift: -1, tail: 2, lid: 0.1, upper: 0, lower: 0, paw: 0),
    GroomKey(dy: 8, lean: -3, head: 7, headLift: -6, tail: 9, lid: 0.55, upper: -96, lower: -50, paw: -30),
    GroomKey(dy: 8, lean: -3.5, head: 9, headLift: -8, tail: 13, lid: 1, upper: -100, lower: -56, paw: -40),
    GroomKey(dy: 8, lean: -4, head: 11, headLift: -7, tail: 10, lid: 1, upper: -122, lower: -36, paw: -30),
    GroomKey(dy: 3, lean: -1, head: 4, headLift: -1, tail: 5, lid: 0.15, upper: 0, lower: 0, paw: 0),
    GroomKey(dy: 0.6, lean: 0, head: 0.6, headLift: 0, tail: 1.5, lid: 0, upper: 0, lower: 0, paw: 0),
]

func cleanup(_ parts: Parts) -> [Frame] {
    func channel(_ field: (GroomKey) -> Double, _ position: Double) -> Double {
        spline(groomKeys.map(field), position, periodic: false)
    }
    return (1...36).map { index in
        let p = Double(index) / 6
        let upper = channel(\.upper, p)
        let raise = LegCommand.raise(upper: upper, lower: channel(\.lower, p), paw: channel(\.paw, p))
        let pose = Pose(
            body: Rigid(pivot: (250, 472), angle: channel(\.lean, p), dy: channel(\.dy, p)), head: channel(\.head, p),
            headLift: channel(\.headLift, p), tail: channel(\.tail, p), lid: min(1, max(0, channel(\.lid, p))),
            tongue: p > 2 && p < 3 ? pow(sin(Double.pi * (p - 2)), 2) : 0, legs: ["nearFront": raise],
            foreInFront: upper < -1)
        return frame(parts, pose, registration: .none, duration: 5.0 / 60)
    }
}

// MARK: - Main

let arguments = CommandLine.arguments
guard arguments.count == 3 else { throw RigError("Expected repository root and new output directory") }
let root = URL(fileURLWithPath: arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
let key = try decode(root.appendingPathComponent("assets/characters/cat/walk/frames/walk_01.png"))
let parts = makeParts(key)
if ProcessInfo.processInfo.environment["RIG_PARTS"] != nil {
    let directory = output.appendingPathComponent("parts", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var named = ["head": parts.head, "tail": parts.tail, "torso": parts.torso]
    for (name, leg) in parts.legs {
        named["\(name)-lower"] = leg.lower
        named["\(name)-paw"] = leg.paw
        if let upper = leg.upper { named["\(name)-upper"] = upper }
    }
    for (name, part) in named { try encode(part, to: directory.appendingPathComponent("\(name).png")) }
}

var report: [String: Any] = ["source": "assets/characters/cat/walk/frames/walk_01.png"]
let builders: [(String, (Parts) -> [Frame])] = [
    ("walk", walk), ("curious", curious), ("idle", idle), ("jump-start", jumpStart), ("jump", jump), ("fall", fall),
    ("landing", landing), ("picked-up", pickedUp), ("held", held), ("climb", climb), ("dance", dance),
    ("cleanup", cleanup),
]
let selected =
    ProcessInfo.processInfo.environment["RIG_CLIPS"].map { $0.split(separator: ",").map(String.init) }
    ?? builders.prefix(10).map(\.0)
for name in selected where !builders.contains(where: { $0.0 == name }) { throw RigError("Unknown clip \(name)") }
for (clip, build) in builders where selected.contains(clip) {
    let frames = build(parts)
    let directory = output.appendingPathComponent("\(clip)/frames", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var entries: [[String: Any]] = []
    for (index, frame) in frames.enumerated() {
        let name = String(format: "%@_%02d.png", clip, index + 1)
        try encode(composite(frame.layers), to: directory.appendingPathComponent(name))
        var paws: [String: Any] = [:]
        for (leg, value) in frame.paws { paws[leg] = ["x": value.0.x, "y": value.0.y, "planted": value.1] }
        entries.append(["image": name, "duration": frame.duration, "events": frame.events, "paws": paws])
    }
    report[clip] = entries
}
let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("rig-report.json"))
print("pointsPerPixel", pointsPerPixel, "walk speed pt/s", walkStride * pointsPerPixel / walkPeriod)
