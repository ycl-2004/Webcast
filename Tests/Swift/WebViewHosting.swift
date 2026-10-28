import XCTest
import UIKit
import WebKit

extension XCTestCase {
    /// Hosted simulators may suspend detached web views, stalling page loads, and throttle their
    /// timers to ~1s. Keep every web view under test foregrounded, as in the actual browser.
    @MainActor func showInKeyWindow(_ view: WKWebView) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        addTeardownBlock {
            await MainActor.run {
                view.stopLoading()
                window.isHidden = true
                window.rootViewController = nil
                previous?.makeKeyAndVisible()
            }
        }
    }
}
