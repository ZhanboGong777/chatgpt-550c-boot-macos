// Pure playback/target synchronization. The host owns timers and window actions.
enum HandoffPhase: Equatable {
    case playing, waiting, revealing, done, cancelled, failed
}

enum HandoffEvent: CaseIterable {
    case playbackEnded, targetReady, targetUnavailable, targetFailed, waitingExpired, cancelled, revealCompleted
}

enum HandoffEffect: Equatable {
    case waitForTarget, revealTarget, showFailure, dismissOverlay
}

struct HandoffState {
    private enum Preparation { case pending, ready, failed }
    private var preparation = Preparation.pending
    private(set) var phase = HandoffPhase.playing

    init() {}

    mutating func handle(_ event: HandoffEvent) -> [HandoffEffect] {
        switch phase {
        case .done, .cancelled, .failed:
            return []
        case .playing, .waiting, .revealing:
            break
        }

        switch event {
        case .cancelled:
            phase = .cancelled
            return [.dismissOverlay]

        case .targetReady:
            guard preparation != .failed else { return [] }
            preparation = .ready
            guard phase == .waiting else { return [] }
            phase = .revealing
            return [.revealTarget]

        case .targetUnavailable:
            // A replaced or disappearing process revokes its readiness, while
            // an actual launch failure remains final.
            guard preparation != .failed else { return [] }
            preparation = .pending
            guard phase == .revealing else { return [] }
            phase = .waiting
            return [.waitForTarget]

        case .targetFailed:
            preparation = .failed
            guard phase != .playing else { return [] }
            return fail()

        case .playbackEnded:
            guard phase == .playing else { return [] }
            switch preparation {
            case .pending:
                phase = .waiting
                return [.waitForTarget]
            case .ready:
                phase = .revealing
                return [.revealTarget]
            case .failed:
                return fail()
            }

        case .waitingExpired:
            guard phase == .waiting else { return [] }
            return fail()

        case .revealCompleted:
            guard phase == .revealing else { return [] }
            phase = .done
            return [.dismissOverlay]
        }
    }

    private mutating func fail() -> [HandoffEffect] {
        phase = .failed
        // The failure UI belongs above the desktop, after the overlay is removed.
        return [.dismissOverlay, .showFailure]
    }
}
