import AVFoundation

/// What the Up next rows and the info line need to know about a file.
struct VideoInfo {
    var duration: Double
    var size: CGSize
    var modified: Date?
    var thumbnail: CGImage?
}

@MainActor
final class VideoInfoCache {
    static let shared = VideoInfoCache()

    private var cache: [URL: VideoInfo] = [:]
    private var pending: [URL: Task<VideoInfo?, Never>] = [:]

    func info(for url: URL) async -> VideoInfo? {
        if let info = cache[url] { return info }
        if let task = pending[url] { return await task.value }
        let task = Task.detached { await Self.load(url) }
        pending[url] = task
        let info = await task.value
        pending[url] = nil
        cache[url] = info
        return info
    }

    nonisolated private static func load(_ url: URL) async -> VideoInfo? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration).seconds, duration.isFinite else { return nil }

        var size = CGSize.zero
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let (natural, transform) = try? await track.load(.naturalSize, .preferredTransform) {
            let rect = CGRect(origin: .zero, size: natural).applying(transform)
            size = CGSize(width: abs(rect.width), height: abs(rect.height))
        }

        // 10% in, to skip black intro frames.
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 336, height: 188)
        let thumbnail = try? await generator.image(at: CMTime(seconds: duration * 0.1, preferredTimescale: 600)).image

        let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return VideoInfo(duration: duration, size: size, modified: modified, thumbnail: thumbnail)
    }
}

/// Frames for the progress bar hover preview, cached per bucket of the timeline.
@MainActor
final class PreviewGenerator {
    static let buckets = 200

    private let generator: AVAssetImageGenerator
    private let duration: Double
    private var cache: [Int: CGImage] = [:]

    init(asset: AVAsset, duration: Double) {
        self.duration = duration
        generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        let tolerance = CMTime(seconds: max(duration / Double(Self.buckets) / 2, 0.5), preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
    }

    func image(bucket: Int) async -> CGImage? {
        if let image = cache[bucket] { return image }
        let time = CMTime(seconds: duration * Double(bucket) / Double(Self.buckets), preferredTimescale: 600)
        guard let image = try? await generator.image(at: time).image else { return nil }
        cache[bucket] = image
        return image
    }
}
