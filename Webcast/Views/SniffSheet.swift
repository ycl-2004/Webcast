import SwiftUI

struct SniffSheet: View {
    @ObservedObject var sniffer: VideoSniffer
    @EnvironmentObject private var cast: CastManager
    @Environment(\.dismiss) private var dismiss
    let loadVideo: (VideoCandidate) -> Void

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
                            ForEach(sniffer.candidates) { candidate in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(candidate.displayTitle).font(.headline).lineLimit(2)
                                    HStack(spacing: 6) {
                                        badge(candidate.format.label)
                                        if candidate.isDRM { badge("不支持投屏") }
                                        else if candidate.isCurrent { badge(candidate.source == "mse" ? "可能是正片" : "当前视频") }
                                        else if candidate.isMaster { badge("主播放列表") }
                                    }
                                    Text(candidate.host).font(.subheadline).foregroundStyle(.secondary)
                                    HStack {
                                        if let duration = candidate.duration { Text(timeLabel(duration)).font(.caption).foregroundStyle(.secondary) }
                                        Spacer()
                                        Button(cast.canControl ? "投到电视" : "选择电视后投屏") { loadVideo(candidate) }
                                            .buttonStyle(.borderedProminent).disabled(candidate.isDRM || cast.isLoading || cast.offlineValidation)
                                    }
                                }.padding(.vertical, 8)
                            }
                        } footer: {
                            Text("如果投屏失败，回到网页重新播放视频后再试。")
                        }
                    }
                }
            }
            .navigationTitle("检测到的视频").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            // sheet 盖住根视图时，根部的 alert 不会弹出，这里用共享 modifier 补一份同样的错误提示
            .castErrorAlert()
        }.presentationDetents([.medium, .large])
    }
    private func badge(_ label: String) -> some View {
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
