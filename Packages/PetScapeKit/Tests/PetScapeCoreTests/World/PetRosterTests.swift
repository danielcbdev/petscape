import Foundation
import Testing

@testable import PetScapeCore

@Suite("PetWorld character roster")
struct PetRosterTests {
    @Test func duplicateCharacterIDsCannotSpawnTwoActivePets() throws {
        var (world, firstID) = try PetWorldTests.makeWorld()
        let definition = try Fixtures.walkingDefinition()
        let duplicateID = world.spawn(definition)

        #expect(duplicateID == firstID)
        #expect(world.pets.count == 1)
    }

    @Test func removingOnePetPreservesTheOtherPetAndItsSimulationState() throws {
        var (world, firstID) = try PetWorldTests.makeWorld()
        var secondDefinition = try Fixtures.walkingDefinition()
        secondDefinition.id = CharacterID("second")
        let secondID = world.spawn(secondDefinition)
        world.apply(.setActivity(secondID, .idle))
        _ = world.step(dt: PetWorldTests.dt)
        let before = try #require(world.pet(secondID))

        let removedFirst = world.removePet(firstID)
        #expect(removedFirst)
        #expect(world.pet(firstID) == nil)
        #expect(world.pet(secondID)?.state == before.state)
        #expect(world.pet(secondID)?.position == before.position)
        #expect(world.pets.map(\.id) == [secondID])
        let removedAgain = world.removePet(firstID)
        #expect(!removedAgain)
    }

    @Test(arguments: [
        PetState.held, .airborne(.falling), .grounded(.preparingJump), .grounded(.climbing(wall: .left)),
        .grounded(.dancing(.manual)), .grounded(.cleaning),
    ])
    func removingOnePetDuringBusyPhasesPreservesTheOtherAndItsEvents(_ state: PetState) throws {
        var (world, removedID) = try PetWorldTests.makeWorld()
        PetWorldTests.set(&world, x: 400, facing: .right, state: state)
        var secondDefinition = try Fixtures.walkingDefinition()
        secondDefinition.id = CharacterID("second")
        let keptID = world.spawn(secondDefinition)
        world.pets[1].state = .walking
        world.pets[1].stateElapsed = 0
        world.apply(.setActivity(keptID, .idle))
        let keptBefore = try #require(world.pet(keptID))

        let didRemove = world.removePet(removedID)
        #expect(didRemove)

        var events: [WorldEvent] = []
        world.drainEvents(into: &events)
        #expect(world.pet(removedID) == nil)
        #expect(world.pet(keptID)?.state == keptBefore.state)
        #expect(world.pet(keptID)?.position == keptBefore.position)
        #expect(events.allSatisfy { $0.petID != removedID })
        #expect(events.contains { $0.petID == keptID })
    }

    @Test func autonomousChoicesAndDurationsAdvanceIndependentlyPerPet() throws {
        var (world, firstID) = try PetWorldTests.makeWorld(seed: 2026)
        var secondDefinition = try Fixtures.walkingDefinition()
        secondDefinition.id = CharacterID("second")
        let secondID = world.spawn(secondDefinition)
        world.apply(.configureBehavior(AutonomySettings(isEnabled: true)))

        for _ in 0..<1_800 { _ = world.step(dt: PetWorldTests.dt) }

        let first = try #require(world.pet(firstID))
        let second = try #require(world.pet(secondID))
        #expect(first.activityDecisionCount > 0)
        #expect(second.activityDecisionCount > 0)
        #expect(first.activityDuration != second.activityDuration || first.activity != second.activity)
    }

    @Test func petCommandsStatesFramesAndDanceTimersRemainIndependent() throws {
        var (world, firstID) = try PetWorldTests.makeWorld(seed: 431)
        PetWorldTests.set(&world, x: 400, facing: .left)
        var secondDefinition = try Fixtures.walkingDefinition(frameCount: 12, fps: 15)
        secondDefinition.id = CharacterID("second")
        let secondID = world.spawn(secondDefinition)
        world.pets[1].state = .walking
        world.pets[1].stateElapsed = 0
        world.apply(.configureBehavior(AutonomySettings(isEnabled: true)))

        world.apply(.requestDance(firstID))
        world.apply(.setActivity(secondID, .idle))
        #expect(world.pet(firstID)?.state == .grounded(.dancing(.manual)))
        #expect(world.pet(secondID)?.state == .grounded(.idle))

        for _ in 0..<30 { _ = world.step(dt: PetWorldTests.dt) }
        let first = try #require(world.pet(firstID))
        let second = try #require(world.pet(secondID))
        #expect(first.animation.currentFrame.frameIndex != second.animation.currentFrame.frameIndex)
        #expect((5...30).contains(first.specialBehaviorDuration))
        #expect(second.specialBehaviorDuration == 0)

        world.apply(.stopDance(firstID))
        #expect(world.pet(firstID)?.state == .grounded(.idle))
        #expect(world.pet(secondID)?.state == second.state)
        #expect(world.pet(secondID)?.animation.currentFrame.frameIndex == second.animation.currentFrame.frameIndex)
    }
}
