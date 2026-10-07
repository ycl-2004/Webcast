import XCTest
import WebKit
@testable import Webcast

@MainActor
private final class ScriptProbe: NSObject, WKScriptMessageHandler {
    var receive: ([String: Any]) -> Void = { _ in }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? [String: Any] { receive(body) }
    }
}

final class SnifferIntegrationTests: XCTestCase {
    @MainActor private func fixture(_ html: String, probe: ScriptProbe, setup: String = "") throws -> WKWebView {
        let controller = WKUserContentController()
        controller.add(probe, name: "videoSniffer")
        let script = setup + "\nwindow.__webcastGeneration = 'test';\n" + (try VideoSniffer.scriptSource())
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: configuration)
        view.loadHTMLString(html, baseURL: URL(string:"https://fixture.example"))
        return view
    }

    @MainActor func testNativeMediaSourcePropertyAndSourceElements() async throws {
        let received = expectation(description:"native sources")
        let probe = ScriptProbe()
        var found = Set<String>()
        probe.receive = { body in
            if let url = body["url"] as? String { found.insert(url) }
            if found.contains("https://cdn.example/native.m3u8?token=a%2Fb") && found.contains("https://cdn.example/source.mp4") {
                received.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("""
        <video id="v"></video><script>
        document.getElementById('v').src = 'https://cdn.example/native.m3u8?token=a%2Fb';
        const source = document.createElement('source'); source.src = 'https://cdn.example/source.mp4';
        document.getElementById('v').appendChild(source);
        </script>
        """, probe: probe)
        await fulfillment(of: [received], timeout: 10)
        withExtendedLifetime(view) {}
    }

    @MainActor func testInjectedScriptSeesSubframeMedia() async throws {
        let received = expectation(description:"iframe video")
        let probe = ScriptProbe()
        probe.receive = { body in
            if body["url"] as? String == "https://cdn.example/frame.mp4" {
                received.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("<iframe sandbox='allow-scripts' srcdoc=\"<video src='https://cdn.example/frame.mp4'></video>\"></iframe>", probe:probe)
        await fulfillment(of: [received], timeout: 10)
        withExtendedLifetime(view) {}
    }

    @MainActor func testFetchRecognizesExtensionlessMasterAndDoesNotConsumeResponse() async throws {
        let master = expectation(description:"extensionless HLS master")
        let original = expectation(description:"original response readable")
        let probe = ScriptProbe()
        probe.receive = { body in
            if body["url"] as? String == "https://cdn.example/playlist?token=abc", body["master"] as? Bool == true {
                master.fulfill();
            }
            if body["originalReadable"] as? Bool == true { original.fulfill() }
        }
        let setup = """
        window.fetch = function() {
          const response = new Response('#EXTM3U\\n#EXT-X-STREAM-INF:BANDWIDTH=1000\\nchild.m3u8', {headers:{'content-type':'text/plain'}});
          Object.defineProperty(response, 'url', {value:'https://cdn.example/playlist?token=abc'});
          return Promise.resolve(response);
        };
        """
        let view = try fixture("""
        <script>fetch('https://cdn.example/playlist?token=abc').then(r => r.text()).then(t =>
        webkit.messageHandlers.videoSniffer.postMessage({originalReadable:t.startsWith('#EXTM3U')}));</script>
        """, probe:probe, setup:setup)
        await fulfillment(of: [master, original], timeout:10)
        withExtendedLifetime(view) {}
    }

    @MainActor func testBlobURLsNeverCrossBridge() async throws {
        let invalid = expectation(description:"blob must be ignored")
        invalid.isInverted = true
        let probe = ScriptProbe()
        probe.receive = { body in if (body["url"] as? String)?.hasPrefix("blob:") == true { invalid.fulfill() } }
        let view = try fixture("<video src='blob:https://fixture.example/123'></video>", probe:probe)
        await fulfillment(of: [invalid], timeout: 1)
        withExtendedLifetime(view) {}
    }

    @MainActor func testXHRReuseAndPlaylistMetadata() async throws {
        let received = expectation(description:"XHR media playlists")
        let probe = ScriptProbe()
        var found = Set<String>()
        probe.receive = { body in
            if body["source"] as? String == "xhr", let url = body["url"] as? String,
               body["segmentFormat"] as? String == "ts", body["live"] as? Bool == false {
                found.insert(url)
            }
            if found.count == 2 { received.fulfill(); probe.receive = { _ in } }
        }
        let setup = """
        window.XMLHttpRequest = class extends EventTarget {
          open(method, url) { this.responseURL = url; }
          getResponseHeader() { return 'application/vnd.apple.mpegurl'; }
          send() { this.responseType = ''; this.responseText = '#EXTM3U\\n#EXTINF:10,\\nsegment.ts?token=a\\n#EXT-X-ENDLIST'; this.dispatchEvent(new Event('load')); }
        };
        """
        let view = try fixture("""
        <script>const request = new XMLHttpRequest();
        request.open('GET', 'https://cdn.example/one'); request.send();
        request.open('GET', 'https://cdn.example/two'); request.send();</script>
        """, probe:probe, setup:setup)
        await fulfillment(of: [received], timeout:10)
        withExtendedLifetime(view) {}
    }
}
