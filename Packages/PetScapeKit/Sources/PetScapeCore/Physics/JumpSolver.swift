import CoreGraphics
import Foundation

/// Bounded discrete candidate search, run on request rather than per frame (ADR-0017).
enum JumpSolver {
    static func solve(
        from start: CGPoint, target: CGPoint, targetSurfaceID: SurfaceID, surfaces: SurfaceMap,
        geometry: ContactGeometry, screen: ScreenDescriptor, physics: PhysicsTuning,
        tuning: JumpTuning, visualMargin: CGFloat = 0
    ) -> JumpPlan? {
        guard physics.isValid, start.x.isFinite, start.y.isFinite, target.x.isFinite, target.y.isFinite,
            visualMargin.isFinite, visualMargin >= 0,
            let destination = surfaces.surface(targetSurfaceID), destination.isUsable,
            abs(target.y - destination.y) <= physics.contactTolerance,
            abs(target.x - start.x) <= tuning.maxHorizontalDisplacement,
            target.y + CGFloat(tuning.clearance) <= start.y + CGFloat(tuning.maxApexRise)
        else { return nil }
        let margin = max(geometry.halfWidth, visualMargin)
        let lower = screen.frame.minX + margin
        let upper = screen.frame.maxX - margin
        let ceiling = min(screen.frame.maxY, screen.visibleFrame.maxY)
        guard lower.isFinite, upper.isFinite, ceiling.isFinite, lower <= upper,
            start.x >= lower, start.x <= upper, start.y >= screen.frame.minY,
            start.y + geometry.height <= ceiling,
            target.x >= max(lower, destination.minX + geometry.halfWidth),
            target.x <= min(upper, destination.maxX - geometry.halfWidth)
        else { return nil }
        let h = FixedStepAccumulator.defaultStep
        let count = Int(tuning.maxFlightDuration / h)
        var best: JumpPlan?
        var bestScore = Double.infinity
        let preferredY = max(start.y, target.y) + CGFloat(tuning.preferredApexHeight)
        for steps in 2...count {
            let duration = Double(steps) * h
            let vy =
                (Double(target.y - start.y) + physics.gravity * h * h * Double(steps * (steps + 1)) / 2)
                / duration
            let vx = Double(target.x - start.x) / duration
            guard vy.isFinite, vx.isFinite, vy > 0, abs(vx) <= tuning.maxHorizontalSpeed,
                vy - physics.gravity * duration < 0
            else { continue }
            var position = start
            var velocity = CGVector(dx: vx, dy: vy)
            var apex = start.y
            for tick in 1...steps {
                guard
                    let result = PhysicsStepper.airborne(
                        position: position, velocity: velocity, acceleration: .zero, dt: h,
                        tuning: physics, surfaces: surfaces, geometry: geometry, visualRange: lower...upper)
                else { break }
                position = result.position
                velocity = result.velocity
                apex = max(apex, position.y)
                guard position.x >= lower, position.x <= upper, position.y >= screen.frame.minY,
                    position.y + geometry.height <= ceiling,
                    apex - start.y <= CGFloat(tuning.maxApexRise) + physics.contactTolerance
                else { break }
                if let landed = result.landedSurfaceID {
                    if landed == targetSurfaceID, abs(position.x - target.x) <= tuning.targetTolerance,
                        apex >= max(start.y, target.y) + CGFloat(tuning.clearance)
                    {
                        let score = abs(Double(apex - preferredY))
                        if score < bestScore - FixedStepAccumulator.tolerance {
                            bestScore = score
                            best = JumpPlan(
                                requestedTarget: target, target: destination, initialVelocity: CGVector(dx: vx, dy: vy),
                                impactPosition: position, flightDuration: Double(tick) * h, apexRise: apex - start.y)
                        }
                    }
                    break
                }
            }
        }
        return best
    }
}
