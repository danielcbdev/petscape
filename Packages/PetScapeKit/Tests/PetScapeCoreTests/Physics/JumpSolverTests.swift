import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

@Suite("Discrete jump solver")
struct JumpSolverTests {
    static let screen = PetWorldTests.screen
    static let floor = PetWorldTests.floor
    static func solve(
        x: CGFloat = 600, y: CGFloat = 0, targetX: CGFloat = 600, targetY: CGFloat = 0,
        targetID: SurfaceID = PetWorldTests.floor.id, surfaces: [Surface]? = nil
    ) throws -> JumpPlan? {
        JumpSolver.solve(
            from: CGPoint(x: x, y: y), target: CGPoint(x: targetX, y: targetY),
            targetSurfaceID: targetID, surfaces: SurfaceMap(surfaces ?? [Self.floor]),
            geometry: try #require(ContactGeometry(displaySize: CGSize(width: 96, height: 96), scale: 1)),
            screen: Self.screen, physics: PhysicsTuning(), tuning: JumpTuning(), visualMargin: 48)
    }
    @Test func verticalReturnsWithinOnePoint() throws {
        let plan = try #require(try Self.solve())
        #expect(plan.initialVelocity.dy > 0)
        #expect(plan.initialVelocity.dx == 0)
        #expect(abs(plan.impactPosition.x - 600) <= 1)
        #expect(plan.impactPosition.y == 0)
        #expect(plan.apexRise <= 120)
        #expect(plan.flightDuration <= 2)
    }
    @Test(arguments: [CGFloat(-80), 80])
    func shortJumpBothDirections(offset: CGFloat) throws {
        let plan = try #require(try Self.solve(targetX: 600 + offset))
        #expect(abs(plan.impactPosition.x - (600 + offset)) <= 1)
        #expect(abs(plan.initialVelocity.dx) <= 160)
    }
    @Test func raisedTargetReached() throws {
        let dock = Surface(id: .dock, kind: .dockTop, y: 64, minX: 0, maxX: 1470)
        let plan = try #require(try Self.solve(targetY: 64, targetID: .dock, surfaces: [Self.floor, dock]))
        #expect(plan.target == dock)
        #expect(plan.impactPosition.y == 64)
    }
    @Test func tooHighOrFarRejected() throws {
        #expect(try Self.solve(targetX: 681) == nil)
        let high = Surface(id: .dock, kind: .dockTop, y: 125, minX: 0, maxX: 1470)
        #expect(try Self.solve(targetY: 125, targetID: .dock, surfaces: [Self.floor, high]) == nil)
        #expect(try Self.solve(targetX: 0) == nil)
    }
    @Test func interveningSurfaceRejected() throws {
        let dock = Surface(id: .dock, kind: .dockTop, y: 64, minX: 0, maxX: 1470)
        #expect(try Self.solve(y: 64, targetY: 0, surfaces: [Self.floor, dock]) == nil)
    }
    @Test func ceilingRejected() throws {
        let elevated = Surface(id: .dock, kind: .dockTop, y: 880, minX: 0, maxX: 1470)
        #expect(try Self.solve(y: 880, targetY: 880, targetID: .dock, surfaces: [elevated]) == nil)
    }
    @Test func nanAndUnsupportedTargetRejected() throws {
        #expect(try Self.solve(x: .nan) == nil)
        #expect(try Self.solve(targetID: SurfaceID("missing")) == nil)
    }
}
