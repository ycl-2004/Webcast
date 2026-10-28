import SwiftUI

struct DevicePicker: View {
    @EnvironmentObject private var cast: CastManager
    @Environment(\.dismiss) private var dismiss
    @State private var confirmStop = false
    var hasPendingCast = false
    var cancelPending: () -> Void = {}

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(cast.connectionLabel, systemImage: "tv")
                    if cast.connection != .disconnected {
                        Button("停止并断开", role: .destructive) { confirmStop = true }
                    }
                }
                if cast.offlineValidation {
                    Section { Text("当前为离线验证模式，设备发现和投屏均已关闭。").foregroundStyle(.secondary) }
                } else {
                    Section("同一 Wi-Fi 下的 Chromecast") {
                        if cast.devices.isEmpty {
                            HStack { ProgressView(); Text("正在查找设备…").foregroundStyle(.secondary) }
                            DisclosureGroup("找不到电视？") {
                                Text("确认电视已开机，手机和电视连接同一个 Wi-Fi，并在系统设置里允许 Webcast 访问本地网络。")
                                    .font(.callout).foregroundStyle(.secondary)
                                Link("打开系统设置", destination: URL(string: UIApplication.openSettingsURLString)!)
                            }
                            Button("重新查找") { cast.discover(restart: true) }
                        } else {
                            ForEach(cast.devices) { device in
                                let isCurrent = cast.deviceID == device.id
                                // 点当前电视只关闭选择器；点另一台则切换过去
                                Button { if isCurrent { dismiss() } else { cast.connect(device) } } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "tv").font(.title2)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(device.name).foregroundStyle(.primary)
                                            Text(device.detail).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if isCurrent && cast.connection == .connecting && !cast.connectionWaitExpired { ProgressView() }
                                        else if isCurrent { Image(systemName: "checkmark").foregroundStyle(.teal) }
                                        else { Image(systemName: "chevron.right").font(.caption) }
                                    }.padding(.vertical, 6)
                                }
                                .disabled(cast.connection == .connecting)
                                .accessibilityAddTraits(isCurrent ? .isSelected : [])
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择电视").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(hasPendingCast ? String(localized: "取消投屏") : String(localized: "完成")) { cancelPending(); dismiss() } } }
            .onAppear { cast.discover() }
            .confirmationDialog("停止电视播放并断开连接？", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("停止并断开", role: .destructive) { cancelPending(); cast.disconnect() }
            }
            // sheet 盖住根视图时，根部的 alert 不会弹出，这里用共享 modifier 补一份同样的错误提示
            .castErrorAlert()
        }
    }
}
