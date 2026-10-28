import XCTest
import WebKit
@testable import Webcast

/// Audit-only probes: assertions deliberately prove the current unwanted behavior.
/// This file lives in an isolated /tmp copy and is not a product test change.
final class AuditRegressionTests: XCTestCase {
    @MainActor private func browser() throws -> BrowserModel {
        let name = "webcast.audit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.set("start", forKey: SettingsKeys.defaultPage)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return BrowserModel(defaults: defaults, dataStore: .nonPersistent())
    }

    @MainActor private func waitFor(_ condition: () -> Bool) async throws {
        let end = Date().addingTimeInterval(10)
        while !condition() && Date() < end { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(condition())
    }

    @MainActor func testReproducesRemovedVideoStillMarkedCurrent() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <video id='v' preload='none'></video><script>
        document.getElementById('v').src='https://cdn.example/removed.mp4';
        </script>
        """, baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('v').remove(); true")
        try await Task.sleep(nanoseconds: 300_000_000)
        let remaining = try await browser.webView.evaluateJavaScript("document.querySelectorAll('video').length")
        XCTAssertEqual(remaining as? Int, 0)
        XCTAssertTrue(browser.sniffer.candidates.first?.isCurrent == true,
                      "Reproduction: deleted element remains the current video")
    }

    @MainActor func testReproducesDetachedPreloadReplacingCurrentVideo() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <video id='v' preload='none' src='https://cdn.example/playing.mp4'></video>
        <script>document.getElementById('v').dispatchEvent(new Event('play'));</script>
        """, baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        _ = try await browser.webView.evaluateJavaScript("""
        window.preload = document.createElement('video'); preload.preload='none';
        preload.src='https://cdn.example/not-playing.mp4'; true
        """)
        try await waitFor { browser.sniffer.candidates.first?.url.lastPathComponent == "not-playing.mp4" }
        let paused = try await browser.webView.evaluateJavaScript("preload.paused && !preload.isConnected")
        XCTAssertEqual(paused as? Bool, true)
        XCTAssertTrue(browser.sniffer.candidates.first?.isCurrent == true,
                      "Reproduction: assigning a detached preload's URL replaces the playing candidate")
    }

    @MainActor func testReproducesRemovedIframeStillMarkedCurrent() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <iframe id='frame' srcdoc="<video id='v' preload='none'></video><script>document.getElementById('v').src='https://cdn.example/frame.mp4';</script>"></iframe>
        """, baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('frame').remove(); true")
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(browser.sniffer.candidates.first?.isCurrent == true,
                      "Reproduction: removed frame retains its active URL")
    }

    @MainActor func testReproducesMainRouteErasingUnchangedIframeVideo() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <iframe id='frame' srcdoc="<video preload='none' src='https://cdn.example/persistent.mp4'></video>"></iframe>
        """, baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { !browser.sniffer.candidates.isEmpty }
        _ = try await browser.webView.evaluateJavaScript("history.pushState({}, '', '/next'); true")
        try await waitFor { browser.webView.url?.path == "/next" && browser.sniffer.candidates.isEmpty }
        try await Task.sleep(nanoseconds: 300_000_000)
        let src = try await browser.webView.evaluateJavaScript("document.getElementById('frame').contentDocument.querySelector('video').src")
        XCTAssertEqual(src as? String, "https://cdn.example/persistent.mp4")
        XCTAssertTrue(browser.sniffer.candidates.isEmpty,
                      "Reproduction: iframe still has media, but the native list is empty")
    }

    @MainActor func testReproducesFragmentRouteKeepingPreviousEpisode() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <video id='v' preload='none'></video><script>document.getElementById('v').src='https://cdn.example/episode1.mp4';</script>
        """, baseURL: URL(string: "https://fixture.example/#/episode/1"))
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('v').remove(); location.hash='/episode/2'; true")
        try await waitFor { browser.webView.url?.fragment == "/episode/2" }
        XCTAssertEqual(browser.sniffer.candidates.first?.url.lastPathComponent, "episode1.mp4")
        XCTAssertTrue(browser.sniffer.candidates.first?.isCurrent == true)
    }

    func testReproducesSameDocumentReturnAcceptingOldHandoff() {
        var handoff = BrowserPlaybackHandoff()
        let attempt = UUID(), document = UUID(), url = URL(string: "https://fixture.example/a")!
        handoff.arm(attempt, document: document, url: url)
        // A -> B -> A via pushState does not replace documentID or call handoff.reset().
        XCTAssertTrue(handoff.confirm(attempt, document: document, url: url),
                      "Reproduction: no route revision exists to reject the old confirmation")
    }
}
