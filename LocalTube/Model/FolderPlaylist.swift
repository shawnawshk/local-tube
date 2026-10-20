import Foundation

/// The Up next list: supported videos in the current folder, in Finder name order.
enum FolderPlaylist {
    static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v"]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// `url` must already be symlink-resolved; entries are resolved the same way so they compare equal.
    static func videos(inFolderOf url: URL) -> [URL] {
        let folder = url.deletingLastPathComponent()
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        return items
            .filter { isSupported($0) && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map { $0.resolvingSymlinksInPath() }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
