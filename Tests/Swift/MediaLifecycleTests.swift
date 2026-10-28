import XCTest
import WebKit
@testable import Webcast

/// Correctness regressions converted from the review reproductions.
final class MediaLifecycleTests: XCTestCase {
    @MainActor private func browser() throws -> BrowserModel {
        let name = "webcast.audit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.set("start", forKey: SettingsKeys.defaultPage)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        let browser = BrowserModel(defaults: defaults, dataStore: .nonPersistent())
        try showInKeyWindow(browser.webView)
        return browser
    }

    @MainActor private func waitFor(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async throws {
        let end = Date().addingTimeInterval(10)
        while !condition() && Date() < end { try await Task.sleep(nanoseconds: 50_000_000) }
        _ = try XCTUnwrap(condition() ? true : nil, "Timed out waiting for media state", file: file, line: line)
    }

    @MainActor func testRemovedVideoLosesCurrentStatus() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <video id='v' preload='none'></video><script>
        document.getElementById('v').src='https://cdn.example/removed.mp4'; document.getElementById('v').dispatchEvent(new Event('play'));
        </script>
        """, baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('v').remove(); true")
        try await Task.sleep(nanoseconds: 300_000_000)
        let remaining = try await browser.webView.evaluateJavaScript("document.querySelectorAll('video').length")
        XCTAssertEqual(remaining as? Int, 0)
        XCTAssertFalse(browser.sniffer.candidates.first?.isCurrent == true)
    }

    @MainActor func testDetachedPreloadDoesNotReplaceCurrentVideo() async throws {
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
        try await waitFor { browser.sniffer.candidates.contains { $0.url.lastPathComponent == "not-playing.mp4" } }
        let paused = try await browser.webView.evaluateJavaScript("preload.paused && !preload.isConnected")
        XCTAssertEqual(paused as? Bool, true)
        XCTAssertEqual(browser.sniffer.candidates.first?.url.lastPathComponent, "playing.mp4")
        XCTAssertTrue(browser.sniffer.candidates.first?.isCurrent == true)
    }

    @MainActor func testRemovedIframeRemovesItsCandidates() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <iframe id='frame' srcdoc="<video id='v' preload='none'></video><script>document.getElementById('v').src='https://cdn.example/frame.mp4'; document.getElementById('v').dispatchEvent(new Event('play'));</script>"></iframe>
        """, baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('frame').remove(); true")
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(browser.sniffer.candidates.isEmpty)
    }

    @MainActor func testParentRoutePreservesUnchangedIframeVideo() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <iframe id='frame' srcdoc="<video preload='none' src='https://cdn.example/persistent.mp4'></video>"></iframe>
        """, baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { !browser.sniffer.candidates.isEmpty }
        _ = try await browser.webView.evaluateJavaScript("history.pushState({}, '', '/next'); true")
        try await waitFor { browser.webView.url?.path == "/next" }
        try await Task.sleep(nanoseconds: 300_000_000)
        let src = try await browser.webView.evaluateJavaScript("document.getElementById('frame').contentDocument.querySelector('video').src")
        XCTAssertEqual(src as? String, "https://cdn.example/persistent.mp4")
        XCTAssertEqual(browser.sniffer.candidates.first?.url.lastPathComponent, "persistent.mp4")
    }

    @MainActor func testHashRouteRemovesPreviousEpisode() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <video id='v' preload='none'></video><script>document.getElementById('v').src='https://cdn.example/episode1.mp4'; document.getElementById('v').dispatchEvent(new Event('play'));</script>
        """, baseURL: URL(string: "https://fixture.example/#/episode/1"))
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('v').remove(); location.hash='/episode/2'; true")
        try await waitFor { browser.webView.url?.fragment == "/episode/2" }
        try await waitFor { browser.sniffer.candidates.isEmpty }
    }

    @MainActor func testSourceChangeAndPausedMetadataDoNotInventPlayback() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("<video id='v' preload='none' src='https://cdn.example/a.mp4'></video>",
            baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { !browser.sniffer.candidates.isEmpty }
        _ = try await browser.webView.evaluateJavaScript("v.dispatchEvent(new Event('play')); true")
        try await waitFor { browser.sniffer.candidates.first?.isCurrent == true }
        let origin = browser.playbackContext
        _ = try await browser.webView.evaluateJavaScript("v.src='https://cdn.example/b.mp4'; v.dispatchEvent(new Event('loadedmetadata')); true")
        try await waitFor { browser.sniffer.candidates.count == 2 }
        XCTAssertFalse(browser.sniffer.candidates.contains { $0.isCurrent })
        XCTAssertNotEqual(browser.playbackContext, origin)
        // Let WebKit finish the source reset before synthesizing playback. Otherwise its real
        // asynchronous emptied event can correctly invalidate our premature synthetic play.
        _ = try await browser.webView.evaluateJavaScript("v.load(); true")
        try await Task.sleep(nanoseconds: 300_000_000)
        _ = try await browser.webView.evaluateJavaScript("""
        Object.defineProperty(v, 'currentSrc', {configurable:true, get() { return this.src; }});
        v.dispatchEvent(new Event('play')); true
        """)
        try await waitFor { browser.sniffer.candidates.first?.url.lastPathComponent == "b.mp4" && browser.sniffer.candidates.first?.isCurrent == true }
        _ = try await browser.webView.evaluateJavaScript("v.src='blob:https://fixture.example/unknown'; v.dispatchEvent(new Event('play')); true")
        try await waitFor { !browser.sniffer.candidates.contains { $0.isCurrent } }
    }

    @MainActor func testIframeNavigationReplacesOnlyItsOwnMedia() async throws {
        let browser = try browser()
        browser.webView.loadHTMLString("""
        <video preload='none' src='https://cdn.example/main.mp4'></video>
        <iframe id='frame' srcdoc="<video preload='none' src='https://cdn.example/old.mp4'></video>"></iframe>
        """, baseURL: URL(string: "https://fixture.example/start"))
        try await waitFor { browser.sniffer.candidates.count == 2 }
        _ = try await browser.webView.evaluateJavaScript("""
        document.getElementById('frame').srcdoc="<video preload='none' src='https://cdn.example/new.mp4'></video>"; true
        """)
        try await waitFor { browser.sniffer.candidates.contains { $0.url.lastPathComponent == "new.mp4" } }
        XCTAssertEqual(Set(browser.sniffer.candidates.map { $0.url.lastPathComponent }), ["main.mp4", "new.mp4"])
    }

}
