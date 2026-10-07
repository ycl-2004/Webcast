import Foundation
import GoogleCast
import Combine
import MediaPlayer

enum CastConnection: Equatable {
    case disconnected, connecting, connected, suspended
}

struct CastDevice: Identifiable {
    let id: String
    let name: String
    let detail: String
    let sdkDevice: GCKDevice
}

/// The SDK owns discovery/reconnection; only explicit UI actions start sessions or send commands.
/// https://developers.google.com/cast/docs/ios_sender/integrate
@MainActor
final class CastManager: NSObject, ObservableObject {
    @Published private(set) var devices: [CastDevice] = []
    @Published private(set) var connection: CastConnection = .disconnected
    @Published private(set) var deviceName = ""
    @Published private(set) var title = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var hasMedia = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var volume: Double = 0.5
    @Published private(set) var isMuted = false
    @Published private(set) var isLoading = false
    @Published private(set) var playbackLabel = "尚未播放视频"
    @Published var errorMessage: String?
    /// 最近一次成功发起的加载请求对应的候选，供「投屏失败后一键重试」使用
    @Published private(set) var lastLoadedCandidate: VideoCandidate?
    /// 电视上报播放错误时可对 lastLoadedCandidate 重试
    private(set) var canRetryLoad = false

    let offlineValidation: Bool
    private let context: GCKCastContext?
    private weak var mediaClient: GCKRemoteMediaClient?
    private var timer: Timer?
    private var loadRequest: GCKRequest?
    private var requests: [ObjectIdentifier: (GCKRequest, String)] = [:]
    private var reportedPlaybackError = false
    var canControl: Bool { !offlineValidation && connection == .connected }

    override init() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        offlineValidation = environment["WEBCAST_OFFLINE_VALIDATION"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
        #else
        offlineValidation = false
        #endif
        if offlineValidation {
            context = nil
        } else {
            let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
            let options = GCKCastOptions(discoveryCriteria: criteria)
            options.disableDiscoveryAutostart = true
            options.startDiscoveryAfterFirstTapOnCastButton = false
            options.disableAnalyticsLogging = true
            GCKCastContext.setSharedInstanceWith(options)
            context = GCKCastContext.sharedInstance()
        }
        super.init()
        context?.sessionManager.add(self)
        context?.discoveryManager.add(self)
        #if DEBUG
        // Debug 构建下转发 Google Cast SDK 原生日志，便于真机排查发现/连接/加载链路
        GCKLogger.sharedInstance().delegate = self
        #else
        GCKLogger.sharedInstance().loggingEnabled = false
        #endif
        refreshSession()
        if !offlineValidation {
            updateTimerState()
            setupNowPlaying()
        }
    }

    deinit { timer?.invalidate() }

    /// 只在有活动会话时开启每秒轮询；断开后挂起，避免长期待机空转
    private func updateTimerState() {
        let active = canControl && context?.sessionManager.currentCastSession != nil
        if active, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.updatePlayback() }
            }
        } else if !active, let existing = timer {
            existing.invalidate()
            timer = nil
        }
    }

    var connectionLabel: String {
        switch connection {
        case .disconnected: return "未连接电视"
        case .connecting: return "正在连接…"
        case .connected: return deviceName.isEmpty ? "已连接" : deviceName
        case .suspended: return "等待恢复连接…"
        }
    }

    func discover() {
        guard let context else { return }
        context.discoveryManager.startDiscovery()
        refreshDevices()
    }

    /// 连接建立或选择器关闭后停止扫描，避免后台持续耗电
    func stopDiscovery() {
        guard let context, context.discoveryManager.discoveryActive else { return }
        context.discoveryManager.stopDiscovery()
    }

    func connect(_ device: CastDevice) {
        guard let context, !offlineValidation else { return }
        errorMessage = nil
        deviceName = device.name
        if context.sessionManager.startSession(with: device.sdkDevice) { connection = .connecting }
        else { errorMessage = "无法开始连接。请确认电视和手机在同一 Wi-Fi。" }
    }

    func disconnect(stopPlayback: Bool) {
        guard let context, !offlineValidation else { return }
        if !context.sessionManager.endSessionAndStopCasting(stopPlayback) {
            errorMessage = "暂时无法断开，请重试。"
        }
    }

    @discardableResult
    func load(_ candidate: VideoCandidate) -> Bool {
        guard canControl, let client = mediaClient else { errorMessage = "请先连接 Chromecast。"; return false }
        guard !candidate.isDRM else { errorMessage = "这个视频需要 DRM 授权，暂时无法投屏。"; return false }
        errorMessage = nil
        isLoading = true
        let request = client.loadMedia(with: MediaLoader.request(for: candidate))
        loadRequest = request
        lastLoadedCandidate = candidate
        canRetryLoad = false
        track(request, action: "加载视频")
        return true
    }

    /// 电视加载失败后，用同一候选重试一次（签名 URL 失效需回网页重新检测）
    @discardableResult
    func retryLoad() -> Bool {
        guard let candidate = lastLoadedCandidate else { return false }
        return load(candidate)
    }

    func togglePlayback() {
        guard canControl, let client = mediaClient, hasMedia else { return }
        track(isPlaying ? client.pause() : client.play(), action: isPlaying ? "暂停" : "播放")
    }

    func seek(to value: Double) {
        guard canControl, hasMedia, duration > 0, let client = mediaClient else { return }
        let options = GCKMediaSeekOptions()
        options.interval = min(max(value, 0), duration)
        track(client.seek(with: options), action: "调整进度")
    }

    func setVolume(_ value: Double) {
        guard canControl, let session = context?.sessionManager.currentCastSession else { return }
        track(session.setDeviceVolume(Float(min(max(value, 0), 1))), action: "调整音量")
    }

    func toggleMute() {
        guard canControl, let session = context?.sessionManager.currentCastSession else { return }
        track(session.setDeviceMuted(!isMuted), action: "切换静音")
    }

    func stop() {
        guard canControl, let client = mediaClient else { return }
        track(client.stop(), action: "停止播放")
    }

    func refreshSession() {
        guard let session = context?.sessionManager.currentCastSession else {
            mediaClient?.remove(self)
            mediaClient = nil
            connection = .disconnected
            deviceName = ""
            clearPlayback()
            requests.removeAll()
            stopDiscoveryIfIdle()
            updateTimerState()
            return
        }
        deviceName = session.device.friendlyName ?? "Chromecast"
        if session.connectionState == .connected { connection = .connected }
        let nextClient = session.remoteMediaClient
        if mediaClient !== nextClient {
            mediaClient?.remove(self)
            mediaClient = nextClient
            mediaClient?.add(self)
        }
        updateTimerState()
        updatePlayback()
    }

    private func clearPlayback() {
        hasMedia = false; isPlaying = false; isLoading = false
        title = ""; position = 0; duration = 0; playbackLabel = "尚未播放视频"
        loadRequest = nil; requests.removeAll()
        reportedPlaybackError = false
        canRetryLoad = false
        updateNowPlaying(reset: true)
    }

    private func updatePlayback() {
        guard !offlineValidation else { return }
        if let session = context?.sessionManager.currentCastSession {
            let rawVolume = Double(session.currentDeviceVolume)
            volume = rawVolume.isFinite ? min(max(rawVolume, 0), 1) : 0.5
            isMuted = session.currentDeviceMuted
        }
        guard let client = mediaClient, let status = client.mediaStatus else { return }
        let state = status.playerState
        hasMedia = status.mediaInformation != nil && state != .idle && state != .unknown
        isPlaying = state == .playing
        if hasMedia {
            title = status.mediaInformation?.metadata?.string(forKey: kGCKMetadataKeyTitle) ?? "网页视频"
            let rawDuration = status.mediaInformation?.streamDuration ?? 0
            duration = rawDuration.isFinite && rawDuration > 0 ? rawDuration : 0
            let rawPosition = client.approximateStreamPosition()
            position = rawPosition.isFinite ? max(0, rawPosition) : 0
        } else { title = ""; position = 0; duration = 0 }
        switch state {
        case .playing: playbackLabel = "正在播放"
        case .paused: playbackLabel = "已暂停"
        case .buffering: playbackLabel = "正在缓冲…"
        case .loading: playbackLabel = "正在加载…"
        default: playbackLabel = "尚未播放视频"
        }
        if state == .idle && status.idleReason == .error {
            if !reportedPlaybackError {
                errorMessage = "电视无法播放这个视频。请回到网页重新播放，再试一次。"
                canRetryLoad = lastLoadedCandidate != nil
                reportedPlaybackError = true
            }
        } else { reportedPlaybackError = false }
        updateNowPlaying()
    }

    /// 连接已建立时保持扫描没有意义；空闲（未连接）时才允许停止检查
    private func stopDiscoveryIfIdle() {
        guard let context, context.sessionManager.currentCastSession == nil else { return }
        stopDiscovery()
    }

    private func refreshDevices() {
        guard let discovery = context?.discoveryManager else { return }
        devices = (0..<discovery.deviceCount).map {
            let device = discovery.device(at: $0)
            return CastDevice(id: device.uniqueID, name: device.friendlyName ?? "Chromecast",
                              detail: device.modelName ?? "Google Cast", sdkDevice: device)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func track(_ request: GCKRequest, action: String) {
        requests[ObjectIdentifier(request)] = (request, action)
        request.delegate = self
    }
}

extension CastManager: @preconcurrency GCKSessionManagerListener {
    func sessionManager(_ sessionManager: GCKSessionManager, willStart session: GCKCastSession) { connection = .connecting }
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKCastSession) {
        stopDiscovery()
        refreshSession()
    }
    @objc(sessionManager:didResumeCastSession:)
    func sessionManager(_ sessionManager: GCKSessionManager, didResumeCastSession session: GCKCastSession) {
        stopDiscovery()
        refreshSession()
    }
    func sessionManager(_ sessionManager: GCKSessionManager, didSuspend session: GCKCastSession, with reason: GCKConnectionSuspendReason) {
        connection = .suspended
        updateTimerState()
    }
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKCastSession, withError error: Error?) {
        refreshSession()
        if error != nil { errorMessage = "连接已中断。请检查手机与电视的 Wi-Fi。" }
    }
    func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKCastSession, withError error: Error) {
        refreshSession()
        errorMessage = "连接失败。请确认本地网络权限已开启，且设备在同一 Wi-Fi。"
    }
}

extension CastManager: @preconcurrency GCKDiscoveryManagerListener {
    func didUpdateDeviceList() { refreshDevices() }
    func didInsert(_ device: GCKDevice, at index: UInt) { refreshDevices() }
    func didRemove(_ device: GCKDevice, at index: UInt) { refreshDevices() }
    func didUpdate(_ device: GCKDevice, at index: UInt) { refreshDevices() }
}

extension CastManager: @preconcurrency GCKRemoteMediaClientListener {
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) { updatePlayback() }
}

#if DEBUG
extension CastManager: GCKLoggerDelegate {
    nonisolated func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        print("[GCK] \(function): \(message)")
    }
}
#endif

extension CastManager: @preconcurrency GCKRequestDelegate {
    func requestDidComplete(_ request: GCKRequest) {
        requests.removeValue(forKey: ObjectIdentifier(request))
        if request === loadRequest { isLoading = false; loadRequest = nil }
        updatePlayback()
    }
    func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        let action = requests.removeValue(forKey: ObjectIdentifier(request))?.1 ?? "操作"
        let isLoad = request === loadRequest
        if isLoad { isLoading = false; loadRequest = nil }
        if isLoad {
            canRetryLoad = lastLoadedCandidate != nil
            errorMessage = "加载视频失败。请检查电视连接，或回到网页重新播放后再试。"
        } else {
            errorMessage = "\(action)失败。请检查电视连接。"
        }
    }
    func request(_ request: GCKRequest, didAbortWith reason: GCKRequestAbortReason) {
        requests.removeValue(forKey: ObjectIdentifier(request))
        if request === loadRequest { isLoading = false; loadRequest = nil }
    }
}
