import SwiftUI

@main
struct WebcastApp: App {
    @StateObject private var cast = CastManager()
    @StateObject private var browser = BrowserModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cast)
                .environmentObject(browser)
                .tint(.teal)
        }
    }
}
