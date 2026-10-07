import Foundation
import WebKit
import Combine
import UIKit

@MainActor
final class BrowserModel: NSObject, ObservableObject {
    @Published var address = ""
    @Published private(set) var title = "浏览器"
    @Published private(set) var progress = 0.0
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published var errorMessage: String?
    /// 原生起始页：默认打开时展示，第一次导航后消失
    @Published private(set) var showingStartPage = false
    @Published private(set) var isClearingWebsiteData = false
    /// 用户正在编辑地址栏时暂停 URL 回写，避免覆盖输入
    @Published var isEditingAddress = false {
        didSet {
            if oldValue && !isEditingAddress, !showingStartPage, let url = webView.url {
                address = url.isFileURL ? "" : url.absoluteString
            }
        }
    }
    let sniffer = VideoSniffer()
    let webView: WKWebView
    @Published private(set) var homeURL = URL(string: SettingsKeys.defaultHome)!
    private var blockPopups = true
    private var desktopSite = false
    private var searchEngine = "bing"
    private var observations: [NSKeyValueObservation] = []
    private var displayedURL: URL?
    private let script: String
    private let defaults: UserDefaults
    private var recoveryAttempts = 0
    private var activeDialog: UIAlertController?
    private var cancelDialog: (() -> Void)?
    private var dataClearCompletion: ((Bool) -> Void)?
    private var dataClearNavigation: WKNavigation?

    init(defaults: UserDefaults = .standard, dataStore: WKWebsiteDataStore? = nil) {
        self.defaults = defaults
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = dataStore ?? .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        var sniffScript = ""
        do { sniffScript = try VideoSniffer.scriptSource() }
        catch {
            // 检测脚本缺失时降级为普通浏览器，而不是让整个浏览器变白屏
            errorMessage = "视频检测不可用（\(error.localizedDescription)），仍可正常浏览网页。"
        }
        script = sniffScript
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.scheduleRefresh() }
        ]
        applySettings()
        #if DEBUG
        if ProcessInfo.processInfo.environment["WEBCAST_DEMO"] == "1" {
            openDemo()
            return
        }
        #endif
        if defaults.string(forKey: SettingsKeys.defaultPage) == "start" {
            showingStartPage = true
            return
        }
        guard !script.isEmpty else {
            open(initialURL())
            return
        }
        configuration.userContentController.add(WeakScriptHandler(sniffer), name: "videoSniffer")
        sniffer.prepareNavigation(controller: configuration.userContentController, source: script)
        open(initialURL())
    }

    /// 依据「浏览器打开时加载」设置决定首个页面：上次访问的页面或主页
    private func initialURL() -> URL {
        let startLoad = defaults.string(forKey: SettingsKeys.startLoad) ?? "last"
        if startLoad == "last",
           let raw = defaults.string(forKey: SettingsKeys.lastURL),
           let url = BrowserAddress.resolve(raw) {
            return url
        }
        return homeURL
    }

    /// 读取设置并应用到 WebView；设置页每次改动后调用
    func applySettings() {
        blockPopups = defaults.object(forKey: SettingsKeys.blockPopups) as? Bool ?? true
        desktopSite = defaults.object(forKey: SettingsKeys.desktopSite) as? Bool ?? false
        searchEngine = defaults.string(forKey: SettingsKeys.searchEngine) ?? "bing"
        homeURL = BrowserAddress.resolve(defaults.string(forKey: SettingsKeys.homeURL) ?? SettingsKeys.defaultHome)
            ?? URL(string: SettingsKeys.defaultHome)!
        webView.customUserAgent = desktopSite ? BrowserAddress.desktopUA : nil
    }

    func openAddress() {
        guard let url = BrowserAddress.resolve(address)
                ?? BrowserAddress.searchURL(for: address, engine: searchEngine) else {
            errorMessage = "请输入有效的网址或搜索词。"; return
        }
        open(url)
    }

    func open(_ url: URL) {
        guard !isClearingWebsiteData else { return }
        cancelDialogs()
        recoveryAttempts = 0
        errorMessage = nil
        showingStartPage = false
        webView.load(URLRequest(url: url))
    }

    func openHome() { open(homeURL) }
    var homeTitle: String {
        let host = homeURL.host?.lowercased() ?? ""
        return host == "iyf.tv" || host.hasSuffix(".iyf.tv") ? "爱壹帆" : "主页"
    }
    func reload() { cancelDialogs(); recoveryAttempts = 0; errorMessage = nil; webView.reload() }
    func back() { cancelDialogs(); recoveryAttempts = 0; webView.goBack() }
    func forward() { cancelDialogs(); recoveryAttempts = 0; webView.goForward() }
    func stopLoading() { webView.stopLoading() }

    #if DEBUG
    func openDemo() {
        guard let url = Bundle.main.url(forResource: "sniffer-demo", withExtension: "html") else {
            errorMessage = "未找到检测示例页面。"; return
        }
        errorMessage = nil
        showingStartPage = false
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    #endif

    func clearWebsiteData(completion: @escaping (Bool) -> Void) {
        guard !isClearingWebsiteData else { return }
        isClearingWebsiteData = true
        dataClearCompletion = completion
        cancelDialogs()
        webView.stopLoading()
        showingStartPage = true
        address = ""
        errorMessage = nil
        defaults.removeObject(forKey: SettingsKeys.lastURL)
        sniffer.reset()
        // 先卸载当前页面，避免仍运行的脚本立即重建 Cookie 和登录状态。
        dataClearNavigation = webView.loadHTMLString("", baseURL: nil)
        if dataClearNavigation == nil { finishWebsiteDataClear(success: false) }
    }

    private func removeWebsiteData() {
        guard let completion = dataClearCompletion else { return }
        dataClearNavigation = nil
        dataClearCompletion = nil
        webView.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                                         modifiedSince: .distantPast) { [weak self] in
            self?.isClearingWebsiteData = false
            completion(true)
        }
    }

    private func finishWebsiteDataClear(success: Bool) {
        let completion = dataClearCompletion
        dataClearNavigation = nil
        dataClearCompletion = nil
        isClearingWebsiteData = false
        completion?(success)
    }

    func cancelDialogs() {
        let dialog = activeDialog
        let cancellation = cancelDialog
        activeDialog = nil
        cancelDialog = nil
        dialog?.dismiss(animated: false)
        cancellation?()
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
                if !isEditingAddress && !showingStartPage {
                    address = url.isFileURL ? "" : url.absoluteString
                }
                // 记录最近页面，供下次启动恢复
                if !isClearingWebsiteData && !showingStartPage,
                   ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    defaults.set(url.absoluteString, forKey: SettingsKeys.lastURL)
                }
            }
        }
    }
}

extension BrowserModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if isClearingWebsiteData && url.scheme != "about" { decisionHandler(.cancel); return }
        guard ["https", "http", "file", "about"].contains(url.scheme?.lowercased() ?? "") else {
            errorMessage = "这个链接需要其他 App。请使用网页播放入口。"
            decisionHandler(.cancel); return
        }
        if navigationAction.targetFrame?.isMainFrame == true {
            cancelDialogs()
            if navigationAction.navigationType != .reload { recoveryAttempts = 0 }
            errorMessage = nil
            sniffer.prepareNavigation(controller: webView.configuration.userContentController, source: script)
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let clearing = dataClearNavigation, navigation === clearing { removeWebsiteData() }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let clearing = dataClearNavigation, navigation === clearing { finishWebsiteDataClear(success: false) }
        show(error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let clearing = dataClearNavigation, navigation === clearing { finishWebsiteDataClear(success: false) }
        show(error)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        cancelDialogs()
        sniffer.reset()
        if isClearingWebsiteData { removeWebsiteData(); return }
        guard !showingStartPage else { return }
        // 只在前台恢复一次；反复崩溃或后台被回收时，交由用户手动重试。
        guard UIApplication.shared.applicationState == .active, recoveryAttempts == 0 else {
            errorMessage = "网页已暂停，请刷新继续。"
            return
        }
        recoveryAttempts += 1
        webView.reload()
    }
    private func show(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        errorMessage = "网页加载失败：\(error.localizedDescription)"
    }
}

extension BrowserModel: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // 拦截 _blank 弹窗：视频站的广告链接大量使用它，默认丢弃，避免广告劫持当前页
        if !blockPopups, navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    // 导航或后台切换取消对话框时，也必须完成 WebKit 回调。
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: frame.request.url?.host, message: message, preferredStyle: .alert)
        let result = DialogResult<Void> { _ in completionHandler() }
        alert.addAction(UIAlertAction(title: "好", style: .default) { [weak self, weak alert] _ in
            self?.finishDialog(alert)
            result.resolve(())
        })
        presentOnRoot(alert) { result.resolve(()) }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: frame.request.url?.host, message: message, preferredStyle: .alert)
        let result = DialogResult(completionHandler)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self, weak alert] _ in
            self?.finishDialog(alert); result.resolve(false)
        })
        alert.addAction(UIAlertAction(title: "好", style: .default) { [weak self, weak alert] _ in
            self?.finishDialog(alert); result.resolve(true)
        })
        presentOnRoot(alert) { result.resolve(false) }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: frame.request.url?.host, message: prompt, preferredStyle: .alert)
        let result = DialogResult(completionHandler)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self, weak alert] _ in
            self?.finishDialog(alert); result.resolve(nil)
        })
        alert.addAction(UIAlertAction(title: "好", style: .default) { [weak self, weak alert] _ in
            let text = alert?.textFields?.first?.text
            self?.finishDialog(alert); result.resolve(text)
        })
        presentOnRoot(alert) { result.resolve(nil) }
    }

    private func finishDialog(_ alert: UIAlertController?) {
        if activeDialog === alert { activeDialog = nil; cancelDialog = nil }
    }

    private func presentOnRoot(_ alert: UIAlertController, cancellation: @escaping () -> Void) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        var presenter = windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = presenter?.presentedViewController { presenter = presented }
        guard activeDialog == nil, UIApplication.shared.applicationState == .active,
              let presenter, !(presenter is UIAlertController),
              presenter.viewIfLoaded?.window != nil,
              !presenter.isBeingDismissed, !presenter.isBeingPresented else { cancellation(); return }
        activeDialog = alert
        cancelDialog = cancellation
        presenter.present(alert, animated: true)
        if alert.presentingViewController == nil { cancelDialogs() }
    }
}

/// 导航、后台切换与按钮操作可能竞争完成同一个 WebKit 回调。
@MainActor
private final class DialogResult<Value> {
    private var completion: ((Value) -> Void)?
    init(_ completion: @escaping (Value) -> Void) { self.completion = completion }
    func resolve(_ value: Value) {
        let callback = completion
        completion = nil
        callback?(value)
    }
}
