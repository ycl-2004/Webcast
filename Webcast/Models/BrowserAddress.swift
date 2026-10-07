import Foundation

enum BrowserAddress {
    /// macOS Safari 的桌面 UA，用于「请求桌面网站」
    static let desktopUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    /// 搜索词与网址分开判断；显式 HTTP(S) 地址允许本机主机名和中文路径。
    private static func looksLikeURL(_ value: String) -> Bool {
        guard !value.isEmpty, !value.contains(where: { $0.isWhitespace }) else { return false }
        if value.lowercased().hasPrefix("https://") || value.lowercased().hasPrefix("http://") { return true }
        return value.contains(".") || value.hasPrefix("localhost")
    }

    static func resolve(_ input: String) -> URL? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeURL(value) else { return nil }
        let normalized = value.contains("://") ? value : "https://\(value)"
        guard let url = URL(string: normalized), let host = url.host, !host.isEmpty,
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func searchURL(for query: String, engine: String) -> URL? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return nil }
        var components = URLComponents(string: engine == "google"
            ? "https://www.google.com/search" : "https://www.bing.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: trimmedQuery)]
        // 搜索引擎按表单解码 query，字面量 + 需要独立转义。
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }
}
