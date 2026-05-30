import Foundation
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var currentSong: Song?
    @Published var volume: Float = 0.7
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackError: String?
    @Published var isShuffleEnabled = false
    @Published var isRepeatEnabled = false
    @Published private(set) var queue: [Song] = []
    @Published private(set) var history: [Song] = []

    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var currentIndex: Int?
    private let volumeDefaultsKey = AppConfiguration.userDefaultsKey("player.volume")
    private let playbackSessionDefaultsKey = AppConfiguration.userDefaultsKey("player.session")
    private let playbackTimerInterval: TimeInterval = 0.2
    private let volumeSliderExponent: Float = 2
    private let playbackFadeDuration: TimeInterval = 0.22
    private let nowPlayingService = NowPlayingService()
    private var lastNowPlayingElapsedUpdate: TimeInterval = 0
    private var lastSessionElapsedUpdate: TimeInterval = 0
    private var pendingStartTime: TimeInterval?
    private var playbackCountingSession: PlaybackCountingSession?
    private var pendingPauseWorkItem: DispatchWorkItem?

    var onPlaybackCounted: ((Song.ID) -> Void)?

    var volumeSliderValue: Float {
        guard volume > 0 else { return 0 }
        return powf(volume, 1 / volumeSliderExponent)
    }

    override init() {
        let storedVolume = UserDefaults.standard.object(forKey: volumeDefaultsKey) as? Float
        volume = min(max(storedVolume ?? 0.7, 0), 1)
        super.init()

        // 配置音频会话
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    // 配置音频会话
    private func setupAudioSession() {
        // macOS 中不需要 AVAudioSession，当前直接使用 AVAudioPlayer 播放本地文件。
    }

    // 播放歌曲
    func play(song: Song) {
        if queue.isEmpty {
            queue = [song]
            currentIndex = 0
        } else if let index = queue.firstIndex(where: { $0.id == song.id }) {
            currentIndex = index
        } else {
            queue.append(song)
            currentIndex = queue.count - 1
        }

        start(song: song)
    }

    // 使用指定队列播放歌曲
    func play(song: Song, in songs: [Song]) {
        queue = songs
        currentIndex = songs.firstIndex(where: { $0.id == song.id })
        start(song: song)
    }

    // 顺序播放指定歌曲列表
    func play(songs: [Song]) {
        guard let firstSong = songs.first else { return }
        isShuffleEnabled = false
        play(song: firstSong, in: songs)
    }

    // 随机播放指定歌曲列表，并同步播放器随机状态
    func shuffle(songs: [Song]) {
        let shuffledSongs = songs.shuffled()
        guard let firstSong = shuffledSongs.first else { return }
        isShuffleEnabled = true
        play(song: firstSong, in: shuffledSongs)
    }

    // 更新播放队列
    func setQueue(_ songs: [Song]) {
        queue = songs
        if let currentSong = currentSong {
            currentIndex = songs.firstIndex(where: { $0.id == currentSong.id })
        }
        updateRemoteCommandAvailability()
        savePlaybackSession()
    }

    // 下一首播放
    func playNext(_ song: Song) {
        guard !queue.contains(where: { $0.id == song.id }) else { return }

        let insertIndex = min((currentIndex ?? -1) + 1, queue.count)
        queue.insert(song, at: insertIndex)
        if currentIndex == nil {
            currentIndex = 0
        }
        updateRemoteCommandAvailability()
        savePlaybackSession()
    }

    // 加入队列末尾
    func addToQueue(_ song: Song) {
        guard !queue.contains(where: { $0.id == song.id }) else { return }
        queue.append(song)
        updateRemoteCommandAvailability()
        savePlaybackSession()
    }

    // 从队列移除
    func removeFromQueue(songId: UUID) {
        guard let index = queue.firstIndex(where: { $0.id == songId }) else { return }
        queue.remove(at: index)

        if let currentIndex {
            if index < currentIndex {
                self.currentIndex = currentIndex - 1
            } else if index == currentIndex {
                self.currentIndex = nil
            }
        }
        updateRemoteCommandAvailability()
        savePlaybackSession()
    }

    // 清空队列
    func clearQueue() {
        queue.removeAll()
        currentIndex = nil
        updateRemoteCommandAvailability()
        savePlaybackSession()
    }

    func restoreLastSession(from songs: [Song]) {
        guard currentSong == nil,
              let session = loadPlaybackSession(),
              let restoredSong = resolveSong(id: session.currentSongId, path: session.currentSongPath, from: songs)
        else { return }

        let restoredQueue = session.queue.compactMap { item in
            resolveSong(id: item.id, path: item.path, from: songs)
        }
        queue = restoredQueue.isEmpty ? [restoredSong] : restoredQueue
        currentIndex = queue.firstIndex(where: { $0.id == restoredSong.id }) ?? session.currentIndex
        currentSong = restoredSong
        duration = restoredSong.duration
        currentTime = min(max(session.currentTime, 0), max(restoredSong.duration, 0))
        pendingStartTime = currentTime
        isShuffleEnabled = session.isShuffleEnabled
        isRepeatEnabled = session.isRepeatEnabled
        isPlaying = false
        updateNowPlayingInfo()
        updateRemoteCommandAvailability()
    }

    private func start(song: Song) {
        cancelPendingPause()
        updatePlaybackCounting()

        if let previousSong = currentSong, previousSong.id != song.id {
            history.insert(previousSong, at: 0)
            if history.count > 50 {
                history.removeLast(history.count - 50)
            }
        }

        currentSong = song
        playbackError = nil
        playbackTimer?.invalidate()
        audioPlayer?.stop()

        // 加载真实的音频文件
        let url = URL(fileURLWithPath: song.path)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()

            // 获取真实的歌曲时长
            duration = audioPlayer?.duration ?? song.duration
            let startTime = min(max(pendingStartTime ?? 0, 0), max(duration, 0))
            audioPlayer?.currentTime = startTime
            currentTime = startTime
            pendingStartTime = nil

            // 开始播放
            audioPlayer?.play()
            isPlaying = true
            startPlaybackCounting(for: song, duration: duration)
            updateNowPlayingInfo()
            updateRemoteCommandAvailability()

            // 启动播放计时器
            startPlaybackTimer()
            savePlaybackSession()

            print("Playing: \(song.title) by \(song.artist)")
        } catch {
            print("Error playing song: \(error)")
            playbackError = "无法播放 \(song.title)：\(error.localizedDescription)"
            isPlaying = false
            playbackCountingSession = nil
            updateNowPlayingInfo()
            updateRemoteCommandAvailability()
            savePlaybackSession()
        }
    }

    // 暂停播放
    func pause() {
        guard isPlaying else { return }

        isPlaying = false
        updatePlaybackCounting()
        playbackTimer?.invalidate()
        fadeOutAndPause()
        updateNowPlayingPlaybackState()
        savePlaybackSession()
        print("Paused")
    }

    // 恢复播放
    func resume() {
        cancelPendingPause()

        if let audioPlayer {
            if currentTime >= duration, let currentSong {
                play(song: currentSong)
                return
            }

            audioPlayer.volume = 0
            audioPlayer.play()
            audioPlayer.setVolume(volume, fadeDuration: playbackFadeDuration)
            isPlaying = true
            resumePlaybackCounting()
            startPlaybackTimer()
            updateNowPlayingPlaybackState()
            savePlaybackSession()
            print("Resumed")
        } else if let currentSong {
            play(song: currentSong)
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    // 停止播放
    func stop() {
        cancelPendingPause()
        isPlaying = false
        updatePlaybackCounting()
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        playbackTimer?.invalidate()
        currentTime = 0
        updateNowPlayingPlaybackState()
        savePlaybackSession()
        print("Stopped")
    }

    // 上一曲
    func previous() {
        guard !queue.isEmpty else { return }

        if currentTime > 3, let currentSong {
            seek(to: 0)
            if isPlaying {
                audioPlayer?.play()
            } else {
                self.currentSong = currentSong
            }
            return
        }

        let index = currentIndex ?? queue.firstIndex(where: { $0.id == currentSong?.id }) ?? 0

        let previousIndex = index == 0 ? (isRepeatEnabled ? queue.count - 1 : 0) : index - 1
        currentIndex = previousIndex
        start(song: queue[previousIndex])
    }

    // 下一曲
    func next() {
        guard !queue.isEmpty else { return }

        let index = currentIndex ?? queue.firstIndex(where: { $0.id == currentSong?.id }) ?? 0

        guard index < queue.count - 1 else {
            if isRepeatEnabled {
                currentIndex = 0
                start(song: queue[0])
            } else {
                finishPlayback()
            }
            return
        }

        let nextIndex = index + 1
        currentIndex = nextIndex
        start(song: queue[nextIndex])
    }

    // 切换随机播放
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            shuffleUpcomingQueue()
        }
        updateRemoteCommandAvailability()
        savePlaybackSession()
    }

    // 切换列表循环
    func toggleRepeat() {
        isRepeatEnabled.toggle()
        updateRemoteCommandAvailability()
        savePlaybackSession()
    }

    // 调整音量
    func setVolume(_ value: Float) {
        let normalizedValue = min(max(value, 0), 1)
        volume = normalizedValue
        if isPlaying {
            audioPlayer?.setVolume(normalizedValue, fadeDuration: playbackFadeDuration)
        } else {
            audioPlayer?.volume = normalizedValue
        }
        UserDefaults.standard.set(normalizedValue, forKey: volumeDefaultsKey)
    }

    func setVolumeFromSlider(_ value: Float) {
        let normalizedValue = min(max(value, 0), 1)
        setVolume(powf(normalizedValue, volumeSliderExponent))
    }

    // 跳转到指定时间
    func seek(to time: TimeInterval) {
        updatePlaybackCounting()
        let normalizedTime = min(max(time, 0), duration)
        audioPlayer?.currentTime = normalizedTime
        currentTime = normalizedTime
        updateNowPlayingPlaybackState()
        savePlaybackSession()
    }

    // 启动播放计时器
    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: playbackTimerInterval, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime

            if abs(self.currentTime - self.lastNowPlayingElapsedUpdate) >= 1 {
                self.updateNowPlayingPlaybackState()
            }

            if abs(self.currentTime - self.lastSessionElapsedUpdate) >= 5 {
                self.savePlaybackSession()
                self.lastSessionElapsedUpdate = self.currentTime
            }

            self.updatePlaybackCounting()
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.audioPlayer === player else { return }
            self.currentTime = self.duration

            guard flag else {
                self.finishPlayback()
                return
            }

            self.next()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.audioPlayer === player else { return }
            self.playbackError = error.map { "播放失败：\($0.localizedDescription)" } ?? "播放失败"
            self.finishPlayback()
        }
    }

    private func shuffleUpcomingQueue() {
        guard !queue.isEmpty else { return }

        guard let currentSong,
              let index = currentIndex ?? queue.firstIndex(where: { $0.id == currentSong.id }) else {
            queue.shuffle()
            currentIndex = nil
            return
        }

        let upcomingSongs = queue.enumerated()
            .filter { $0.offset != index }
            .map(\.element)
            .shuffled()

        queue = [currentSong] + upcomingSongs
        currentIndex = 0
    }

    private func finishPlayback() {
        cancelPendingPause()
        isPlaying = false
        updatePlaybackCounting()
        playbackTimer?.invalidate()
        audioPlayer?.stop()
        currentTime = duration
        updateNowPlayingPlaybackState()
        savePlaybackSession()
    }

    private func startPlaybackCounting(for song: Song, duration: TimeInterval) {
        let threshold = duration * 0.6
        guard threshold.isFinite, threshold > 0 else {
            playbackCountingSession = nil
            return
        }

        playbackCountingSession = PlaybackCountingSession(
            songID: song.id,
            countedThreshold: threshold,
            accumulatedPlaybackTime: 0,
            lastStartedAt: Date(),
            hasCounted: false
        )
    }

    private func resumePlaybackCounting() {
        guard var session = playbackCountingSession,
              !session.hasCounted,
              session.lastStartedAt == nil
        else { return }

        session.lastStartedAt = Date()
        playbackCountingSession = session
    }

    private func fadeOutAndPause() {
        guard let player = audioPlayer else { return }

        player.setVolume(0, fadeDuration: playbackFadeDuration)

        let pauseWorkItem = DispatchWorkItem { [weak self, weak player] in
            guard let self, let player, self.audioPlayer === player, !self.isPlaying else { return }
            player.pause()
            player.volume = self.volume
        }

        pendingPauseWorkItem = pauseWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + playbackFadeDuration, execute: pauseWorkItem)
    }

    private func cancelPendingPause() {
        pendingPauseWorkItem?.cancel()
        pendingPauseWorkItem = nil
    }

    private func updatePlaybackCounting() {
        guard var session = playbackCountingSession,
              !session.hasCounted,
              let lastStartedAt = session.lastStartedAt
        else { return }

        let now = Date()
        session.accumulatedPlaybackTime += max(0, now.timeIntervalSince(lastStartedAt))
        session.lastStartedAt = isPlaying ? now : nil

        if session.accumulatedPlaybackTime >= session.countedThreshold {
            session.hasCounted = true
            session.lastStartedAt = nil
            onPlaybackCounted?(session.songID)
        }

        playbackCountingSession = session
    }

    // 接入系统“正在播放”和媒体键控制
    private func setupRemoteCommandCenter() {
        nowPlayingService.configureRemoteCommands(
            play: { [weak self] in
                guard let self, self.currentSong != nil else { return false }
                DispatchQueue.main.async { self.resume() }
                return true
            },
            pause: { [weak self] in
                guard let self, self.currentSong != nil else { return false }
                DispatchQueue.main.async { self.pause() }
                return true
            },
            togglePlayPause: { [weak self] in
                guard let self, self.currentSong != nil else { return false }
                DispatchQueue.main.async {
                    self.isPlaying ? self.pause() : self.resume()
                }
                return true
            },
            nextTrack: { [weak self] in
                guard let self, self.hasNextTrack else { return false }
                DispatchQueue.main.async { self.next() }
                return true
            },
            previousTrack: { [weak self] in
                guard let self, self.hasPreviousTrack else { return false }
                DispatchQueue.main.async { self.previous() }
                return true
            },
            seek: { [weak self] position in
                guard let self, self.currentSong != nil else { return false }
                DispatchQueue.main.async { self.seek(to: position) }
                return true
            }
        )
        updateRemoteCommandAvailability()
    }

    private var hasNextTrack: Bool {
        guard !queue.isEmpty else { return false }
        if isRepeatEnabled {
            return true
        }
        let index = currentIndex ?? queue.firstIndex(where: { $0.id == currentSong?.id }) ?? 0
        return index < queue.count - 1
    }

    private var hasPreviousTrack: Bool {
        guard !queue.isEmpty else { return false }
        if currentTime > 3 || isRepeatEnabled {
            return true
        }
        let index = currentIndex ?? queue.firstIndex(where: { $0.id == currentSong?.id }) ?? 0
        return index > 0
    }

    private func updateRemoteCommandAvailability() {
        nowPlayingService.updateCommandAvailability(
            hasSong: currentSong != nil,
            hasNextTrack: hasNextTrack,
            hasPreviousTrack: hasPreviousTrack
        )
    }

    private func updateNowPlayingInfo() {
        guard let currentSong else {
            nowPlayingService.clear()
            return
        }

        nowPlayingService.updateInfo(
            song: currentSong,
            duration: duration,
            elapsedTime: currentTime,
            isPlaying: isPlaying
        )
        lastNowPlayingElapsedUpdate = currentTime
    }

    private func updateNowPlayingPlaybackState() {
        guard currentSong != nil else {
            nowPlayingService.clear()
            return
        }

        if !nowPlayingService.hasNowPlayingInfo {
            updateNowPlayingInfo()
            return
        }

        nowPlayingService.updatePlaybackState(
            elapsedTime: currentTime,
            isPlaying: isPlaying
        )
        lastNowPlayingElapsedUpdate = currentTime
        updateRemoteCommandAvailability()
    }

    private func loadPlaybackSession() -> PlaybackSession? {
        guard let data = UserDefaults.standard.data(forKey: playbackSessionDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(PlaybackSession.self, from: data)
    }

    private func savePlaybackSession() {
        guard let currentSong else { return }

        let session = PlaybackSession(
            currentSongId: currentSong.id,
            currentSongPath: currentSong.path,
            currentTime: currentTime,
            queue: queue.map { PlaybackSession.QueueItem(id: $0.id, path: $0.path) },
            currentIndex: currentIndex ?? queue.firstIndex(where: { $0.id == currentSong.id }),
            isShuffleEnabled: isShuffleEnabled,
            isRepeatEnabled: isRepeatEnabled
        )

        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: playbackSessionDefaultsKey)
        }
    }

    private func resolveSong(id: Song.ID, path: String, from songs: [Song]) -> Song? {
        songs.first { $0.id == id } ?? songs.first { standardizedPath($0.path) == standardizedPath(path) }
    }

    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    // 清理资源
    deinit {
        cancelPendingPause()
        updatePlaybackCounting()
        savePlaybackSession()
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        nowPlayingService.reset()
    }
}

private struct PlaybackCountingSession {
    let songID: Song.ID
    let countedThreshold: TimeInterval
    var accumulatedPlaybackTime: TimeInterval
    var lastStartedAt: Date?
    var hasCounted: Bool
}

private struct PlaybackSession: Codable {
    struct QueueItem: Codable {
        let id: UUID
        let path: String
    }

    let currentSongId: UUID
    let currentSongPath: String
    let currentTime: TimeInterval
    let queue: [QueueItem]
    let currentIndex: Int?
    let isShuffleEnabled: Bool
    let isRepeatEnabled: Bool
}
