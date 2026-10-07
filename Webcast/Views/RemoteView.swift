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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(cast.connectionLabel, systemImage: "tv").font(.subheadline.weight(.medium)).foregroundStyle(.teal)
                    Text(cast.hasMedia ? cast.title : "把网页视频放到大屏上")
                        .font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(cast.isLoading ? "正在请求电视加载视频…" : cast.playbackLabel).foregroundStyle(.secondary)
                }
                if cast.connection == .disconnected {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("手机和电视连接同一个 Wi-Fi，然后选择 Chromecast。")
                            .foregroundStyle(.secondary)
                        Button("选择电视", action: selectDevice).buttonStyle(.borderedProminent)
                    }
                }
                VStack(spacing: 12) {
                    Slider(value: $seekValue, in: 0...max(cast.duration, 1), onEditingChanged: { editing in
                        editingSeek = editing
                        if !editing { cast.seek(to: seekValue) }
                    }).disabled(!cast.canControl || !cast.hasMedia || cast.duration <= 0)
                        .accessibilityLabel("播放进度")
                    HStack {
                        Text(timeLabel(editingSeek ? seekValue : cast.position))
                        Spacer()
                        Text(cast.duration > 0 ? timeLabel(cast.duration) : (cast.hasMedia ? "直播" : "--:--"))
                    }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    HStack(spacing: 32) {
                        Button { cast.seek(to: cast.position - 15) } label: { Image(systemName: "gobackward.15").font(.title).frame(width: 48, height: 48) }
                            .disabled(cast.duration <= 0).accessibilityLabel("后退 15 秒")
                        Button(action: cast.togglePlayback) {
                            Image(systemName: cast.isPlaying ? "pause.fill" : "play.fill").font(.title)
                                .frame(width: 72, height: 72).background(Color.teal.opacity(0.12)).clipShape(Circle())
                        }.accessibilityLabel(cast.isPlaying ? "暂停" : "播放")
                        Button { cast.seek(to: cast.position + 15) } label: { Image(systemName: "goforward.15").font(.title).frame(width: 48, height: 48) }
                            .disabled(cast.duration <= 0).accessibilityLabel("前进 15 秒")
                    }.disabled(!cast.canControl || !cast.hasMedia || cast.isLoading)
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("电视音量").font(.headline); Spacer(); Text("\(Int(cast.volume * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                    HStack {
                        Button(action: cast.toggleMute) { Image(systemName: cast.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 44, height: 44) }
                            .accessibilityLabel(cast.isMuted ? "取消静音" : "静音")
                        Slider(value: $volumeValue, in: 0...1, onEditingChanged: { editing in
                            editingVolume = editing
                            if !editing { cast.setVolume(volumeValue) }
                        }).accessibilityLabel("电视音量")
                    }.disabled(!cast.canControl)
                }
                if cast.canControl {
                    Button("停止播放", role: .destructive, action: cast.stop).disabled(!cast.hasMedia)
                    Button("停止并断开", role: .destructive) { confirmStop = true }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("先检查投屏链路").font(.headline)
                    Text("连接后可播放 Apple 的公开 HLS 测试视频，再尝试网页视频。").font(.callout).foregroundStyle(.secondary)
                    Button("投屏 HLS 测试视频") { loadVideo(.testStream) }
                        .buttonStyle(.bordered).disabled(cast.offlineValidation || cast.isLoading)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                if cast.offlineValidation { Text("离线验证模式 · 不会连接或控制电视").font(.footnote).foregroundStyle(.secondary) }
            }.padding(24).frame(maxWidth: 640)
        }
        .navigationTitle("投屏遥控").navigationBarTitleDisplayMode(.inline)
        .onAppear { seekValue = cast.position; volumeValue = cast.volume }
        .onChange(of: cast.position) { if !editingSeek { seekValue = min($0, max(cast.duration, 1)) } }
        .onChange(of: cast.volume) { if !editingVolume { volumeValue = $0 } }
        .confirmationDialog("停止电视播放并断开连接？", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("停止并断开", role: .destructive) { cast.disconnect(stopPlayback: true) }
        }
    }
}
