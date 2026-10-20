import AppKit
import Foundation
import XCTest
@testable import LocalTube

final class PlaybackSpeedTests: XCTestCase {
    func testPresetsStartAtThreeQuarters() {
        XCTAssert(PlaybackSpeed.presets == [0.75, 1, 1.25, 1.5, 1.75, 2])
    }

    func testStepsThroughPresets() {
        XCTAssert(PlaybackSpeed.faster(than: 1) == 1.25)
        XCTAssert(PlaybackSpeed.slower(than: 1) == 0.75)
        XCTAssert(PlaybackSpeed.faster(than: 2) == 2)
        XCTAssert(PlaybackSpeed.slower(than: 0.75) == 0.75)
    }

    func testCustomSpeedJumpsToNearestPreset() {
        XCTAssert(PlaybackSpeed.faster(than: 1.15) == 1.25)
        XCTAssert(PlaybackSpeed.slower(than: 1.15) == 1)
    }

    func testNormalizesToRangeAndGrid() {
        XCTAssert(PlaybackSpeed.normalized(0.25) == 0.75)
        XCTAssert(PlaybackSpeed.normalized(3) == 2)
        XCTAssert(PlaybackSpeed.normalized(1.149) == 1.15)
        XCTAssert(PlaybackSpeed.normalized(1.25) == 1.25)
    }

    func testLabels() {
        XCTAssert(PlaybackSpeed.label(1) == "Normal")
        XCTAssert(PlaybackSpeed.label(0.75) == "0.75")
        XCTAssert(PlaybackSpeed.label(2) == "2")
        XCTAssert(PlaybackSpeed.label(PlaybackSpeed.normalized(1.15)) == "1.15")
    }
}

final class TimeFormatTests: XCTestCase {
    func testYoutubeStyle() {
        XCTAssert(TimeFormat.string(0) == "0:00")
        XCTAssert(TimeFormat.string(5.9) == "0:05")
        XCTAssert(TimeFormat.string(754) == "12:34")
        XCTAssert(TimeFormat.string(3723) == "1:02:03")
        XCTAssert(TimeFormat.string(.nan) == "0:00")
    }
}

final class FolderPlaylistTests: XCTestCase {
    func testListsSupportedVideosInFinderOrder() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["第10集.mp4", "第2集.mp4", "第1集.MOV", "clip.m4v", "notes.txt", "talk.webm", ".hidden.mp4"] {
            FileManager.default.createFile(atPath: folder.appendingPathComponent(name).path, contents: Data())
        }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("sub.mp4"), withIntermediateDirectories: false)

        let names = FolderPlaylist.videos(inFolderOf: folder.appendingPathComponent("第2集.mp4")).map(\.lastPathComponent)
        XCTAssert(names == ["clip.m4v", "第1集.MOV", "第2集.mp4", "第10集.mp4"])
    }

    /// /tmp is a symlink to /private/tmp; the opened file must still match its list entry.
    func testOpenedFileMatchesItsEntryUnderSymlinkedFolder() throws {
        let folder = URL(fileURLWithPath: "/tmp/LocalTubeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        FileManager.default.createFile(atPath: folder.appendingPathComponent("a.mp4").path, contents: Data())

        let opened = folder.appendingPathComponent("a.mp4").resolvingSymlinksInPath()
        XCTAssert(FolderPlaylist.videos(inFolderOf: opened) == [opened])
    }
}

final class ProgressStoreTests: XCTestCase {
    private func makeStore() -> ProgressStore {
        ProgressStore(defaults: UserDefaults(suiteName: "LocalTubeTests-\(UUID().uuidString)")!)
    }

    func testResumesWhereLeftOff() {
        XCTAssert(ProgressStore.startPosition(for: nil) == 0)
        XCTAssert(ProgressStore.startPosition(for: .init(position: 120, duration: 600)) == 120)
    }

    func testLastTenSecondsCountsAsWatched() {
        XCTAssert(ProgressStore.startPosition(for: .init(position: 591, duration: 600)) == 0)
        XCTAssert(ProgressStore.startPosition(for: .init(position: 589, duration: 600)) == 589)
        XCTAssert(ProgressStore.fraction(for: .init(position: 591, duration: 600)) == 1)
        XCTAssert(ProgressStore.fraction(for: .init(position: 150, duration: 600)) == 0.25)
    }

    func testPersistsAcrossInstances() {
        let defaults = UserDefaults(suiteName: "LocalTubeTests-\(UUID().uuidString)")!
        let url = URL(fileURLWithPath: "/videos/a.mp4")
        ProgressStore(defaults: defaults).save(position: 42, duration: 100, for: url)
        XCTAssert(ProgressStore(defaults: defaults).entry(for: url) == .init(position: 42, duration: 100))
    }

    func testClampsPosition() {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/videos/b.mp4")
        store.save(position: 130, duration: 100, for: url)
        XCTAssert(store.entry(for: url)?.position == 100)
    }
}

final class SplitLayoutTests: XCTestCase {
    func testUsesTheFractionInsideTheLimits() {
        XCTAssert(SplitLayout.listWidth(fraction: 0.3, available: 1500) == 450)
    }

    func testKeepsBothSidesUsable() {
        XCTAssert(SplitLayout.listWidth(fraction: 0.05, available: 1500) == 280)
        XCTAssert(SplitLayout.listWidth(fraction: 0.9, available: 1500) == 1020)
    }

    func testNarrowWindowFavorsTheListMinimum() {
        // Smallest window: 960 - 2 * 24 padding - 24 divider.
        XCTAssert(SplitLayout.listWidth(fraction: 0.3, available: 888) == 280)
        XCTAssert(SplitLayout.listWidth(fraction: 0.9, available: 888) == 408)
        XCTAssert(SplitLayout.listWidth(fraction: 0.5, available: 600) == 280)
    }
}

final class WatchLayoutTests: XCTestCase {
    func testPlayerTakesTheInnerWidthWithoutTheList() {
        XCTAssert(WatchLayout.playerWidth(contentWidth: 960, showsList: false, theater: false, listFraction: 0.3) == 912)
        XCTAssert(WatchLayout.playerWidth(contentWidth: 960, showsList: true, theater: true, listFraction: 0.3) == 960)
    }

    func testListTakesItsShareFromThePlayer() {
        // 1600 - 48 padding - 24 divider = 1528 shared; 30% list = 458.4
        XCTAssert(WatchLayout.playerWidth(contentWidth: 1600, showsList: true, theater: false, listFraction: 0.3) == 1528 - 458.4)
    }

    func testHeightFitsPlayerAndInfoExactly() {
        // Plain numbers: written as a sum of integer literals, the assertion failed with both sides printing 633.
        // 24 top + 513 player (912 * 9/16) + 12 + 60 info + 24 bottom
        XCTAssert(WatchLayout.contentHeight(contentWidth: 960, showsList: false, theater: false, listFraction: 0.3,
                                            infoHeight: 60) == 633)
        // Theater: no top padding, player spans the whole width. 540 + 12 + 60 + 24
        XCTAssert(WatchLayout.contentHeight(contentWidth: 960, showsList: false, theater: true, listFraction: 0.3,
                                            infoHeight: 60) == 636)
    }

    func testOpeningTheListMakesTheWindowShorter() {
        let closed = WatchLayout.contentHeight(contentWidth: 1200, showsList: false, theater: false, listFraction: 0.3, infoHeight: 60)
        let open = WatchLayout.contentHeight(contentWidth: 1200, showsList: true, theater: false, listFraction: 0.3, infoHeight: 60)
        XCTAssert(open < closed)
    }
}

final class ShortcutTests: XCTestCase {
    private func action(_ keyCode: UInt16, _ chars: String = "", _ mods: NSEvent.ModifierFlags = []) -> ShortcutAction? {
        ShortcutAction.from(keyCode: keyCode, characters: chars, modifiers: mods)
    }

    func testArrowsAndSpace() {
        XCTAssert(action(123, "", [.numericPad, .function]) == .seek(by: -5))
        XCTAssert(action(124, "", [.numericPad, .function]) == .seek(by: 5))
        XCTAssert(action(126) == .volume(by: 0.05))
        XCTAssert(action(125) == .volume(by: -0.05))
        XCTAssert(action(49, " ") == .togglePlay)
    }

    func testYoutubeLetters() {
        XCTAssert(action(40, "k") == .togglePlay)
        XCTAssert(action(38, "j") == .seek(by: -10))
        XCTAssert(action(37, "l") == .seek(by: 10))
        XCTAssert(action(46, "m") == .toggleMute)
        XCTAssert(action(3, "f") == .toggleFullscreen)
        XCTAssert(action(17, "t") == .toggleTheater)
        XCTAssert(action(34, "i") == .togglePictureInPicture)
    }

    func testDigitsJumpToPercent() {
        XCTAssert(action(29, "0") == .seekToFraction(0))
        XCTAssert(action(23, "5") == .seekToFraction(0.5))
        XCTAssert(action(25, "9") == .seekToFraction(0.9))
    }

    func testShiftCombos() {
        XCTAssert(action(47, ">", .shift) == .faster)
        XCTAssert(action(43, "<", .shift) == .slower)
        XCTAssert(action(45, "N", .shift) == .next)
        XCTAssert(action(35, "P", .shift) == .previous)
        XCTAssert(action(40, "K", .shift) == nil)
    }

    func testFrameStep() {
        XCTAssert(action(43, ",") == .frameStep(-1))
        XCTAssert(action(47, ".") == .frameStep(1))
    }

    func testMenuShortcutsPassThrough() {
        XCTAssert(action(31, "o", .command) == nil)
        XCTAssert(action(12, "q", .command) == nil)
        XCTAssert(action(123, "", [.option]) == nil)
    }
}
