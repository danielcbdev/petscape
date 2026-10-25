import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("M20 character addition")
struct CharacterReplacementTests {
    @Test func addingCharacterPreservesExistingIdentityPositionFacingStateAndAnimation() throws {
        var (world, oldID) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: 400, facing: .left)
        world.pets[0].pendingDockCleanup = true
        world.pets[0].stationaryElapsed = 4
        _ = world.pets[0].animation.advance(by: 0.1)
        var definition = try Fixtures.walkingDefinition()
        definition.id = CharacterID("second")
        let old = world.pets[0]

        let newID = world.spawn(definition)
        let preserved = try #require(world.pet(oldID))
        #expect(newID != oldID && world.pet(newID)?.characterID == CharacterID("second"))
        #expect(preserved.position == old.position && preserved.facing == old.facing)
        #expect(preserved.attachment == old.attachment && preserved.state == old.state)
        #expect(preserved.animation.currentFrame == old.animation.currentFrame)
        #expect(preserved.pendingDockCleanup && preserved.stationaryElapsed == 4)
        #expect(world.pets.count == 2)
    }

    @Test(arguments: [
        PetState.held, .airborne(.falling), .grounded(.preparingJump), .grounded(.climbing(wall: .left)),
        .grounded(.dancing(.manual)), .grounded(.cleaning),
    ])
    func addingDuringBusyStateDoesNotInterruptTheExistingPet(_ state: PetState) throws {
        var (world, _) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: 400, facing: .right, state: state)
        let before = world.pets[0]
        var definition = try Fixtures.walkingDefinition()
        definition.id = CharacterID("second")

        let newID = world.spawn(definition)
        #expect(world.pets.count == 2)
        #expect(world.pet(before.id)?.state == before.state)
        #expect(world.pet(before.id)?.position == before.position)
        #expect(world.pet(before.id)?.interactionID == before.interactionID)
        #expect(world.pet(newID)?.characterID == CharacterID("second"))
    }

    @Test(arguments: [true, false])
    func oversizedNewCharacterDoesNotMoveTheExistingPet(_ wide: Bool) throws {
        var (world, _) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: PetWorldTests.screen.frame.midX, facing: .right)
        let before = world.pets[0]
        var definition = try Fixtures.walkingDefinition()
        definition.displaySize = wide ? .init(width: 2000, height: 96) : .init(width: 96, height: 2000)
        definition.id = CharacterID("oversized")

        let newID = world.spawn(definition)
        #expect(world.pet(before.id)?.position == before.position)
        #expect(world.pet(before.id)?.attachment == before.attachment)
        #expect(world.pet(newID)?.state == .spawning)
    }

    @Test(arguments: [false, true])
    func addedPetUsesItsOwnPlacementOnTheCurrentDisplayAndSurface(_ windowTop: Bool) throws {
        let second = ScreenDescriptor(
            id: ScreenID(2), frame: CGRect(x: 1470, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 1470, y: 70, width: 1470, height: 853), backingScale: 1, isPrimary: false)
        let surface =
            windowTop
            ? Surface(id: SurfaceID("secondary-window"), kind: .windowTop, y: 300, minX: 1670, maxX: 2740)
            : Surface.screenBottom(of: second)
        var (world, _) = try PetWorldTests.makeWorld(surfaces: [surface])
        world.apply(.screens([PetWorldTests.screen, second]))
        PetWorldTests.set(&world, x: 1900, facing: .left)
        let before = world.pets[0]
        var definition = try Fixtures.walkingDefinition()
        definition.id = CharacterID("second")

        let id = world.spawn(definition)
        #expect(world.pets[0].attachment == before.attachment && world.pets[0].position == before.position)
        #expect(world.pet(id)?.attachment?.surfaceID == surface.id)
    }

    @Test func largerCharacterDoesNotReplaceOrMoveTheExistingPet() throws {
        var (world, _) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: 60, facing: .right)
        let before = world.pets[0]
        var definition = try Fixtures.walkingDefinition()
        definition.displaySize = .init(width: 500, height: 500)
        definition.id = CharacterID("larger")

        _ = world.spawn(definition)
        #expect(world.pet(before.id)?.position == before.position)
        #expect(world.pet(before.id)?.attachment == before.attachment)
    }
}
