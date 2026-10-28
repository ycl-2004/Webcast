import SwiftUI
import WebKit

/// 全局设置键；@AppStorage 与 BrowserModel 共用
enum SettingsKeys {
    static let defaultPage = "settings.defaultPage"     // start | browser | remote | last
    static let startLoad = "settings.startLoad"         // last | home
    static let blockPopups = "settings.blockPopups"     // Bool，默认 true
    static let desktopSite = "settings.desktopSite"     // Bool，默认 false
    static let homeURL = "settings.homeURL"
    static let searchEngine = "settings.searchEngine"   // bing | google
    static let defaultHome = "https://www.iyf.tv"
    static let lastTab = "state.lastTab"
    static let lastURL = "state.lastURL"
    static let lastCastDevice = "state.lastCastDevice"
}

struct SettingsView: View {
    @EnvironmentObject private var browser: BrowserModel
    @AppStorage(SettingsKeys.defaultPage) private var defaultPage = "last"
    @AppStorage(SettingsKeys.startLoad) private var startLoad = "last"
    @AppStorage(SettingsKeys.blockPopups) private var blockPopups = true
    @AppStorage(SettingsKeys.desktopSite) private var desktopSite = false
    @AppStorage(SettingsKeys.homeURL) private var storedHomeURL = SettingsKeys.defaultHome
    @AppStorage(SettingsKeys.searchEngine) private var searchEngine = "bing"
    @State private var confirmClear = false
    @State private var dataCleared = false
    @State private var clearingData = false
    @State private var clearError = false
    @State private var homeURLString = ""
    @State private var homeError: String?
    @FocusState private var editingHome: Bool

    var body: some View {
        List {
            Section {
                Picker("默认打开", selection: $defaultPage) {
                    Text("起始页").tag("start")
                    Text("浏览器").tag("browser")
                    Text("投屏遥控").tag("remote")
                    Text("上次位置").tag("last")
                }
                if defaultPage == "browser" || defaultPage == "last" {
                    Picker("浏览器打开时加载", selection: $startLoad) {
                        Text("上次访问的页面").tag("last")
                        Text("主页").tag("home")
                    }
                }
            }

            Section("浏览") {
                Toggle("拦截新窗口", isOn: $blockPopups)
                    .onChange(of: blockPopups) { _ in browser.applySettings() }
                Toggle("请求桌面网站", isOn: $desktopSite)
                    .onChange(of: desktopSite) { _ in browser.applySettings() }
                Picker("搜索引擎", selection: $searchEngine) {
                    Text("必应").tag("bing")
                    Text("Google").tag("google")
                }
                .onChange(of: searchEngine) { _ in browser.applySettings() }
                VStack(alignment: .leading, spacing: 6) {
                    TextField("主页地址", text: $homeURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($editingHome)
                        .onSubmit { saveHomeURL() }
                    if let homeError {
                        Text(homeError).font(.footnote).foregroundStyle(.red)
                    }
                }
            }

            Section {
                Button(clearingData ? String(localized: "正在清除…") : String(localized: "清除网站数据"), role: .destructive) { confirmClear = true }
                    .disabled(clearingData)
                if dataCleared {
                    Label("网站数据已清除", systemImage: "checkmark.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if clearError { Text("清除未完成，请重试。").font(.footnote).foregroundStyle(.red) }
            }

            Section("关于") {
                LabeledContent("版本", value: AppBuild.version)
                NavigationLink("投屏诊断") { CastDiagnosticsView() }
            }

            #if DEBUG
            Section {
                LabeledContent("构建", value: "Debug")
            }
            #endif
        }
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
        .onAppear { homeURLString = storedHomeURL }
        .onChange(of: editingHome) { if !$0 { saveHomeURL() } }
        .onDisappear { saveHomeURL() }
        .confirmationDialog("清除网站数据并退出登录？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清除", role: .destructive) { clearWebsiteData() }
        }
    }

    private func clearWebsiteData() {
        clearingData = true
        dataCleared = false
        clearError = false
        browser.clearWebsiteData { success in
            clearingData = false
            dataCleared = success
            clearError = !success
        }
    }

    private func saveHomeURL() {
        guard let url = BrowserAddress.resolve(homeURLString) else {
            homeError = String(localized: "请输入有效的网址。")
            return
        }
        homeError = nil
        storedHomeURL = url.absoluteString
        browser.applySettings()
    }
}
