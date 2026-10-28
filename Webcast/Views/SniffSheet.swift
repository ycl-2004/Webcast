import SwiftUI

struct SniffSheet: View {
    @ObservedObject var sniffer: VideoSniffer
    @EnvironmentObject private var cast: CastManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let loadVideo: (VideoCandidate) -> Void
    var hasPendingCast = false
    var cancelPending: () -> Void = {}

    var body: some View {
        NavigationStack {
            Group {
                if sniffer.candidates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle").font(.system(size: 44)).foregroundStyle(.teal)
                        Text("还没有检测到视频").font(.title3.weight(.semibold))
                        Text("先在网页里播放视频。")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("返回网页播放") { dismiss() }.buttonStyle(.borderedProminent)
                    }.padding(32)
                } else {
                    List {
                        Section {
                            ForEach(Array(sniffer.candidates.enumerated()), id: \.element.id) { index, candidate in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(verbatim: "\(index + 1)").foregroundStyle(.secondary)
                                        Text(candidate.displayTitle).lineLimit(2)
                                    }.font(.headline)
                                    adaptiveLayout {
                                        if candidate.isLive == true { badge("直播") }
                                        if candidate.isDRM { badge("不支持投屏") }
                                        else if candidate.isCurrent { badge(candidate.source == "mse" ? "可能是正片" : "当前视频") }
                                    }
                                    Text(candidate.host).font(.subheadline).foregroundStyle(.secondary)
                                        .lineLimit(2).truncationMode(.middle)
                                    DisclosureGroup("来源详情") {
                                        Text(verbatim: candidate.format.label + " · " + candidate.url.path)
                                            .font(.caption).foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                    adaptiveLayout {
                                        if let duration = candidate.duration { Text(timeLabel(duration)).font(.caption).foregroundStyle(.secondary) }
                                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                                        Button(castTitle) { loadVideo(candidate) }
                                            .buttonStyle(.borderedProminent)
                                            .frame(minHeight: 44)
                                            .disabled(candidate.isDRM || cast.isLoading || cast.offlineValidation
                                                      || cast.connection == .connecting || cast.connection == .suspended)
                                    }
                                }.padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("检测到的视频").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(hasPendingCast ? String(localized: "取消投屏") : String(localized: "完成")) { cancelPending(); dismiss() } } }
            // sheet 盖住根视图时，根部的 alert 不会弹出，这里用共享 modifier 补一份同样的错误提示
            .castErrorAlert()
        }.presentationDetents([.medium, .large])
    }
    private var castTitle: LocalizedStringKey {
        if cast.canControl { return "投到电视" }
        if cast.connection == .connecting { return "正在连接电视…" }
        if cast.connection == .suspended { return "等待恢复连接…" }
        if let device = cast.quickConnectDevice, cast.connection == .disconnected { return "投到 \(device.name)" }
        return "选择电视后投屏"
    }

    private var adaptiveLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
    }

    private func badge(_ label: LocalizedStringKey) -> some View {
        Text(label).font(.caption2.weight(.medium)).padding(.horizontal, 6).padding(.vertical, 4)
            .background(Color.teal.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

func timeLabel(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "--:--" }
    let total = Int(seconds)
    return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
        : String(format: "%d:%02d", total / 60, total % 60)
}
