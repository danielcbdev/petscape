import CoreGraphics
import Foundation
import Testing

@testable import PetScapeCore

/// T7.1: pure airborne integration and pose-independent contact geometry (physics-engine.md).
@Suite("PhysicsStepper")
struct PhysicsStepperTests {
    @Test func gravityFromRest() throws {
        let result = try #require(
            PhysicsStepper.integrate(
                position: CGPoint(x: -100, y: 100), velocity: .zero, acceleration: .zero,
                dt: 1.0 / 60, tuning: PhysicsTuning()))
        #expect(result.position.x == -100)
        #expect(abs(result.position.y - 99.33333333333333) < 1e-6)
        #expect(result.velocity == CGVector(dx: 0, dy: -40))
    }

    @Test func horizontalAcceleration() throws {
        let result = try #require(
            PhysicsStepper.integrate(
                position: .zero, velocity: .zero, acceleration: CGVector(dx: 60, dy: 2400),
                dt: 1.0 / 60, tuning: PhysicsTuning()))
        #expect(result.velocity == CGVector(dx: 1, dy: 0))
        #expect(abs(result.position.x - 0.016666666666666666) < 1e-9)
        #expect(result.position.y == 0)
    }

    @Test func velocityAccumulatesAcrossSteps() throws {
        let first = try #require(
            PhysicsStepper.integrate(
                position: CGPoint(x: 10, y: 100), velocity: CGVector(dx: -20, dy: 0), acceleration: .zero,
                dt: 1.0 / 60, tuning: PhysicsTuning()))
        let second = try #require(
            PhysicsStepper.integrate(
                position: first.position, velocity: first.velocity, acceleration: .zero,
                dt: 1.0 / 60, tuning: PhysicsTuning()))
        #expect(second.velocity == CGVector(dx: -20, dy: -80))
        #expect(abs(second.position.x - 9.333333333333334) < 1e-9)
        #expect(abs(second.position.y - 98) < 1e-9)
    }

    @Test func terminalClamp() throws {
        let result = try #require(
            PhysicsStepper.integrate(
                position: CGPoint(x: 0, y: 100), velocity: CGVector(dx: 30, dy: -1790), acceleration: .zero,
                dt: 1.0 / 60, tuning: PhysicsTuning()))
        #expect(result.velocity == CGVector(dx: 30, dy: -1800))
        #expect(result.position == CGPoint(x: 0.5, y: 70))
    }

    @Test func ascentIsNotCappedByTerminalFallSpeed() throws {
        let result = try #require(
            PhysicsStepper.integrate(
                position: .zero, velocity: CGVector(dx: 0, dy: 2000), acceleration: .zero,
                dt: 1.0 / 60, tuning: PhysicsTuning()))
        #expect(result.velocity.dy == 1960)
        #expect(abs(result.position.y - 32.666666666666664) < 1e-9)
    }

    @Test func customGravityAndFallLimitAreApplied() throws {
        let result = try #require(
            PhysicsStepper.integrate(
                position: .zero, velocity: CGVector(dx: 0, dy: -9), acceleration: .zero,
                dt: 1.0 / 60, tuning: PhysicsTuning(gravity: 120, terminalFallSpeed: 10)))
        #expect(result.velocity.dy == -10)
        #expect(abs(result.position.y + 0.16666666666666666) < 1e-9)
    }

    @Test(arguments: [0.0, -1, Double.nan, .infinity, -.infinity, 0.5, 1.0 / 60 + 2e-9])
    func invalidStepIsRejected(dt: Double) {
        #expect(
            PhysicsStepper.integrate(
                position: .zero, velocity: .zero, acceleration: .zero,
                dt: dt, tuning: PhysicsTuning()) == nil)
    }

    @Test func stepWithinToleranceNormalizesToFixedStep() throws {
        let result = try #require(
            PhysicsStepper.integrate(
                position: .zero, velocity: .zero, acceleration: .zero,
                dt: 1.0 / 60 + 0.5e-9, tuning: PhysicsTuning()))
        #expect(result.velocity.dy == -40)
    }

    @Test func smallerStepIsIntegratedWithoutHiddenSubsteps() throws {
        let result = try #require(
            PhysicsStepper.integrate(
                position: .zero, velocity: .zero, acceleration: .zero,
                dt: 1.0 / 120, tuning: PhysicsTuning()))
        #expect(result.velocity.dy == -20)
        #expect(abs(result.position.y + 0.16666666666666666) < 1e-9)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func nonfiniteInputIsRejected(value: Double) {
        let component = CGFloat(value)
        let cases: [(CGPoint, CGVector, CGVector)] = [
            (CGPoint(x: component, y: 0), .zero, .zero),
            (CGPoint(x: 0, y: component), .zero, .zero),
            (.zero, CGVector(dx: component, dy: 0), .zero),
            (.zero, CGVector(dx: 0, dy: component), .zero),
            (.zero, .zero, CGVector(dx: component, dy: 0)),
            (.zero, .zero, CGVector(dx: 0, dy: component)),
        ]
        for (position, velocity, acceleration) in cases {
            #expect(
                PhysicsStepper.integrate(
                    position: position, velocity: velocity, acceleration: acceleration,
                    dt: 1.0 / 60, tuning: PhysicsTuning()) == nil)
        }
    }

    @Test func numericOverflowIsRejectedBeforeClamping() {
        #expect(
            PhysicsStepper.integrate(
                position: .zero, velocity: CGVector(dx: 0, dy: -CGFloat.greatestFiniteMagnitude),
                acceleration: CGVector(dx: 0, dy: -CGFloat.greatestFiniteMagnitude),
                dt: 1.0 / 60, tuning: PhysicsTuning()) == nil)
        #expect(
            PhysicsStepper.integrate(
                position: CGPoint(x: CGFloat.greatestFiniteMagnitude, y: 0),
                velocity: CGVector(dx: CGFloat.greatestFiniteMagnitude, dy: 0), acceleration: .zero,
                dt: 1.0 / 60, tuning: PhysicsTuning()) == nil)
    }

    @Test(arguments: [0.0, -1, Double.nan, .infinity])
    func invalidTuningIsRejected(value: Double) {
        let configurations = [
            PhysicsTuning(gravity: value), PhysicsTuning(terminalFallSpeed: value),
            PhysicsTuning(contactTolerance: CGFloat(value)), PhysicsTuning(maxAirborneDuration: value),
        ]
        for tuning in configurations {
            #expect(
                PhysicsStepper.integrate(
                    position: .zero, velocity: .zero, acceleration: .zero,
                    dt: 1.0 / 60, tuning: tuning) == nil)
        }
    }

    @Test func geometryIndependentOfPose() throws {
        let geometry = try #require(ContactGeometry(displaySize: CGSize(width: 96, height: 96), scale: 1))
        let scaled = try #require(ContactGeometry(displaySize: CGSize(width: 96, height: 96), scale: 1.5))
        #expect(geometry.halfWidth == 24)
        #expect(geometry.height == 60)
        #expect(scaled.halfWidth == 36)
        #expect(scaled.height == 90)
    }

    @Test func geometryUsesEachLogicalDimensionIndependently() throws {
        let geometry = try #require(ContactGeometry(displaySize: CGSize(width: 120, height: 80), scale: 0.5))
        #expect(geometry.halfWidth == 15)
        #expect(geometry.height == 25)
    }

    @Test(arguments: [0.0, -1, Double.nan, .infinity])
    func invalidGeometryIsRejected(value: Double) {
        #expect(ContactGeometry(displaySize: CGSize(width: value, height: 96), scale: 1) == nil)
        #expect(ContactGeometry(displaySize: CGSize(width: 96, height: value), scale: 1) == nil)
        #expect(ContactGeometry(displaySize: CGSize(width: 96, height: 96), scale: value) == nil)
    }

    @Test func geometryOverflowIsRejected() {
        #expect(
            ContactGeometry(displaySize: CGSize(width: 96, height: 96), scale: .greatestFiniteMagnitude) == nil)
    }
}
