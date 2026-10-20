import AppKit
import Foundation
import Testing
@testable import LocalTube

struct PlaybackSpeedTests {
    @Test func presetsStartAtThreeQuarters() {
        #expect(PlaybackSpeed.presets == [0.75, 1, 1.25, 1.5, 1.75, 2])
    }

    @Test func stepsThroughPresets() {
        #expect(PlaybackSpeed.faster(than: 1) == 1.25)
        #expect(PlaybackSpeed.slower(than: 1) == 0.75)
        #expect(PlaybackSpeed.faster(than: 2) == 2)
        #expect(PlaybackSpeed.slower(than: 0.75) == 0.75)
    }

    @Test func customSpeedJumpsToNearestPreset() {
        #expect(PlaybackSpeed.faster(than: 1.15) == 1.25)
        #expect(PlaybackSpeed.slower(than: 1.15) == 1)
    }

    @Test func normalizesToRangeAndGrid() {
        #expect(PlaybackSpeed.normalized(0.25) == 0.75)
        #expect(PlaybackSpeed.normalized(3) == 2)
        #expect(PlaybackSpeed.normalized(1.149) == 1.15)
        #expect(PlaybackSpeed.normalized(1.25) == 1.25)
    }

    @Test func labels() {
        #expect(PlaybackSpeed.label(1) == "Normal")
        #expect(PlaybackSpeed.label(0.75) == "0.75")
        #expect(PlaybackSpeed.label(2) == "2")
        #expect(PlaybackSpeed.label(PlaybackSpeed.normalized(1.15)) == "1.15")
    }
}

struct TimeFormatTests {
    @Test func youtubeStyle() {
        #expect(TimeFormat.string(0) == "0:00")
        #expect(TimeFormat.string(5.9) == "0:05")
        #expect(TimeFormat.string(754) == "12:34")
        #expect(TimeFormat.string(3723) == "1:02:03")
        #expect(TimeFormat.string(.nan) == "0:00")
    }
}

struct FolderPlaylistTests {
    @Test func listsSupportedVideosInFinderOrder() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["第10集.mp4", "第2集.mp4", "第1集.MOV", "clip.m4v", "notes.txt", "talk.webm", ".hidden.mp4"] {
            FileManager.default.createFile(atPath: folder.appendingPathComponent(name).path, contents: Data())
        }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("sub.mp4"), withIntermediateDirectories: false)

        let names = FolderPlaylist.videos(inFolderOf: folder.appendingPathComponent("第2集.mp4")).map(\.lastPathComponent)
        #expect(names == ["clip.m4v", "第1集.MOV", "第2集.mp4", "第10集.mp4"])
    }

    /// /tmp is a symlink to /private/tmp; the opened file must still match its list entry.
    @Test func openedFileMatchesItsEntryUnderSymlinkedFolder() throws {
        let folder = URL(fileURLWithPath: "/tmp/LocalTubeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        FileManager.default.createFile(atPath: folder.appendingPathComponent("a.mp4").path, contents: Data())

        let opened = folder.appendingPathComponent("a.mp4").resolvingSymlinksInPath()
        #expect(FolderPlaylist.videos(inFolderOf: opened) == [opened])
    }
}

struct ProgressStoreTests {
    private func makeStore() -> ProgressStore {
        ProgressStore(defaults: UserDefaults(suiteName: "LocalTubeTests-\(UUID().uuidString)")!)
    }

    @Test func resumesWhereLeftOff() {
        #expect(ProgressStore.startPosition(for: nil) == 0)
        #expect(ProgressStore.startPosition(for: .init(position: 120, duration: 600)) == 120)
    }

    @Test func lastTenSecondsCountsAsWatched() {
        #expect(ProgressStore.startPosition(for: .init(position: 591, duration: 600)) == 0)
        #expect(ProgressStore.startPosition(for: .init(position: 589, duration: 600)) == 589)
        #expect(ProgressStore.fraction(for: .init(position: 591, duration: 600)) == 1)
        #expect(ProgressStore.fraction(for: .init(position: 150, duration: 600)) == 0.25)
    }

    @Test func persistsAcrossInstances() {
        let defaults = UserDefaults(suiteName: "LocalTubeTests-\(UUID().uuidString)")!
        let url = URL(fileURLWithPath: "/videos/a.mp4")
        ProgressStore(defaults: defaults).save(position: 42, duration: 100, for: url)
        #expect(ProgressStore(defaults: defaults).entry(for: url) == .init(position: 42, duration: 100))
    }

    @Test func clampsPosition() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/videos/b.mp4")
        store.save(position: 130, duration: 100, for: url)
        #expect(store.entry(for: url)?.position == 100)
    }
}

struct SplitLayoutTests {
    @Test func usesTheFractionInsideTheLimits() {
        #expect(SplitLayout.listWidth(fraction: 0.3, available: 1500) == 450)
    }

    @Test func keepsBothSidesUsable() {
        #expect(SplitLayout.listWidth(fraction: 0.05, available: 1500) == 280)
        #expect(SplitLayout.listWidth(fraction: 0.9, available: 1500) == 1020)
    }

    @Test func narrowWindowFavorsTheListMinimum() {
        // Smallest window: 960 - 2 * 24 padding - 24 divider.
        #expect(SplitLayout.listWidth(fraction: 0.3, available: 888) == 280)
        #expect(SplitLayout.listWidth(fraction: 0.9, available: 888) == 408)
        #expect(SplitLayout.listWidth(fraction: 0.5, available: 600) == 280)
    }
}

struct WatchLayoutTests {
    @Test func playerTakesTheInnerWidthWithoutTheList() {
        #expect(WatchLayout.playerWidth(contentWidth: 960, showsList: false, theater: false, listFraction: 0.3) == 912)
        #expect(WatchLayout.playerWidth(contentWidth: 960, showsList: true, theater: true, listFraction: 0.3) == 960)
    }

    @Test func listTakesItsShareFromThePlayer() {
        // 1600 - 48 padding - 24 divider = 1528 shared; 30% list = 458.4
        #expect(WatchLayout.playerWidth(contentWidth: 1600, showsList: true, theater: false, listFraction: 0.3) == 1528 - 458.4)
    }

    @Test func heightFitsPlayerAndInfoExactly() {
        // Plain numbers: written as a sum of integer literals, #expect reported false with both sides printing 633.
        // 24 top + 513 player (912 * 9/16) + 12 + 60 info + 24 bottom
        #expect(WatchLayout.contentHeight(contentWidth: 960, showsList: false, theater: false, listFraction: 0.3,
                                          infoHeight: 60) == 633)
        // Theater: no top padding, player spans the whole width. 540 + 12 + 60 + 24
        #expect(WatchLayout.contentHeight(contentWidth: 960, showsList: false, theater: true, listFraction: 0.3,
                                          infoHeight: 60) == 636)
    }

    @Test func openingTheListMakesTheWindowShorter() {
        let closed = WatchLayout.contentHeight(contentWidth: 1200, showsList: false, theater: false, listFraction: 0.3, infoHeight: 60)
        let open = WatchLayout.contentHeight(contentWidth: 1200, showsList: true, theater: false, listFraction: 0.3, infoHeight: 60)
        #expect(open < closed)
    }
}

struct ShortcutTests {
    private func action(_ keyCode: UInt16, _ chars: String = "", _ mods: NSEvent.ModifierFlags = []) -> ShortcutAction? {
        ShortcutAction.from(keyCode: keyCode, characters: chars, modifiers: mods)
    }

    @Test func arrowsAndSpace() {
        #expect(action(123, "", [.numericPad, .function]) == .seek(by: -5))
        #expect(action(124, "", [.numericPad, .function]) == .seek(by: 5))
        #expect(action(126) == .volume(by: 0.05))
        #expect(action(125) == .volume(by: -0.05))
        #expect(action(49, " ") == .togglePlay)
    }

    @Test func youtubeLetters() {
        #expect(action(40, "k") == .togglePlay)
        #expect(action(38, "j") == .seek(by: -10))
        #expect(action(37, "l") == .seek(by: 10))
        #expect(action(46, "m") == .toggleMute)
        #expect(action(3, "f") == .toggleFullscreen)
        #expect(action(17, "t") == .toggleTheater)
        #expect(action(34, "i") == .togglePictureInPicture)
    }

    @Test func digitsJumpToPercent() {
        #expect(action(29, "0") == .seekToFraction(0))
        #expect(action(23, "5") == .seekToFraction(0.5))
        #expect(action(25, "9") == .seekToFraction(0.9))
    }

    @Test func shiftCombos() {
        #expect(action(47, ">", .shift) == .faster)
        #expect(action(43, "<", .shift) == .slower)
        #expect(action(45, "N", .shift) == .next)
        #expect(action(35, "P", .shift) == .previous)
        #expect(action(40, "K", .shift) == nil)
    }

    @Test func frameStep() {
        #expect(action(43, ",") == .frameStep(-1))
        #expect(action(47, ".") == .frameStep(1))
    }

    @Test func menuShortcutsPassThrough() {
        #expect(action(31, "o", .command) == nil)
        #expect(action(12, "q", .command) == nil)
        #expect(action(123, "", [.option]) == nil)
    }
}
