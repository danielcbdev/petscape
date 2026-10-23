import CoreGraphics

/// Pure bounded kinematics in canonical y-up points (physics-engine.md, ADR-0016).
/// No clock, pet storage, surface recovery or renderer dependency.
enum PhysicsStepper {
    /// Attached motion has no gravity; policy chooses an intent, this function computes displacement.
    static func attached(
        position: CGPoint, on surface: Surface, margin: CGFloat, intent: MovementIntent, dt: Double
    ) -> PhysicsStepResult? {
        guard surface.isUsable, position.x.isFinite, margin.isFinite, margin >= 0,
            dt.isFinite, dt > 0, dt <= FixedStepAccumulator.defaultStep + FixedStepAccumulator.tolerance
        else { return nil }
        let speed: CGFloat
        switch intent {
        case .hold: speed = 0
        case .walk(let value, let facing):
            guard value.isFinite, value >= 0 else { return nil }
            speed = CGFloat(value) * (facing == .right ? 1 : -1)
        case .airborne: return nil
        }
        let range = surface.walkableRange(margin: margin)
        let nextX = position.x + speed * CGFloat(dt)
        guard nextX.isFinite else { return nil }
        let edge = speed > 0 ? nextX >= range.upperBound : speed < 0 && nextX <= range.lowerBound
        let x = min(max(nextX, range.lowerBound), range.upperBound)
        return PhysicsStepResult(
            position: CGPoint(x: x, y: surface.y), velocity: CGVector(dx: edge ? 0 : speed, dy: 0),
            attachment: SurfaceAttachment(surfaceID: surface.id, parameter: surface.parameter(atX: x)),
            edgeReached: edge)
    }

    /// Moves a pet's contact point upward on a vertical screen wall, clamped before the canvas exits the host.
    static func climbing(
        position: CGPoint, on wall: Surface, verticalRange: ClosedRange<CGFloat>, speed: Double, dt: Double
    ) -> PhysicsStepResult? {
        guard wall.isUsable, wall.isVertical, speed.isFinite, speed > 0,
            position.x.isFinite, position.y.isFinite, dt.isFinite, dt > 0,
            dt <= FixedStepAccumulator.defaultStep + FixedStepAccumulator.tolerance,
            verticalRange.lowerBound.isFinite, verticalRange.upperBound.isFinite,
            verticalRange.lowerBound <= verticalRange.upperBound
        else { return nil }
        let nextY = position.y + CGFloat(speed * dt)
        guard nextY.isFinite else { return nil }
        let y = min(max(nextY, verticalRange.lowerBound), verticalRange.upperBound)
        let reachedTop = y >= verticalRange.upperBound
        let point = CGPoint(x: wall.segment.start.x, y: y)
        return PhysicsStepResult(
            position: point, velocity: CGVector(dx: 0, dy: reachedTop ? 0 : CGFloat(speed)),
            attachment: SurfaceAttachment(surfaceID: wall.id, parameter: wall.parameter(atY: y)),
            edgeReached: reachedTop)
    }

    /// Integration and first-hit resolution shared by the live world and M8 trajectory replay.
    static func airborne(
        position: CGPoint, velocity: CGVector, acceleration: CGVector, dt: Double,
        tuning: PhysicsTuning, surfaces: SurfaceMap, geometry: ContactGeometry,
        visualRange: ClosedRange<CGFloat>, wallTarget: Surface? = nil
    ) -> PhysicsStepResult? {
        guard
            let result = integrate(
                position: position, velocity: velocity, acceleration: acceleration, dt: dt, tuning: tuning)
        else { return nil }
        if let wallTarget, wallTarget.isVertical, wallTarget.isUsable,
            (wallTarget.kind == .windowLeft || wallTarget.kind == .windowRight),
            let point = wallContact(from: position, to: result.position, with: wallTarget, geometry: geometry),
            surfaces.surface(wallTarget.id) == wallTarget
        {
            return PhysicsStepResult(
                position: point, velocity: .zero,
                attachment: SurfaceAttachment(surfaceID: wallTarget.id, parameter: wallTarget.parameter(atY: point.y)),
                landedSurfaceID: wallTarget.id)
        }
        guard result.velocity.dy < 0,
            let contact = surfaces.firstLanding(
                from: position, to: result.position, geometry: geometry,
                visualRange: visualRange, tolerance: tuning.contactTolerance),
            let surface = surfaces.surface(contact.surfaceID)
        else { return result }
        return PhysicsStepResult(
            position: contact.position, velocity: .zero,
            attachment: SurfaceAttachment(surfaceID: surface.id, parameter: surface.parameter(atX: contact.position.x)),
            landedSurfaceID: surface.id)
    }

    private static func wallContact(
        from start: CGPoint, to end: CGPoint, with wall: Surface, geometry: ContactGeometry
    ) -> CGPoint? {
        let x = wall.segment.start.x
        let dx = end.x - start.x
        let crossed =
            wall.kind == .windowLeft
            ? start.x <= x && end.x >= x
            : start.x >= x && end.x <= x
        guard crossed, dx != 0 else { return nil }
        let fraction = (x - start.x) / dx
        let y = start.y + (end.y - start.y) * fraction
        guard fraction >= 0, fraction <= 1, y >= wall.minY + geometry.height, y <= wall.maxY else { return nil }
        return CGPoint(x: x, y: y)
    }

    /// Semi-implicit airborne step. Invalid inputs/results return nil without mutating caller state.
    static func integrate(
        position: CGPoint, velocity: CGVector, acceleration: CGVector, dt: Double, tuning: PhysicsTuning
    ) -> PhysicsStepResult? {
        let step = FixedStepAccumulator.defaultStep
        let tolerance = FixedStepAccumulator.tolerance
        guard dt.isFinite, dt > 0, dt <= step + tolerance, tuning.isValid,
            position.x.isFinite, position.y.isFinite,
            velocity.dx.isFinite, velocity.dy.isFinite,
            acceleration.dx.isFinite, acceleration.dy.isFinite
        else { return nil }

        let h = CGFloat(abs(dt - step) <= tolerance ? step : dt)
        let verticalAcceleration = acceleration.dy - CGFloat(tuning.gravity)
        let nextDX = velocity.dx + acceleration.dx * h
        let nextDY = velocity.dy + verticalAcceleration * h
        // Check before clamping: a numerical overflow is not a legitimate terminal-speed fall.
        guard verticalAcceleration.isFinite, nextDX.isFinite, nextDY.isFinite else { return nil }

        let nextVelocity = CGVector(dx: nextDX, dy: max(nextDY, -CGFloat(tuning.terminalFallSpeed)))
        let nextPosition = CGPoint(
            x: position.x + nextVelocity.dx * h,
            y: position.y + nextVelocity.dy * h)
        guard nextPosition.x.isFinite, nextPosition.y.isFinite else { return nil }

        return PhysicsStepResult(position: nextPosition, velocity: nextVelocity)
    }
}
