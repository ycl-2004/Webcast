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
    @State private var pendingCast = PendingCast()

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
                RemoteView(selectDevice: { pendingCast.cancel(); sheet = .devices }, loadVideo: castVideo)
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { deviceButton } }
            }
            .tabItem { Label("投屏遥控", systemImage: "tv") }.tag(1)
            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("设置", systemImage: "gearshape") }.tag(2)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if pendingCast.intent != nil {
                HStack {
                    Text("连接后投屏").font(.callout)
                    Spacer()
                    Button("取消投屏") { pendingCast.cancel() }
                }.padding(.horizontal, 16).frame(minHeight: 44).background(.thinMaterial)
            }
            if cast.connection != .disconnected {
                Button { tab = 1 } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tv").foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cast.connectionLabel).font(.caption.weight(.semibold))
                            if cast.hasMedia { Text(cast.title).font(.caption).lineLimit(1) }
                        }
                        Spacer()
                        Text(cast.isLoading ? String(localized: "正在加载…") : cast.playbackLabel).font(.caption)
                        Image(systemName: "chevron.right").font(.caption)
                    }.padding(.horizontal, 16).padding(.vertical, 10)
                }.foregroundStyle(.primary).background(.thinMaterial)
            }
        }
        .sheet(item: $sheet, onDismiss: {
            browser.cancelDialogs()
            if sheet == nil { pendingCast.cancel() }
        }) { item in
            switch item {
            case .devices:
                DevicePicker(hasPendingCast: pendingCast.intent != nil, cancelPending: { pendingCast.cancel() })
            case .videos:
                SniffSheet(sniffer: browser.sniffer, loadVideo: castVideo,
                           hasPendingCast: pendingCast.intent != nil, cancelPending: { pendingCast.cancel() })
            }
        }
        .onChange(of: cast.connection) { state in
            if state == .connected {
                if let intent = pendingCast.take() { beginLoad(intent) }
                // 只收起选择器；会话自动恢复时不能把正在看的视频列表关掉
                else if sheet == .devices { sheet = nil }
            } else if state == .disconnected { pendingCast.cancel() }
        }
        .onChange(of: sheet) { if $0 == nil { pendingCast.cancel() } }
        .onChange(of: tab) { UserDefaults.standard.set($0, forKey: SettingsKeys.lastTab) }
        .onReceive(cast.loadEvents) { browser.handleCastLoad($0) }
        .onReceive(cast.pendingCastCancellations) { pendingCast.cancel() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { cast.refreshSession(); cast.beginForegroundRecoveryWait() }
            else { browser.cancelDialogs(); cast.suspendConnectionWait() }
        }
        .castErrorAlert()
    }

    private var deviceButton: some View {
        Button { pendingCast.cancel(); sheet = .devices } label: {
            Label(cast.connectionLabel, systemImage: cast.connection == .connected ? "tv.fill" : "tv")
                .labelStyle(.iconOnly)
        }.accessibilityLabel("选择 Chromecast")
    }

    private func castVideo(_ video: VideoCandidate) {
        let intent = browser.castIntent(for: video)
        if cast.canControl { beginLoad(intent) }
        else if cast.connection == .disconnected, let device = cast.quickConnectDevice {
            // 上次用过的电视在线：直接连接，连上后自动投屏
            pendingCast.select(intent)
            if !cast.connect(device) { pendingCast.cancel() }
        }
        else { pendingCast.select(intent); sheet = .devices }
    }

    private func beginLoad(_ intent: CastIntent) {
        if cast.load(intent.candidate, origin: intent.origin) {
            sheet = nil
            tab = 1
        }
    }
}
