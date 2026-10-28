import Foundation
import WebKit
import Combine

@MainActor
final class VideoSniffer: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published private(set) var candidates: [VideoCandidate] = []
    private var store = CandidateStore()
    private var generation = UUID().uuidString
    /// 仍在页面上的脚本代次。每次主框架导航前发新代次，但旧代次要等新文档真正提交才作废：
    /// 页内锚点跳转、加载失败留在原页时，原页面的上报仍然有效。
    private(set) var acceptedGenerations: [String] = []
    private var documentGeneration: String?
    private var issuedGenerations: [String] = []
    private var budget = SnifferMessageBudget()
    private var publication: Task<Void, Never>?
    private var deferred: [String: [String: Any]] = [:]
    private var drain: Task<Void, Never>?
    var playbackRevision: UUID { store.playbackRevision }
    func latestCandidate(for id: String) -> VideoCandidate? { store.items[id] }

    private func accept(_ value: String) {
        acceptedGenerations.removeAll { $0 == value }
        acceptedGenerations.append(value)
        // Failed and same-document navigations may never commit. Bound their generations while
        // keeping the current main document valid, even after many such attempts.
        if acceptedGenerations.count > 100,
           let oldest = acceptedGenerations.firstIndex(where: { $0 != documentGeneration }) {
            acceptedGenerations.remove(at: oldest)
        }
    }

    static func scriptSource() throws -> String {
        guard let url = Bundle.main.url(forResource: "sniff", withExtension: "js") else {
            throw NSError(domain: "Webcast", code: 1, userInfo: [NSLocalizedDescriptionKey:String(localized: "缺少视频检测脚本，请重新安装 App。")])
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func prepareNavigation(controller: WKUserContentController, source: String) {
        generation = UUID().uuidString
        issuedGenerations.append(generation)
        if issuedGenerations.count > 200 { issuedGenerations.removeFirst() }
        accept(generation)
        controller.removeAllUserScripts()
        // Only network hooks share the page's JS world. The native bridge and DOM lifecycle
        // live in defaultClient, whose global objects cannot be accessed by the website.
        // https://developer.apple.com/documentation/webkit/wkcontentworld/defaultclient
        controller.addUserScript(WKUserScript(
            source: "window.__webcastMode = 'network';\n" + source,
            injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .page))
        controller.addUserScript(WKUserScript(
            source: "window.__webcastMode = 'dom'; window.__webcastGeneration = '\(generation)';\n" + source,
            injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .defaultClient))
    }

    /// 主框架提交了新文档：旧页面的候选与代次一并作废
    func documentCommitted() {
        documentGeneration = generation
        acceptedGenerations = [generation]
        reset()
    }

    /// A native post-commit query of the isolated world handles cache-event/commit ordering.
    @discardableResult
    func restoreCommittedGeneration(_ value: String) -> Bool {
        guard issuedGenerations.contains(value) else { return false }
        documentGeneration = value
        acceptedGenerations = [value]
        return true
    }

    func reset() {
        publication?.cancel(); publication = nil
        drain?.cancel(); drain = nil; deferred.removeAll()
        budget = SnifferMessageBudget()
        store.reset(); candidates = []
    }

    private func publishSoon() {
        guard publication == nil else { return }
        publication = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled, let self else { return }
            let next = store.sorted
            if candidates != next { candidates = next }
            publication = nil
        }
    }

    private func deferObservation(_ body: [String: Any], frame: String) {
        guard deferred[frame] != nil || deferred.count < 100 else { return }
        deferred[frame] = body // Preserve the latest observation after a burst, not the whole backlog.
        guard drain == nil else { return }
        drain = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self else { return }
            let pending = deferred
            deferred.removeAll(); drain = nil
            for (frame, body) in pending {
                guard let generation = body["generation"] as? String, acceptedGenerations.contains(generation) else { continue }
                if budget.allow(frame: frame, lifecycle: false) {
                    if store.ingest(body) { publishSoon() }
                } else { deferObservation(body, frame: frame) }
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "videoSniffer", let body = message.body as? [String: Any],
              SnifferPayload.validate(body),
              let messageGeneration = body["generation"] as? String,
              let frame = body["frameID"] as? String, !frame.isEmpty else { return }
        let type = body["type"] as? String
        guard acceptedGenerations.contains(messageGeneration) || type == "restored" else { return }
        var observation = body
        observation["pageURL"] = message.frameInfo.request.url?.absoluteString
        guard budget.allow(frame: frame, lifecycle: type != nil) else {
            if type == nil { deferObservation(observation, frame: frame) }
            return
        }
        switch body["type"] as? String {
        case "restored":
            guard issuedGenerations.contains(messageGeneration),
                  message.frameInfo.isMainFrame || acceptedGenerations.contains(messageGeneration) else { return }
            // 往返缓存恢复的页面不会重跑脚本，仍带着当初的代次；接纳后它会重放之前的上报
            if message.frameInfo.isMainFrame { documentGeneration = messageGeneration }
            accept(messageGeneration)
            store.restoreFrame(frame)
            return
        default:
            break
        }
        guard acceptedGenerations.contains(messageGeneration) else { return }
        switch body["type"] as? String {
        case "route": deferred.removeValue(forKey: frame); store.clearFrame(frame)
        case "inactive":
            // A queued current flag must never reactivate a player after its cleanup event.
            deferred.removeValue(forKey: frame); store.deactivate(frame: frame)
        case "frameGone":
            deferred.removeValue(forKey: frame); store.removeFrame(frame); budget.remove(frame: frame)
        case "frameLinked":
            if let child = body["childFrameID"] as? String, child.count <= 100 { store.linkFrame(child, parent: frame) }
        case "frameRemoved":
            if let child = body["childFrameID"] as? String, child.count <= 100 { store.removeFrame(child) }
        default:
            deferred.removeValue(forKey: frame)
            if !store.ingest(observation) { return }
        }
        // The bridge accepts media data only; it can never connect to or command a TV.
        publishSoon()
    }
}

final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
