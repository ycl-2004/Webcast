import XCTest
import WebKit
@testable import Webcast

final class SnifferSecurityTests: XCTestCase {
    func testMalformedAndOversizedMetadataNeverEntersCandidateStore() {
        let long = String(repeating: "x", count: 1_048_576)
        let invalid: [[String: Any]] = [
            ["source":long], ["segmentFormat":long], ["pageURL":long], ["generation":long],
            ["mime":["nested":"value"]], ["title":String(repeating:"中", count:401)],
            ["current":1], ["duration":true], ["duration":Double.infinity],
            ["segmentFormat":"anything"], ["source":"spoofed"], ["unexpected":["object":long]]
        ]
        for fields in invalid {
            var body = fields; body["url"] = "https://cdn.example/video.mp4"
            var store = CandidateStore()
            XCTAssertFalse(store.ingest(body), "Rejected fields: \(fields.keys)")
            XCTAssertTrue(store.items.isEmpty)
        }
    }

    func testTypedMetadataAndSignedURLRemainValid() {
        var store = CandidateStore()
        let signed = "https://cdn.example/master.m3u8?token=a%2Fb&expires=123"
        XCTAssertTrue(store.ingest(["url":signed, "source":"fetch", "manifest":"#EXTM3U",
                                    "segmentFormat":"fmp4", "master":true, "live":false, "duration":120.0]))
        XCTAssertEqual(store.sorted.first?.url.absoluteString, signed)
        XCTAssertEqual(store.sorted.first?.segmentFormat, "fmp4")
        for raw in ["file:///private/movie.mp4", "https://user:secret@cdn.example/video.mp4", "https:///", "javascript:1"] {
            XCTAssertNil(SnifferPayload.mediaURL(raw))
        }
    }

    func testMediaFloodHasGlobalAndPerFrameBudgetButCleanupStillWorks() {
        var budget = SnifferMessageBudget()
        let now = ProcessInfo.processInfo.systemUptime
        let allowed = (0..<1000).filter { _ in budget.allow(frame:"one", lifecycle:false, now:now) }.count
        XCTAssertEqual(allowed, 64)
        XCTAssertTrue(budget.allow(frame:"one", lifecycle:true, now:now))
        XCTAssertTrue(budget.allow(frame:"one", lifecycle:false, now:now + 1))
        var rotating = SnifferMessageBudget()
        XCTAssertLessThanOrEqual((0..<1000).filter { rotating.allow(frame:"\($0)", lifecycle:false, now:now) }.count, 160)
        XCTAssertLessThanOrEqual(rotating.trackedFrameCount, 100)
    }

    func testConnectionWaitExpiresOnceAndCanBeReset() {
        var wait = CastConnectionWait()
        wait.begin(now:0)
        XCTAssertFalse(wait.expire(now:29.99))
        XCTAssertTrue(wait.expire(now:30))
        XCTAssertFalse(wait.expire(now:60))
        wait.begin(now:60); wait.reset()
        XCTAssertFalse(wait.expire(now:100))
    }

    @MainActor private func browser() throws -> BrowserModel {
        let name = "webcast.security.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName:name))
        defaults.set("start", forKey:SettingsKeys.defaultPage)
        addTeardownBlock { defaults.removePersistentDomain(forName:name) }
        let browser = BrowserModel(defaults:defaults, dataStore:.nonPersistent())
        try showInKeyWindow(browser.webView)
        return browser
    }

    @MainActor private func waitFor(_ predicate: () -> Bool) async throws {
        let end = Date().addingTimeInterval(10)
        while !predicate() && Date() < end { try await Task.sleep(nanoseconds:50_000_000) }
        _ = try XCTUnwrap(predicate() ? true : nil, "Timed out waiting for bridge state")
    }

    @MainActor func testPageCannotCallBridgeOrPromoteNetworkMessageToCurrent() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("<title>Security fixture</title><video preload='none' src='https://cdn.example/real.mp4'></video>",
                                       baseURL:URL(string:"https://fixture.example"))
        try await waitFor { browser.sniffer.candidates.count == 1 }
        let blocked = try await browser.webView.evaluateJavaScript("""
        window.postMessage({webcastNetwork:{url:'https://cdn.example/forged.mp4',source:'fetch',current:true,type:'restored'},webcastRouteKey:location.href}, '*');
        typeof window.__webcastGeneration === 'undefined' &&
          !(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.videoSniffer)
        """
        )
        XCTAssertEqual(blocked as? Bool, true)
        try await Task.sleep(nanoseconds:300_000_000)
        XCTAssertEqual(browser.sniffer.candidates.map(\.url.lastPathComponent), ["real.mp4"])
        XCTAssertFalse(browser.sniffer.candidates[0].isCurrent)
    }

    @MainActor func testSelectionReadsImmediateMediaStateInsteadOfDelayedListRow() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <video id='a' preload='none' src='https://cdn.example/a.mp4'></video>
        <video id='b' preload='none' src='https://cdn.example/b.mp4'></video>
        <script>document.getElementById('a').dispatchEvent(new Event('play'));</script>
        """, baseURL:URL(string:"https://fixture.example"))
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        let oldRow = try XCTUnwrap(browser.sniffer.candidates.first { $0.url.lastPathComponent == "a.mp4" })
        XCTAssertTrue(oldRow.isCurrent)
        _ = try await isolatedJavaScript(browser.webView, "document.getElementById('b').dispatchEvent(new Event('play')); return true;")
        try await waitFor { browser.sniffer.latestCandidate(for:"https://cdn.example/b.mp4")?.isCurrent == true }
        XCTAssertNil(browser.castIntent(for:oldRow).origin)
        XCTAssertFalse(browser.castIntent(for:oldRow).candidate.isCurrent)
    }

    @MainActor func testUnknownRestoredGenerationRejectedEvenInIsolatedWorld() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("<video preload='none' src='https://cdn.example/real.mp4'></video>",
                                       baseURL:URL(string:"https://fixture.example"))
        try await waitFor { browser.sniffer.candidates.count == 1 }
        _ = try await isolatedJavaScript(browser.webView, """
        webkit.messageHandlers.videoSniffer.postMessage({type:'restored',generation:'forged',frameID:'forged'});
        webkit.messageHandlers.videoSniffer.postMessage({generation:'forged',frameID:'forged',url:'https://cdn.example/fake.mp4',current:true});
        return true;
        """
        )
        try await Task.sleep(nanoseconds:300_000_000)
        XCTAssertFalse(browser.sniffer.acceptedGenerations.contains("forged"))
        XCTAssertEqual(browser.sniffer.candidates.map(\.url.lastPathComponent), ["real.mp4"])
    }

    @MainActor func testPageWorldFetchStillReachesIsolatedBridge() async throws {
        let sniffer = VideoSniffer()
        let configuration = WKWebViewConfiguration()
        let controller = configuration.userContentController
        controller.add(WeakScriptHandler(sniffer), contentWorld:.defaultClient, name:"videoSniffer")
        let setup = """
        window.fetch = () => {
          const response = new Response('#EXTM3U\\n#EXT-X-ENDLIST\\nclip.ts', {headers:{'Content-Type':'application/vnd.apple.mpegurl'}});
          Object.defineProperty(response, 'url', {value:'https://cdn.example/from-fetch.m3u8?token=a%2Fb'});
          return Promise.resolve(response);
        };
        """
        sniffer.prepareNavigation(controller:controller, source:setup + "\n" + (try VideoSniffer.scriptSource()))
        let view = WKWebView(frame:CGRect(x:0, y:0, width:320, height:480), configuration:configuration)
        try showInKeyWindow(view)
        view.loadHTMLString("<script>fetch('/stream');</script>", baseURL:URL(string:"https://fixture.example"))
        try await waitFor { sniffer.candidates.first?.isLive == false }
        XCTAssertEqual(sniffer.candidates.first?.url.absoluteString, "https://cdn.example/from-fetch.m3u8?token=a%2Fb")
        XCTAssertFalse(sniffer.candidates.first?.isCurrent == true)
        withExtendedLifetime(view) {}
    }

    @MainActor private func isolatedJavaScript(_ view: WKWebView, _ source: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            view.callAsyncJavaScript(source, arguments:[:], in:nil, in:.defaultClient) { result in
                continuation.resume(with:result)
            }
        }
    }
}
