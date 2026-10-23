import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

@Suite("M11 edge climbing")
struct ClimbingWorldTests {
    static let dt = 1.0 / 60
    static let dock = Surface(id: .dock, kind: .dockTop, y: 64, minX: 0, maxX: 1470)
    static let floor = PetWorldTests.floor

    static func spriteRect(position: CGPoint, size: CGSize, frame: AnimationFrameRef) -> CGRect {
        let anchorX = frame.mirrored ? 1 - frame.anchor.x : frame.anchor.x
        return CGRect(
            x: position.x - anchorX * size.width,
            y: position.y - frame.anchor.y * size.height,
            width: size.width, height: size.height)
    }

    static func world() throws -> PetWorld {
        let screen = PetWorldTests.screen
        let manifest = CharacterManifest(
            id: "climber", displayName: "Climber", defaultAnimation: "walk",
            canvas: .init(width: 512, height: 512), displaySize: .init(width: 96, height: 96),
            anchor: .init(x: 0.5, y: 0.074),
            animations: [
                "walk": .init(fps: 9, frames: [.init(image: "walk.png")], nominalSpeed: 20),
                "climb": .init(
                    fps: 8, frames: [.init(image: "climb.png")], anchor: .init(x: 0.977, y: 0.5),
                    alignment: .right, interruptible: false),
                "fall": .init(fps: 10, frames: [.init(image: "fall.png")]),
            ])
        let definition = try CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
        var world = PetWorld(random: SeededRandomSource(seed: 17))
        world.apply(.screens([screen]))
        world.apply(.surfaces([dock, floor] + SurfaceMap.screenWalls(for: [screen])))
        world.spawn(definition)
        return world
    }

    @Test(arguments: [WallSide.left, .right])
    func walksIntoEitherWallClimbsAndFallsBackWithoutTeleport(side: WallSide) throws {
        var world = try Self.world()
        let wall = try #require(
            world.surfaces.surfaces.first { $0.kind == (side == .left ? .screenLeft : .screenRight) })
        let startX: CGFloat = side == .left ? 48 : 1422
        let facing: Facing = side == .left ? .left : .right
        PetWorldTests.set(&world, x: startX, facing: facing)
        let initial = world.pets[0]
        let initialSpriteRect = Self.spriteRect(
            position: initial.position, size: initial.size, frame: initial.animation.currentFrame)
        var events: [WorldEvent] = []
        world.step(dt: Self.dt, into: &events)
        #expect(world.pets[0].state.kind == .climbing)
        let climbingRect = Self.spriteRect(
            position: world.pets[0].position, size: world.pets[0].size,
            frame: world.pets[0].animation.currentFrame)
        #expect(abs(climbingRect.minX - initialSpriteRect.minX) <= 3)
        #expect(abs(climbingRect.minY - initialSpriteRect.minY) <= 0.001)
        #expect(world.pets[0].attachment?.surfaceID == wall.id)
        #expect(world.pets[0].position.x == wall.segment.start.x)
        #expect(world.pets[0].facing == (side == .left ? .left : .right))
        #expect(world.pets[0].animation.currentFrame.alignment == .right)
        #expect(world.pets[0].animation.currentFrame.anchor == .init(x: 0.977, y: 0.5))
        #expect(world.pets[0].animation.currentFrame.mirrored == (side == .left))

        let startingY = world.pets[0].position.y
        var previous = world.pets[0].position
        let topY =
            wall.maxY
            - (1 - CGFloat(world.pets[0].animation.currentFrame.anchor.y)) * world.pets[0].size.height
        for _ in 0..<500 where world.pets[0].state.kind == .climbing {
            previous = world.pets[0].position
            let previousRect = Self.spriteRect(
                position: previous, size: world.pets[0].size, frame: world.pets[0].animation.currentFrame)
            world.step(dt: Self.dt, into: &events)
            if world.pets[0].state.kind == .climbing {
                #expect(world.pets[0].position.x == wall.segment.start.x)
                #expect(world.pets[0].position.y >= previous.y)
                #expect(world.pets[0].position.y - previous.y <= 2.001)
            } else if world.pets[0].state.kind == .falling {
                let fallingRect = Self.spriteRect(
                    position: world.pets[0].position, size: world.pets[0].size,
                    frame: world.pets[0].animation.currentFrame)
                let ascent = min(CGFloat(120 * Self.dt), topY - previous.y)
                #expect(abs(fallingRect.minX - previousRect.minX) <= 0.001)
                #expect(abs(fallingRect.minY - (previousRect.minY + ascent)) <= 0.001)
            }
        }
        #expect(world.pets[0].state.kind == .falling)
        #expect(world.pets[0].position.y > startingY)

        previous = world.pets[0].position
        var landed = false
        for _ in 0..<180 where !landed {
            world.step(dt: Self.dt, into: &events)
            let current = world.pets[0].position
            #expect(abs(current.x - previous.x) <= 2.501)
            #expect(current.y <= previous.y)
            previous = current
            landed = world.pets[0].attachment != nil
        }
        #expect(landed)
        #expect(
            world.pets[0].attachment?.surfaceID == Self.dock.id || world.pets[0].attachment?.surfaceID == Self.floor.id)
        #expect(world.pets[0].state == .grounded(.landing))
        #expect(events.contains { if case .landed = $0 { true } else { false } })
    }

    @Test(arguments: [WallSide.left, .right])
    func removedWallDuringClimbDetachesTowardScreenInterior(side: WallSide) throws {
        var world = try Self.world()
        let screen = PetWorldTests.screen
        var surfaces = [Self.dock, Self.floor] + SurfaceMap.screenWalls(for: [screen])
        let wall = try #require(
            surfaces.first { $0.kind == (side == .left ? .screenLeft : .screenRight) })
        let y: CGFloat = 300
        world.pets[0].position = CGPoint(x: wall.segment.start.x, y: y)
        world.pets[0].attachment = SurfaceAttachment(surfaceID: wall.id, parameter: wall.parameter(atY: y))
        world.pets[0].state = .grounded(.climbing(wall: side))
        world.pets[0].facing = side == .left ? .left : .right
        world.pets[0].animation.setFacing(world.pets[0].facing)
        world.pets[0].animation.transition(AnimationRequest(clip: "climb", priority: 90))
        let id = world.pets[0].id
        surfaces.removeAll { $0.id == wall.id }
        world.apply(.surfaces(surfaces))
        let events = world.step(dt: Self.dt)
        #expect(events.contains(.surfaceLost(id, wall.id)))
        #expect(world.pets[0].state.kind == .falling)
        #expect(world.pets[0].attachment == nil)
        #expect(world.pets[0].velocity.dx == (side == .left ? 150 : -150))
        #expect(world.pets[0].facing == (side == .left ? .right : .left))
    }

    @Test func shortenedWallThatCannotContainThePetDetachesSafely() throws {
        var world = try Self.world()
        let side = WallSide.left
        let oldWall = try #require(world.surfaces.surfaces.first { $0.kind == .screenLeft })
        let y: CGFloat = 300
        world.pets[0].position = CGPoint(x: oldWall.segment.start.x, y: y)
        world.pets[0].attachment = SurfaceAttachment(surfaceID: oldWall.id, parameter: oldWall.parameter(atY: y))
        world.pets[0].state = .grounded(.climbing(wall: side))
        world.pets[0].facing = .left
        world.pets[0].animation.setFacing(.left)
        world.pets[0].animation.transition(AnimationRequest(clip: "climb", priority: 90))

        let tooShort = Surface(id: oldWall.id, kind: .screenLeft, x: oldWall.segment.start.x, minY: 0, maxY: 80)
        world.apply(.surfaces([Self.dock, Self.floor, tooShort]))
        let events = world.step(dt: Self.dt)

        #expect(events.contains(.surfaceLost(world.pets[0].id, oldWall.id)))
        #expect(world.pets[0].state.kind == .falling)
        #expect(world.pets[0].attachment == nil)
        #expect(world.pets[0].velocity.dx == 150)
    }
}
