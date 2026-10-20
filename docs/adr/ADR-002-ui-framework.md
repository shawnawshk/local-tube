# ADR-002 界面用 SwiftUI,控制条自己画

状态:已采纳 | 2026-10-20

## 背景

界面要做成 YouTube 观看页的样子。候选:

- **SwiftUI 原生**:app 小、启动快,能直接用 AVFoundation。
- **Electron**:用 HTML/CSS 照抄 YouTube 最容易,用户在别的项目里也用过。但 app 会大上百 MB,播放走的是 Chromium 的 `<video>`,跟 ADR-001 选的 AVFoundation 对不上。

## 决策

Swift + SwiftUI(用户已确认)。

- 视频画面:用 `NSViewRepresentable` 包一个 `AVPlayerLayer`。
- 不用 AVKit 的 `VideoPlayer` / `AVPlayerView` 自带的控制条。它们是 QuickTime 风格,改不成 YouTube 的样子。控制条、进度条、齿轮菜单全部用 SwiftUI 自己画,叠在画面上。

## 后果

- 控制条的显示/隐藏(鼠标不动几秒后自动隐藏)、拖动进度条、齿轮菜单这些交互都得自己写。
- 快捷键在 app 层统一处理,不依赖系统播放器控件。
