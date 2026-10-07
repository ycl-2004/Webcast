import SwiftUI
import WebKit

struct BrowserView: View {
    @EnvironmentObject private var browser: BrowserModel
    @ObservedObject var sniffer: VideoSniffer
    let showVideos: () -> Void
    @FocusState private var editingAddress: Bool

    var body: some View {
        VStack(spacing: 0) {
            addressBar.disabled(browser.isClearingWebsiteData)
            if browser.isLoading { ProgressView(value: browser.progress).progressViewStyle(.linear).tint(.teal) }
            if let error = browser.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error).font(.callout)
                    Spacer()
                    Button("重试") { browser.reload() }
                }.padding(16).background(Color(uiColor: .secondarySystemBackground))
            }
            if browser.showingStartPage {
                StartPageView(browser: browser).disabled(browser.isClearingWebsiteData)
            } else {
                BrowserWebView(webView: browser.webView)
                Divider()
                bottomToolbar
            }
        }
        .navigationTitle("浏览器").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(browser.homeTitle) { editingAddress = false; browser.openHome() }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel("打开\(browser.homeTitle)")
            }
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("打开视频检测示例", systemImage: "play.rectangle", action: browser.openDemo)
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("浏览器菜单")
            }
        }
        #endif
        .onChange(of: editingAddress) { browser.isEditingAddress = $0 }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe").foregroundStyle(.secondary)
            TextField("输入网址或搜索", text: $browser.address)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.go).focused($editingAddress)
                    .onSubmit { browser.openAddress(); editingAddress = false }
                .accessibilityLabel("网页地址")
            if !browser.address.isEmpty {
                Button { browser.address = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }.accessibilityLabel("清空地址")
            }
            Button { browser.openAddress(); editingAddress = false } label: {
                Image(systemName: "arrow.right.circle.fill").font(.title2)
            }.frame(width: 44, height: 44).accessibilityLabel("打开网址")
        }
        .padding(.leading, 12).background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 16).padding(.bottom, 10)
    }

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            Button(action: browser.back) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .disabled(!browser.canGoBack).accessibilityLabel("后退")
            Button(action: browser.forward) { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(!browser.canGoForward).accessibilityLabel("前进")
            Button { browser.isLoading ? browser.stopLoading() : browser.reload() } label: {
                Image(systemName: browser.isLoading ? "xmark" : "arrow.clockwise").frame(width: 44, height: 44)
            }.accessibilityLabel(browser.isLoading ? "停止加载" : "刷新")
            Spacer(minLength: 8)
            Button(action: showVideos) {
                Label(sniffer.candidates.isEmpty ? "视频" : "视频 · \(sniffer.candidates.count)", systemImage: "play.rectangle")
                    .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                    .background(sniffer.candidates.isEmpty ? Color(uiColor: .secondarySystemBackground)
                                                           : Color.teal.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("检测到的视频，\(sniffer.candidates.count) 个")
            .foregroundStyle(sniffer.candidates.isEmpty ? .secondary : .primary)
        }.padding(.horizontal, 12).padding(.vertical, 8).background(.regularMaterial)
    }
}

/// 原生起始页：干净、目标单一，只提供入口
private struct StartPageView: View {
    @ObservedObject var browser: BrowserModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)
            Image(systemName: "tv")
                .font(.system(size: 52, weight: .light)).foregroundStyle(.teal)
                .padding(.bottom, 12)
            Text("Webcast").font(.title2.weight(.semibold))
            Text("打开网页，播放视频，再投到电视")
                .font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
            VStack(spacing: 12) {
                shortcut(icon: "play.tv", title: browser.homeTitle, subtitle: browser.homeURL.host ?? "",
                         action: browser.openHome)
            }
            .padding(.horizontal, 36).padding(.top, 32)
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private func shortcut(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3).foregroundStyle(.teal)
                    .frame(width: 44, height: 44)
                    .background(Color.teal.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct BrowserWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
