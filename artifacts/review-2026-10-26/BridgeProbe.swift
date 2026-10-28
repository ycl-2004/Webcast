// Isolated macOS audit harness. Compiles the unchanged CandidateStore and VideoSniffer.
// Uses synthetic HTML only. No media URL is requested and no Cast SDK is linked.
import AppKit
import WebKit

@MainActor
final class BridgeProbe: NSObject, WKNavigationDelegate {
    let sniffer = VideoSniffer()
    var view: WKWebView!

    func start(script: String) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(WeakScriptHandler(sniffer), name: "videoSniffer")
        sniffer.prepareNavigation(controller: configuration.userContentController, source: script)
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: 320, height: 480), configuration: configuration)
        view.navigationDelegate = self
        view.loadHTMLString("<title>Synthetic audit fixture</title><p>No media elements or network requests.</p>",
                            baseURL: URL(string: "https://fixture.invalid"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            print("{\"error\":\"WebKit fixture timed out\"}")
            exit(2)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // A page can invoke the bridge without creating or playing a video element.
        webView.evaluateJavaScript("""
        window.webkit.messageHandlers.videoSniffer.postMessage({
          type:'restored', generation:'audit-forged-generation', frameID:'audit-forged-frame'
        });
        window.webkit.messageHandlers.videoSniffer.postMessage({
          generation:'audit-forged-generation', frameID:'audit-forged-frame',
          url:'https://cdn.invalid/not-actually-playing.mp4', current:true,
          title:'Synthetic claimed current video', pageURL:'https://other.invalid/forged'
        });
        null;
        """
        ) { _, error in
            if let error { print(error); exit(2) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.finish() }
        }
    }

    func finish() {
        var store = CandidateStore()
        let privateAddressAccepted = store.ingest(["url":"http://192.168.1.1/audit.mp4"])
        let longField = String(repeating: "x", count: 1_048_576)
        store.ingest(["url":"https://cdn.invalid/metadata.mp4", "source":longField, "segmentFormat":longField])
        let retained = store.items["https://cdn.invalid/metadata.mp4"]!
        let report: [String: Any] = [
            "platform":"macOS WKWebView; unchanged native ingestion code",
            "noVideoElementForgedCurrentAccepted":sniffer.candidates.first?.isCurrent == true,
            "forgedRestoreGenerationAccepted":sniffer.acceptedGenerations.contains("audit-forged-generation"),
            "forgedCandidateHost":sniffer.candidates.first?.url.host ?? "",
            "privateHTTPMediaAddressAccepted":privateAddressAccepted,
            "retainedSourceBytes":retained.source.utf8.count,
            "retainedSegmentFormatBytes":retained.segmentFormat?.utf8.count ?? 0,
            "receiverContacted":false
        ]
        let data = try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding:data, as:UTF8.self))
        exit(0)
    }
}

@main
enum AuditMain {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let runner = BridgeProbe()
        runner.start(script:try String(contentsOfFile:CommandLine.arguments[1], encoding:.utf8))
        withExtendedLifetime(runner) { app.run() }
    }
}
