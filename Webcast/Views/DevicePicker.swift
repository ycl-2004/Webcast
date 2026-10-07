import SwiftUI

struct DevicePicker: View {
    @EnvironmentObject private var cast: CastManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(cast.connectionLabel, systemImage: "tv")
                    if cast.connection == .connected {
                        Button("仅断开手机连接") { cast.disconnect(stopPlayback: false); dismiss() }
                    }
                }
                if cast.offlineValidation {
                    Section { Text("当前为离线验证模式，设备发现和投屏均已关闭。").foregroundStyle(.secondary) }
                } else {
                    Section("同一 Wi-Fi 下的 Chromecast") {
                        if cast.devices.isEmpty {
                            HStack { ProgressView(); Text("正在查找设备…").foregroundStyle(.secondary) }
                            Text("没有找到？确认电视已开机、手机与电视连接同一个 Wi-Fi，并在系统设置中允许 Webcast 访问本地网络。")
                                .font(.callout).foregroundStyle(.secondary)
                            Button("重新查找", action: cast.discover)
                        } else {
                            ForEach(cast.devices) { device in
                                Button { cast.connect(device) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "tv").font(.title2)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(device.name).foregroundStyle(.primary)
                                            Text(device.detail).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if cast.connection == .connecting && cast.deviceName == device.name { ProgressView() }
                                        else { Image(systemName: "chevron.right").font(.caption) }
                                    }.padding(.vertical, 6)
                                }.disabled(cast.connection == .connecting)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择电视").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .onAppear(perform: cast.discover)
            // sheet 盖住根视图时，ContentView 根部的 alert 不会弹出，这里补一份同样的错误提示
            .alert("投屏提示", isPresented: Binding(get: { cast.errorMessage != nil }, set: { if !$0 { cast.errorMessage = nil } })) {
                Button("知道了", role: .cancel) { cast.errorMessage = nil }
            } message: { Text(cast.errorMessage ?? "") }
        }
    }
}
