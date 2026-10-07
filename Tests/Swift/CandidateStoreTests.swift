import XCTest
import GoogleCast
@testable import Webcast

final class CandidateStoreTests: XCTestCase {
    func testSignedURLIsPreservedAndFragmentsDeduplicated() {
        var store = CandidateStore()
        let url = "https://cdn.example/video.m3u8?token=a%2Fb&expires=123"
        XCTAssertTrue(store.ingest(["url":url + "#first", "current":true]))
        XCTAssertTrue(store.ingest(["url":url + "#second", "master":true]))
        XCTAssertEqual(store.sorted.count, 1)
        XCTAssertEqual(store.sorted[0].url.absoluteString, url)
        XCTAssertTrue(store.sorted[0].isMaster)
        XCTAssertTrue(store.sorted[0].isCurrent)
    }

    func testMasterPriorityAndActiveVideoReplacement() {
        var store = CandidateStore()
        store.ingest(["url":"https://cdn.example/ad.mp4", "current":true, "frameID":"player"])
        store.ingest(["url":"https://cdn.example/episode.m3u8", "current":true, "frameID":"player"])
        store.ingest(["url":"https://cdn.example/master.m3u8", "master":true])
        XCTAssertEqual(store.sorted.first?.url.lastPathComponent, "master.m3u8")
        XCTAssertFalse(store.items["https://cdn.example/ad.mp4"]!.isCurrent)
        XCTAssertTrue(store.items["https://cdn.example/episode.m3u8"]!.isCurrent)
    }

    func testMIMEAndManifestRecognizeExtensionlessStreams() {
        var store = CandidateStore()
        XCTAssertTrue(store.ingest(["url":"https://cdn.example/stream?id=1", "mime":"application/vnd.apple.mpegurl; charset=UTF-8"]))
        XCTAssertTrue(store.ingest(["url":"https://cdn.example/stream?id=2", "manifest":"#EXTM3U"]))
        XCTAssertEqual(store.sorted.map(\.format), [.hls, .hls])
    }

    func testRejectsBlobInvalidCredentialsAndNonMedia() {
        var store = CandidateStore()
        for url in ["blob:https://cdn.example/a", "javascript:alert(1)", "file:///video.mp4", "https://a:b@cdn.example/a.mp4", "https://cdn.example/page", "garbage"] {
            XCTAssertFalse(store.ingest(["url":url]))
        }
        XCTAssertTrue(store.sorted.isEmpty)
    }

    func testDRMAndMetadataSurviveRepeatedReports() {
        var store = CandidateStore()
        let url = "https://cdn.example/live.m3u8"
        store.ingest(["url":url, "drm":true, "live":true, "segmentFormat":"fmp4"])
        store.ingest(["url":url, "current":true, "duration":Double.infinity])
        XCTAssertTrue(store.sorted[0].isDRM)
        XCTAssertEqual(store.sorted[0].isLive, true)
        XCTAssertEqual(store.sorted[0].segmentFormat, "fmp4")
        XCTAssertNil(store.sorted[0].duration)
        store.reset()
        XCTAssertTrue(store.sorted.isEmpty)
    }

    func testBrowserAddressesAreHTTPOnly() {
        XCTAssertEqual(BrowserAddress.resolve(" iyf.tv ")?.absoluteString, "https://iyf.tv")
        XCTAssertEqual(BrowserAddress.resolve("http://localhost:8000")?.port, 8000)
        for input in ["", "javascript:alert(1)", "file:///etc/passwd", "not a url", "https://a:b@example.com"] {
            XCTAssertNil(BrowserAddress.resolve(input))
        }
    }

    @MainActor func testOfflineModeCannotLoadMediaOrDiscoverDevices() {
        let manager = CastManager()
        XCTAssertTrue(manager.offlineValidation)
        manager.discover()
        XCTAssertTrue(manager.devices.isEmpty)
        XCTAssertFalse(manager.canControl)
        XCTAssertFalse(manager.load(.testStream))
        XCTAssertEqual(manager.connection, .disconnected)
    }

    @MainActor func testMediaRequestHasCorrectHLSMetadata() {
        let request = MediaLoader.request(for: .testStream)
        XCTAssertEqual(request.mediaInformation?.contentURL, VideoCandidate.testStream.url)
        XCTAssertEqual(request.mediaInformation?.contentType, "application/x-mpegurl")
        XCTAssertEqual(request.mediaInformation?.streamType, .buffered)
        XCTAssertEqual(request.mediaInformation?.metadata?.string(forKey: kGCKMetadataKeyTitle), "Apple HLS 测试视频")
    }

    @MainActor func testSDKOptionalCallbacksHaveCorrectSelectors() {
        let manager = CastManager()
        for selector in ["sessionManager:didStartCastSession:", "sessionManager:didResumeCastSession:",
                         "sessionManager:didSuspendCastSession:withReason:", "sessionManager:didEndCastSession:withError:",
                         "sessionManager:didFailToStartCastSession:withError:", "didUpdateDeviceList",
                         "didInsertDevice:atIndex:", "remoteMediaClient:didUpdateMediaStatus:", "request:didFailWithError:"] {
            XCTAssertTrue(manager.responds(to: NSSelectorFromString(selector)), selector)
        }
    }
}
