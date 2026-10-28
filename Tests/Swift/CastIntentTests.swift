import XCTest
import WebKit
import GoogleCast
import Combine
@testable import Webcast

final class CastIntentTests: XCTestCase {
    func testDelayedConnectionKeepsSelectionOriginAndCancellationConsumesNothing() {
        let a = BrowserPlaybackContext(document: UUID(), mediaRevision: UUID(), url: URL(string: "https://fixture.example/a"))
        let b = BrowserPlaybackContext(document: UUID(), mediaRevision: UUID(), url: URL(string: "https://fixture.example/b"))
        var pending = PendingCast()
        pending.select(CastIntent(candidate: .testStream, origin: a))
        let intent = pending.take()!
        XCTAssertEqual(intent.origin, a)
        XCTAssertNil(pending.take())
        var handoff = BrowserPlaybackHandoff()
        let attempt = UUID()
        handoff.arm(attempt, origin: intent.origin)
        XCTAssertFalse(handoff.confirm(attempt, current: b))
        pending.select(intent)
        pending.cancel()
        XCTAssertNil(pending.take())
    }

    func testSameDocumentAndURLWithDifferentMediaRevisionCannotPause() {
        let origin = BrowserPlaybackContext(document: UUID(), mediaRevision: UUID(), url: URL(string: "https://fixture.example/a"))
        let returned = BrowserPlaybackContext(document: origin.document, mediaRevision: UUID(), url: origin.url)
        var handoff = BrowserPlaybackHandoff()
        let attempt = UUID()
        handoff.arm(attempt, origin: origin)
        XCTAssertFalse(handoff.confirm(attempt, current: returned))
        handoff.arm(attempt, origin: nil)
        XCTAssertFalse(handoff.confirm(attempt, current: origin))
    }

    @MainActor func testLoadEventRetainsOriginalContextForNewAttempt() {
        let manager = CastManager()
        let origin = BrowserPlaybackContext(document: UUID(), mediaRevision: UUID(), url: URL(string: "https://fixture.example/a"))
        var origins: [BrowserPlaybackContext?] = []
        let sub = manager.loadEvents.sink { if case .started(_, let value) = $0 { origins.append(value) } }
        let request = GCKRequest.application()
        manager.trackLoadRequest(request, candidate: .testStream, origin: origin)
        request.failWithError(GCKError(code: .timeout))
        let retry = manager.retryIntent!
        manager.trackLoadRequest(GCKRequest.application(), candidate: retry.candidate, origin: retry.origin)
        XCTAssertEqual(origins.count, 2)
        XCTAssertEqual(origins[1], origin)
        XCTAssertEqual(origins[0], origin)
        withExtendedLifetime(sub) {}
    }

    func testFrameRoutesAndSourceInvalidationAdvanceRevisionButMetadataDoesNot() {
        var store = CandidateStore()
        let media: [String: Any] = ["url":"https://cdn.example/a.mp4", "frameID":"frame", "current":true]
        store.ingest(media)
        let original = store.playbackRevision
        store.ingest(media)
        XCTAssertEqual(store.playbackRevision, original)
        store.deactivate(frame: "frame")
        XCTAssertNotEqual(store.playbackRevision, original)
        store.ingest(media)
        let resumed = store.playbackRevision
        store.clearFrame("frame")
        store.ingest(media)
        XCTAssertNotEqual(store.playbackRevision, resumed)
    }

    func testRemovingParentRetiresNestedFramesButPreservesSharedMediaElsewhere() {
        var store = CandidateStore()
        store.linkFrame("child", parent: "parent")
        store.linkFrame("nested", parent: "child")
        let url = "https://cdn.example/shared.mp4"
        for frame in ["parent", "child", "nested", "other"] {
            store.ingest(["url":url, "frameID":frame, "current":true])
        }
        store.removeFrame("parent")
        XCTAssertTrue(store.items[url]?.isCurrent == true)
        store.removeFrame("other")
        XCTAssertTrue(store.items.isEmpty)
    }
    func testRemovedFrameRejectsLateReportsUntilCacheRestore() {
        var store = CandidateStore()
        store.linkFrame("child", parent: "parent")
        let payload: [String: Any] = ["url":"https://cdn.example/late.mp4", "frameID":"child", "current":true]
        XCTAssertTrue(store.ingest(payload))
        store.removeFrame("parent")
        XCTAssertFalse(store.ingest(payload))
        XCTAssertTrue(store.items.isEmpty)
        store.restoreFrame("child")
        XCTAssertTrue(store.ingest(payload))
    }

}
