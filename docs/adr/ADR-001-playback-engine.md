# ADR-001 播放引擎用 AVFoundation

状态:已采纳 | 2026-10-20

## 背景

本地视频播放器要选播放引擎。候选两个:

- **AVFoundation**:苹果自带。硬件解码、省电、不用额外打包。但只认苹果支持的容器和编码(mp4/mov/m4v 这类),webm、mkv 打不开。
- **libmpv**:基于 ffmpeg,什么格式都能播。代价是要把 libmpv 和 ffmpeg 的动态库一起打包进 app,app 体积大很多,构建也麻烦。

## 决策

用 AVFoundation。只支持 mp4 / mov / m4v(用户已确认)。

## 依据

- 用户常用目录里的视频基本都是 mp4(7 个 mp4、1 个 webm,没有 mkv)。
- 本机实测(2026-10-20):webm 返回 `-11828 "This media format is not supported"`,两个 mp4 都 `isPlayable = true`。

## 后果

- webm、mkv、avi、flv 等打不开。打开这些文件时要给出明确提示,不能静默失败。
- 接下来播放列表只列受支持视频。
- 以后如果要支持更多格式,换成 libmpv 等于把播放层重写一遍,控制条和快捷键这层可以保留。
