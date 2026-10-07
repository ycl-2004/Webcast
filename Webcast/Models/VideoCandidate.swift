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
        let type = mime.lowercased().split(separator: ";").first.map(String.init) ?? ""
        if manifest.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#EXTM3U") { return .hls }
        if ["application/vnd.apple.mpegurl", "application/x-mpegurl", "audio/mpegurl", "audio/x-mpegurl"].contains(type) { return .hls }
        if type == "application/dash+xml" { return .dash }
        if type == "video/mp4" { return .mp4 }
        switch url.pathExtension.lowercased() {
        case "m3u8": return .hls
        case "mp4", "m4v": return .mp4
        case "mpd": return .dash
        default: return nil
        }
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
        title.isEmpty ? (url.lastPathComponent.isEmpty ? "网页视频" : url.lastPathComponent) : title
    }
    var host: String { url.host ?? "未知来源" }

    static let testStream = VideoCandidate(
        url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
        format: .hls, title: "Apple HLS 测试视频", pageURL: nil, source: "test",
        isMaster: true, isCurrent: false, duration: nil, isLive: false,
        segmentFormat: "ts", isDRM: false, observedAt: Date()
    )
}

/// Keep signed query parameters intact; stripping them can invalidate playback.
struct CandidateStore {
    private(set) var items: [String: VideoCandidate] = [:]
    private var activeByFrame: [String: String] = [:]

    var sorted: [VideoCandidate] {
        items.values.sorted {
            if $0.isMaster != $1.isMaster { return $0.isMaster }
            if $0.isCurrent != $1.isCurrent { return $0.isCurrent }
            return $0.observedAt > $1.observedAt
        }
    }

    mutating func reset() { items.removeAll(); activeByFrame.removeAll() }

    @discardableResult
    mutating func ingest(_ payload: [String: Any], now: Date = Date()) -> Bool {
        guard let raw = payload["url"] as? String, raw.count <= 16384,
              var components = URLComponents(string: raw),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil, components.user == nil, components.password == nil else { return false }
        components.fragment = nil
        guard let url = components.url,
              let format = VideoFormat.detect(url: url, mime: payload["mime"] as? String ?? "",
                                              manifest: payload["manifest"] as? String ?? "") else { return false }
        let key = url.absoluteString
        let current = payload["current"] as? Bool ?? false
        let frame = payload["frameID"] as? String ?? "main"
        if current {
            if let previous = activeByFrame[frame], previous != key { items[previous]?.isCurrent = false }
            activeByFrame[frame] = key
        }
        let duration = (payload["duration"] as? NSNumber)?.doubleValue
        let validDuration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        if var existing = items[key] {
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
        if items.count > 100,
           let oldest = items.values.filter({ !$0.isCurrent }).min(by: { $0.observedAt < $1.observedAt }) {
            items.removeValue(forKey: oldest.id)
        }
        return true
    }
}
