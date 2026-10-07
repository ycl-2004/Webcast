import Foundation
import MediaPlayer

/// 锁屏 / 控制中心遥控桥：把 Cast 会话状态映射到 MPNowPlayingInfoCenter，
/// 并把系统远程指令转回 Cast 会话。仅在真机（非离线验证）模式下启用。
/// https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter
extension CastManager {
    private var commandCenter: MPRemoteCommandCenter { MPRemoteCommandCenter.shared() }

    func setupNowPlaying() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { $0.togglePlayback() } ?? .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { $0.togglePlayback() } ?? .commandFailed
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.dispatchRemoteCommand { $0.togglePlayback() } ?? .commandFailed
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
        guard !reset, canControl, hasMedia else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let live = duration <= 0
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: deviceName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue
        ]
        if live { info[MPNowPlayingInfoPropertyIsLiveStream] = true }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
