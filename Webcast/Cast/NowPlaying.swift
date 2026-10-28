import Foundation
import MediaPlayer

@MainActor
protocol RemotePlaybackTarget: AnyObject {
    func play()
    func pause()
    func togglePlayback()
}

/// 系统的 play/pause 是明确指令；重复发送也不应切换到相反状态。
enum RemotePlaybackCommand {
    case play, pause, toggle

    @MainActor func perform(on target: RemotePlaybackTarget) {
        switch self {
        case .play: target.play()
        case .pause: target.pause()
        case .toggle: target.togglePlayback()
        }
    }
}

/// 活动会话的系统媒体控制桥。后台会话会挂起并清空系统媒体信息；
/// 支持回到前台后恢复，不承诺持续锁屏遥控。仅在非离线验证模式下启用。
/// https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter
extension CastManager: RemotePlaybackTarget {
    private var commandCenter: MPRemoteCommandCenter { MPRemoteCommandCenter.shared() }

    func setupNowPlaying() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { RemotePlaybackCommand.play.perform(on: $0) } ?? .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { RemotePlaybackCommand.pause.perform(on: $0) } ?? .commandFailed
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { RemotePlaybackCommand.toggle.perform(on: $0) } ?? .commandFailed
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            return self?.dispatchRemoteCommand { $0.seek(to: event.positionTime) } ?? .commandFailed
        }
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { $0.seek(to: $0.position + 15) } ?? .commandFailed
        }
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { $0.seek(to: max(0, $0.position - 15)) } ?? .commandFailed
        }
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { $0.stop() } ?? .commandFailed
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    /// 远程指令必须回到主线程执行；未连接或无媒体时快速失败，避免锁屏按钮白发请求。
    @discardableResult
    private func dispatchRemoteCommand(_ action: @escaping (CastManager) -> Void) -> MPRemoteCommandHandlerStatus {
        guard canControl, hasMedia, !isLoading else { return .commandFailed }
        Task { @MainActor [weak self] in
            guard let self else { return }
            action(self)
        }
        return .success
    }

    /// 每次 updatePlayback 后同步锁屏信息；断开或无媒体时清空，锁屏控件随之消失。
    func updateNowPlaying(reset: Bool = false) {
        let controlsEnabled = !reset && canControl && hasMedia && !isLoading
        commandCenter.playCommand.isEnabled = controlsEnabled
        commandCenter.pauseCommand.isEnabled = controlsEnabled
        commandCenter.togglePlayPauseCommand.isEnabled = controlsEnabled
        commandCenter.stopCommand.isEnabled = controlsEnabled
        commandCenter.changePlaybackPositionCommand.isEnabled = controlsEnabled && duration > 0
        commandCenter.skipForwardCommand.isEnabled = controlsEnabled && duration > 0
        commandCenter.skipBackwardCommand.isEnabled = controlsEnabled && duration > 0
        guard !reset, canControl, hasMedia else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: deviceName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue
        ]
        if isLive { info[MPNowPlayingInfoPropertyIsLiveStream] = true }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
