import Foundation
import Testing

@testable import PetScapeCore

@Suite("AnimationController")
struct AnimationControllerTests {
    private func makeController() throws -> AnimationController {
        AnimationController(definition: try Fixtures.definition("full-featured"))
    }

    @Test func startsWithTheDefaultClipFacingTheDefaultDirection() throws {
        let controller = try makeController()
        #expect(controller.player.clip.name == "walk")
        #expect(controller.priority == 0)
        #expect(controller.facing == .left)
        #expect(
            controller.currentFrame
                == AnimationFrameRef(clip: "walk", frameIndex: 0, mirrored: false, anchor: .init(x: 0.5, y: 0.1)))
    }

    // MARK: Priority and interruptibility

    @Test func equalOrHigherPriorityReplacesTheClip() throws {
        var controller = try makeController()
        let accepted1 = controller.request(AnimationRequest(clip: "sit", priority: 10))
        #expect(accepted1)
        #expect(controller.player.clip.name == "sit")
        let accepted2 = controller.request(AnimationRequest(clip: "climb", priority: 10))
        #expect(accepted2)
        #expect(controller.player.clip.name == "climb")
    }

    @Test func lowerPriorityIsRejected() throws {
        var controller = try makeController()
        controller.request(AnimationRequest(clip: "sit", priority: 50))
        let accepted3 = controller.request(AnimationRequest(clip: "walk", priority: 49))
        #expect(!accepted3)
        #expect(controller.player.clip.name == "sit")
        #expect(controller.priority == 50)
    }

    @Test func aNonInterruptibleClipYieldsOnlyToCriticalRequests() throws {
        var controller = try makeController()
        controller.request(AnimationRequest(clip: "sit-down", priority: 10))
        let accepted4 = controller.request(AnimationRequest(clip: "walk", priority: 89))
        #expect(!accepted4)
        #expect(controller.player.clip.name == "sit-down")
        let accepted5 = controller.request(AnimationRequest(clip: "walk", priority: AnimationRequest.criticalPriority))
        #expect(accepted5)
        #expect(controller.player.clip.name == "walk")
    }

    @Test func aFinishedClipAcceptsAnyRequest() throws {
        var controller = try makeController()
        controller.request(AnimationRequest(clip: "yawn", priority: 50))
        _ = controller.advance(by: 1)
        #expect(controller.player.isFinished)
        let accepted6 = controller.request(AnimationRequest(clip: "walk", priority: 0))
        #expect(accepted6)
        #expect(controller.player.clip.name == "walk")
    }

    // MARK: Restarting

    @Test func requestingThePlayingClipContinuesUnlessRestartIsSet() throws {
        var controller = try makeController()
        _ = controller.advance(by: 0.25)
        #expect(controller.player.frameIndex == 2)
        controller.request(AnimationRequest(clip: "walk"))
        #expect(controller.player.frameIndex == 2)
        controller.request(AnimationRequest(clip: "walk", restart: true))
        #expect(controller.player.frameIndex == 0)
    }

    // MARK: Chaining

    @Test func aOnceClipChainsIntoNextInTheSameStep() throws {
        var controller = try makeController()
        controller.request(AnimationRequest(clip: "sit-down", priority: 10))
        let events = controller.advance(by: 0.35)  // sit-down lasts 0.3 s; 0.05 s carries into "sit"

        #expect(
            events == [
                AnimationEvent(clip: "sit-down", frameIndex: 1, kind: .frame("contact")),
                AnimationEvent(clip: "sit-down", frameIndex: 1, kind: .finished),
            ])
        #expect(controller.player.clip.name == "sit")
        #expect(controller.requestedClip == "sit")
        #expect(controller.priority == 10)
        #expect(controller.player.frameIndex == 0)
        _ = controller.advance(by: 0.2)  // 0.25 s into sit (4 fps) → frame 1
        #expect(controller.player.frameIndex == 1)
    }

    @Test func chainedClipsKeepThePlaybackRate() throws {
        var controller = try makeController()
        controller.rate = 2
        controller.request(AnimationRequest(clip: "sit-down", priority: 10))
        _ = controller.advance(by: 0.15)
        #expect(controller.player.clip.name == "sit")
        #expect(controller.rate == 2)
    }

    // MARK: Fallbacks

    @Test func missingClipsResolveThroughFallbacks() throws {
        var controller = try makeController()
        controller.request(AnimationRequest(clip: "sit", priority: 5))
        let accepted7 = controller.request(AnimationRequest(clip: "broken", priority: 5))
        #expect(accepted7)  // broken → sit
        #expect(controller.player.clip.name == "sit")
        let accepted8 = controller.request(AnimationRequest(clip: "fall", priority: 5))
        #expect(accepted8)  // fall → jump → walk
        #expect(controller.player.clip.name == "walk")
        #expect(controller.requestedClip == "fall")
        let accepted9 = controller.request(AnimationRequest(clip: "no-such-clip", priority: 5))
        #expect(accepted9)
        #expect(controller.player.clip.name == "walk")
    }

    // MARK: Facing

    @Test func turningMirrorsAMirrorableClip() throws {
        var controller = try makeController()
        controller.setFacing(.right)
        #expect(controller.player.clip.name == "walk")
        #expect(controller.currentFrame.mirrored)
        controller.setFacing(.left)
        #expect(!controller.currentFrame.mirrored)
    }

    @Test func turningSwitchesToAVariantAtTheSameFrame() throws {
        var controller = try makeController()
        controller.request(AnimationRequest(clip: "climb", priority: 5))
        _ = controller.advance(by: 0.2)  // 6 fps → frame 1
        #expect(controller.player.frameIndex == 1)

        controller.setFacing(.right)
        #expect(controller.player.clip.name == "walk-right")
        #expect(controller.player.frameIndex == 1)
        #expect(!controller.isMirrored)

        controller.setFacing(.left)
        #expect(controller.player.clip.name == "climb")
        #expect(controller.requestedClip == "climb")
    }

    @Test func requestsUseTheCurrentFacing() throws {
        var controller = try makeController()
        controller.setFacing(.right)
        controller.request(AnimationRequest(clip: "climb", priority: 5))
        #expect(controller.player.clip.name == "walk-right")
    }
}
