import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

/// The test list of coordinate-system.md#unit-tests-t31 (AC-M3-01).
@Suite("CoordinateConverter")
struct CoordinateConverterTests {
    // MARK: Fixtures

    static func screen(
        _ id: UInt32, _ frame: CGRect, visibleInset: CGFloat = 0, scale: Double = 2, primary: Bool = false
    ) -> ScreenDescriptor {
        var visible = frame
        visible.origin.y += visibleInset
        visible.size.height -= visibleInset
        return ScreenDescriptor(
            id: ScreenID(id), frame: frame, visibleFrame: visible, backingScale: scale, isPrimary: primary)
    }

    static let laptop = screen(1, CGRect(x: 0, y: 0, width: 1440, height: 900), visibleInset: 65, primary: true)

    static func converter(_ screens: [ScreenDescriptor]) throws -> CoordinateConverter {
        try #require(CoordinateConverter(screens: screens))
    }

    // MARK: Construction

    @Test func noScreensMeansNoConverter() {
        #expect(CoordinateConverter(screens: []) == nil)
    }

    @Test func primaryIsTheFlaggedScreenOtherwiseTheFirst() throws {
        let external = Self.screen(2, CGRect(x: 1440, y: 0, width: 1920, height: 1080), primary: false)
        #expect(try Self.converter([external, Self.laptop]).primary.id == ScreenID(1))
        var unflagged = Self.laptop
        unflagged.isPrimary = false
        #expect(try Self.converter([external, unflagged]).primary.id == ScreenID(2))
    }

    // MARK: Single screen 1440 × 900

    @Test(
        "Quartz → global for points on a single 1440 × 900 screen",
        arguments: [
            (QuartzPoint(x: 0, y: 0), CGPoint(x: 0, y: 900)),  // top-left
            (QuartzPoint(x: 1440, y: 0), CGPoint(x: 1440, y: 900)),  // top-right
            (QuartzPoint(x: 0, y: 900), CGPoint(x: 0, y: 0)),  // bottom-left
            (QuartzPoint(x: 1440, y: 900), CGPoint(x: 1440, y: 0)),  // bottom-right
            (QuartzPoint(x: 720, y: 33), CGPoint(x: 720, y: 867)),  // just under a 33 pt menu bar
            (QuartzPoint(x: 100, y: 850), CGPoint(x: 100, y: 50)),  // Dock area
        ])
    func singleScreenPoints(quartz: QuartzPoint, global: CGPoint) throws {
        let converter = try Self.converter([Self.laptop])
        #expect(converter.globalPoint(fromQuartz: quartz) == global)
        #expect(converter.quartzPoint(fromGlobal: global) == quartz)
    }

    @Test func singleScreenRects() throws {
        let converter = try Self.converter([Self.laptop])
        // Menu bar strip at the top.
        let menuBar = QuartzRect(x: 0, y: 0, width: 1440, height: 33)
        #expect(converter.globalRect(fromQuartz: menuBar) == CGRect(x: 0, y: 867, width: 1440, height: 33))
        // Dock band at the bottom.
        let dock = QuartzRect(x: 300, y: 835, width: 840, height: 65)
        #expect(converter.globalRect(fromQuartz: dock) == CGRect(x: 300, y: 0, width: 840, height: 65))
        // Full screen maps onto itself.
        let full = QuartzRect(x: 0, y: 0, width: 1440, height: 900)
        #expect(converter.globalRect(fromQuartz: full) == Self.laptop.frame)
        for rect in [menuBar, dock, full] {
            #expect(converter.quartzRect(fromGlobal: converter.globalRect(fromQuartz: rect)) == rect)
        }
    }

    @Test func singleScreenOverlayIsIdentity() throws {
        let converter = try Self.converter([Self.laptop])
        let point = CGPoint(x: 700, y: 65)
        #expect(converter.overlayPoint(fromGlobal: point, on: Self.laptop) == point)
        #expect(converter.globalPoint(fromOverlay: point, on: Self.laptop) == point)
    }

    // MARK: Two screens

    /// Arrangements of a 1920 × 1080 @1x external display relative to the 1440 × 900 primary.
    enum Arrangement: CaseIterable, Sendable {
        case right, left, above, below

        var externalFrame: CGRect {
            switch self {
            case .right: CGRect(x: 1440, y: 0, width: 1920, height: 1080)
            case .left: CGRect(x: -1920, y: -180, width: 1920, height: 1080)
            case .above: CGRect(x: -240, y: 900, width: 1920, height: 1080)
            case .below: CGRect(x: 0, y: -1080, width: 1920, height: 1080)
            }
        }
    }

    @Test(arguments: Arrangement.allCases)
    func twoScreensRoundTripAndOverlayLocal(arrangement: Arrangement) throws {
        let external = Self.screen(2, arrangement.externalFrame, scale: 1)
        let converter = try Self.converter([Self.laptop, external])
        #expect(converter.primaryHeight == 900)

        let frame = external.frame
        let corners = [
            CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
            CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY),
            CGPoint(x: frame.midX, y: frame.midY),
        ]
        for global in corners {
            let quartz = converter.quartzPoint(fromGlobal: global)
            #expect(quartz.y == 900 - global.y)
            #expect(converter.globalPoint(fromQuartz: quartz) == global)
        }
        #expect(converter.globalRect(fromQuartz: converter.quartzRect(fromGlobal: frame)) == frame)

        // Overlay-local origin is the external screen's bottom-left, whatever the sign of its origin.
        let bottomLeft = CGPoint(x: frame.minX, y: frame.minY)
        #expect(converter.overlayPoint(fromGlobal: bottomLeft, on: external) == .zero)
        let inside = CGPoint(x: frame.minX + 100, y: frame.minY + 40)
        #expect(converter.overlayPoint(fromGlobal: inside, on: external) == CGPoint(x: 100, y: 40))
        #expect(converter.globalPoint(fromOverlay: CGPoint(x: 100, y: 40), on: external) == inside)
        #expect(
            converter.overlayRect(fromGlobal: CGRect(origin: inside, size: CGSize(width: 96, height: 96)), on: external)
                == CGRect(x: 100, y: 40, width: 96, height: 96))
        #expect(converter.screen(containing: inside)?.id == external.id)
        #expect(converter.screen(containing: CGPoint(x: 10, y: 10))?.id == Self.laptop.id)
    }

    @Test func screenAboveThePrimaryHasNegativeQuartzY() throws {
        let external = Self.screen(2, Arrangement.above.externalFrame, scale: 1)
        let converter = try Self.converter([Self.laptop, external])
        // Global y greater than H → Quartz y negative.
        #expect(converter.quartzPoint(fromGlobal: CGPoint(x: 0, y: 1980)) == QuartzPoint(x: 0, y: -1080))
        #expect(
            converter.quartzRect(fromGlobal: external.frame) == QuartzRect(x: -240, y: -1080, width: 1920, height: 1080)
        )
    }

    @Test func secondaryTallerThanPrimaryStillUsesPrimaryHeight() throws {
        // The tall screen is listed first but is not primary: H must be 900, not 2560.
        let tall = Self.screen(2, CGRect(x: 1440, y: -830, width: 1440, height: 2560), scale: 1)
        let converter = try Self.converter([tall, Self.laptop])
        #expect(converter.primaryHeight == 900)
        #expect(converter.globalPoint(fromQuartz: QuartzPoint(x: 1500, y: 0)) == CGPoint(x: 1500, y: 900))
        // The tall screen's bottom edge, 830 pt below the primary's bottom.
        #expect(converter.quartzPoint(fromGlobal: CGPoint(x: 1500, y: -830)) == QuartzPoint(x: 1500, y: 1730))
        #expect(converter.globalRect(fromQuartz: converter.quartzRect(fromGlobal: tall.frame)) == tall.frame)
    }

    // MARK: Mixed backing scales

    @Test func mixedBackingScalesKeepPointsAndSizePixelsForTheMaximum() throws {
        let external = Self.screen(2, Arrangement.right.externalFrame, scale: 1)
        let converter = try Self.converter([external, Self.laptop])
        #expect(converter.maximumBackingScale == 2)
        #expect(converter.pixelSize(forPointSize: CGSize(width: 96, height: 96)) == CGSize(width: 192, height: 192))
        // Points are the same on both screens: a 96 pt rect is 96 pt in overlay-local space on each.
        let rect = CGRect(x: 1500, y: 10, width: 96, height: 96)
        #expect(converter.overlayRect(fromGlobal: rect, on: external).size == rect.size)
        #expect(converter.quartzRect(fromGlobal: rect).size == rect.size)

        let oneX = try Self.converter([external])
        #expect(oneX.pixelSize(forPointSize: CGSize(width: 96, height: 96)) == CGSize(width: 96, height: 96))
    }

    // MARK: Mirrored hit mask lookup

    /// 8 × 8 mask of a 96 pt sprite at (500, 65). The left paw is the bottom-left cell of the image
    /// (column 1, row 7) when facing right.
    static let spriteRect = CGRect(x: 500, y: 65, width: 96, height: 96)
    static let leftPawGlobal = CGPoint(x: 500 + 18, y: 65 + 4)

    @Test func leftPawHitsTheCorrectCellInBothFacings() {
        let facingRight = CoordinateConverter.maskCell(
            at: Self.leftPawGlobal, spriteRect: Self.spriteRect, isMirrored: false, columns: 8, rows: 8)
        #expect(facingRight == MaskCell(column: 1, row: 7))

        // Mirrored, the same image cell is drawn at the mirrored position on screen.
        let mirroredScreenPoint = CGPoint(x: Self.spriteRect.maxX - 18, y: Self.leftPawGlobal.y)
        let facingLeft = CoordinateConverter.maskCell(
            at: mirroredScreenPoint, spriteRect: Self.spriteRect, isMirrored: true, columns: 8, rows: 8)
        #expect(facingLeft == MaskCell(column: 1, row: 7))

        // And the original screen point now shows the opposite side of the image.
        let sameScreenPointMirrored = CoordinateConverter.maskCell(
            at: Self.leftPawGlobal, spriteRect: Self.spriteRect, isMirrored: true, columns: 8, rows: 8)
        #expect(sameScreenPointMirrored == MaskCell(column: 6, row: 7))
    }

    @Test func maskLookupCornersAndOutside() {
        func cell(_ x: CGFloat, _ y: CGFloat, mirrored: Bool = false) -> MaskCell? {
            CoordinateConverter.maskCell(
                at: CGPoint(x: x, y: y), spriteRect: Self.spriteRect, isMirrored: mirrored, columns: 8, rows: 8)
        }
        #expect(cell(500, 65) == MaskCell(column: 0, row: 7))  // bottom-left = last image row
        #expect(cell(595.9, 160.9) == MaskCell(column: 7, row: 0))  // top-right
        #expect(cell(500, 65, mirrored: true) == MaskCell(column: 7, row: 7))
        #expect(cell(499.9, 100) == nil)
        #expect(cell(596, 100) == nil)
        #expect(cell(550, 161) == nil)
        #expect(cell(550, 64.9) == nil)
        #expect(
            CoordinateConverter.maskCell(
                at: CGPoint(x: 550, y: 100), spriteRect: Self.spriteRect, isMirrored: false, columns: 0, rows: 8) == nil
        )
    }

    // MARK: Property test

    @Test func randomRectsRoundTripExactly() throws {
        let external = Self.screen(2, Arrangement.left.externalFrame, scale: 1)
        let converter = try Self.converter([Self.laptop, external])
        var random = SplitMix64(seed: 0x5EED_CA75)
        for _ in 0..<10_000 {
            let screen = random.next() % 2 == 0 ? Self.laptop : external
            let frame = screen.frame
            let width = CGFloat(random.unit()) * frame.width
            let height = CGFloat(random.unit()) * frame.height
            let rect = CGRect(
                x: frame.minX + CGFloat(random.unit()) * (frame.width - width),
                y: frame.minY + CGFloat(random.unit()) * (frame.height - height),
                width: width, height: height)

            let back = converter.globalRect(fromQuartz: converter.quartzRect(fromGlobal: rect))
            #expect(abs(back.minX - rect.minX) <= 1e-9)
            #expect(abs(back.minY - rect.minY) <= 1e-9)
            #expect(abs(back.width - rect.width) <= 1e-9)
            #expect(abs(back.height - rect.height) <= 1e-9)

            let local = converter.overlayRect(fromGlobal: rect, on: screen)
            let global = converter.globalPoint(fromOverlay: local.origin, on: screen)
            #expect(abs(global.x - rect.minX) <= 1e-9)
            #expect(abs(global.y - rect.minY) <= 1e-9)
        }
    }
}

/// Deterministic generator for the property test (SplitMix64).
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }
}
