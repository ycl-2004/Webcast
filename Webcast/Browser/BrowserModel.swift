import Foundation
import WebKit
import Combine
import UIKit

@MainActor
final class BrowserModel: NSObject, ObservableObject {
    @Published var address = "https://www.iyf.tv"
    @Published private(set) var title = "浏览器"
    @Published private(set) var progress = 0.0
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published var errorMessage: String?
    let sniffer = VideoSniffer()
    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private var displayedURL: URL?
    private let script: String

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        do { script = try VideoSniffer.scriptSource() }
        catch { script = ""; super.init(); errorMessage = error.localizedDescription; return }
        super.init()
        configuration.userContentController.add(WeakScriptHandler(sniffer), name: "videoSniffer")
        sniffer.prepareNavigation(controller: configuration.userContentController, source: script)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() }
        ]
        if ProcessInfo.processInfo.environment["WEBCAST_DEMO"] == "1" { openDemo() }
        else { openAddress() }
    }

    func openAddress() {
        guard let url = BrowserAddress.resolve(address) else {
            errorMessage = "请输入有效的网址，例如 iyf.tv。"; return
        }
        errorMessage = nil
        webView.load(URLRequest(url: url))
    }

    func home() { address = "https://www.iyf.tv"; openAddress() }
    func reload() { errorMessage = nil; webView.reload() }
    func back() { webView.goBack() }
    func forward() { webView.goForward() }
    func stopLoading() { webView.stopLoading() }

    func openDemo() {
        guard let url = Bundle.main.url(forResource: "sniffer-demo", withExtension: "html") else {
            errorMessage = "未找到检测示例页面。"; return
        }
        errorMessage = nil
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func pauseLocalPlayback() {
        webView.evaluateJavaScript("document.querySelectorAll('video,audio').forEach(v => v.pause());", completionHandler: nil)
    }

    nonisolated private func scheduleRefresh() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            progress = webView.estimatedProgress
            isLoading = webView.isLoading
            canGoBack = webView.canGoBack
            canGoForward = webView.canGoForward
            title = webView.title ?? "浏览器"
            if let url = webView.url, url != displayedURL {
                displayedURL = url
                address = url.isFileURL ? "" : url.absoluteString
            }
        }
    }
}

extension BrowserModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        guard ["https", "http", "file", "about"].contains(url.scheme?.lowercased() ?? "") else {
            errorMessage = "这个链接需要其他 App。请使用网页播放入口。"
            decisionHandler(.cancel); return
        }
        if navigationAction.targetFrame?.isMainFrame == true {
            errorMessage = nil
            sniffer.prepareNavigation(controller: webView.configuration.userContentController, source: script)
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { show(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { show(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        errorMessage = "网页进程已停止，请刷新页面。"
    }
    private func show(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        errorMessage = "网页加载失败：\(error.localizedDescription)"
    }
}

extension BrowserModel: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}
