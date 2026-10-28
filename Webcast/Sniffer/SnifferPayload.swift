import Foundation
import CoreFoundation

/// Validate again in native code: page-world network observations are never trusted.
enum SnifferPayload {
    private static let stringLimits = [
        "url": 16384, "pageURL": 16384, "title": 1200, "source": 16,
        "mime": 256, "manifest": 16, "segmentFormat": 8,
        "generation": 100, "frameID": 100, "childFrameID": 100, "type": 16
    ]
    private static let flags: Set<String> = ["current", "master", "live", "drm", "inferred"]
    private static let numbers: Set<String> = ["duration", "time"]
    private static let sources: Set<String> = ["video", "source", "fetch", "xhr", "mse", "网页", "test"]
    static let lifecycle: Set<String> = ["restored", "route", "inactive", "frameGone", "frameLinked", "frameRemoved"]

    static func validate(_ payload: [String: Any]) -> Bool {
        guard payload.count <= 24 else { return false }
        var bytes = 0
        for (key, value) in payload {
            if let limit = stringLimits[key] {
                guard let string = value as? String else { return false }
                // prefix avoids scanning an arbitrarily large string in full.
                let size = string.utf8.prefix(limit + 1).count
                guard size <= limit else { return false }
                bytes += size
            } else if flags.contains(key) {
                guard let number = value as? NSNumber,
                      CFGetTypeID(number) == CFBooleanGetTypeID() else { return false }
            } else if numbers.contains(key) {
                guard let number = value as? NSNumber,
                      CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { return false }
            } else { return false }
        }
        guard bytes <= 35000 else { return false }
        if let source = payload["source"] as? String, !sources.contains(source) { return false }
        if let segment = payload["segmentFormat"] as? String, !["ts", "fmp4"].contains(segment) { return false }
        if let manifest = payload["manifest"] as? String, manifest != "#EXTM3U" { return false }
        if let type = payload["type"] as? String, !lifecycle.contains(type) { return false }
        return true
    }

    static func mediaURL(_ raw: String) -> URL? {
        guard raw.utf8.prefix(16385).count <= 16384,
              var parts = URLComponents(string: raw),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil else { return nil }
        parts.fragment = nil
        return parts.url
    }
}

/// Separate budgets keep media floods from consuming lifecycle cleanup capacity.
struct SnifferMessageBudget {
    private struct Bucket {
        var tokens: Double
        var updated: TimeInterval
        mutating func take(now: TimeInterval, capacity: Double, rate: Double) -> Bool {
            tokens = min(capacity, tokens + max(0, now - updated) * rate)
            updated = now
            guard tokens >= 1 else { return false }
            tokens -= 1
            return true
        }
    }
    private var media = Bucket(tokens: 160, updated: ProcessInfo.processInfo.systemUptime)
    private var controls = Bucket(tokens: 256, updated: ProcessInfo.processInfo.systemUptime)
    private var frames: [String: Bucket] = [:]
    var trackedFrameCount: Int { frames.count }

    mutating func allow(frame: String, lifecycle: Bool, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        if lifecycle { return controls.take(now: now, capacity: 256, rate: 128) }
        guard media.take(now: now, capacity: 160, rate: 80) else { return false }
        // Global budget applies even when a page rotates frame identifiers.
        if frames[frame] == nil, frames.count >= 100,
           let oldest = frames.min(by: { $0.value.updated < $1.value.updated })?.key {
            frames.removeValue(forKey:oldest)
        }
        var bucket = frames[frame] ?? Bucket(tokens: 64, updated: now)
        let allowed = bucket.take(now: now, capacity: 64, rate: 32)
        frames[frame] = bucket
        return allowed
    }

    mutating func remove(frame: String) { frames.removeValue(forKey: frame) }
}
