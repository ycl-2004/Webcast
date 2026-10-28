import XCTest
import GoogleCast
@testable import Webcast

final class CastDiagnosticTests: XCTestCase {
    func testDiagnosticsRetainOnlyBoundedSanitizedFields() {
        var log = CastDiagnosticLog()
        for index in 0..<25 {
            log.append(CastDiagnostic(stage: .load, errorCode: index,
                sourceURL: URL(string: "https://user:password@cdn.example/private/video.mp4?token=secret#fragment"),
                deviceModel: "Chromecast", time: Date(timeIntervalSince1970: Double(index))))
        }
        XCTAssertEqual(log.entries.count, 20)
        XCTAssertEqual(log.entries.first?.errorCode, 24)
        XCTAssertEqual(log.entries.last?.errorCode, 5)
        XCTAssertEqual(log.entries.first?.sourceHost, "cdn.example")
        let fields = String(reflecting: log.entries)
        for secret in ["password", "private/video", "token=secret", "fragment"] {
            XCTAssertFalse(fields.contains(secret))
        }
        log.clear()
        XCTAssertTrue(log.entries.isEmpty)
    }

    @MainActor func testSDKFailureAndTimeoutAreRecordedButCancellationIsNot() {
        let manager = CastManager()
        let cancelled = GCKRequest.application()
        manager.trackLoadRequest(cancelled, candidate: .testStream)
        cancelled.failWithError(GCKError(code: .cancelled))
        XCTAssertTrue(manager.diagnostics.isEmpty)
        let failed = GCKRequest.application()
        manager.trackLoadRequest(failed, candidate: .testStream)
        failed.failWithError(GCKError(code: .mediaLoadFailed))
        XCTAssertEqual(manager.diagnostics.first?.errorCode, GCKErrorCode.mediaLoadFailed.rawValue)
        XCTAssertEqual(manager.diagnostics.first?.sourceHost, VideoCandidate.testStream.url.host)
        let waiting = GCKRequest.application()
        manager.trackLoadRequest(waiting, candidate: .testStream)
        for _ in 0..<2 {
            manager.receiveLoadStatus(contentID: nil, playback: .waiting, now: Date().addingTimeInterval(46))
        }
        XCTAssertEqual(manager.diagnostics.count, 2)
        manager.clearDiagnostics()
        XCTAssertTrue(manager.diagnostics.isEmpty)
    }

    func testDynamicStatusAndFailureTranslationsAreBundled() throws {
        let en = try XCTUnwrap(Bundle(path: try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))))
        let tw = try XCTUnwrap(Bundle(path: try XCTUnwrap(Bundle.main.path(forResource: "zh-Hant", ofType: "lproj"))))
        XCTAssertEqual(String(localized: "未连接电视", bundle: en), "No TV connected")
        XCTAssertEqual(String(localized: "请先连接 Chromecast。", bundle: en), "Connect to a Chromecast first.")
        XCTAssertEqual(String(localized: "电视播放", bundle: tw), "電視播放")
        let model = "Living room 客厅"
        XCTAssertTrue(String(localized: "\(model)失败。请检查电视连接。", bundle: en).contains(model))
    }
}
