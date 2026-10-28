import SwiftUI

struct CastDiagnosticsView: View {
    @EnvironmentObject private var cast: CastManager

    var body: some View {
        List {
            Section {
                if cast.diagnostics.isEmpty { Text("暂无投屏问题") }
                ForEach(cast.diagnostics) { entry in
                    DisclosureGroup {
                        LabeledContent("版本", value: entry.build)
                        if let code = entry.errorCode { LabeledContent("错误代码", value: String(code)) }
                        if let model = entry.deviceModel { LabeledContent("设备型号", value: model) }
                        if let host = entry.sourceHost { LabeledContent("来源域名", value: host) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.stage.label)
                            Text(entry.time, format: .dateTime.month().day().hour().minute().second())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("最多保留最近 20 条问题，重新启动 App 后清空，不会上传。来源只显示域名。")
            }
            if !cast.diagnostics.isEmpty {
                Button("清除诊断记录", role: .destructive) { cast.clearDiagnostics() }
            }
        }
        .navigationTitle("投屏诊断").navigationBarTitleDisplayMode(.inline)
    }
}
