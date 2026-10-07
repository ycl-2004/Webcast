import XCTest
import WebKit
import UIKit
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
        let suite = "webcast.review.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("start", forKey: SettingsKeys.defaultPage)
        let browser = BrowserModel(defaults: defaults, dataStore: .nonPersistent())
        XCTAssertTrue(browser.showingStartPage)
        XCTAssertEqual(browser.homeTitle, "爱壹帆")
        defaults.set("https://example.org", forKey: SettingsKeys.homeURL)
        defaults.set(true, forKey: SettingsKeys.desktopSite)
        browser.applySettings()
        XCTAssertEqual(browser.homeURL.host, "example.org")
        XCTAssertEqual(browser.homeTitle, "主页")
        XCTAssertEqual(browser.webView.customUserAgent, BrowserAddress.desktopUA)
        defaults.set("invalid", forKey: SettingsKeys.homeURL)
        defaults.set(false, forKey: SettingsKeys.desktopSite)
        browser.applySettings()
        XCTAssertEqual(browser.homeURL.absoluteString, SettingsKeys.defaultHome)
        XCTAssertNotEqual(browser.webView.customUserAgent, BrowserAddress.desktopUA)
    }

    @MainActor func testWebsiteClearRemovesIndexedDBAfterUnloadingPage() async throws {
        let suite = "webcast.review.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("start", forKey: SettingsKeys.defaultPage)
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let browser = BrowserModel(defaults: defaults, dataStore: dataStore)
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
        let suite = "webcast.review.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("start", forKey: SettingsKeys.defaultPage)
        let browser = BrowserModel(defaults: defaults, dataStore: .nonPersistent())
        let completed = expectation(description: "prompt cancelled")
        let probe = PromptProbe(browser: browser, completed: completed)
        browser.webView.uiDelegate = probe
        browser.webView.loadHTMLString("<script>prompt('review', 'default');</script>", baseURL: URL(string: "https://fixture.review"))
        await fulfillment(of: [completed], timeout: 10)
        XCTAssertEqual(probe.completionCount, 1)
        withExtendedLifetime(probe) {}
    }

    @MainActor func testRepeatedWebContentTerminationShowsManualRecovery() throws {
        let suite = "webcast.review.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("start", forKey: SettingsKeys.defaultPage)
        let browser = BrowserModel(defaults: defaults, dataStore: .nonPersistent())
        browser.open(URL(string: "about:blank")!)
        browser.webViewWebContentProcessDidTerminate(browser.webView)
        browser.webViewWebContentProcessDidTerminate(browser.webView)
        XCTAssertEqual(browser.errorMessage, "网页已暂停，请刷新继续。")
    }
}
