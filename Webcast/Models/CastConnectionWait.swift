import Foundation

/// Foreground waiting has an exit; the SDK still owns session recovery.
struct CastConnectionWait {
    private(set) var deadline: TimeInterval?
    mutating func begin(now: TimeInterval = ProcessInfo.processInfo.systemUptime) { deadline = now + 30 }
    mutating func reset() { deadline = nil }
    mutating func expire(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard let deadline, now >= deadline else { return false }
        self.deadline = nil
        return true
    }
}
