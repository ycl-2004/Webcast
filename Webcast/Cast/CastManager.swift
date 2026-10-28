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
    @Published private(set) var connectionWaitExpired = false
    private var connectionWait = CastConnectionWait()
    private var connectionWaitTask: Task<Void, Never>?
    let pendingCastCancellations = PassthroughSubject<Void, Never>()
    @Published private(set) var deviceName = ""
    /// 当前会话（或正在连接）的电视；设备列表按 ID 标记状态，同名电视也不会混淆
    @Published private(set) var deviceID: String?
    @Published private(set) var title = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var isLive = false
    @Published private(set) var hasMedia = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var volume: Double = 0.5
    @Published private(set) var isMuted = false
    @Published private var loadState = CastLoadState()
    var isLoading: Bool { loadState.isLoading }
    @Published private(set) var playbackLabel = String(localized: "尚未播放视频")
    @Published var errorMessage: String? {
        didSet { retryableLoadFailure = false }
    }
    /// 最近一次成功发起的加载请求对应的候选，供「投屏失败后一键重试」使用
    var lastLoadedCandidate: VideoCandidate? { loadState.lastCandidate }
    /// 电视上报播放错误时可对 lastLoadedCandidate 重试
    var canRetryLoad: Bool { retryableLoadFailure && loadState.canRetry && canControl }
    private var retryableLoadFailure = false
    private let loadEventSubject = PassthroughSubject<CastLoadEvent, Never>()
    var loadEvents: AnyPublisher<CastLoadEvent, Never> { loadEventSubject.eraseToAnyPublisher() }

    @Published private var diagnosticLog = CastDiagnosticLog()
    var diagnostics: [CastDiagnostic] { diagnosticLog.entries }
    func clearDiagnostics() { diagnosticLog.clear() }

    func recordFailure(_ stage: CastDiagnosticStage, code: Int? = nil, source: URL? = nil, model: String? = nil) {
        diagnosticLog.append(CastDiagnostic(stage: stage, errorCode: code, sourceURL: source,
            deviceModel: model ?? context?.sessionManager.currentCastSession?.device.modelName))
    }

    let offlineValidation: Bool
    private let context: GCKCastContext?
    private weak var mediaClient: GCKRemoteMediaClient?
    private var timer: Timer?
    private struct TrackedRequest {
        let request: GCKRequest
        let action: CastDiagnosticStage
        var loadID: UUID?
    }
    private var requests: [ObjectIdentifier: TrackedRequest] = [:]
    private var reportedPlaybackError = false
    /// 上次成功连接的电视；它在线时「投到电视」直接连接，省掉选择器
    private var lastDeviceID = UserDefaults.standard.string(forKey: SettingsKeys.lastCastDevice)
    /// 已连接时换电视：SDK 不允许并存两个会话，先结束当前会话，在结束回调里再连接它
    private var switchTarget: CastDevice?
    private var lastLoadOrigin: BrowserPlaybackContext?
    var retryIntent: CastIntent? {
        lastLoadedCandidate.map { CastIntent(candidate: $0, origin: lastLoadOrigin) }
    }
    var canControl: Bool { !offlineValidation && connection == .connected }

    override convenience init() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let offline = environment["WEBCAST_OFFLINE_VALIDATION"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
        #else
        let offline = false
        #endif
        self.init(offlineValidation: offline)
    }

    /// Explicit construction lets the separate, opt-in receiver suite exercise this same manager.
    init(offlineValidation: Bool) {
        self.offlineValidation = offlineValidation
        if offlineValidation {
            context = nil
        } else {
            let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
            let options = GCKCastOptions(discoveryCriteria: criteria)
            // 发现交给 SDK：前台自动扫描、后台自动暂停。锁屏回来或 App 被系统回收后，
            // 会话恢复要先重新发现同一台电视，手动停扫会让恢复失败（见 GCKSessionManager 文档）。
            // 没有使用 GCKUICastButton，必须关掉「首次点按钮才扫描」，否则永远不会开始扫描。
            options.startDiscoveryAfterFirstTapOnCastButton = false
            // 手机音量键直接调电视音量（SDK 默认关闭）
            options.physicalVolumeButtonsWillControlDeviceVolume = true
            options.disableAnalyticsLogging = true
            // Foreground recovery is supported; this app does not keep a background network session.
            options.suspendSessionsWhenBackgrounded = true
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

    deinit { timer?.invalidate(); connectionWaitTask?.cancel() }

    private func startConnectionWait() {
        connectionWaitTask?.cancel()
        connectionWaitExpired = false
        connectionWait.begin()
        connectionWaitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled, let self, connection == .connecting || connection == .suspended,
                  connectionWait.expire() else { return }
            connectionWaitExpired = true
            switchTarget = nil
            pendingCastCancellations.send(())
            recordFailure(.connect)
            errorMessage = String(localized: "连接等待超时。请检查电视和本地网络，或停止并断开后重试。")
        }
    }

    private func finishConnectionWait() {
        connectionWaitTask?.cancel(); connectionWaitTask = nil
        connectionWait.reset(); connectionWaitExpired = false
    }

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
        if connectionWaitExpired { return String(localized: "连接等待超时") }
        switch connection {
        case .disconnected: return String(localized: "未连接电视")
        case .connecting: return String(localized: "正在连接…")
        case .connected: return deviceName.isEmpty ? String(localized: "已连接") : deviceName
        case .suspended: return String(localized: "等待恢复连接…")
        }
    }

    func suspendConnectionWait() {
        connectionWaitTask?.cancel(); connectionWait.reset()
    }

    /// 上次连接过、当前在线的电视
    var quickConnectDevice: CastDevice? {
        guard let lastDeviceID else { return nil }
        return devices.first { $0.id == lastDeviceID }
    }

    /// SDK 在前台会自动扫描；这里确保选择器打开时扫描在跑，「重新查找」时重启扫描
    func discover(restart: Bool = false) {
        guard let discovery = context?.discoveryManager else { return }
        if restart && discovery.discoveryActive { discovery.stopDiscovery() }
        if !discovery.discoveryActive { discovery.startDiscovery() }
        refreshDevices()
    }

    @discardableResult
    func connect(_ device: CastDevice) -> Bool {
        guard let context, !offlineValidation else { return false }
        errorMessage = nil
        if let session = context.sessionManager.currentCastSession {
            // 已有会话时 startSession 会直接失败：同一台电视沿用当前会话，换电视先结束当前会话
            guard session.device.uniqueID != device.id else { return connection == .connected }
            switchTarget = device
            if !context.sessionManager.endSessionAndStopCasting(true) {
                switchTarget = nil
                recordFailure(.switchDevice)
                errorMessage = String(localized: "暂时无法切换电视，请先断开连接再试。")
                return false
            }
            return true
        }
        deviceID = device.id
        deviceName = device.name
        if context.sessionManager.startSession(with: device.sdkDevice) { connection = .connecting; return true }
        else {
            deviceID = nil
            deviceName = ""
            recordFailure(.connect, model: device.detail)
            errorMessage = String(localized: "无法开始连接。请确认电视和手机在同一 Wi-Fi。")
            return false
        }
    }

    /// 单发送端下 SDK 也会停止播放，因此只提供明确的“停止并断开”。
    // https://developers.google.com/cast/docs/reference/ios/interface_g_c_k_session_manager
    func disconnect() {
        guard let context, !offlineValidation else { return }
        switchTarget = nil
        pendingCastCancellations.send(())
        finishConnectionWait()
        if !context.sessionManager.endSessionAndStopCasting(true) {
            recordFailure(.disconnect)
            errorMessage = String(localized: "暂时无法断开，请重试。")
        }
    }

    @discardableResult
    func load(_ candidate: VideoCandidate, origin: BrowserPlaybackContext? = nil) -> Bool {
        guard canControl, let client = mediaClient else { errorMessage = String(localized: "请先连接 Chromecast。"); return false }
        guard !isLoading else { return false }
        guard SnifferPayload.mediaURL(candidate.url.absoluteString) != nil else { return false }
        guard !candidate.isDRM else { errorMessage = String(localized: "这个视频需要 DRM 授权，暂时无法投屏。"); return false }
        errorMessage = nil
        let request = client.loadMedia(with: MediaLoader.request(for: candidate))
        trackLoadRequest(request, candidate: candidate, origin: origin)
        return true
    }

    /// Record the transport boundary separately so SDK application requests can exercise callbacks offline.
    func trackLoadRequest(_ request: GCKRequest, candidate: VideoCandidate, origin: BrowserPlaybackContext? = nil) {
        requests = requests.filter { $0.value.loadID == nil }
        errorMessage = nil
        reportedPlaybackError = false
        let id = loadState.begin(candidate)
        lastLoadOrigin = origin
        requests[ObjectIdentifier(request)] = TrackedRequest(request: request, action: .load, loadID: id)
        request.delegate = self
        loadEventSubject.send(.started(id, origin))
    }

    func receiveLoadStatus(contentID: String?, playback: CastLoadState.Playback, now: Date = Date()) {
        switch loadState.observe(contentID: contentID, playback: playback) {
        case .confirmed(let id):
            if retryableLoadFailure { errorMessage = nil }
            loadEventSubject.send(.confirmed(id))
        case .failed:
            recordFailure(.receiver, source: lastLoadedCandidate?.url)
            presentLoadFailure(String(localized: "电视无法播放这个视频。请回到网页重新播放，再试一次。"))
            reportedPlaybackError = true
        case nil:
            break
        }
        if loadState.expire(now: now) {
            recordFailure(.timeout, source: lastLoadedCandidate?.url)
            presentLoadFailure(String(localized: "电视加载超时。手机仍可继续播放，请检查连接或重新检测视频。"))
        }
    }

    /// 电视加载失败后，用同一候选重试一次（签名 URL 失效需回网页重新检测）
    @discardableResult
    func retryLoad() -> Bool {
        guard let intent = retryIntent else { return false }
        return load(intent.candidate, origin: intent.origin)
    }

    func play() {
        guard canControl, !isLoading, let client = mediaClient, hasMedia else { return }
        track(client.play(), action: .play)
    }

    func pause() {
        guard canControl, !isLoading, let client = mediaClient, hasMedia else { return }
        track(client.pause(), action: .pause)
    }

    func togglePlayback() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to value: Double) {
        guard value.isFinite, canControl, !isLoading, hasMedia, duration > 0, let client = mediaClient else { return }
        let options = GCKMediaSeekOptions()
        options.interval = min(max(value, 0), duration)
        track(client.seek(with: options), action: .seek)
    }

    func setVolume(_ value: Double) {
        guard value.isFinite, canControl, let session = context?.sessionManager.currentCastSession else { return }
        track(session.setDeviceVolume(Float(min(max(value, 0), 1))), action: .volume)
    }

    func toggleMute() {
        guard canControl, let session = context?.sessionManager.currentCastSession else { return }
        track(session.setDeviceMuted(!isMuted), action: .mute)
    }

    func stop() {
        guard canControl, let client = mediaClient else { return }
        track(client.stop(), action: .stop)
    }

    func refreshSession() {
        guard let session = context?.sessionManager.currentCastSession else {
            finishConnectionWait()
            mediaClient?.remove(self)
            mediaClient = nil
            connection = .disconnected
            deviceName = ""
            deviceID = nil
            clearPlayback()
            updateTimerState()
            return
        }
        deviceName = session.device.friendlyName ?? "Chromecast"
        deviceID = session.device.uniqueID
        if session.connectionState == .connected { connection = .connected; finishConnectionWait() }
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
        hasMedia = false; isPlaying = false; isLive = false
        title = ""; position = 0; duration = 0; playbackLabel = String(localized: "尚未播放视频")
        loadState.reset(); requests.removeAll()
        lastLoadOrigin = nil
        loadEventSubject.send(.reset)
        reportedPlaybackError = false
        retryableLoadFailure = false
        updateNowPlaying(reset: true)
    }

    private func updatePlayback() {
        guard !offlineValidation else { return }
        if let session = context?.sessionManager.currentCastSession {
            let rawVolume = Double(session.currentDeviceVolume)
            volume = rawVolume.isFinite ? min(max(rawVolume, 0), 1) : 0.5
            isMuted = session.currentDeviceMuted
        }
        guard let client = mediaClient, let status = client.mediaStatus else {
            receiveLoadStatus(contentID: nil, playback: .waiting)
            return
        }
        let state = status.playerState
        hasMedia = status.mediaInformation != nil && state != .idle && state != .unknown
        isPlaying = state == .playing
        isLive = hasMedia && status.mediaInformation?.streamType == .live
        if hasMedia {
            title = status.mediaInformation?.metadata?.string(forKey: kGCKMetadataKeyTitle) ?? String(localized: "网页视频")
            let rawDuration = status.mediaInformation?.streamDuration ?? 0
            duration = rawDuration.isFinite && rawDuration > 0 ? rawDuration : 0
            let rawPosition = client.approximateStreamPosition()
            position = rawPosition.isFinite ? max(0, rawPosition) : 0
        } else { title = ""; position = 0; duration = 0 }
        switch state {
        case .playing: playbackLabel = String(localized: "正在播放")
        case .paused: playbackLabel = String(localized: "已暂停")
        case .buffering: playbackLabel = String(localized: "正在缓冲…")
        case .loading: playbackLabel = String(localized: "正在加载…")
        default: playbackLabel = String(localized: "尚未播放视频")
        }
        let failed = state == .idle && status.idleReason == .error
        let contentID = status.mediaInformation?.contentURL?.absoluteString ?? status.mediaInformation?.contentID
        receiveLoadStatus(contentID: contentID, playback: failed ? .failed :
                          (canControl && (state == .playing || state == .paused) ? .ready : .waiting))
        if failed && loadState.attemptID == nil {
            if !reportedPlaybackError {
                recordFailure(.receiver, source: status.mediaInformation?.contentURL)
                let message = String(localized: "电视无法播放这个视频。请回到网页重新播放，再试一次。")
                if loadState.playbackFailed(contentID: contentID) { presentLoadFailure(message) }
                else { errorMessage = message }
                reportedPlaybackError = true
            }
        } else if !failed { reportedPlaybackError = false }
        updateNowPlaying()
    }

    private func rememberDevice(_ session: GCKCastSession) {
        lastDeviceID = session.device.uniqueID
        UserDefaults.standard.set(lastDeviceID, forKey: SettingsKeys.lastCastDevice)
    }

    private func refreshDevices() {
        guard let discovery = context?.discoveryManager else { return }
        devices = (0..<discovery.deviceCount).map {
            let device = discovery.device(at: $0)
            return CastDevice(id: device.uniqueID, name: device.friendlyName ?? "Chromecast",
                              detail: device.modelName ?? "Google Cast", sdkDevice: device)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func track(_ request: GCKRequest, action: CastDiagnosticStage) {
        requests[ObjectIdentifier(request)] = TrackedRequest(request: request, action: action)
        request.delegate = self
    }

    private func presentLoadFailure(_ message: String) {
        errorMessage = message
        retryableLoadFailure = true
        reportedPlaybackError = true
    }
}

extension CastManager: @preconcurrency GCKSessionManagerListener {
    func sessionManager(_ sessionManager: GCKSessionManager, willStart session: GCKCastSession) {
        connection = .connecting; startConnectionWait()
    }
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKCastSession) {
        rememberDevice(session)
        refreshSession()
    }
    @objc(sessionManager:didResumeCastSession:)
    func sessionManager(_ sessionManager: GCKSessionManager, didResumeCastSession session: GCKCastSession) {
        rememberDevice(session)
        refreshSession()
    }
    func sessionManager(_ sessionManager: GCKSessionManager, didSuspend session: GCKCastSession, with reason: GCKConnectionSuspendReason) {
        connection = .suspended
        connectionWaitTask?.cancel(); connectionWait.reset()
        updateTimerState()
        updateNowPlaying(reset: true)
    }
    func beginForegroundRecoveryWait() {
        if connection == .suspended { startConnectionWait() }
    }
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKCastSession, withError error: Error?) {
        refreshSession()
        if let next = switchTarget {
            switchTarget = nil
            connect(next)
        } else if let error {
            recordFailure(.disconnect, code: (error as NSError).code, model: session.device.modelName)
            errorMessage = String(localized: "连接已中断。请检查手机与电视的 Wi-Fi。")
        }
    }
    func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKCastSession, withError error: Error) {
        refreshSession()
        if let castError = error as? GCKError, castError.code == GCKErrorCode.cancelled.rawValue { return }
        recordFailure(.connect, code: (error as NSError).code, model: session.device.modelName)
        errorMessage = String(localized: "连接失败。请确认本地网络权限已开启，且设备在同一 Wi-Fi。")
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
        guard let tracked = requests.removeValue(forKey: ObjectIdentifier(request)) else { return }
        if let id = tracked.loadID, !loadState.acknowledge(id) { return }
        updatePlayback()
    }
    func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        guard let tracked = requests.removeValue(forKey: ObjectIdentifier(request)) else { return }
        let superseded = error.code == GCKErrorCode.cancelled.rawValue || error.code == GCKErrorCode.replaced.rawValue
        if let id = tracked.loadID {
            guard loadState.fail(id, retryable: !superseded) else { return }
            if !superseded {
                recordFailure(.load, code: error.code, source: lastLoadedCandidate?.url)
                presentLoadFailure(String(localized: "加载视频失败。请检查电视连接，或回到网页重新播放后再试。"))
            }
        } else if !superseded {
            recordFailure(tracked.action, code: error.code)
            errorMessage = String(localized: "\(tracked.action.label)失败。请检查电视连接。")
        }
    }
    func request(_ request: GCKRequest, didAbortWith reason: GCKRequestAbortReason) {
        guard let tracked = requests.removeValue(forKey: ObjectIdentifier(request)) else { return }
        if let id = tracked.loadID { loadState.fail(id, retryable: false) }
    }
}
