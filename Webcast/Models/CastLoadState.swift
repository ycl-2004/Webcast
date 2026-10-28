import Foundation

enum CastLoadEvent {
    case started(UUID, BrowserPlaybackContext?), confirmed(UUID), reset
}

struct BrowserPlaybackContext: Equatable {
    let document: UUID
    let mediaRevision: UUID
    let url: URL?
}

/// Created at selection time; connection delays and retries must not replace its origin.
struct CastIntent {
    let candidate: VideoCandidate
    let origin: BrowserPlaybackContext?
}

struct PendingCast {
    private(set) var intent: CastIntent?
    mutating func select(_ value: CastIntent) { intent = value }
    mutating func cancel() { intent = nil }
    mutating func take() -> CastIntent? {
        defer { intent = nil }
        return intent
    }
}

/// A command acknowledgement is not proof that the requested media reached the screen.
struct CastLoadState {
    enum Playback { case waiting, ready, failed }
    enum Observation: Equatable { case confirmed(UUID), failed }
    private enum Phase { case idle, loading, failed }

    private var phase: Phase = .idle
    private var acknowledged = false
    private var deadline: Date?
    private(set) var attemptID: UUID?
    private(set) var lastCandidate: VideoCandidate?
    private(set) var canRetry = false
    var isLoading: Bool { phase == .loading }

    mutating func begin(_ candidate: VideoCandidate, now: Date = Date()) -> UUID {
        let id = UUID()
        attemptID = id
        lastCandidate = candidate
        phase = .loading
        acknowledged = false
        canRetry = false
        deadline = now.addingTimeInterval(45)
        return id
    }

    @discardableResult
    mutating func acknowledge(_ id: UUID) -> Bool {
        guard attemptID == id else { return false }
        acknowledged = true
        return true
    }

    @discardableResult
    mutating func fail(_ id: UUID, retryable: Bool) -> Bool {
        guard attemptID == id else { return false }
        attemptID = nil
        deadline = nil
        phase = .failed
        canRetry = retryable
        return true
    }

    mutating func observe(contentID: String?, playback: Playback) -> Observation? {
        guard let id = attemptID, acknowledged, let candidate = lastCandidate else { return nil }
        // Preserve the full signed URL; a status for previous media must not confirm a new load.
        let matches = contentID == candidate.url.absoluteString
        if playback == .ready, matches {
            attemptID = nil
            deadline = nil
            phase = .idle
            canRetry = false
            return .confirmed(id)
        }
        if playback == .failed, matches {
            fail(id, retryable: true)
            return .failed
        }
        return nil
    }

    /// Runtime failures are retryable only when the receiver identifies the media we loaded.
    mutating func playbackFailed(contentID: String?) -> Bool {
        guard attemptID == nil, let candidate = lastCandidate, contentID == candidate.id else { return false }
        phase = .failed
        canRetry = true
        return true
    }

    /// Stop indefinite loading UI; a late matching acknowledgement/status may still confirm it.
    mutating func expire(now: Date = Date()) -> Bool {
        guard isLoading, let deadline, now >= deadline else { return false }
        phase = .failed
        canRetry = true
        return true
    }

    mutating func reset() { self = CastLoadState() }
}

/// A delayed receiver confirmation must not pause a different page or a reloaded document.
struct BrowserPlaybackHandoff {
    private var pending: (attempt: UUID, origin: BrowserPlaybackContext)?

    mutating func arm(_ attempt: UUID, origin: BrowserPlaybackContext?) {
        pending = origin.map { (attempt, $0) }
    }

    mutating func confirm(_ attempt: UUID, current: BrowserPlaybackContext) -> Bool {
        guard let pending, pending.attempt == attempt else { return false }
        self.pending = nil
        return pending.origin == current && current.url != nil
    }

    mutating func reset() { pending = nil }
}
