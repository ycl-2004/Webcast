import Foundation

var store = CandidateStore()
for index in 0..<150 {
    store.ingest(["url": "https://cdn.example/\(index).mp4", "current": true, "frameID": "frame-\(index)"])
}
print("Candidate bound: inserted=150, retained=\(store.items.count), intendedLimit=100")

var ranking = CandidateStore()
ranking.ingest(["url": "https://cdn.example/old-ad.m3u8", "master": true])
ranking.ingest(["url": "https://cdn.example/current-episode.mp4", "current": true])
print("Ranking: first=\(ranking.sorted.first!.url.lastPathComponent), current=\(ranking.sorted.first!.isCurrent)")

var frames = CandidateStore()
frames.ingest(["url": "https://cdn.example/shared.mp4", "current": true, "frameID": "one"])
frames.ingest(["url": "https://cdn.example/shared.mp4", "current": true, "frameID": "two"])
frames.ingest(["url": "https://cdn.example/other.mp4", "current": true, "frameID": "two"])
print("Multi-frame current: frame one still uses shared.mp4, markedCurrent=\(frames.items["https://cdn.example/shared.mp4"]!.isCurrent)")

if CommandLine.arguments.contains("--expect-fixed") {
    precondition(store.items.count == 100, "Candidate capacity regressed")
    precondition(frames.items["https://cdn.example/shared.mp4"]!.isCurrent, "Shared frame state regressed")
}
