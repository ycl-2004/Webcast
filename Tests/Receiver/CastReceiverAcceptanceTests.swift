import XCTest
import GoogleCast
@testable import Webcast

/// Separate opt-in suite: excluded from Webcast's offline/CI scheme.
final class CastReceiverAcceptanceTests: XCTestCase {
    @MainActor private func waitFor(_ name: String, timeout: TimeInterval = 30, _ predicate: () -> Bool) async throws {
        let end = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < end { try await Task.sleep(nanoseconds:200_000_000) }
        guard predicate() else { throw NSError(domain:"ReceiverAcceptance", code:1,
            userInfo:[NSLocalizedDescriptionKey:"Timed out: " + name]) }
    }

    @MainActor func testExplicitlyAuthorizedReceiverPlaybackAndControls() async throws {
        let target = ProcessInfo.processInfo.environment["WEBCAST_CAST_RECEIVER_ID"] ?? ""
        try XCTSkipIf(target.isEmpty, "Opt in with a specific receiver ID in the test-run environment.")
        let defaults = UserDefaults.standard
        let previousDevice = defaults.object(forKey:SettingsKeys.lastCastDevice)
        defer { defaults.set(previousDevice, forKey:SettingsKeys.lastCastDevice) }
        let manager = CastManager(offlineValidation:false)
        var checks: [String] = []
        var originalVolume: Double?
        var originalMute: Bool?
        var failure: Error?
        func matches(_ device: CastDevice) -> Bool {
            // GCK uniqueID includes the provider category; mDNS advertises deviceID.
            device.sdkDevice.deviceID.replacingOccurrences(of:"-", with:"").lowercased() == target.replacingOccurrences(of:"-", with:"").lowercased()
        }
        do {
            manager.discover()
            try await waitFor("discovery") { manager.devices.contains(where:matches) }
            let device = try XCTUnwrap(manager.devices.first(where:matches))
            checks.append("discovery")
            XCTAssertTrue(manager.connect(device))
            try await waitFor("connection") { manager.canControl }
            checks.append("connection")
            originalVolume = manager.volume; originalMute = manager.isMuted
            manager.setVolume(0.08)
            try await waitFor("safe volume") { abs(manager.volume - 0.08) < 0.02 }
            XCTAssertTrue(manager.load(.testStream))
            try await waitFor("matching media playing", timeout:50) { !manager.isLoading && manager.hasMedia && manager.isPlaying }
            checks.append("HLS playing and load confirmed")
            let before = manager.position
            try await waitFor("advancing position") { manager.position > before + 1 }
            checks.append("position advancing")
            manager.pause()
            try await waitFor("pause") { !manager.isPlaying && manager.hasMedia }
            manager.pause()
            checks.append("pause")
            manager.seek(to:30)
            try await waitFor("seek") { abs(manager.position - 30) < 4 }
            checks.append("seek")
            manager.play()
            try await waitFor("resume") { manager.isPlaying }
            checks.append("resume")
            manager.toggleMute()
            try await waitFor("mute change") { manager.isMuted != originalMute }
            manager.toggleMute()
            try await waitFor("mute restoration") { manager.isMuted == originalMute }
            checks.append("mute/unmute")
        } catch { failure = error }

        // Cleanup runs on success and failure, through the same application commands.
        if manager.canControl {
            manager.stop()
            do {
                try await waitFor("stop") { !manager.hasMedia }
                checks.append("stop")
                if let originalVolume {
                    manager.setVolume(originalVolume)
                    try await waitFor("restore volume") { abs(manager.volume - originalVolume) < 0.02 }
                }
                if let originalMute, manager.isMuted != originalMute { manager.toggleMute() }
                manager.disconnect()
                try await waitFor("disconnect") { manager.connection == .disconnected }
                checks.append("volume restored and disconnected")
            } catch { if failure == nil { failure = error } }
        }
        let report: [String: Any] = ["scope":"current app CastManager -> physical receiver (simulator or iPhone per test destination)",
            "build":AppBuild.version, "checks":checks, "discoveredReceiverCount":manager.devices.count,
            "diagnosticStages":manager.diagnostics.map { $0.stage.label },
            "result":failure == nil ? "passed" : "failed", "error":failure?.localizedDescription ?? ""]
        let data = try JSONSerialization.data(withJSONObject:report, options:[.prettyPrinted,.sortedKeys])
        print("WEBCAST_RECEIVER_ACCEPTANCE " + String(decoding:data, as:UTF8.self))
        let attachment = XCTAttachment(data:data, uniformTypeIdentifier:"public.json")
        attachment.name = "receiver-acceptance"; attachment.lifetime = .keepAlways
        add(attachment)
        if let failure { throw failure }
    }
}
