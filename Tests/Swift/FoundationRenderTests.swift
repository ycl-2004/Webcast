import XCTest
import SwiftUI
import UIKit
import WebKit
@testable import Webcast

/// Component renders for local design inspection; these do not exercise a receiver or E2E flow.
final class FoundationRenderTests: XCTestCase {
    @MainActor func testNarrowAndLargeTextFoundationScreensRender() async throws {
        let defaultsName = "webcast.render.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defaults.set("start", forKey: SettingsKeys.defaultPage)
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let browser = BrowserModel(defaults: defaults, dataStore: .nonPersistent())
        let cast = CastManager()
        XCTAssertTrue(cast.offlineValidation)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKeyAndVisible() }
        cast.recordFailure(.load, code: 4, source: URL(string: "https://cdn.example/video.mp4?token=secret"), model: "Chromecast")
        let screens: [(String, AnyView, DynamicTypeSize)] = [
            ("browser-start-narrow", AnyView(NavigationStack {
                BrowserView(sniffer: browser.sniffer, showVideos: {})
            }), .large),
            ("browser-start-accessibility", AnyView(NavigationStack {
                BrowserView(sniffer: browser.sniffer, showVideos: {})
            }), .accessibility3),
            ("remote-accessibility", AnyView(NavigationStack {
                RemoteView(selectDevice: {}, loadVideo: { _ in })
            }), .accessibility3),
            ("videos-public-narrow", AnyView(SniffSheet(sniffer: browser.sniffer, loadVideo: { _ in })), .large),
            ("videos-public-accessibility", AnyView(SniffSheet(sniffer: browser.sniffer, loadVideo: { _ in })), .accessibility3),
            ("settings-public-narrow", AnyView(NavigationStack { SettingsView() }), .large),
            ("diagnostics-accessibility", AnyView(NavigationStack { CastDiagnosticsView() }), .accessibility3)
        ]
        for (name, screen, size) in screens {
            if name == "videos-public-narrow" {
                browser.webView.loadHTMLString("""
                <title>影片示例</title><video preload='none' src='https://cdn.example/episode.m3u8?token=demo'></video>
                """, baseURL: URL(string: "https://fixture.example"))
                let deadline = Date().addingTimeInterval(10)
                while browser.sniffer.candidates.isEmpty && Date() < deadline {
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                XCTAssertFalse(browser.sniffer.candidates.isEmpty)
            }
            let root = screen.environmentObject(browser).environmentObject(cast)
                .dynamicTypeSize(size).tint(.teal)
            let controller = UIHostingController(rootView: root)
            controller.overrideUserInterfaceStyle = .light
            window.rootViewController = controller
            window.makeKeyAndVisible()
            try await Task.sleep(nanoseconds: 100_000_000)
            controller.view.layoutIfNeeded()
            var rendered = false
            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                rendered = controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            XCTAssertTrue(rendered, name)
            XCTAssertEqual(image.size.width, 320, "Render must actually use the narrow viewport")
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
