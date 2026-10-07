import Foundation
import WebKit
import Combine

@MainActor
final class VideoSniffer: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published private(set) var candidates: [VideoCandidate] = []
    private var store = CandidateStore()
    private(set) var generation = UUID().uuidString

    static func scriptSource() throws -> String {
        guard let url = Bundle.main.url(forResource: "sniff", withExtension: "js") else {
            throw NSError(domain: "Webcast", code: 1, userInfo: [NSLocalizedDescriptionKey:"缺少视频检测脚本，请重新安装 App。"])
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func prepareNavigation(controller: WKUserContentController, source: String) {
        generation = UUID().uuidString
        reset()
        controller.removeAllUserScripts()
        // Page world is necessary to intercept the site's fetch and native media setters.
        // https://developer.apple.com/documentation/webkit/wkuserscript
        controller.addUserScript(WKUserScript(
            source: "window.__webcastGeneration = '\(generation)';\n" + source,
            injectionTime: .atDocumentStart, forMainFrameOnly: false))
    }

    func reset() { store.reset(); candidates = [] }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "videoSniffer", let body = message.body as? [String: Any],
              body["generation"] as? String == generation else { return }
        if body["type"] as? String == "route" {
            if message.frameInfo.isMainFrame { reset() }
            return
        }
        // The bridge accepts media data only; it can never connect to or command a TV.
        if store.ingest(body) { candidates = store.sorted }
    }
}

final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
