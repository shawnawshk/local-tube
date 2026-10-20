# LocalTube

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple)](#requirements)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-AVFoundation-F05138?logo=swift&logoColor=white)](#project-layout)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A native macOS player for local video files that looks and handles like a YouTube watch page: adjustable playback speed, YouTube's keyboard shortcuts, and an "Up next" list built from the video's folder.

> [!NOTE]
> LocalTube is a personal project. There are no prebuilt or notarized downloads; you build it from source with Xcode.

## Contents

- [Features](#features)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Requirements](#requirements)
- [Build and install](#build-and-install)
- [Limitations](#limitations)
- [Project layout](#project-layout)
- [Design docs](#design-docs)
- [License](#license)

## Features

- **YouTube watch-page layout**: dark theme, YouTube-style control bar, title and file details under the player.
- **Up next list**: every mp4 / mov / m4v in the current folder, sorted like Finder ("Episode 2" before "Episode 10"), with thumbnails, durations and red watched bars. Hidden by default; toggle it from the title bar and drag the divider to resize it.
- **Playback speed** from 0.75× to 2×: presets plus a Custom slider in 0.05 steps. Pitch is preserved, and the speed is remembered across videos and launches.
- **Resume where you left off**. A video with less than 10 seconds left counts as watched and starts over next time.
- **Autoplay** with YouTube's 5-second "Up next" countdown card.
- Hover preview on the progress bar, theater mode, full screen and picture-in-picture.
- The window height follows its content, so there is no empty space under the player.
- Opens files by drag and drop, ⌘O, or from Finder (LocalTube registers as an "Open With" app for mp4, mov and m4v).

## Keyboard shortcuts

The same keys as YouTube:

| Key | Action |
| --- | --- |
| Space / K | Play / pause |
| ← / → | Back / forward 5 seconds |
| J / L | Back / forward 10 seconds |
| ↑ / ↓ | Volume up / down 5% |
| M | Mute |
| 0–9 | Jump to 0%–90% |
| Home / End | Jump to start / end |
| Shift + > / Shift + < | Next / previous speed preset |
| , / . | Previous / next frame (while paused) |
| Shift + N / Shift + P | Next / previous video in the folder |
| F | Full screen (Esc to leave) |
| T | Theater mode |
| I | Picture-in-picture |

Click the video to play or pause; double-click for full screen.

## Requirements

- macOS 14 or later
- Xcode 15.4 or later. The project lists its files explicitly, so a new source file has to be added to the project in Xcode.

## Build and install

```bash
git clone https://github.com/shawnawshk/local-tube.git
cd local-tube
./scripts/install.sh
```

> [!WARNING]
> `install.sh` builds the Release configuration, quits LocalTube if it is running, and **replaces** `/Applications/LocalTube.app`.

The app is ad-hoc signed, which is fine on the Mac that built it but not for handing the app to someone else.

To make LocalTube the default player, select a video in Finder, choose **File › Get Info**, pick LocalTube under **Open with**, and click **Change All…**.

### Development

Open `LocalTube.xcodeproj` in Xcode, or run the unit tests from the command line:

```bash
xcodebuild -project LocalTube.xcodeproj -scheme LocalTube -derivedDataPath build/DerivedData test
```

- Debug builds use the bundle ID `local.LocalTube.debug`, so their settings and watch progress stay separate from the installed app (`local.LocalTube`).
- Run the tests with the screen unlocked; with the screen locked the test host app never quits and `xcodebuild` hangs.
- To change the app icon, edit `scripts/AppIcon.svg` and run `./scripts/make-icon.sh`.

## Limitations

- **Formats**: mp4, mov and m4v only. Playback uses AVFoundation, which cannot open webm, mkv, avi or flv ([ADR-001](docs/adr/ADR-001-playback-engine.md)).
- No subtitles.
- Not sandboxed, because the Up next list reads the whole folder of the video you open ([ADR-003](docs/adr/ADR-003-self-use-no-sandbox.md)). Not notarized.
- One window. Videos in subfolders are not listed.

## Project layout

```text
.
├── LocalTube/
│   ├── LocalTubeApp.swift   # app entry, menu commands, keyboard shortcut monitor
│   ├── Model/               # player state, folder playlist, watch progress, speed and layout rules
│   ├── Views/               # watch page, player, control bar, speed menu, Up next list
│   └── Assets.xcassets      # app icon
├── LocalTubeTests/          # unit tests (XCTest)
├── Support/Info.plist       # document types for Finder's "Open With"
├── scripts/                 # install.sh, make-icon.sh, AppIcon.svg
├── docs/adr/                # architecture decision records (Chinese)
└── CONTEXT.md               # design context and glossary (Chinese)
```

## Design docs

The design was worked out up front and is recorded in Chinese:

- [`CONTEXT.md`](CONTEXT.md): glossary, decided requirements, the shortcut table, and facts verified on a real machine.
- [`docs/adr/`](docs/adr/): decisions on the playback engine (AVFoundation), the UI framework (SwiftUI with a custom control bar), and distribution (local signing, no sandbox).

## License

[MIT](LICENSE)
