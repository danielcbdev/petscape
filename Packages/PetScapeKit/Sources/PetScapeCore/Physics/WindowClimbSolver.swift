import CoreGraphics

enum WindowClimbSolver {
    static func solve(
        from start: CGPoint, target: Surface, targetY: CGFloat, surfaces: SurfaceMap,
        geometry: ContactGeometry, screen: ScreenDescriptor, physics: PhysicsTuning,
        tuning: JumpTuning, visualMargin: CGFloat
    ) -> WindowClimbPlan? {
        guard physics.isValid, target.isUsable, target.isVertical,
            target.kind == .windowLeft || target.kind == .windowRight,
            start.x.isFinite, start.y.isFinite, targetY.isFinite,
            targetY >= target.minY + geometry.height,
            targetY <= target.maxY,
            visualMargin.isFinite, visualMargin >= 0
        else { return nil }

        let margin = max(geometry.halfWidth, visualMargin)
        let lowerX = screen.frame.minX + margin
        let upperX = screen.frame.maxX - margin
        let ceiling = min(screen.frame.maxY, screen.visibleFrame.maxY)
        guard lowerX <= upperX, start.x >= lowerX, start.x <= upperX,
            start.y >= screen.frame.minY, start.y + geometry.height <= ceiling
        else { return nil }

        let h = FixedStepAccumulator.defaultStep
        let count = Int(tuning.maxFlightDuration / h)
        var best: WindowClimbPlan?
        var bestApex = CGFloat.infinity
        for steps in 2...count {
            let duration = Double(steps) * h
            let vx = Double(target.segment.start.x - start.x) / duration
            let vy =
                (Double(targetY - start.y) + physics.gravity * h * h * Double(steps * (steps + 1)) / 2)
                / duration
            guard vx.isFinite, vy.isFinite, abs(vx) <= tuning.maxHorizontalSpeed,
                vy > physics.gravity * duration
            else { continue }

            var position = start
            var velocity = CGVector(dx: vx, dy: vy)
            var apex = start.y
            var found: PhysicsStepResult?
            for _ in 1...steps {
                guard
                    let result = PhysicsStepper.airborne(
                        position: position, velocity: velocity, acceleration: .zero, dt: h,
                        tuning: physics, surfaces: surfaces, geometry: geometry,
                        visualRange: lowerX...upperX, wallTarget: target)
                else { break }
                position = result.position
                velocity = result.velocity
                apex = max(apex, position.y)
                guard position.x >= lowerX, position.x <= upperX, position.y >= screen.frame.minY,
                    position.y + geometry.height <= ceiling
                else { break }
                if result.landedSurfaceID == target.id {
                    found = result
                    break
                }
                if result.landedSurfaceID != nil { break }
            }
            guard let found, apex < bestApex else { continue }
            bestApex = apex
            best = WindowClimbPlan(
                target: target, initialVelocity: CGVector(dx: vx, dy: vy), contactPosition: found.position)
        }
        return best
    }
}
