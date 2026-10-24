import CoreGraphics
import Testing

@testable import PetScapeCore

@Suite("M18 character replacement")
struct CharacterReplacementTests {
    @Test func replacementKeepsContactFacingAndSurfaceButResetsIdentityAnimationAndTransientState() throws {
        var (world, oldID) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: 400, facing: .left)
        world.pets[0].pendingDockCleanup = true
        world.pets[0].stationaryElapsed = 4
        var definition = try Fixtures.walkingDefinition()
        definition.id = CharacterID("second")
        let old = world.pets[0]
        let accepted = world.replaceSettledCharacter(with: definition, scale: 1)
        #expect(accepted)
        let pet = try #require(world.pets.first)
        #expect(pet.id != oldID && pet.characterID == CharacterID("second"))
        #expect(pet.position == old.position && pet.facing == old.facing && pet.attachment == old.attachment)
        #expect(pet.velocity == .zero && pet.animation.currentFrame.frameIndex == 0)
        #expect(!pet.pendingDockCleanup && pet.stationaryElapsed == 0 && pet.interactionID == nil)
        var events: [WorldEvent] = []
        world.drainEvents(into: &events)
        #expect(events.isEmpty)
    }

    @Test(arguments: [
        PetState.held, .airborne(.falling), .grounded(.preparingJump), .grounded(.climbing(wall: .left)),
        .grounded(.dancing(.manual)), .grounded(.cleaning),
    ])
    func busyStatesRejectWithoutMutatingThePet(_ state: PetState) throws {
        var (world, _) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: 400, facing: .right, state: state)
        let before = world.snapshot()
        let accepted = world.replaceSettledCharacter(with: try Fixtures.walkingDefinition(), scale: 1)
        #expect(!accepted)
        #expect(world.snapshot() == before)
    }

    @Test(arguments: [true, false])
    func oversizedGeometryAtSurfaceMidpointIsRejectedWithoutUsingTheClampedMidpointFallback(_ wide: Bool) throws {
        var (world, _) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: PetWorldTests.screen.frame.midX, facing: .right)
        let before = world.snapshot()
        var definition = try Fixtures.walkingDefinition()
        definition.displaySize = wide ? .init(width: 2000, height: 96) : .init(width: 96, height: 2000)
        let accepted = world.replaceSettledCharacter(with: definition, scale: 1)
        #expect(!accepted)
        #expect(world.snapshot() == before)
    }

    @Test(arguments: [false, true])
    func replacementUsesTheCurrentDisplayAndSurfaceRatherThanThePrimaryDisplay(_ windowTop: Bool) throws {
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
        let accepted = world.replaceSettledCharacter(with: try Fixtures.walkingDefinition(), scale: 1)
        #expect(accepted)
        #expect(world.pets[0].attachment == before.attachment && world.pets[0].position == before.position)
    }

    @Test func largerGeometryDoesNotMoveThePetToMakeItFit() throws {
        var (world, _) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: 60, facing: .right)
        let before = world.snapshot()
        var definition = try Fixtures.walkingDefinition()
        definition.displaySize = .init(width: 500, height: 500)
        let accepted = world.replaceSettledCharacter(with: definition, scale: 1)
        #expect(!accepted)
        #expect(world.snapshot() == before)
    }
}
