import XCTest
@testable import Webcast

@MainActor
private final class PlaybackTarget: RemotePlaybackTarget {
    var isPlaying = false
    func play() { isPlaying = true }
    func pause() { isPlaying = false }
    func togglePlayback() { isPlaying.toggle() }
}

final class RemotePlaybackCommandTests: XCTestCase {
    @MainActor func testRepeatedPlayAndPauseCommandsKeepTheirRequestedState() {
        let target = PlaybackTarget()
        for _ in 0..<3 {
            RemotePlaybackCommand.play.perform(on: target)
            XCTAssertTrue(target.isPlaying)
        }
        for _ in 0..<3 {
            RemotePlaybackCommand.pause.perform(on: target)
            XCTAssertFalse(target.isPlaying)
        }
    }

    @MainActor func testOnlyToggleCommandReversesPlaybackState() {
        let target = PlaybackTarget()
        RemotePlaybackCommand.pause.perform(on: target)
        XCTAssertFalse(target.isPlaying)
        RemotePlaybackCommand.toggle.perform(on: target)
        XCTAssertTrue(target.isPlaying)
        RemotePlaybackCommand.play.perform(on: target)
        XCTAssertTrue(target.isPlaying)
        RemotePlaybackCommand.toggle.perform(on: target)
        XCTAssertFalse(target.isPlaying)
    }
}
