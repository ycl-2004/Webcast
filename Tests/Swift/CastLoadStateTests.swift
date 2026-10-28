import XCTest
import GoogleCast
import Combine
@testable import Webcast

final class CastLoadStateTests: XCTestCase {
    func testAcknowledgementAndMatchingReadyStatusAreBothRequired() {
        var state = CastLoadState()
        let candidate = VideoCandidate.testStream
        let id = state.begin(candidate)
        XCTAssertNil(state.observe(contentID: candidate.id, playback: .ready))
        state.acknowledge(id)
        XCTAssertNil(state.observe(contentID: nil, playback: .failed))
        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.observe(contentID: candidate.id, playback: .waiting))
        XCTAssertEqual(state.observe(contentID: candidate.id, playback: .ready), .confirmed(id))
        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.observe(contentID: candidate.id, playback: .ready))
    }

    func testStatusForOldMediaOrDifferentSignedURLCannotConfirmOrFailNewLoad() {
        var state = CastLoadState()
        let id = state.begin(.testStream)
        state.acknowledge(id)
        XCTAssertNil(state.observe(contentID: VideoCandidate.testStream.id + "?token=old", playback: .ready))
        XCTAssertNil(state.observe(contentID: "https://cdn.example/old.mp4", playback: .failed))
        XCTAssertTrue(state.isLoading)
    }

    func testSupersededCallbacksDoNotChangeNewAttempt() {
        var state = CastLoadState()
        let old = state.begin(.testStream)
        let current = state.begin(.testStream)
        XCTAssertFalse(state.acknowledge(old))
        XCTAssertFalse(state.fail(old, retryable: true))
        XCTAssertEqual(state.attemptID, current)
        XCTAssertTrue(state.isLoading)
        XCTAssertFalse(state.canRetry)
    }

    func testFailedLoadCanRetryAndNewAttemptClearsFailure() {
        var state = CastLoadState()
        let id = state.begin(.testStream)
        state.acknowledge(id)
        XCTAssertEqual(state.observe(contentID: VideoCandidate.testStream.id, playback: .failed), .failed)
        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.canRetry)
        XCTAssertNotNil(state.lastCandidate)
        state.begin(.testStream)
        XCTAssertFalse(state.canRetry)
        XCTAssertTrue(state.isLoading)
    }

    func testTimeoutOccursOnceAndLateMatchingPlaybackCanStillConfirm() {
        var state = CastLoadState()
        let now = Date(timeIntervalSince1970: 100)
        let id = state.begin(.testStream, now: now)
        state.acknowledge(id)
        XCTAssertFalse(state.expire(now: now.addingTimeInterval(44)))
        XCTAssertTrue(state.expire(now: now.addingTimeInterval(45)))
        XCTAssertFalse(state.expire(now: now.addingTimeInterval(46)))
        XCTAssertTrue(state.canRetry)
        XCTAssertEqual(state.observe(contentID: VideoCandidate.testStream.id, playback: .ready), .confirmed(id))
        XCTAssertFalse(state.canRetry)
    }

    func testResetAndCancellationRemoveRetryAndPendingConfirmation() {
        var state = CastLoadState()
        let id = state.begin(.testStream)
        state.fail(id, retryable: false)
        XCTAssertFalse(state.canRetry)
        XCTAssertFalse(state.isLoading)
        state.reset()
        XCTAssertNil(state.lastCandidate)
        XCTAssertNil(state.observe(contentID: VideoCandidate.testStream.id, playback: .ready))
    }

    func testRuntimePlaybackFailureCanRetryOnlyTheConfirmedMedia() {
        var state = CastLoadState()
        let id = state.begin(.testStream)
        state.acknowledge(id)
        XCTAssertFalse(state.playbackFailed(contentID: VideoCandidate.testStream.id))
        _ = state.observe(contentID: VideoCandidate.testStream.id, playback: .ready)
        XCTAssertFalse(state.playbackFailed(contentID: nil))
        XCTAssertFalse(state.playbackFailed(contentID: "https://cdn.example/other.mp4"))
        XCTAssertTrue(state.playbackFailed(contentID: VideoCandidate.testStream.id))
        XCTAssertTrue(state.canRetry)
    }

    @MainActor func testSDKRequestCompletionWaitsForMatchingPlaybackAndEmitsOneConfirmation() {
        let manager = CastManager()
        var confirmations = 0
        let subscription = manager.loadEvents.sink { event in
            if case .confirmed = event { confirmations += 1 }
        }
        let request = GCKRequest.application()
        manager.trackLoadRequest(request, candidate: .testStream)
        request.complete()
        XCTAssertTrue(manager.isLoading)
        XCTAssertEqual(confirmations, 0)
        manager.receiveLoadStatus(contentID: "https://cdn.example/other.mp4", playback: .ready)
        XCTAssertTrue(manager.isLoading)
        manager.receiveLoadStatus(contentID: VideoCandidate.testStream.id, playback: .ready)
        manager.receiveLoadStatus(contentID: VideoCandidate.testStream.id, playback: .ready)
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(confirmations, 1)
        withExtendedLifetime(subscription) {}
    }

    @MainActor func testOldUnknownAndClearedRequestFailuresAreIgnored() {
        let manager = CastManager()
        let old = GCKRequest.application()
        let current = GCKRequest.application()
        manager.trackLoadRequest(old, candidate: .testStream)
        manager.trackLoadRequest(current, candidate: .testStream)
        old.failWithError(GCKError(code: .timeout))
        manager.request(GCKRequest.application(), didFailWithError: GCKError(code: .timeout))
        XCTAssertNil(manager.errorMessage)
        XCTAssertTrue(manager.isLoading)
        manager.refreshSession()
        current.failWithError(GCKError(code: .timeout))
        XCTAssertNil(manager.errorMessage)
        XCTAssertFalse(manager.isLoading)
    }

    @MainActor func testCancelledAndReplacedRequestsDoNotCreateFalseErrors() {
        let manager = CastManager()
        for code: GCKErrorCode in [.cancelled, .replaced] {
            let request = GCKRequest.application()
            manager.trackLoadRequest(request, candidate: .testStream)
            request.failWithError(GCKError(code: code))
            XCTAssertFalse(manager.isLoading)
            XCTAssertNil(manager.errorMessage)
        }
        let request = GCKRequest.application()
        manager.trackLoadRequest(request, candidate: .testStream)
        request.abort(with: .cancelled)
        XCTAssertFalse(manager.isLoading)
        XCTAssertNil(manager.errorMessage)
    }

    @MainActor func testCurrentRequestFailureAndUnresponsiveReceiverExitLoading() {
        let manager = CastManager()
        let request = GCKRequest.application()
        manager.trackLoadRequest(request, candidate: .testStream)
        request.failWithError(GCKError(code: .mediaLoadFailed))
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(manager.lastLoadedCandidate?.id, VideoCandidate.testStream.id)
        let retry = GCKRequest.application()
        manager.trackLoadRequest(retry, candidate: .testStream)
        XCTAssertNil(manager.errorMessage)
        manager.receiveLoadStatus(contentID: nil, playback: .waiting, now: Date().addingTimeInterval(46))
        XCTAssertFalse(manager.isLoading)
        XCTAssertEqual(manager.errorMessage, String(localized: "电视加载超时。手机仍可继续播放，请检查连接或重新检测视频。"))
    }
}

final class BrowserPlaybackHandoffTests: XCTestCase {
    func testOnlyMatchingAttemptPausesTheOriginalDocumentOnce() {
        var handoff = BrowserPlaybackHandoff()
        let attempt = UUID(), document = UUID(), revision = UUID()
        let url = URL(string: "https://fixture.example/episode")!
        handoff.arm(attempt, origin: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url))
        XCTAssertFalse(handoff.confirm(UUID(), current: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url)))
        XCTAssertTrue(handoff.confirm(attempt, current: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url)))
        XCTAssertFalse(handoff.confirm(attempt, current: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url)))
    }

    func testNavigationReloadAndResetPreventPausingUnrelatedContent() {
        var handoff = BrowserPlaybackHandoff()
        let attempt = UUID(), document = UUID(), revision = UUID()
        let url = URL(string: "https://fixture.example/episode")!
        handoff.arm(attempt, origin: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url))
        XCTAssertFalse(handoff.confirm(attempt, current: BrowserPlaybackContext(document: UUID(), mediaRevision: revision, url: url)))
        handoff.arm(attempt, origin: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url))
        XCTAssertFalse(handoff.confirm(attempt, current: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url.appendingPathComponent("next"))))
        handoff.arm(attempt, origin: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url))
        handoff.reset()
        XCTAssertFalse(handoff.confirm(attempt, current: BrowserPlaybackContext(document: document, mediaRevision: revision, url: url)))
    }
}
