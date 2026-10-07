import SwiftUI

struct RemoteView: View {
    @EnvironmentObject private var cast: CastManager
    let selectDevice: () -> Void
    let loadVideo: (VideoCandidate) -> Void
    @State private var seekValue = 0.0
    @State private var editingSeek = false
    @State private var volumeValue = 0.5
    @State private var editingVolume = false
    @State private var confirmStop = false
    @State private var showHelp = false

    /// 只有「未连接」时才能发起新连接；连接中/等待恢复期间 CTA 关闭。
    private var canStartConnection: Bool {
        !cast.offlineValidation && cast.connection == .disconnected
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if cast.canControl {
                    connectedRemote
                } else {
                    connectHero
                }
                #if DEBUG
                debugTools
                #endif
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity) // iPad 上内容居中
        }
        .navigationTitle("投屏遥控").navigationBarTitleDisplayMode(.inline)
        .onAppear { seekValue = cast.position; volumeValue = cast.volume }
        .onChange(of: cast.position) { if !editingSeek { seekValue = min($0, max(cast.duration, 1)) } }
        .onChange(of: cast.volume) { if !editingVolume { volumeValue = $0 } }
        .onChange(of: cast.connection) { state in
            // 恢复/重连后同步本地滑条，避免用旧值发送指令
            if state == .connected { seekValue = cast.position; volumeValue = cast.volume }
        }
        .confirmationDialog("停止电视播放并断开连接？", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("停止并断开", role: .destructive) { cast.disconnect(stopPlayback: true) }
        }
    }

    // MARK: - 未连接：只保留一个任务，连上电视

    private var connectHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusEyebrow
            Text("把网页视频放到大屏上")
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("手机和电视连接同一 Wi-Fi，然后选择电视。")
                .foregroundStyle(.secondary)
            Button(action: selectDevice) {
                Label("选择电视", systemImage: "tv").frame(minWidth: 132)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStartConnection)
            .padding(.top, 6)
            .accessibilityHint("查找同一 Wi-Fi 下的 Chromecast")
            if canStartConnection {
                Button("找不到电视？") { withAnimation(.easeInOut(duration: 0.2)) { showHelp.toggle() } }
                    .font(.subheadline)
            }
            if cast.connection == .suspended {
                Button("断开并重试", role: .destructive) { confirmStop = true }
                    .buttonStyle(.bordered)
                    .padding(.top, 6)
            }
            if showHelp {
                Text("确认电视已开机，手机和电视连接同一个 Wi-Fi，并在系统设置里允许 Webcast 访问本地网络，然后重新选择电视。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusEyebrow: some View {
        switch cast.connection {
        case .connecting:
            Label("正在连接电视…", systemImage: "tv")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        case .suspended:
            Label("连接中断，等待恢复…", systemImage: "wifi.exclamationmark")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        default:
            Label("未连接电视", systemImage: "tv")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 已连接：完整遥控器

    private var connectedRemote: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Label(cast.deviceName.isEmpty ? "已连接电视" : cast.deviceName, systemImage: "tv.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.teal)
                if cast.hasMedia {
                    Text(cast.title)
                        .font(.title2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if cast.isLoading {
                    Text("正在请求电视加载视频…").foregroundStyle(.secondary)
                } else if cast.hasMedia {
                    Text(cast.playbackLabel).foregroundStyle(.secondary)
                } else {
                    Text("在浏览器播放视频，再点「视频」投到电视。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            if cast.hasMedia {
                transportControls
            }
            Divider()
            volumeControls
            stopControls
        }
    }

    private var transportControls: some View {
        VStack(spacing: 12) {
            Slider(value: $seekValue, in: 0...max(cast.duration, 1), onEditingChanged: { editing in
                editingSeek = editing
                if !editing { cast.seek(to: seekValue) }
            })
            .disabled(cast.duration <= 0)
            .accessibilityLabel("播放进度")
            HStack {
                Text(timeLabel(editingSeek ? seekValue : cast.position))
                Spacer()
                Text(cast.duration > 0 ? timeLabel(cast.duration) : "直播")
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack(spacing: 32) {
                Button {
                    cast.seek(to: cast.position - 15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title).frame(width: 48, height: 48)
                }
                .disabled(cast.duration <= 0)
                .accessibilityLabel("后退 15 秒")
                Button(action: cast.togglePlayback) {
                    Image(systemName: cast.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 72, height: 72)
                        .background(Color.teal.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel(cast.isPlaying ? "暂停" : "播放")
                Button {
                    cast.seek(to: cast.position + 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title).frame(width: 48, height: 48)
                }
                .disabled(cast.duration <= 0)
                .accessibilityLabel("前进 15 秒")
            }.disabled(cast.isLoading)
        }
    }

    private var volumeControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("电视音量").font(.headline)
                Spacer()
                Text("\(Int(cast.volume * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack {
                Button(action: cast.toggleMute) { Image(systemName: cast.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 44, height: 44) }
                    .accessibilityLabel(cast.isMuted ? "取消静音" : "静音")
                Slider(value: $volumeValue, in: 0...1, onEditingChanged: { editing in
                    editingVolume = editing
                    if !editing { cast.setVolume(volumeValue) }
                }).accessibilityLabel("电视音量")
            }
        }
    }

    private var stopControls: some View {
        HStack(spacing: 12) {
            Button("停止播放", role: .destructive, action: cast.stop)
                .buttonStyle(.borderedProminent)
                .disabled(!cast.hasMedia || cast.isLoading)
            Button("断开连接", role: .destructive) { confirmStop = true }
                .buttonStyle(.bordered)
                .disabled(cast.isLoading)
        }
        .padding(.top, 4)
    }

    // MARK: - 调试工具（仅 Debug 构建可见）

    #if DEBUG
    private var debugTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("调试").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            Button("投屏 HLS 测试视频") { loadVideo(.testStream) }
                .buttonStyle(.bordered)
                .disabled(!cast.canControl || cast.isLoading)
            if cast.offlineValidation {
                Text("离线验证模式 · 不会连接或控制电视")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    #endif
}
