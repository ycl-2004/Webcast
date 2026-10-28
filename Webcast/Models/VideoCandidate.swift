import Foundation

enum VideoFormat: String, Codable {
    case hls, mp4, dash

    var label: String { rawValue.uppercased() }
    var contentType: String {
        switch self {
        case .hls: return "application/x-mpegurl"
        case .mp4: return "video/mp4"
        case .dash: return "application/dash+xml"
        }
    }

    static func detect(url: URL, mime: String = "", manifest: String = "") -> VideoFormat? {
        if let metadata = detectMetadata(mime: mime, manifest: manifest) { return metadata }
        switch url.pathExtension.lowercased() {
        case "m3u8": return .hls
        case "mp4", "m4v": return .mp4
        case "mpd": return .dash
        default: return nil
        }
    }

    static func detectMetadata(mime: String, manifest: String) -> VideoFormat? {
        let type = mime.lowercased().split(separator: ";").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if manifest.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#EXTM3U") { return .hls }
        if ["application/vnd.apple.mpegurl", "application/x-mpegurl", "audio/mpegurl", "audio/x-mpegurl"].contains(type) { return .hls }
        if type == "application/dash+xml" { return .dash }
        if type == "video/mp4" { return .mp4 }
        return nil
    }
}

struct VideoCandidate: Identifiable, Equatable {
    var id: String { url.absoluteString }
    let url: URL
    var format: VideoFormat
    var title: String
    var pageURL: URL?
    var source: String
    var isMaster: Bool
    var isCurrent: Bool
    var duration: Double?
    var isLive: Bool?
    var segmentFormat: String?
    var isDRM: Bool
    var observedAt: Date

    var displayTitle: String {
        title.isEmpty ? (url.lastPathComponent.isEmpty ? String(localized: "网页视频") : url.lastPathComponent) : title
    }
    var host: String { url.host ?? String(localized: "未知来源") }

    static let testStream = VideoCandidate(
        url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
        format: .hls, title: String(localized: "Apple HLS 测试视频"), pageURL: nil, source: "test",
        isMaster: true, isCurrent: false, duration: nil, isLive: false,
        segmentFormat: "ts", isDRM: false, observedAt: Date()
    )
}

/// Keep signed query parameters intact; stripping them can invalidate playback.
struct CandidateStore {
    private static let capacity = 100
    private(set) var items: [String: VideoCandidate] = [:]
    private var activeByFrame: [String: String] = [:]
    private var recentFrames: [String] = []
    private var sourcesByURL: [String: Set<String>] = [:]
    private var parentByFrame: [String: String] = [:]
    private var retiredFrames: [String] = []
    /// Changes only when the media identity/lifecycle changes, not on metadata refreshes.
    private(set) var playbackRevision = UUID()

    var sorted: [VideoCandidate] {
        items.values.sorted {
            if $0.isCurrent != $1.isCurrent { return $0.isCurrent }
            if $0.isMaster != $1.isMaster { return $0.isMaster }
            if $0.observedAt != $1.observedAt { return $0.observedAt > $1.observedAt }
            return $0.id < $1.id
        }
    }

    mutating func reset() {
        items.removeAll(); activeByFrame.removeAll(); recentFrames.removeAll()
        sourcesByURL.removeAll(); parentByFrame.removeAll(); retiredFrames.removeAll(); playbackRevision = UUID()
    }

    private mutating func touchFrame(_ frame: String) {
        recentFrames.removeAll { $0 == frame }
        recentFrames.append(frame)
        if recentFrames.count > Self.capacity { removeFrame(recentFrames[0], retire: false) }
    }

    private mutating func refreshCurrent() {
        let active = Set(activeByFrame.values)
        for id in items.keys { items[id]?.isCurrent = active.contains(id) }
    }

    mutating func deactivate(frame: String) {
        if activeByFrame.removeValue(forKey: frame) != nil { playbackRevision = UUID() }
        refreshCurrent()
    }

    /// A route replaces this frame's observations, not the media in surviving child frames.
    mutating func clearFrame(_ frame: String) {
        playbackRevision = UUID()
        activeByFrame.removeValue(forKey: frame)
        for url in Array(sourcesByURL.keys) {
            sourcesByURL[url]?.remove(frame)
            if sourcesByURL[url]?.isEmpty == true {
                sourcesByURL.removeValue(forKey: url); items.removeValue(forKey: url)
            }
        }
        refreshCurrent()
    }

    mutating func linkFrame(_ child: String, parent: String) {
        guard child != parent, !retiredFrames.contains(child), !retiredFrames.contains(parent) else { return }
        touchFrame(parent); touchFrame(child)
        parentByFrame[child] = parent
    }

    mutating func restoreFrame(_ frame: String) {
        retiredFrames.removeAll { $0 == frame }
    }

    mutating func removeFrame(_ frame: String, retire: Bool = true) {
        // A bounded traversal also tolerates malformed/cyclic page-world messages.
        var removed: Set<String> = [frame]
        for _ in 0..<Self.capacity {
            let children = Set(parentByFrame.filter { removed.contains($0.value) }.map(\.key))
            let next = removed.union(children)
            if next == removed { break }; removed = next
        }
        for id in removed {
            clearFrame(id); parentByFrame.removeValue(forKey: id)
            if retire {
                retiredFrames.removeAll { $0 == id }
                retiredFrames.append(id)
            }
        }
        if retiredFrames.count > 200 { retiredFrames.removeFirst(retiredFrames.count - 200) }
        recentFrames.removeAll { removed.contains($0) }
    }

    @discardableResult
    mutating func ingest(_ payload: [String: Any], now: Date = Date()) -> Bool {
        guard SnifferPayload.validate(payload), let raw = payload["url"] as? String,
              let url = SnifferPayload.mediaURL(raw),
              let format = VideoFormat.detect(url: url, mime: payload["mime"] as? String ?? "",
                                              manifest: payload["manifest"] as? String ?? "") else { return false }
        let key = url.absoluteString
        let current = payload["current"] as? Bool ?? false
        let frame = String((payload["frameID"] as? String ?? "main").prefix(100))
        guard !retiredFrames.contains(frame) else { return false }
        touchFrame(frame)
        sourcesByURL[key, default: []].insert(frame)
        if current {
            if activeByFrame[frame] != key { playbackRevision = UUID() }
            activeByFrame[frame] = key
        }
        let duration = (payload["duration"] as? NSNumber)?.doubleValue
        let validDuration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        if var existing = items[key] {
            // A response's MIME/playlist can correct an earlier filename-only guess. Later DOM
            // scans have no such evidence and must not change it back.
            if let confirmed = VideoFormat.detectMetadata(mime: payload["mime"] as? String ?? "",
                                                          manifest: payload["manifest"] as? String ?? "") {
                existing.format = confirmed
            }
            existing.isMaster = existing.isMaster || (payload["master"] as? Bool ?? false)
            existing.isCurrent = existing.isCurrent || current
            existing.isDRM = existing.isDRM || (payload["drm"] as? Bool ?? false)
            existing.duration = validDuration ?? existing.duration
            existing.isLive = payload["live"] as? Bool ?? existing.isLive
            existing.segmentFormat = payload["segmentFormat"] as? String ?? existing.segmentFormat
            if current { existing.source = payload["source"] as? String ?? existing.source }
            if let title = payload["title"] as? String, !title.isEmpty { existing.title = String(title.prefix(300)) }
            existing.observedAt = now
            items[key] = existing
        } else {
            items[key] = VideoCandidate(url: url, format: format,
                title: String((payload["title"] as? String ?? "").prefix(300)),
                pageURL: (payload["pageURL"] as? String).flatMap(URL.init(string:)),
                source: payload["source"] as? String ?? "网页", isMaster: payload["master"] as? Bool ?? false,
                isCurrent: current, duration: validDuration, isLive: payload["live"] as? Bool,
                segmentFormat: payload["segmentFormat"] as? String, isDRM: payload["drm"] as? Bool ?? false,
                observedAt: now)
        }
        // 某个 frame 换片不代表其他 frame 也停止使用同一 URL。
        refreshCurrent()
        while items.count > Self.capacity {
            let inactive = items.values.filter { !$0.isCurrent }
            guard let oldest = (inactive.isEmpty ? Array(items.values) : inactive)
                .min(by: { $0.observedAt < $1.observedAt }) else { break }
            items.removeValue(forKey: oldest.id)
            sourcesByURL.removeValue(forKey: oldest.id)
            activeByFrame = activeByFrame.filter { $0.value != oldest.id }
        }
        return true
    }
}
