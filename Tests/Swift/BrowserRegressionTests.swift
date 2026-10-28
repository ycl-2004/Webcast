import XCTest
import WebKit
@testable import Webcast

@MainActor
private final class NavigationProbe: NSObject, WKNavigationDelegate {
    let loaded: XCTestExpectation
    init(_ loaded: XCTestExpectation) { self.loaded = loaded }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded.fulfill() }
}

@MainActor
private final class PromptProbe: NSObject, WKUIDelegate {
    let browser: BrowserModel
    let completed: XCTestExpectation
    private(set) var completionCount = 0
    init(browser: BrowserModel, completed: XCTestExpectation) {
        self.browser = browser
        self.completed = completed
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        browser.webView(webView, runJavaScriptTextInputPanelWithPrompt: prompt,
                        defaultText: defaultText, initiatedByFrame: frame) { [self] value in
            completionCount += 1
            XCTAssertNil(value)
            completionHandler(value)
            completed.fulfill()
        }
        browser.cancelDialogs()
        browser.cancelDialogs()
    }
}

final class BrowserRegressionTests: XCTestCase {
    /// 每个用例独立的 UserDefaults 与数据存储；默认起始页，避免启动即联网
    @MainActor private func makeBrowser(dataStore: WKWebsiteDataStore? = nil, defaultPage: String = "start") throws -> (BrowserModel, UserDefaults) {
        let suite = "webcast.review.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        defaults.set(defaultPage, forKey: SettingsKeys.defaultPage)
        let browser = BrowserModel(defaults: defaults, dataStore: dataStore ?? .nonPersistent())
        try showInKeyWindow(browser.webView)
        return (browser, defaults)
    }

    @MainActor private func waitUntil(_ description: String, timeout: TimeInterval = 10,
                                      _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                // Stop at the missing prerequisite instead of cascading into invalid JavaScript.
                return try XCTUnwrap(nil as Void?, "Timed out: \(description)")
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @MainActor private func isolatedJavaScript(_ view: WKWebView, _ source: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            view.callAsyncJavaScript(source, arguments:[:], in:nil, in:.defaultClient) { result in
                continuation.resume(with:result)
            }
        }
    }

    @MainActor private func candidateURLs(_ browser: BrowserModel) -> Set<String> {
        Set(browser.sniffer.candidates.map(\.url.absoluteString))
    }

    @MainActor func testBrowserDefersStartupNetworkingAndReadsLatestHomeSettingOnFirstVisit() throws {
        let (browser, defaults) = try makeBrowser(defaultPage: "remote")
        XCTAssertNil(browser.webView.url)
        defaults.set("home", forKey: SettingsKeys.startLoad)
        defaults.set("https://fixture.invalid/home", forKey: SettingsKeys.homeURL)
        browser.applySettings()
        browser.startIfNeeded()
        XCTAssertEqual(browser.webView.url?.absoluteString, "https://fixture.invalid/home")
        browser.stopLoading()
    }

    @MainActor func testDeferredLastPageLoadsOnlyOnceAndExplicitStartPageStaysLocal() throws {
        let (browser, defaults) = try makeBrowser(defaultPage: "last")
        defaults.set("https://fixture.invalid/last", forKey: SettingsKeys.lastURL)
        browser.startIfNeeded()
        XCTAssertEqual(browser.webView.url?.absoluteString, "https://fixture.invalid/last")
        browser.open(URL(string: "about:blank")!)
        browser.startIfNeeded()
        XCTAssertEqual(browser.webView.url?.absoluteString, "about:blank")
        browser.stopLoading()
        let (start, _) = try makeBrowser()
        start.startIfNeeded()
        XCTAssertTrue(start.showingStartPage)
        XCTAssertNil(start.webView.url)
    }

    func testExplicitURLsKeepUnicodeAndSingleLabelHosts() {
        XCTAssertEqual(BrowserAddress.resolve("http://localhost:8000")?.port, 8000)
        XCTAssertEqual(BrowserAddress.resolve("https://intranet/video")?.host, "intranet")
        XCTAssertEqual(BrowserAddress.resolve("https://www.iyf.tv/search/仙逆")?.path, "/search/仙逆")
        XCTAssertNil(BrowserAddress.resolve("仙逆 第一集"))
    }

    func testSearchPreservesQueryDelimitersAndLiteralPlus() throws {
        let query = "C++ & 仙逆 #第一集?x=1"
        for engine in ["bing", "google"] {
            let url = try XCTUnwrap(BrowserAddress.searchURL(for: query, engine: engine))
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.queryItems, [URLQueryItem(name: "q", value: query)])
            XCTAssertNil(components.fragment)
            XCTAssertTrue(components.percentEncodedQuery?.contains("%2B%2B") == true)
        }
    }

    @MainActor func testHomeSettingsApplyAndInvalidStoredValueFallsBack() throws {
        let (browser, defaults) = try makeBrowser()
        XCTAssertTrue(browser.showingStartPage)
        XCTAssertEqual(browser.homeTitle, "爱壹帆")
        defaults.set("https://example.org", forKey: SettingsKeys.homeURL)
        defaults.set(true, forKey: SettingsKeys.desktopSite)
        browser.applySettings()
        XCTAssertEqual(browser.homeURL.host, "example.org")
        XCTAssertEqual(browser.homeTitle, String(localized: "主页"))
        XCTAssertEqual(browser.webView.customUserAgent, BrowserAddress.desktopUA)
        defaults.set("invalid", forKey: SettingsKeys.homeURL)
        defaults.set(false, forKey: SettingsKeys.desktopSite)
        browser.applySettings()
        XCTAssertEqual(browser.homeURL.absoluteString, SettingsKeys.defaultHome)
        XCTAssertNotEqual(browser.webView.customUserAgent, BrowserAddress.desktopUA)
    }

    @MainActor func testWebsiteClearRemovesIndexedDBAfterUnloadingPage() async throws {
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let (browser, defaults) = try makeBrowser(dataStore: dataStore)
        let loaded = expectation(description: "local page loaded")
        let navigation = NavigationProbe(loaded)
        browser.webView.navigationDelegate = navigation
        browser.webView.loadHTMLString("<html><body>Storage fixture</body></html>", baseURL: URL(string: "https://fixture.review"))
        await fulfillment(of: [loaded], timeout: 10)
        browser.webView.navigationDelegate = browser
        let created: Any = try await withCheckedThrowingContinuation { continuation in
            browser.webView.callAsyncJavaScript("""
            return await new Promise((resolve, reject) => {
                const request = indexedDB.open('review', 1);
                request.onupgradeneeded = () => request.result.createObjectStore('session');
                request.onerror = () => reject(request.error.message);
                request.onsuccess = () => { request.result.close(); resolve(true); };
            });
            """, arguments: [:], in: nil, in: .page) { result in
                continuation.resume(with: result)
            }
        }
        XCTAssertEqual(created as? Bool, true)
        let before = await dataStore.dataRecords(ofTypes: [WKWebsiteDataTypeIndexedDBDatabases])
        XCTAssertFalse(before.isEmpty)
        defaults.set("https://fixture.review", forKey: SettingsKeys.lastURL)
        let cleared = expectation(description: "data actually removed")
        browser.clearWebsiteData { success in
            XCTAssertTrue(success)
            cleared.fulfill()
        }
        XCTAssertTrue(browser.isClearingWebsiteData)
        browser.open(URL(string: "https://example.org")!)
        XCTAssertTrue(browser.showingStartPage)
        await fulfillment(of: [cleared], timeout: 10)
        let after = await dataStore.dataRecords(ofTypes: [WKWebsiteDataTypeIndexedDBDatabases])
        XCTAssertTrue(after.isEmpty)
        XCTAssertFalse(browser.isClearingWebsiteData)
        XCTAssertNil(defaults.string(forKey: SettingsKeys.lastURL))
        XCTAssertEqual(browser.address, "")
    }

    @MainActor func testCancelledPromptResumesWebKitExactlyOnce() async throws {
        let (browser, _) = try makeBrowser()
        let completed = expectation(description: "prompt cancelled")
        let probe = PromptProbe(browser: browser, completed: completed)
        browser.webView.uiDelegate = probe
        browser.webView.loadHTMLString("<script>prompt('review', 'default');</script>", baseURL: URL(string: "https://fixture.review"))
        await fulfillment(of: [completed], timeout: 10)
        XCTAssertEqual(probe.completionCount, 1)
        withExtendedLifetime(probe) {}
    }

    @MainActor func testRepeatedWebContentTerminationShowsManualRecovery() throws {
        let (browser, _) = try makeBrowser()
        browser.open(URL(string: "about:blank")!)
        browser.webViewWebContentProcessDidTerminate(browser.webView)
        browser.webViewWebContentProcessDidTerminate(browser.webView)
        XCTAssertEqual(browser.errorMessage, String(localized: "网页已暂停，请刷新继续。"))
    }

    /// 「默认打开：起始页」时也必须注册检测桥，否则整个会话都检测不到视频
    @MainActor func testStartPageDefaultStillDetectsVideos() async throws {
        let (browser, _) = try makeBrowser()
        XCTAssertTrue(browser.showingStartPage)
        browser.webView.loadHTMLString("<video src='https://cdn.example/start.mp4'></video>",
                                       baseURL: URL(string: "https://fixture.review"))
        try await waitUntil("video detected") { candidateURLs(browser).contains("https://cdn.example/start.mp4") }
    }

    /// 页内锚点跳转不换文档，检测脚本仍是旧的；之后出现的视频也要能检测到
    @MainActor func testSameDocumentFragmentNavigationKeepsDetecting() async throws {
        let (browser, _) = try makeBrowser()
        browser.webView.loadHTMLString("<a id='next' href='#episode-2'>next</a><video src='https://cdn.example/one.mp4'></video>",
                                       baseURL: URL(string: "https://fixture.review/play"))
        try await waitUntil("first video") { candidateURLs(browser).contains("https://cdn.example/one.mp4") }
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('next').click(); true")
        try await waitUntil("fragment navigation") { browser.webView.url?.fragment == "episode-2" }
        _ = try await browser.webView.evaluateJavaScript("""
        const video = document.createElement('video'); video.src = 'https://cdn.example/two.mp4';
        document.body.appendChild(video); true
        """)
        try await waitUntil("video after fragment navigation") { candidateURLs(browser).contains("https://cdn.example/two.mp4") }
    }

    /// 后退回上一页（含往返缓存恢复）后，原页面的视频要重新出现在列表里
    @MainActor func testBackNavigationRestoresPreviousPageVideos() async throws {
        let (browser, _) = try makeBrowser()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.html")
        try "<a id='go' href='second.html'>next</a><video src='https://cdn.example/first.mp4'></video>"
            .write(to: first, atomically: true, encoding: .utf8)
        try "<video src='https://cdn.example/second.mp4'></video>"
            .write(to: directory.appendingPathComponent("second.html"), atomically: true, encoding: .utf8)
        browser.webView.loadFileURL(first, allowingReadAccessTo: directory)
        try await waitUntil("first page video") { candidateURLs(browser).contains("https://cdn.example/first.mp4") }
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('go').click(); true")
        try await waitUntil("second page replaces list") { candidateURLs(browser) == ["https://cdn.example/second.mp4"] }
        browser.back()
        try await waitUntil("first page video after back") { candidateURLs(browser) == ["https://cdn.example/first.mp4"] }
    }

    /// 往返缓存恢复不会重跑脚本：提交清空列表、旧代次作废后，页面要重新报到并重放上报
    @MainActor func testCacheRestoredPageReplaysReports() async throws {
        let (browser, _) = try makeBrowser()
        browser.webView.loadHTMLString("<video src='https://cdn.example/cached.mp4'></video>",
                                       baseURL: URL(string: "https://fixture.review"))
        try await waitUntil("video detected") { candidateURLs(browser).contains("https://cdn.example/cached.mp4") }
        // 模拟后退：导航决策发出新代次，随后提交
        browser.sniffer.prepareNavigation(controller: WKUserContentController(), source: "")
        browser.webView(browser.webView, didCommit: nil)
        XCTAssertTrue(browser.sniffer.candidates.isEmpty)
        _ = try await browser.webView.evaluateJavaScript(
            "window.dispatchEvent(new PageTransitionEvent('pageshow', {persisted: true})); true")
        try await waitUntil("reports replayed") { candidateURLs(browser).contains("https://cdn.example/cached.mp4") }
    }

    /// 首次加载失败时 WebView 没有可刷新的页面；「重试」必须重新打开失败的地址
    @MainActor func testRetryReopensFailedAddress() throws {
        let (browser, _) = try makeBrowser()
        let failed = URL(string: "https://fixture.review/episode")!
        browser.webView(browser.webView, didFailProvisionalNavigation: nil, withError: NSError(
            domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost,
            userInfo: [NSURLErrorFailingURLErrorKey: failed]))
        XCTAssertNotNil(browser.errorMessage)
        browser.reload()
        XCTAssertNil(browser.errorMessage)
        XCTAssertEqual(browser.webView.url, failed)
        browser.stopLoading()
    }
    @MainActor func testManyUncommittedNavigationsAreBoundedAndKeepCurrentDocumentAlive() async throws {
        let (browser, _) = try makeBrowser()
        browser.webView.loadHTMLString("<video id='v' src='https://cdn.example/original.mp4'></video>",
                                       baseURL: URL(string: "https://fixture.review"))
        try await waitUntil("original video") { candidateURLs(browser).contains("https://cdn.example/original.mp4") }
        let controller = WKUserContentController()
        for _ in 0..<500 { browser.sniffer.prepareNavigation(controller: controller, source: "") }
        XCTAssertEqual(browser.sniffer.acceptedGenerations.count, 100)
        _ = try await browser.webView.evaluateJavaScript("document.getElementById('v').src = 'https://cdn.example/still-active.mp4'; true")
        try await waitUntil("current document remains accepted") {
            candidateURLs(browser).contains("https://cdn.example/still-active.mp4")
        }
    }

    @MainActor func testRepeatedSPARoutesAndFragmentChangesPreserveCurrentPageMedia() async throws {
        let (browser, _) = try makeBrowser()
        browser.webView.loadHTMLString("<video src='https://cdn.example/initial.mp4'></video>",
                                       baseURL: URL(string: "https://fixture.review/start"))
        try await waitUntil("initial media") { !browser.sniffer.candidates.isEmpty }
        _ = try await browser.webView.evaluateJavaScript("""
        (async () => { for (let i = 0; i < 200; i++) {
          document.body.replaceChildren();
          history.replaceState({}, '', '/episode/' + i);
          const video = document.createElement('video'); video.preload = 'none';
          video.src = 'https://cdn.example/' + i + '.mp4'; document.body.appendChild(video);
          await new Promise(resolve => setTimeout(resolve, 120));
        }
        location.hash = 'player'; })(); true
        """)
        try await waitUntil("last SPA episode and fragment", timeout: 40) {
            candidateURLs(browser) == ["https://cdn.example/199.mp4"] && browser.webView.url?.fragment == "player"
        }
        XCTAssertFalse(browser.sniffer.candidates.first?.isCurrent == true, "Assigning src alone is not playback")
        XCTAssertNil(browser.errorMessage)
    }

    @MainActor func testRepeatedDocumentSwitchesRejectPreviousPageMessages() async throws {
        let (browser, _) = try makeBrowser()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        var previousGeneration = ""
        for index in 0..<20 {
            let file = directory.appendingPathComponent("page-\(index).html")
            try "<video preload='none' src='https://cdn.example/\(index).mp4'></video>".write(to: file, atomically: true, encoding: .utf8)
            browser.webView.loadFileURL(file, allowingReadAccessTo: directory)
            try await waitUntil("document \(index) replaces previous media") {
                candidateURLs(browser) == ["https://cdn.example/\(index).mp4"]
            }
            if !previousGeneration.isEmpty {
                _ = try await isolatedJavaScript(browser.webView, """
                webkit.messageHandlers.videoSniffer.postMessage({generation:'\(previousGeneration)',
                  frameID:'retired-frame', url:'https://cdn.example/stale.mp4', current:true}); return true;
                """)
            }
            let value = try await isolatedJavaScript(browser.webView, "return window.__webcastGeneration;")
            previousGeneration = try XCTUnwrap(value as? String)
        }
        // A final bridge round trip also drains earlier stale-message deliveries.
        _ = try await browser.webView.evaluateJavaScript("true")
        XCTAssertEqual(candidateURLs(browser), ["https://cdn.example/19.mp4"])
    }

}
