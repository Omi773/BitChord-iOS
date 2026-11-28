import Foundation
import BitChordCore

// The Local Music folder: one folder the listener picks once, kept in step with the library for
// as long as the app runs. Replaces the one-off Files picker (PORTING.md Q8) — there is nothing to
// import by hand and nothing to set.

/// The chosen folder, remembered as a security-scoped bookmark so access outlives the launch.
public enum LocalMusicFolder {
    private static let key = "bitchord.localMusicFolder.bookmark"

    /// Whether a folder has been picked, whether or not it can still be reached.
    public static var isChosen: Bool { UserDefaults.standard.data(forKey: key) != nil }

    /// Remembers `url` (a folder returned by the system's picker).
    @discardableResult
    public static func choose(_ url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return false
        }
        UserDefaults.standard.set(data, forKey: key)
        return true
    }

    /// The folder, or nil when none was picked or the bookmark no longer resolves (the folder was
    /// deleted, or its provider was removed). A stale bookmark is renewed in place.
    public static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale { _ = choose(url) }
        return url
    }
}

/// What the last pass found, for tests and the log.
public struct LocalFolderSyncReport: Equatable, Sendable {
    public var added = 0
    public var updated = 0
    public var removed = 0
    public var isEmpty: Bool { added == 0 && updated == 0 && removed == 0 }
}

/// Keeps the library's imported tracks equal to the music in the chosen folder.
///
/// Each pass lists the folder (names, sizes, modification dates — no file is opened), compares the
/// listing with a manifest of what the last pass saw, and only then does work: a new file is
/// copied in and tagged, a changed one is replaced, a vanished one is removed. A pass that cannot
/// reach the folder changes nothing, so an unplugged drive or a signed-out provider never empties
/// the library.
@MainActor
public final class LocalFolderSync {
    public let library: DownloadLibrary

    /// How often the folder is listed while the app is running.
    public static let interval: Duration = .seconds(15)

    private struct Entry: Codable, Equatable {
        var size: Int64
        var modified: Double
        /// The id the file is filed under; nil for a file that is not music (too short, a voice
        /// memo folder), remembered so it is not read again until it changes.
        var videoId: String?
    }

    private struct Manifest: Codable {
        var folder: String = ""
        var files: [String: Entry] = [:]
    }

    struct Listed {
        var relativePath: String
        var url: URL
        var size: Int64
        var modified: Double
    }

    private static let manifestName = "local-folder.json"
    private var manifest = Manifest()
    private var loop: Task<Void, Never>?
    private var running = false
    private var again = false

    public init(library: DownloadLibrary) {
        self.library = library
        if let saved = try? library.store.records.load(Manifest.self, from: Self.manifestName) {
            manifest = saved
        }
    }

    /// Starts listing the folder now and every ``interval`` after. Safe to call again.
    public func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync()
                try? await Task.sleep(for: LocalFolderSync.interval)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    /// Picks `folder` as the Local Music folder and lists it at once. Choosing a different folder
    /// from the last one replaces the tracks the last one supplied.
    public func choose(_ folder: URL) {
        guard LocalMusicFolder.choose(folder) else { return }
        start()
        Task { await sync() }
    }

    /// One pass. Calls that arrive while one is running are folded into a single follow-up.
    @discardableResult
    public func sync() async -> LocalFolderSyncReport {
        guard !running else { again = true; return LocalFolderSyncReport() }
        running = true
        defer { running = false }
        var total = LocalFolderSyncReport()
        repeat {
            again = false
            let pass = await runPass()
            total.added += pass.added
            total.updated += pass.updated
            total.removed += pass.removed
        } while again && !Task.isCancelled
        return total
    }

    private func runPass() async -> LocalFolderSyncReport {
        var report = LocalFolderSyncReport()
        guard let folder = LocalMusicFolder.resolve() else { return report }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        guard let listing = await Task.detached(priority: .utility, operation: { Self.list(folder) }).value else {
            // Unreachable right now: leave everything as it is.
            return report
        }

        let folderKey = folder.standardizedFileURL.path(percentEncoded: false)
        if manifest.folder != folderKey {
            // A different folder from the one the library was built from.
            let stale = Set(manifest.files.values.compactMap(\.videoId))
            if !stale.isEmpty { removeTracks(stale) }
            report.removed += stale.count
            manifest = Manifest(folder: folderKey, files: [:])
        }

        var seen = Set<String>()
        var dirty = false
        let importer = LocalMusicImporter(library: library)
        var processed = 0

        for file in listing {
            if Task.isCancelled { break }
            seen.insert(file.relativePath)
            if let known = manifest.files[file.relativePath], known.size == file.size, known.modified == file.modified {
                continue
            }
            let previous = manifest.files[file.relativePath]
            if let old = previous?.videoId {
                // Replaced under the same name: the old track goes first so the new bytes aren't
                // taken for a duplicate of it.
                manifest.files[file.relativePath] = nil
                removeTracks(unreferenced([old]))
            }
            let id = await importer.importScannedFile(at: file.url)
            manifest.files[file.relativePath] = Entry(size: file.size, modified: file.modified, videoId: id)
            if id != nil { if previous?.videoId != nil { report.updated += 1 } else { report.added += 1 } }
            dirty = true
            processed += 1
            if processed % 10 == 0 { persist() }
        }

        // Only a pass that read the whole listing may conclude that a file is gone.
        if !Task.isCancelled {
            let gone = manifest.files.keys.filter { !seen.contains($0) }
            if !gone.isEmpty {
                let ids = gone.compactMap { manifest.files[$0]?.videoId }
                for path in gone { manifest.files[path] = nil }
                let removable = unreferenced(ids)
                removeTracks(removable)
                report.removed += removable.count
                dirty = true
            }
        }
        if dirty { persist() }
        return report
    }

    /// Of `ids`, those no remaining manifest entry still points at (two copies of one song in the
    /// folder share an id).
    private func unreferenced(_ ids: [String]) -> Set<String> {
        let live = Set(manifest.files.values.compactMap(\.videoId))
        return Set(ids).subtracting(live)
    }

    private func removeTracks(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            if let path = library.records[id]?.path {
                // The lyrics file that travelled with the copy.
                let audio = library.store.url(forRelativePath: path)
                try? FileManager.default.removeItem(at: audio.deletingPathExtension().appendingPathExtension("lrc"))
            }
        }
        library.delete(Array(ids))
    }

    private func persist() {
        do {
            try library.store.records.save(manifest, to: Self.manifestName)
        } catch {
            DebugLog.w("Downloads", "could not save the local folder manifest", error: error)
        }
    }

    /// Every playable audio file under `folder`, or nil if the folder itself can't be listed.
    /// Reads names and attributes only.
    nonisolated static func list(_ folder: URL) -> [Listed]? {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: folder.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        var failed = false
        guard let enumerator = manager.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in failed = true; return true }
        ) else { return nil }
        let base = folder.standardizedFileURL.path(percentEncoded: false)
        var files: [Listed] = []
        for case let url as URL in enumerator where LocalMediaFilter.isPlayableAudioFileName(url.lastPathComponent) {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            let full = url.standardizedFileURL.path(percentEncoded: false)
            let relative = full.hasPrefix(base) ? String(full.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) : full
            files.append(Listed(relativePath: relative, url: url, size: Int64(values.fileSize ?? 0),
                                modified: values.contentModificationDate?.timeIntervalSince1970 ?? 0))
        }
        // A listing cut short by an error must not be mistaken for a folder with fewer songs.
        return failed ? nil : files.sorted { $0.relativePath < $1.relativePath }
    }
}
