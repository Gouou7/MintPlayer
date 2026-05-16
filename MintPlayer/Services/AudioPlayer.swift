import Foundation
import AVFoundation
import Combine

class AudioPlayer: ObservableObject {
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
    private let volumeDefaultsKey = "mintPlayer.player.volume"
    private let nowPlayingService = NowPlayingService()
    private var lastNowPlayingElapsedUpdate: TimeInterval = 0
    
    var onSongStarted: ((Song) -> Void)?
    
    init() {
        let storedVolume = UserDefaults.standard.object(forKey: volumeDefaultsKey) as? Float
        volume = min(max(storedVolume ?? 0.7, 0), 1)
        
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
    
    // 更新播放队列
    func setQueue(_ songs: [Song]) {
        queue = songs
        if let currentSong = currentSong {
            currentIndex = songs.firstIndex(where: { $0.id == currentSong.id })
        }
        updateRemoteCommandAvailability()
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
    }
    
    // 加入队列末尾
    func addToQueue(_ song: Song) {
        guard !queue.contains(where: { $0.id == song.id }) else { return }
        queue.append(song)
        updateRemoteCommandAvailability()
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
    }
    
    // 清空队列
    func clearQueue() {
        queue.removeAll()
        currentIndex = nil
        updateRemoteCommandAvailability()
    }
    
    private func start(song: Song) {
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
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            
            // 获取真实的歌曲时长
            duration = audioPlayer?.duration ?? song.duration
            currentTime = 0
            
            // 开始播放
            audioPlayer?.play()
            isPlaying = true
            updateNowPlayingInfo()
            updateRemoteCommandAvailability()
            
            // 启动播放计时器
            startPlaybackTimer()
            onSongStarted?(song)
            
            print("Playing: \(song.title) by \(song.artist)")
        } catch {
            print("Error playing song: \(error)")
            playbackError = "无法播放 \(song.title)：\(error.localizedDescription)"
            isPlaying = false
            updateNowPlayingInfo()
            updateRemoteCommandAvailability()
        }
    }
    
    // 暂停播放
    func pause() {
        audioPlayer?.pause()
        playbackTimer?.invalidate()
        isPlaying = false
        updateNowPlayingPlaybackState()
        print("Paused")
    }
    
    // 恢复播放
    func resume() {
        if let audioPlayer {
            if currentTime >= duration, let currentSong {
                play(song: currentSong)
                return
            }
            
            audioPlayer.play()
            startPlaybackTimer()
            isPlaying = true
            updateNowPlayingPlaybackState()
            print("Resumed")
        } else if let currentSong {
            play(song: currentSong)
        }
    }
    
    // 停止播放
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        playbackTimer?.invalidate()
        currentTime = 0
        isPlaying = false
        updateNowPlayingPlaybackState()
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
        
        if isShuffleEnabled {
            playRandomSong(excluding: index, shouldFinishSingleSong: false)
            return
        }
        
        let previousIndex = index == 0 ? (isRepeatEnabled ? queue.count - 1 : 0) : index - 1
        currentIndex = previousIndex
        start(song: queue[previousIndex])
    }
    
    // 下一曲
    func next() {
        guard !queue.isEmpty else { return }
        
        let index = currentIndex ?? queue.firstIndex(where: { $0.id == currentSong?.id }) ?? 0
        
        if isShuffleEnabled {
            playRandomSong(excluding: index, shouldFinishSingleSong: true)
            return
        }
        
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
        updateRemoteCommandAvailability()
    }
    
    // 切换列表循环
    func toggleRepeat() {
        isRepeatEnabled.toggle()
        updateRemoteCommandAvailability()
    }
    
    // 调整音量
    func setVolume(_ value: Float) {
        let normalizedValue = min(max(value, 0), 1)
        volume = normalizedValue
        audioPlayer?.volume = normalizedValue
        UserDefaults.standard.set(normalizedValue, forKey: volumeDefaultsKey)
    }
    
    // 跳转到指定时间
    func seek(to time: TimeInterval) {
        let normalizedTime = min(max(time, 0), duration)
        audioPlayer?.currentTime = normalizedTime
        currentTime = normalizedTime
        updateNowPlayingPlaybackState()
    }
    
    // 启动播放计时器
    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            
            if abs(self.currentTime - self.lastNowPlayingElapsedUpdate) >= 1 {
                self.updateNowPlayingPlaybackState()
            }
            
            // 检查是否播放完毕
            if self.duration > 0, self.currentTime >= self.duration {
                self.next()
            }
        }
    }
    
    private func playRandomSong(excluding index: Int, shouldFinishSingleSong: Bool) {
        if queue.count == 1 {
            if isRepeatEnabled || !shouldFinishSingleSong {
                currentIndex = 0
                start(song: queue[0])
            } else {
                finishPlayback()
            }
            return
        }
        
        var nextIndex = Int.random(in: queue.indices)
        while nextIndex == index {
            nextIndex = Int.random(in: queue.indices)
        }
        
        currentIndex = nextIndex
        start(song: queue[nextIndex])
    }
    
    private func finishPlayback() {
        playbackTimer?.invalidate()
        audioPlayer?.stop()
        currentTime = duration
        isPlaying = false
        updateNowPlayingPlaybackState()
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
        if isShuffleEnabled || isRepeatEnabled {
            return true
        }
        let index = currentIndex ?? queue.firstIndex(where: { $0.id == currentSong?.id }) ?? 0
        return index < queue.count - 1
    }
    
    private var hasPreviousTrack: Bool {
        guard !queue.isEmpty else { return false }
        if currentTime > 3 || isShuffleEnabled || isRepeatEnabled {
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
    
    // 清理资源
    deinit {
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        nowPlayingService.reset()
    }
}
