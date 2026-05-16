import Foundation
import MediaPlayer
import AppKit

final class NowPlayingService {
    private var remoteCommandTokens: [(command: MPRemoteCommand, token: Any)] = []
    
    var hasNowPlayingInfo: Bool {
        MPNowPlayingInfoCenter.default().nowPlayingInfo != nil
    }
    
    func configureRemoteCommands(
        play: @escaping () -> Bool,
        pause: @escaping () -> Bool,
        togglePlayPause: @escaping () -> Bool,
        nextTrack: @escaping () -> Bool,
        previousTrack: @escaping () -> Bool,
        seek: @escaping (TimeInterval) -> Bool
    ) {
        removeRemoteCommandHandlers()
        
        let commandCenter = MPRemoteCommandCenter.shared()
        addHandler(to: commandCenter.playCommand) { play() ? .success : .noSuchContent }
        addHandler(to: commandCenter.pauseCommand) { pause() ? .success : .noSuchContent }
        addHandler(to: commandCenter.togglePlayPauseCommand) { togglePlayPause() ? .success : .noSuchContent }
        addHandler(to: commandCenter.nextTrackCommand) { nextTrack() ? .success : .commandFailed }
        addHandler(to: commandCenter.previousTrackCommand) { previousTrack() ? .success : .commandFailed }
        
        addHandler(to: commandCenter.changePlaybackPositionCommand) { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            return seek(positionEvent.positionTime) ? .success : .commandFailed
        }
        
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.ratingCommand.isEnabled = false
        commandCenter.bookmarkCommand.isEnabled = false
    }
    
    func updateCommandAvailability(hasSong: Bool, hasNextTrack: Bool, hasPreviousTrack: Bool) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = hasSong
        commandCenter.pauseCommand.isEnabled = hasSong
        commandCenter.togglePlayPauseCommand.isEnabled = hasSong
        commandCenter.changePlaybackPositionCommand.isEnabled = hasSong
        commandCenter.nextTrackCommand.isEnabled = hasNextTrack
        commandCenter.previousTrackCommand.isEnabled = hasPreviousTrack
    }
    
    func updateInfo(song: Song, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyAssetURL: URL(fileURLWithPath: song.path)
        ]
        
        if let artwork = artwork(for: song) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
    
    func updatePlaybackState(elapsedTime: TimeInterval, isPlaying: Bool) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
    
    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func reset() {
        removeRemoteCommandHandlers()
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    private func addHandler(
        to command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        let token = command.addTarget(handler: handler)
        remoteCommandTokens.append((command, token))
    }
    
    private func addHandler(
        to command: MPRemoteCommand,
        handler: @escaping () -> MPRemoteCommandHandlerStatus
    ) {
        addHandler(to: command) { _ in handler() }
    }
    
    private func removeRemoteCommandHandlers() {
        remoteCommandTokens.forEach { command, token in
            command.removeTarget(token)
        }
        remoteCommandTokens.removeAll()
    }
    
    private func artwork(for song: Song) -> MPMediaItemArtwork? {
        guard
            let coverPath = song.coverPath,
            let image = NSImage(contentsOfFile: coverPath)
        else {
            return nil
        }
        
        return MPMediaItemArtwork(boundsSize: image.size) { _ in
            image
        }
    }
}
