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

    func testCurrentVideoPriorityAndActiveVideoReplacement() {
        var store = CandidateStore()
        store.ingest(["url":"https://cdn.example/ad.mp4", "current":true, "frameID":"player"])
        store.ingest(["url":"https://cdn.example/episode.m3u8", "current":true, "frameID":"player"])
        store.ingest(["url":"https://cdn.example/master.m3u8", "master":true])
        XCTAssertEqual(store.sorted.first?.url.lastPathComponent, "episode.m3u8")
        XCTAssertFalse(store.items["https://cdn.example/ad.mp4"]!.isCurrent)
        XCTAssertTrue(store.items["https://cdn.example/episode.m3u8"]!.isCurrent)
        store.ingest(["url":"https://cdn.example/master.m3u8", "master":true, "current":true, "frameID":"player"])
        XCTAssertEqual(store.sorted.first?.url.lastPathComponent, "master.m3u8")
    }

    func testSharedVideoRemainsCurrentUntilEveryFrameSwitchesAway() {
        var store = CandidateStore()
        let shared = "https://cdn.example/shared.mp4"
        store.ingest(["url":shared, "current":true, "frameID":"one"])
        store.ingest(["url":shared, "current":true, "frameID":"two"])
        store.ingest(["url":"https://cdn.example/other.mp4", "current":true, "frameID":"two"])
        XCTAssertTrue(store.items[shared]!.isCurrent)
        store.ingest(["url":"https://cdn.example/next.mp4", "current":true, "frameID":"one"])
        XCTAssertFalse(store.items[shared]!.isCurrent)
    }

    func testCandidateLimitHoldsWhenEveryFrameReportsCurrentMedia() {
        var store = CandidateStore()
        for index in 0..<150 {
            store.ingest(["url":"https://cdn.example/\(index).mp4", "current":true, "frameID":"\(index)"],
                         now: Date(timeIntervalSince1970: Double(index)))
        }
        XCTAssertEqual(store.items.count, 100)
        XCTAssertNil(store.items["https://cdn.example/0.mp4"])
        XCTAssertTrue(store.items["https://cdn.example/149.mp4"]!.isCurrent)
    }

    func testCandidateLimitPreservesCurrentMediaBeforeInactiveCandidates() {
        var store = CandidateStore()
        for index in 0..<101 {
            store.ingest(["url":"https://cdn.example/\(index).mp4", "current":index == 0],
                         now: Date(timeIntervalSince1970: Double(index)))
        }
        XCTAssertEqual(store.items.count, 100)
        XCTAssertTrue(store.items["https://cdn.example/0.mp4"]!.isCurrent)
        XCTAssertNil(store.items["https://cdn.example/1.mp4"])
        XCTAssertNotNil(store.items["https://cdn.example/100.mp4"])
    }

    func testFrameTrackingIsBoundedEvenWhenAllFramesShareOneURL() {
        var store = CandidateStore()
        let shared = "https://cdn.example/shared.mp4"
        for index in 0..<150 {
            store.ingest(["url":shared, "current":true, "frameID":"\(index)"])
        }
        for index in 50..<150 {
            store.ingest(["url":"https://cdn.example/next.mp4", "current":true, "frameID":"\(index)"])
        }
        XCTAssertFalse(store.items[shared]!.isCurrent)
        store.reset()
        store.ingest(["url":shared])
        XCTAssertFalse(store.items[shared]!.isCurrent)
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
        XCTAssertEqual(request.mediaInformation?.metadata?.string(forKey: kGCKMetadataKeyTitle), String(localized: "Apple HLS 测试视频"))
    }

    @MainActor func testSDKOptionalCallbacksHaveCorrectSelectors() {
        let manager = CastManager()
        for selector in ["sessionManager:didStartCastSession:", "sessionManager:didResumeCastSession:",
                         "sessionManager:didSuspendCastSession:withReason:", "sessionManager:didEndCastSession:withError:",
                         "sessionManager:didFailToStartCastSession:withError:", "didUpdateDeviceList",
                         "didInsertDevice:atIndex:", "remoteMediaClient:didUpdateMediaStatus:", "request:didFailWithError:"] {
            XCTAssertTrue(manager.responds(to: NSSelectorFromString(selector)), selector)
        }
        #if DEBUG
        XCTAssertTrue(manager.responds(to: NSSelectorFromString("logMessage:atLevel:fromFunction:location:")))
        #endif
    }
    func testResponseMetadataCorrectsFilenameGuessAndSurvivesDOMRescan() throws {
        var store = CandidateStore()
        let url = "https://cdn.example/stream.mp4?token=a%2Fb"
        store.ingest(["url":url])
        XCTAssertEqual(store.sorted.first?.format, .mp4)
        store.ingest(["url":url, "mime":"application/vnd.apple.mpegurl", "manifest":"#EXTM3U", "master":true])
        store.ingest(["url":url, "source":"video", "current":true])
        XCTAssertEqual(store.sorted.first?.format, .hls)
    }

    @MainActor func testCastRequestPreservesSignedMasterAndBothHLSSegmentFormats() throws {
        for (format, audio, video) in [("fmp4", GCKHLSSegmentFormat.FMP4, GCKHLSVideoSegmentFormat.FMP4),
                                      ("ts", GCKHLSSegmentFormat.TS, GCKHLSVideoSegmentFormat.MPEG2_TS)] {
            // A signed master URL, not the low bitrate child URL observed by the phone.
            var store = CandidateStore()
            store.ingest(["url":"https://cdn.example/master.m3u8?token=a%2Fb&quality=all", "master":true,
                          "segmentFormat":format, "live":false, "duration":120.0])
            let candidate = try XCTUnwrap(store.sorted.first)
            let request = MediaLoader.request(for: candidate)
            let media = try XCTUnwrap(request.mediaInformation)
            XCTAssertEqual(media.contentURL?.absoluteString, candidate.url.absoluteString)
            XCTAssertEqual(media.contentType, "application/x-mpegurl")
            XCTAssertEqual(media.hlsSegmentFormat, audio)
            XCTAssertEqual(media.hlsVideoSegmentFormat, video)
            XCTAssertEqual(media.streamDuration, 120)
            XCTAssertEqual(media.streamType, .buffered)
            XCTAssertEqual(request.autoplay?.boolValue, true)
        }
    }

}
