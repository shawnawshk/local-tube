import AVFoundation
import AVKit
import AppKit
import Observation
import UniformTypeIdentifiers

/// Transient on-screen feedback (center icon, "5 seconds", "50%", "1.25x").
struct OSD: Equatable {
    enum Kind: Equatable {
        case play, pause
        case seek(Double)
        case volume(Double)
        case speed(Double)
    }
    let kind: Kind
    let id = UUID()
}

@MainActor
@Observable
final class PlayerModel {
    static let shared = PlayerModel()
    static let countdownSeconds = 5.0

    let player = AVPlayer()
    let progress = ProgressStore(defaults: .standard)

    private(set) var url: URL?
    private(set) var playlist: [URL] = []
    private(set) var info: VideoInfo?
    private(set) var preview: PreviewGenerator?
    private(set) var duration: Double = 0
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    private(set) var hasEnded = false
    private(set) var speed: Double
    private(set) var volume: Double
    private(set) var isMuted = false
    private(set) var autoplay: Bool
    private(set) var isTheater = false
    private(set) var showsPlaylist: Bool
    private(set) var playlistFraction: Double
    private(set) var isFullscreen = false
    private(set) var isPictureInPicture = false
    private(set) var countdownStart: Date?
    private(set) var controlsVisible = true
    private(set) var osd: OSD?
    var isSettingsOpen = false
    var unsupportedFile: URL?

    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored private let windowFitter = WindowFitter()
    @ObservationIgnored private var infoHeight: CGFloat = 60
    @ObservationIgnored var isMouseInPlayer = false
    @ObservationIgnored private var pip: AVPictureInPictureController?
    @ObservationIgnored private var pendingSeek: Double?
    @ObservationIgnored private var lastSaved = Date.distantPast
    @ObservationIgnored private var loadToken = UUID()
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var hideControlsTask: Task<Void, Never>?
    @ObservationIgnored private var osdTask: Task<Void, Never>?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private let defaults = UserDefaults.standard

    private init() {
        let stored = UserDefaults.standard
        speed = PlaybackSpeed.normalized(stored.object(forKey: "speed") as? Double ?? 1)
        volume = stored.object(forKey: "volume") as? Double ?? 1
        autoplay = stored.object(forKey: "autoplay") as? Bool ?? true
        showsPlaylist = stored.bool(forKey: "showsPlaylist")
        playlistFraction = stored.object(forKey: "playlistFraction") as? Double ?? SplitLayout.defaultListFraction
        player.volume = Float(volume)
        player.defaultRate = Float(speed)

        player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time.seconds) }
        }
        observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor [weak self] in self?.playingChanged(playing) }
        })
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let item = note.object as? AVPlayerItem
            MainActor.assumeIsolated {
                if let self, item === self.player.currentItem { self.reachedEnd() }
            }
        }
    }

    // MARK: - Opening

    var title: String? { url?.deletingPathExtension().lastPathComponent }
    var currentIndex: Int? { url.flatMap { playlist.firstIndex(of: $0) } }

    var nextURL: URL? {
        guard let i = currentIndex, i + 1 < playlist.count else { return nil }
        return playlist[i + 1]
    }

    var previousURL: URL? {
        guard let i = currentIndex, i > 0 else { return nil }
        return playlist[i - 1]
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        var types: [UTType] = [.mpeg4Movie, .quickTimeMovie]
        if let m4v = UTType(filenameExtension: "m4v") { types.append(m4v) }
        panel.allowedContentTypes = types
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func open(_ rawURL: URL) {
        let url = rawURL.resolvingSymlinksInPath()
        let token = UUID()
        loadToken = token
        // State changes go through this Task: set synchronously inside the AppKit open/drop
        // callback, SwiftUI missed the change and the unsupported-file alert never showed.
        Task {
            guard FolderPlaylist.isSupported(url) else {
                unsupportedFile = url
                return
            }
            let asset = AVURLAsset(url: url)
            let playable = (try? await asset.load(.isPlayable)) ?? false
            let duration = (try? await asset.load(.duration).seconds) ?? 0
            guard loadToken == token else { return }
            guard playable, duration.isFinite, duration > 0 else {
                unsupportedFile = url
                return
            }
            await load(url, asset: asset, duration: duration, token: token)
        }
    }

    private func load(_ url: URL, asset: AVURLAsset, duration: Double, token: UUID) async {
        saveProgress()
        cancelCountdown()
        self.url = url
        self.duration = duration
        fitWindow()
        playlist = FolderPlaylist.videos(inFolderOf: url)
        info = nil
        hasEnded = false
        isSettingsOpen = false
        preview = PreviewGenerator(asset: asset, duration: duration)

        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = .spectral
        player.replaceCurrentItem(with: item)
        let start = ProgressStore.startPosition(for: progress.entry(for: url))
        currentTime = start
        if start > 0 {
            _ = await player.seek(to: CMTime(seconds: start, preferredTimescale: 600),
                                  toleranceBefore: .zero, toleranceAfter: .zero)
        }
        guard loadToken == token else { return }
        play()

        let info = await VideoInfoCache.shared.info(for: url)
        if loadToken == token { self.info = info }
    }

    func saveProgress() {
        guard let url, duration > 0 else { return }
        progress.save(position: hasEnded ? duration : currentTime, duration: duration, for: url)
        lastSaved = Date()
    }

    // MARK: - Playback

    func play() {
        guard url != nil else { return }
        cancelCountdown()
        if hasEnded {
            hasEnded = false
            seek(to: 0)
        }
        player.play()
    }

    func pause() {
        player.pause()
        saveProgress()
    }

    func togglePlay(feedback: Bool = true) {
        if player.rate != 0 {
            pause()
            if feedback { show(.pause) }
        } else {
            play()
            if feedback { show(.play) }
        }
    }

    func seek(by delta: Double) {
        guard url != nil else { return }
        seek(to: (pendingSeek ?? currentTime) + delta)
        show(.seek(delta))
    }

    func seek(to time: Double) {
        guard url != nil, duration > 0 else { return }
        let target = min(max(time, 0), duration)
        if target < duration { hasEnded = false }
        cancelCountdown()
        pendingSeek = target
        currentTime = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                if self?.pendingSeek == target { self?.pendingSeek = nil }
            }
        }
    }

    /// `,` / `.` only work while paused, like YouTube.
    func step(_ frames: Int) {
        guard url != nil, player.rate == 0 else { return }
        player.currentItem?.step(byCount: frames)
    }

    func setSpeed(_ value: Double) {
        speed = PlaybackSpeed.normalized(value)
        player.defaultRate = Float(speed)
        if player.rate != 0 { player.rate = Float(speed) }
        defaults.set(speed, forKey: "speed")
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        player.volume = Float(volume)
        defaults.set(volume, forKey: "volume")
        if isMuted, volume > 0 {
            isMuted = false
            player.isMuted = false
        }
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
        show(.volume(isMuted ? 0 : volume))
    }

    func setAutoplay(_ on: Bool) {
        autoplay = on
        defaults.set(on, forKey: "autoplay")
        if !on { cancelCountdown() }
    }

    func playNext() {
        if let next = nextURL { open(next) }
    }

    func playPrevious() {
        if let previous = previousURL { open(previous) }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownStart = nil
    }

    private func tick(_ seconds: Double) {
        guard pendingSeek == nil, seconds.isFinite else { return }
        currentTime = seconds
        if isPlaying, Date().timeIntervalSince(lastSaved) > 5 { saveProgress() }
    }

    private func playingChanged(_ playing: Bool) {
        isPlaying = playing
        if playing {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
            controlsVisible = true
        }
    }

    private func reachedEnd() {
        hasEnded = true
        currentTime = duration
        saveProgress()
        guard autoplay, nextURL != nil else { return }
        countdownStart = Date()
        countdownTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.countdownSeconds))
            guard !Task.isCancelled else { return }
            self?.playNext()
        }
    }

    // MARK: - Presentation

    var showsControls: Bool { controlsVisible || !isPlaying || isSettingsOpen }

    func toggleTheater() {
        isTheater.toggle()
        fitWindow()
    }

    /// The list is hidden in theater mode, so asking for it there leaves theater mode.
    func togglePlaylist() {
        if isTheater {
            isTheater = false
            showsPlaylist = true
        } else {
            showsPlaylist.toggle()
        }
        defaults.set(showsPlaylist, forKey: "showsPlaylist")
        fitWindow()
    }

    func setPlaylistFraction(_ fraction: Double) {
        playlistFraction = fraction
        defaults.set(fraction, forKey: "playlistFraction")
        fitWindow()
    }

    func toggleFullscreen() { window?.toggleFullScreen(nil) }

    func togglePictureInPicture() {
        guard let pip else { return }
        if pip.isPictureInPictureActive { pip.stopPictureInPicture() } else { pip.startPictureInPicture() }
    }

    func attach(window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        let center = NotificationCenter.default
        center.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isFullscreen = true }
        }
        center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isFullscreen = false
                self?.fitWindow()
            }
        }
        windowFitter.attach(window) { [weak self] width in self?.contentHeight(forWidth: width) }
    }

    /// The title block can wrap, so the view reports its real height.
    func setInfoHeight(_ height: CGFloat) {
        guard abs(height - infoHeight) > 0.5 else { return }
        infoHeight = height
        fitWindow()
    }

    func fitWindow() { windowFitter.fit() }

    private func contentHeight(forWidth width: CGFloat) -> CGFloat? {
        guard url != nil, !isFullscreen else { return nil }
        return WatchLayout.contentHeight(contentWidth: width, showsList: showsPlaylist && !isTheater,
                                         theater: isTheater, listFraction: playlistFraction, infoHeight: infoHeight)
    }

    func attach(playerLayer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let pip = AVPictureInPictureController(playerLayer: playerLayer) else { return }
        observations.append(pip.observe(\.isPictureInPictureActive, options: [.new]) { [weak self] pip, _ in
            let active = pip.isPictureInPictureActive
            Task { @MainActor [weak self] in self?.isPictureInPicture = active }
        })
        self.pip = pip
    }

    /// Mouse moved or a key was pressed: show the controls, hide them again after 3s of playback.
    func noteActivity() {
        controlsVisible = true
        scheduleHideControls()
    }

    func mouseLeftPlayer() {
        isMouseInPlayer = false
        guard isPlaying, !isSettingsOpen else { return }
        hideControlsTask?.cancel()
        controlsVisible = false
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        guard isPlaying else { return }
        hideControlsTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.isPlaying, !self.isSettingsOpen else { return }
            self.controlsVisible = false
            if self.isMouseInPlayer { NSCursor.setHiddenUntilMouseMoves(true) }
        }
    }

    private func show(_ kind: OSD.Kind) {
        osd = OSD(kind: kind)
        osdTask?.cancel()
        osdTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.osd = nil
        }
    }

    // MARK: - Keyboard

    /// Returns false when the key isn't ours, so the event keeps going.
    @discardableResult
    func perform(_ action: ShortcutAction) -> Bool {
        guard url != nil else { return false }
        switch action {
        case .togglePlay: togglePlay()
        case .seek(let delta): seek(by: delta)
        case .seekToFraction(let fraction): seek(to: duration * fraction)
        case .seekToStart: seek(to: 0)
        case .seekToEnd: seek(to: duration)
        case .frameStep(let frames): step(frames)
        case .volume(let delta):
            setVolume(volume + delta)
            show(.volume(volume))
        case .toggleMute: toggleMute()
        case .faster:
            setSpeed(PlaybackSpeed.faster(than: speed))
            show(.speed(speed))
        case .slower:
            setSpeed(PlaybackSpeed.slower(than: speed))
            show(.speed(speed))
        case .toggleFullscreen: toggleFullscreen()
        case .exitFullscreen:
            if isSettingsOpen {
                isSettingsOpen = false
            } else if isFullscreen {
                toggleFullscreen()
            } else {
                return false
            }
        case .toggleTheater: toggleTheater()
        case .togglePictureInPicture: togglePictureInPicture()
        case .next: playNext()
        case .previous: playPrevious()
        }
        noteActivity()
        return true
    }
}
