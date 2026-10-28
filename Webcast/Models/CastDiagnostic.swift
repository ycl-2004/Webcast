import Foundation

enum CastDiagnosticStage {
    case connect, disconnect, switchDevice, load, receiver, timeout
    case play, pause, seek, volume, mute, stop

    var label: String {
        switch self {
        case .connect: return String(localized: "连接电视")
        case .disconnect: return String(localized: "停止并断开")
        case .switchDevice: return String(localized: "切换电视")
        case .load: return String(localized: "加载视频")
        case .receiver: return String(localized: "电视播放")
        case .timeout: return String(localized: "等待电视确认")
        case .play: return String(localized: "播放")
        case .pause: return String(localized: "暂停")
        case .seek: return String(localized: "调整进度")
        case .volume: return String(localized: "调整音量")
        case .mute: return String(localized: "切换静音")
        case .stop: return String(localized: "停止播放")
        }
    }
}

enum AppBuild {
    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}

/// Deliberately has no raw URL, NSError, title, userInfo or device-name field.
struct CastDiagnostic: Identifiable {
    let id = UUID()
    let time: Date
    let stage: CastDiagnosticStage
    let errorCode: Int?
    let sourceHost: String?
    let deviceModel: String?
    let build: String

    init(stage: CastDiagnosticStage, errorCode: Int? = nil, sourceURL: URL? = nil,
         deviceModel: String? = nil, time: Date = Date()) {
        self.time = time
        self.stage = stage
        self.errorCode = errorCode
        self.sourceHost = sourceURL?.host.map { String($0.prefix(253)) }
        self.deviceModel = deviceModel.map { String($0.prefix(100)) }
        self.build = AppBuild.version
    }
}

struct CastDiagnosticLog {
    private(set) var entries: [CastDiagnostic] = []
    mutating func append(_ entry: CastDiagnostic) {
        entries.insert(entry, at: 0)
        if entries.count > 20 { entries.removeLast(entries.count - 20) }
    }
    mutating func clear() { entries.removeAll() }
}
