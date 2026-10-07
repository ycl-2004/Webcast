import SwiftUI

private enum AppSheet: String, Identifiable {
    case devices, videos
    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var cast: CastManager
    @EnvironmentObject private var browser: BrowserModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var sheet: AppSheet?
    @State private var pendingVideo: VideoCandidate?

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
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if cast.connection != .disconnected {
                Button { tab = 1 } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "tv")
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
        .onChange(of: scenePhase) { phase in
            if phase == .active { cast.refreshSession() }
        }
        .alert("投屏提示", isPresented: Binding(get: { cast.errorMessage != nil }, set: { if !$0 { cast.errorMessage = nil } })) {
            Button("知道了", role: .cancel) { cast.errorMessage = nil }
        } message: { Text(cast.errorMessage ?? "") }
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
