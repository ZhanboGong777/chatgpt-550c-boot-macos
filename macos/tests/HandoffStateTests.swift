@main
struct HandoffStateTests {
    static var checks = 0

    static func expect(_ state: inout HandoffState, _ event: HandoffEvent,
                       _ effects: [HandoffEffect], _ phase: HandoffPhase,
                       file: StaticString = #file, line: UInt = #line) {
        let actual = state.handle(event)
        precondition(actual == effects, "Unexpected effects for \(event): \(actual)", file: file, line: line)
        precondition(state.phase == phase, "Unexpected phase for \(event): \(state.phase)", file: file, line: line)
        checks += 1
    }

    static func terminalIsIdempotent(_ state: inout HandoffState, _ phase: HandoffPhase) {
        for event in HandoffEvent.allCases {
            expect(&state, event, [], phase)
        }
    }

    static func main() {
        // A warm target stays hidden until the animation ends, and reveals once.
        var warm = HandoffState()
        expect(&warm, .targetReady, [], .playing)
        expect(&warm, .targetReady, [], .playing)
        expect(&warm, .playbackEnded, [.revealTarget], .revealing)
        expect(&warm, .playbackEnded, [], .revealing)
        expect(&warm, .targetReady, [], .revealing)
        expect(&warm, .revealCompleted, [.dismissOverlay], .done)
        terminalIsIdempotent(&warm, .done)

        // A cold target keeps the final animation frame visible while preparing.
        var cold = HandoffState()
        expect(&cold, .playbackEnded, [.waitForTarget], .waiting)
        expect(&cold, .playbackEnded, [], .waiting)
        expect(&cold, .targetReady, [.revealTarget], .revealing)
        expect(&cold, .targetReady, [], .revealing)
        expect(&cold, .revealCompleted, [.dismissOverlay], .done)
        terminalIsIdempotent(&cold, .done)

        // Readiness belongs to a process; losing it before playback ends must
        // restore waiting rather than reveal a stale target.
        var lostBeforePlaybackEnd = HandoffState()
        expect(&lostBeforePlaybackEnd, .targetUnavailable, [], .playing)
        expect(&lostBeforePlaybackEnd, .targetReady, [], .playing)
        expect(&lostBeforePlaybackEnd, .targetUnavailable, [], .playing)
        expect(&lostBeforePlaybackEnd, .playbackEnded, [.waitForTarget], .waiting)
        expect(&lostBeforePlaybackEnd, .targetUnavailable, [], .waiting)
        expect(&lostBeforePlaybackEnd, .targetReady, [.revealTarget], .revealing)
        expect(&lostBeforePlaybackEnd, .revealCompleted, [.dismissOverlay], .done)
        terminalIsIdempotent(&lostBeforePlaybackEnd, .done)

        // A replacement during reveal keeps the overlay until the new window
        // is ready. Stale reveal completion and repeated loss cannot dismiss it.
        var replacedDuringReveal = HandoffState()
        expect(&replacedDuringReveal, .targetReady, [], .playing)
        expect(&replacedDuringReveal, .playbackEnded, [.revealTarget], .revealing)
        expect(&replacedDuringReveal, .targetUnavailable, [.waitForTarget], .waiting)
        expect(&replacedDuringReveal, .revealCompleted, [], .waiting)
        expect(&replacedDuringReveal, .targetUnavailable, [], .waiting)
        expect(&replacedDuringReveal, .targetReady, [.revealTarget], .revealing)
        expect(&replacedDuringReveal, .revealCompleted, [.dismissOverlay], .done)
        terminalIsIdempotent(&replacedDuringReveal, .done)

        // Disappearance can recover, but cannot bypass the bounded wait.
        var replacementTimeout = HandoffState()
        expect(&replacementTimeout, .targetReady, [], .playing)
        expect(&replacementTimeout, .playbackEnded, [.revealTarget], .revealing)
        expect(&replacementTimeout, .targetUnavailable, [.waitForTarget], .waiting)
        expect(&replacementTimeout, .waitingExpired, [.dismissOverlay, .showFailure], .failed)
        terminalIsIdempotent(&replacementTimeout, .failed)

        // Preparation failure is deferred until playback has finished.
        var earlyFailure = HandoffState()
        expect(&earlyFailure, .targetFailed, [], .playing)
        expect(&earlyFailure, .targetUnavailable, [], .playing)
        expect(&earlyFailure, .targetReady, [], .playing)
        expect(&earlyFailure, .playbackEnded, [.dismissOverlay, .showFailure], .failed)
        terminalIsIdempotent(&earlyFailure, .failed)

        // A target that fails after preparation also cannot be revealed.
        var changedResult = HandoffState()
        expect(&changedResult, .targetReady, [], .playing)
        expect(&changedResult, .targetFailed, [], .playing)
        expect(&changedResult, .playbackEnded, [.dismissOverlay, .showFailure], .failed)

        var lateFailure = HandoffState()
        expect(&lateFailure, .playbackEnded, [.waitForTarget], .waiting)
        expect(&lateFailure, .targetFailed, [.dismissOverlay, .showFailure], .failed)
        terminalIsIdempotent(&lateFailure, .failed)

        var timeout = HandoffState()
        expect(&timeout, .waitingExpired, [], .playing)
        expect(&timeout, .revealCompleted, [], .playing)
        expect(&timeout, .playbackEnded, [.waitForTarget], .waiting)
        expect(&timeout, .waitingExpired, [.dismissOverlay, .showFailure], .failed)
        terminalIsIdempotent(&timeout, .failed)

        // Cancellation never produces reveal or target-termination effects.
        var cancelledPlaying = HandoffState()
        expect(&cancelledPlaying, .cancelled, [.dismissOverlay], .cancelled)
        terminalIsIdempotent(&cancelledPlaying, .cancelled)

        var cancelledWaiting = HandoffState()
        expect(&cancelledWaiting, .playbackEnded, [.waitForTarget], .waiting)
        expect(&cancelledWaiting, .cancelled, [.dismissOverlay], .cancelled)
        terminalIsIdempotent(&cancelledWaiting, .cancelled)

        var cancelledRevealing = HandoffState()
        expect(&cancelledRevealing, .targetReady, [], .playing)
        expect(&cancelledRevealing, .playbackEnded, [.revealTarget], .revealing)
        expect(&cancelledRevealing, .cancelled, [.dismissOverlay], .cancelled)
        terminalIsIdempotent(&cancelledRevealing, .cancelled)

        var failedRevealing = HandoffState()
        expect(&failedRevealing, .targetReady, [], .playing)
        expect(&failedRevealing, .playbackEnded, [.revealTarget], .revealing)
        expect(&failedRevealing, .targetFailed, [.dismissOverlay, .showFailure], .failed)
        terminalIsIdempotent(&failedRevealing, .failed)

        print("PASS HandoffState: \(checks) transition and exactly-once checks")
    }
}
