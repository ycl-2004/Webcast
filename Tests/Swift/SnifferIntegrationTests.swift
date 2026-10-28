import XCTest
import WebKit
@testable import Webcast

@MainActor
private final class ScriptProbe: NSObject, WKScriptMessageHandler {
    var receive: ([String: Any]) -> Void = { _ in }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? [String: Any] {
            if let error = body["fixtureError"] as? String { XCTFail("Fixture JavaScript: \(error)") }
            receive(body)
        }
    }
}

final class SnifferIntegrationTests: XCTestCase {
    @MainActor private func fixture(_ html: String, probe: ScriptProbe, setup: String = "", visible: Bool = false) throws -> WKWebView {
        let controller = WKUserContentController()
        controller.add(probe, name: "videoSniffer")
        let diagnostics = """
        const fixtureError = value => webkit.messageHandlers.videoSniffer.postMessage({fixtureError:String(value)});
        window.addEventListener('error', event => fixtureError(event.message));
        window.addEventListener('unhandledrejection', event => fixtureError(event.reason));
        """
        let script = diagnostics + setup + "\nwindow.__webcastGeneration = 'test';\n" + (try VideoSniffer.scriptSource())
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: configuration)
        if visible {
            // Route/timer fixtures must stay foregrounded, as in the actual browser.
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previous = scene.windows.first { $0.isKeyWindow }
            let window = UIWindow(windowScene: scene)
            let controller = UIViewController()
            controller.view = view
            window.rootViewController = controller
            window.makeKeyAndVisible()
            addTeardownBlock {
                await MainActor.run {
                    view.stopLoading()
                    window.isHidden = true
                    window.rootViewController = nil
                    previous?.makeKeyAndVisible()
                }
            }
        }
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

    /// 分片格式只写在子列表里；主列表要继承它，电视才会用 fMP4 解析器
    @MainActor func testMasterInheritsVariantSegmentFormat() async throws {
        let inherited = expectation(description:"master carries variant metadata")
        let probe = ScriptProbe()
        probe.receive = { body in
            if body["url"] as? String == "https://cdn.example/master.m3u8", body["master"] as? Bool == true,
               body["segmentFormat"] as? String == "fmp4", body["live"] as? Bool == false {
                inherited.fulfill(); probe.receive = { _ in }
            }
        }
        let setup = """
        window.fetch = function(url) {
          const child = String(url).endsWith('child.m3u8');
          const body = child ? '#EXTM3U\\n#EXT-X-MAP:URI="init.mp4"\\n#EXTINF:4,\\nseg1.m4s\\n#EXT-X-ENDLIST'
                             : '#EXTM3U\\n#EXT-X-STREAM-INF:BANDWIDTH=1000\\nchild.m3u8';
          const response = new Response(body, {headers:{'content-type':'application/vnd.apple.mpegurl'}});
          Object.defineProperty(response, 'url', {value:String(url)});
          return Promise.resolve(response);
        };
        """
        let view = try fixture("""
        <script>fetch('https://cdn.example/master.m3u8').then(r => r.text())
        .then(() => new Promise(resolve => setTimeout(resolve, 100)))
        .then(() => fetch('https://cdn.example/child.m3u8')).then(r => r.text());</script>
        """, probe:probe, setup:setup)
        await fulfillment(of: [inherited], timeout:10)
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

    @MainActor func testReturningToPreviousVideoReportsActivationWithoutDuplicateEvents() async throws {
        let completed = expectation(description:"A to B to A playback")
        let probe = ScriptProbe()
        var reports: [String] = []
        var store = CandidateStore()
        probe.receive = { body in
            if body["current"] as? Bool == true, let url = body["url"] as? String { reports.append(url) }
            store.ingest(body)
            if body["finished"] as? Bool == true {
                XCTAssertEqual(reports, ["https://cdn.example/a.mp4", "https://cdn.example/b.mp4", "https://cdn.example/a.mp4"])
                XCTAssertTrue(store.items["https://cdn.example/a.mp4"]!.isCurrent)
                XCTAssertFalse(store.items["https://cdn.example/b.mp4"]!.isCurrent)
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("""
        <video id='a' src='https://cdn.example/a.mp4'></video>
        <video id='b' src='https://cdn.example/b.mp4'></video>
        <script>
        for (const id of ['a', 'b', 'a', 'a']) {
          document.getElementById(id).dispatchEvent(new Event('play'));
        }
        webkit.messageHandlers.videoSniffer.postMessage({finished:true});
        </script>
        """, probe:probe)
        await fulfillment(of: [completed], timeout:10)
        withExtendedLifetime(view) {}
    }

    @MainActor func testCacheReplayKeepsMostRecentlyActivatedVideoCurrent() async throws {
        let completed = expectation(description:"active video survives cache replay")
        let probe = ScriptProbe()
        var store = CandidateStore()
        probe.receive = { body in
            if body["type"] as? String == "restored" { store.reset() }
            store.ingest(body)
            if body["finished"] as? Bool == true {
                XCTAssertTrue(store.items["https://cdn.example/a.mp4"]!.isCurrent)
                XCTAssertFalse(store.items["https://cdn.example/b.mp4"]!.isCurrent)
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("""
        <video id='a' src='https://cdn.example/a.mp4'></video>
        <video id='b' src='https://cdn.example/b.mp4'></video>
        <script>
        for (const id of ['a', 'b', 'a']) document.getElementById(id).dispatchEvent(new Event('play'));
        document.dispatchEvent(new Event('DOMContentLoaded'));
        window.dispatchEvent(new PageTransitionEvent('pageshow', {persisted:true}));
        webkit.messageHandlers.videoSniffer.postMessage({finished:true});
        </script>
        """, probe:probe)
        await fulfillment(of: [completed], timeout:10)
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
    @MainActor func testNonPlaylistResponsesAreNotClonedAndRemainReadable() async throws {
        let completed = expectation(description: "ordinary responses untouched")
        let probe = ScriptProbe()
        probe.receive = { body in
            if let clones = body["clones"] as? Int {
                XCTAssertEqual(clones, 0)
                XCTAssertEqual(body["readable"] as? Bool, true)
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let setup = """
        window.clones = 0;
        window.fetch = function(mime) {
          const response = new Response('ordinary content', {headers:{'content-type':mime}});
          Object.defineProperty(response, 'url', {value:'https://cdn.example/resource'});
          const clone = response.clone.bind(response);
          response.clone = () => { window.clones++; return clone(); };
          return Promise.resolve(response);
        };
        """
        let view = try fixture("""
        <script>(async () => {
          const values = await Promise.all(['application/json','text/html','text/css','video/mp4','video/mp2t','text/event-stream']
            .map(mime => fetch(mime).then(r => r.text())));
          webkit.messageHandlers.videoSniffer.postMessage({clones, readable:values.every(v => v === 'ordinary content')});
        })();</script>
        """, probe: probe, setup: setup)
        await fulfillment(of: [completed], timeout: 10)
        withExtendedLifetime(view) {}
    }

    /// Cancelling the inspection's tee branch must not cancel the website's response.
    @MainActor func testConcurrentInspectionIsBoundedAndRouteChangesCancelOnlyClones() async throws {
        let completed = expectation(description: "bounded readers and route cleanup")
        let probe = ScriptProbe()
        probe.receive = { body in
            if let clones = body["clones"] as? Int {
                XCTAssertEqual(clones, 4)
                XCTAssertEqual(body["cancelledClones"] as? Int, 4)
                XCTAssertEqual(body["cancelledOriginals"] as? Int, 0)
                XCTAssertEqual(body["readable"] as? Bool, true)
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("""
        <script>(async () => {
          const responses = await Promise.all(Array.from({length:20}, (_, i) => fetch('https://cdn.example/' + i + '.m3u8')));
          history.replaceState({}, '', '/next');
          const values = await Promise.all(responses.map(r => r.body.getReader().read()));
          webkit.messageHandlers.videoSniffer.postMessage({clones, cancelledClones, cancelledOriginals,
            readable:values.every(v => new TextDecoder().decode(v.value).startsWith('#EXTM3U'))});
        })();</script>
        """, probe: probe, setup: trackedStreamingFetch)
        await fulfillment(of: [completed], timeout: 10)
        withExtendedLifetime(view) {}
    }

    @MainActor func testNeverEndingInspectionTimesOutWithoutCancellingWebsiteStream() async throws {
        let completed = expectation(description: "inspection timeout")
        let probe = ScriptProbe()
        probe.receive = { body in
            if let cancelled = body["cancelledClones"] as? Int {
                XCTAssertEqual(cancelled, 1)
                XCTAssertEqual(body["cancelledOriginals"] as? Int, 0)
                XCTAssertEqual(body["readable"] as? Bool, true)
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("""
        <script>(async () => {
          const response = await fetch('https://cdn.example/never.m3u8');
          await new Promise(resolve => setTimeout(resolve, 5300));
          const first = await response.body.getReader().read();
          webkit.messageHandlers.videoSniffer.postMessage({cancelledClones, cancelledOriginals,
            readable:new TextDecoder().decode(first.value).startsWith('#EXTM3U')});
        })();</script>
        """, probe: probe, setup: trackedStreamingFetch)
        // Allow extra time for WebKit startup and timer scheduling on hosted simulators.
        await fulfillment(of: [completed], timeout: 25)
        withExtendedLifetime(view) {}
    }

    private var trackedStreamingFetch: String {
        """
        window.clones = 0; window.cancelledClones = 0; window.cancelledOriginals = 0;
        window.fetch = function(url) {
          const stream = new ReadableStream({
            start(controller) { controller.enqueue(new TextEncoder().encode('#EXTM3U\\n')); },
            cancel() { window.cancelledOriginals++; }
          });
          const response = new Response(stream, {headers:{'content-type':'application/vnd.apple.mpegurl'}});
          Object.defineProperty(response, 'url', {value:String(url)});
          const clone = response.clone.bind(response);
          response.clone = () => {
            window.clones++;
            const copy = clone();
            const getReader = copy.body.getReader.bind(copy.body);
            copy.body.getReader = () => {
              const reader = getReader();
              const cancel = reader.cancel.bind(reader);
              reader.cancel = () => { window.cancelledClones++; return cancel(); };
              return reader;
            };
            return copy;
          };
          return Promise.resolve(response);
        };
        """
    }

    @MainActor func testOldFetchAndXHRDoNotReappearAfterReturningToSameRoute() async throws {
        let completed = expectation(description: "route A B A rejects stale responses")
        let probe = ScriptProbe()
        var urls: [String] = []
        probe.receive = { body in
            if let url = body["url"] as? String { urls.append(url) }
            if body["finished"] as? Bool == true {
                XCTAssertEqual(Set(urls), ["https://cdn.example/current.mp4"])
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let setup = """
        window.fetch = () => new Promise(resolve => { window.finishFetch = resolve; });
        window.XMLHttpRequest = class extends EventTarget {
          open(method, url) { this.responseURL = url; }
          getResponseHeader() { return 'application/vnd.apple.mpegurl'; }
          send() { this.responseText = '#EXTM3U'; this.dispatchEvent(new Event('load')); }
        };
        """
        let view = try fixture("""
        <body><script>(async () => {
          history.replaceState({}, '', '/initial');
          const request = new XMLHttpRequest(); request.open('GET', 'https://cdn.example/old-xhr.m3u8');
          const pending = fetch('https://cdn.example/old-fetch.m3u8');
          const initial = location.href;
          history.replaceState({}, '', '/other'); history.replaceState({}, '', initial);
          const response = new Response('#EXTM3U', {headers:{'content-type':'application/vnd.apple.mpegurl'}});
          Object.defineProperty(response, 'url', {value:'https://cdn.example/old-fetch.m3u8'});
          finishFetch(response); request.send(); await pending;
          const video = document.createElement('video'); video.src = 'https://cdn.example/current.mp4'; document.body.appendChild(video);
          await new Promise(resolve => setTimeout(resolve, 100));
          webkit.messageHandlers.videoSniffer.postMessage({finished:true});
        })();</script>
        """, probe: probe, setup: setup, visible: true)
        await fulfillment(of: [completed], timeout: 10)
        withExtendedLifetime(view) {}
    }

    @MainActor func testOversizedPlaylistIsNotParsedAndOriginalResponseRemainsReadable() async throws {
        let completed = expectation(description: "bounded playlist body")
        let probe = ScriptProbe()
        var parsedMaster = false
        probe.receive = { body in
            if body["master"] as? Bool == true { parsedMaster = true }
            if let count = body["originalBytes"] as? Int {
                XCTAssertGreaterThan(count, 512 * 1024)
                XCTAssertFalse(parsedMaster)
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("""
        <script>fetch('https://cdn.example/large.m3u8').then(r => r.text()).then(async text => {
          await new Promise(resolve => setTimeout(resolve, 100));
          webkit.messageHandlers.videoSniffer.postMessage({originalBytes:text.length});
        });</script>
        """, probe: probe, setup: """
        window.fetch = function(url) {
          const response = new Response('#EXTM3U\\n#EXT-X-STREAM-INF:BANDWIDTH=1\\na.m3u8\\n' + '#'.repeat(600000),
            {headers:{'content-type':'application/vnd.apple.mpegurl'}});
          Object.defineProperty(response, 'url', {value:String(url)});
          return Promise.resolve(response);
        };
        """)
        await fulfillment(of: [completed], timeout: 10)
        withExtendedLifetime(view) {}
    }

    @MainActor func testPlaylistCachesStayBoundedDuringRepeatedRequests() async throws {
        let completed = expectation(description: "bounded playlist caches")
        let probe = ScriptProbe()
        probe.receive = { body in
            if let sizes = body["cacheSizes"] as? [Int] {
                XCTAssertEqual(sizes.sorted(), [100, 200, 200])
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("""
        <script>(async () => {
          for (let i = 0; i < 260; i++) {
            await fetch('https://cdn.example/' + i + '.m3u8').then(r => r.text());
          }
          await new Promise(resolve => setTimeout(resolve, 100));
          webkit.messageHandlers.videoSniffer.postMessage({cacheSizes:cacheInstances.map(cache => cache.size)});
        })();</script>
        """, probe: probe, setup: """
        window.cacheInstances = [];
        window.Map = class extends Map { constructor(...args) { super(...args); cacheInstances.push(this); } };
        window.fetch = function(url) {
          const response = new Response('#EXTM3U\\n#EXT-X-STREAM-INF:BANDWIDTH=1000\\n' + url + '-child',
            {headers:{'content-type':'application/vnd.apple.mpegurl'}});
          Object.defineProperty(response, 'url', {value:String(url)});
          return Promise.resolve(response);
        };
        """)
        await fulfillment(of: [completed], timeout: 15)
        withExtendedLifetime(view) {}
    }

    @MainActor func testMSEPrefersMasterWithEveryQualityVariantAvailable() async throws {
        let completed = expectation(description: "MSE uses full quality master")
        let probe = ScriptProbe()
        var store = CandidateStore()
        probe.receive = { body in
            store.ingest(body)
            if body["finished"] as? Bool == true {
                XCTAssertEqual(store.sorted.first?.url.absoluteString, "https://cdn.example/master.m3u8?token=a%2Fb")
                XCTAssertTrue(store.sorted.first?.isMaster == true)
                XCTAssertTrue(store.sorted.first?.isCurrent == true)
                XCTAssertEqual(store.sorted.first?.segmentFormat, "fmp4")
                XCTAssertEqual(store.sorted.first?.isLive, false)
                completed.fulfill(); probe.receive = { _ in }
            }
        }
        let view = try fixture("""
        <video id='player' src='blob:https://fixture.example/test'></video>
        <script>(async () => {
          await fetch('https://cdn.example/master.m3u8?token=a%2Fb').then(r => r.text());
          await new Promise(resolve => setTimeout(resolve, 50));
          await fetch('https://cdn.example/low.m3u8').then(r => r.text());
          await new Promise(resolve => setTimeout(resolve, 50));
          document.getElementById('player').dispatchEvent(new Event('play'));
          webkit.messageHandlers.videoSniffer.postMessage({finished:true});
        })();</script>
        """, probe: probe, setup: """
        window.fetch = function(url) {
          const body = String(url).includes('master')
            ? '#EXTM3U\\n#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360\\nlow.m3u8\\n#EXT-X-STREAM-INF:BANDWIDTH=15000000,RESOLUTION=3840x2160\\nuhd.m3u8'
            : '#EXTM3U\\n#EXT-X-MAP:URI="init.mp4"\\n#EXTINF:4,\\nseg.m4s\\n#EXT-X-ENDLIST';
          const response = new Response(body, {headers:{'content-type':'application/vnd.apple.mpegurl'}});
          Object.defineProperty(response, 'url', {value:String(url)});
          return Promise.resolve(response);
        };
        """)
        await fulfillment(of: [completed], timeout: 10)
        withExtendedLifetime(view) {}
    }

}
