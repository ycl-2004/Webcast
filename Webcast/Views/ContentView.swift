import SwiftUI

private enum AppSheet: String, Identifiable {
    case devices, videos
    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var cast: CastManager
    @EnvironmentObject private var browser: BrowserModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = ContentView.initialTab()
    @State private var sheet: AppSheet?
    @State private var pendingVideo: VideoCandidate?

    /// 依据「默认打开」设置决定启动标签页
    private static func initialTab() -> Int {
        switch UserDefaults.standard.string(forKey: SettingsKeys.defaultPage) ?? "last" {
        case "browser": return 0
        case "remote": return 1
        case "start": return 0
        default:
            let last = UserDefaults.standard.integer(forKey: SettingsKeys.lastTab)
            return (0...2).contains(last) ? last : 0
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                BrowserView(sniffer: browser.sniffer, showVideos: { sheet = .videos })
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { deviceButton } }
            }
            .tabItem { Label("浏览器", systemImage: "globe") }.tag(0)
            NavigationStack {
                RemoteView(selectDevice: { pendingVideo = nil; sheet = .devices }, loadVideo: castVideo)
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { deviceButton } }
            }
            .tabItem { Label("投屏遥控", systemImage: "tv") }.tag(1)
            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("设置", systemImage: "gearshape") }.tag(2)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if cast.connection != .disconnected {
                Button { tab = 1 } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tv").foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cast.connectionLabel).font(.caption.weight(.semibold))
                            if cast.hasMedia { Text(cast.title).font(.caption).lineLimit(1) }
                        }
                        Spacer()
                        Text(cast.isLoading ? "正在加载…" : cast.playbackLabel).font(.caption)
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(.horizontal, 16).padding(.vertical, 10)
                }.foregroundStyle(.primary).background(.thinMaterial)
            }
        }
        .sheet(item: $sheet, onDismiss: {
            browser.cancelDialogs()
            if sheet == nil && cast.connection != .connecting { pendingVideo = nil }
        }) { item in
            switch item {
            case .devices:
                DevicePicker()
            case .videos:
                SniffSheet(sniffer: browser.sniffer, loadVideo: castVideo)
            }
        }
        .onChange(of: cast.connection) { state in
            if state == .connected {
                if let video = pendingVideo { pendingVideo = nil; beginLoad(video) }
                else { sheet = nil }
            } else if state == .disconnected { pendingVideo = nil }
        }
        .onChange(of: tab) { UserDefaults.standard.set($0, forKey: SettingsKeys.lastTab) }
        .onChange(of: scenePhase) { phase in
            if phase == .active { cast.refreshSession() }
            else { browser.cancelDialogs() }
        }
        .castErrorAlert()
    }

    private var deviceButton: some View {
        Button { pendingVideo = nil; sheet = .devices } label: {
            Label(cast.connectionLabel, systemImage: cast.connection == .connected ? "tv.fill" : "tv")
                .labelStyle(.iconOnly)
        }.accessibilityLabel("选择 Chromecast")
    }

    private func castVideo(_ video: VideoCandidate) {
        if cast.canControl { beginLoad(video) }
        else { pendingVideo = video; sheet = .devices }
    }

    private func beginLoad(_ video: VideoCandidate) {
        if cast.load(video) {
            sheet = nil
            browser.pauseLocalPlayback()
            tab = 1
        }
    }
}
