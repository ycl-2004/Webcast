import SwiftUI
import WebKit

struct BrowserView: View {
    @EnvironmentObject private var browser: BrowserModel
    @ObservedObject var sniffer: VideoSniffer
    let showVideos: () -> Void
    @FocusState private var editingAddress: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "globe").foregroundStyle(.secondary)
                TextField("输入网址", text: $browser.address)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.go).focused($editingAddress)
                    .onSubmit { editingAddress = false; browser.openAddress() }
                    .accessibilityLabel("网页地址")
                Button { editingAddress = false; browser.openAddress() } label: {
                    Image(systemName: "arrow.right.circle.fill").font(.title2)
                }.frame(width: 44, height: 44).accessibilityLabel("打开网址")
            }
            .padding(.leading, 12).background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 16).padding(.bottom, 10)
            if browser.isLoading { ProgressView(value: browser.progress).progressViewStyle(.linear).tint(.teal) }
            if let error = browser.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error).font(.callout)
                    Spacer()
                    Button("重试") { browser.reload() }
                }.padding(16).background(Color(uiColor: .secondarySystemBackground))
            }
            BrowserWebView(webView: browser.webView)
            Divider()
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
                    Label(sniffer.candidates.isEmpty ? "检测到的视频" : "视频 · \(sniffer.candidates.count)", systemImage: "play.rectangle")
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                        .background(Color.teal.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 8))
                }.accessibilityLabel("检测到的视频，\(sniffer.candidates.count) 个")
            }.padding(.horizontal, 12).padding(.vertical, 8).background(.regularMaterial)
        }
        .navigationTitle("浏览器").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("打开 iyf.tv", systemImage: "house", action: browser.home)
                    Button("打开视频检测示例", systemImage: "play.rectangle", action: browser.openDemo)
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("浏览器菜单")
            }
        }
    }
}

struct BrowserWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
