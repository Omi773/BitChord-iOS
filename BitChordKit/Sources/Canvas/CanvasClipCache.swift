import CryptoKit
import BitChordCore
import Foundation

/// Disk cache for canvas clips — the looping video some releases publish alongside a track,
/// played over the cover art in a looping `AVPlayerLayer` (Android: `CanvasCache` in
/// `data/canvas/CanvasCache.kt`).
///
/// Why a cache at all: a five-second clip behind a four-minute track loops around fifty
/// times, and without a cache every loop re-downloads the same few seconds of video — the
/// "40MB for one song" reports trace to exactly this repeat, not to audio bitrate. Serving
/// the clip from disk after the first loop ends that.
///
/// iOS difference: Android wraps ExoPlayer's data source so the player itself reads through
/// the cache. `AVPlayer` has no such hook, so this cache sits one level up: `localFile(for:)`
/// answers the on-disk copy when there is one, and `fetchClip(from:)` downloads through
/// `URLSession` (a plain progressive MP4) before handing the local file to the player.
///
/// For the player, progressive clips are cached as they are. Apple serves HLS playlists, which
/// are a directory of segments rather than one file — `fetchClip` hands those straight to
/// `AVPlayer` unless they were already joined into one local file, which `fetchLocalClip` does
/// (the lock screen takes only a file) and which then plays from disk like the rest.
///
/// Offline: the cache also remembers which clip belongs to which track (`remember(_:forTrack:)`),
/// because the lookup that finds a track's clip needs the network and the clip files alone
/// don't say whose they are. With that record a track's clip plays with no connection at all.
/// What is used least is dropped first: a read marks a clip recently used, and the oldest go
/// once the total passes the limit.
public final class CanvasClipCache: Sendable {
    /// Small on purpose — a clip is a few seconds of video, not a song, and this only needs
    /// to outlive one player screen's worth of looping, not a library.
    public static let defaultLimitBytes: Int64 = 150 * 1024 * 1024

    /// The record of which clip belongs to which track, kept in the clips' own folder so a wipe
    /// of the folder takes both. Never counted as a clip, never evicted as one.
    static let savedTracksFileName = "saved-tracks.json"
    /// Tracks remembered at most; past it, tracks whose clip is gone go first, then the oldest.
    static let savedTrackLimit = 300

    private let directory: URL
    private let limitBytes: Int64
    private let lock = NSLock()

    /// - Parameters:
    ///   - directory: where clips live; created on init. The app passes a
    ///     `caches/com.music.bitchord/canvas` folder (excluded from backup and purged by the
    ///     system under pressure, which is exactly the semantics wanted here).
    ///   - limitBytes: eviction target; the oldest clips go once the total passes it.
    public init(directory: URL, limitBytes: Int64 = defaultLimitBytes) {
        self.directory = directory
        self.limitBytes = limitBytes
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// The on-disk copy of `remoteURL`'s clip, or nil when it isn't cached yet.
    public func localFile(for remoteURL: URL) -> URL? {
        let file = fileURL(for: remoteURL)
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return nil }
        // A hit is a use: keep the clip being looped out of the next eviction.
        try? FileManager.default.setAttributes([.modificationDate: Date()],
                                               ofItemAtPath: file.path(percentEncoded: false))
        return file
    }

    /// Whether `remoteURL`'s clip is already on disk.
    public func contains(_ remoteURL: URL) -> Bool {
        localFile(for: remoteURL) != nil
    }

    /// Stores `data` as `remoteURL`'s clip. A write that fails (full disk, evicted mid-write)
    /// is swallowed: callers fall back to streaming the remote URL rather than surfacing a
    /// playback error.
    @discardableResult
    public func store(_ data: Data, for remoteURL: URL) -> URL? {
        let file = fileURL(for: remoteURL)
        do {
            try data.write(to: file, options: .atomic)
            evictIfNeeded()
            return file
        } catch {
            try? FileManager.default.removeItem(at: file)
            return nil
        }
    }

    /// The clip for `artwork`, ready to mount: the on-disk copy for progressive MP4 (fetching
    /// it first when missing), or the remote URL itself for HLS. Never throws — on any
    /// failure the remote URL comes back and the player streams it.
    public func fetchClip(
        for artwork: CanvasArtwork, session: URLSession = BitChordHTTP.session
    ) async -> URL {
        let candidates = artwork.playbackURLs
        guard let primary = candidates.first else {
            return URL(string: "about:blank")!
        }
        if primary.isCanvasHLS {
            // Joined into one local file before (see `fetchLocalClip`): plays from disk, so it
            // plays with no connection too. Otherwise the stream, as always.
            return localFile(for: primary.appendingPathExtension("mp4")) ?? primary
        }
        if let cached = localFile(for: primary) { return cached }
        do {
            let (data, response) = try await session.data(from: primary)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if status / 100 == 2, !data.isEmpty, let stored = store(data, for: primary) {
                return stored
            }
        } catch {
            // Fall through to streaming the remote URL.
        }
        return primary
    }

    /// The clip for `artwork` as a local file, for a caller that can't take a stream (the lock
    /// screen's animated artwork), or nil when it can't be had. Progressive MP4 goes
    /// through ``fetchClip(for:session:)``; HLS is joined into one fragmented MP4 by
    /// ``HLSClipAssembler`` and kept under the playlist URL plus `.mp4`, so it loops from disk
    /// like the rest and never collides with the stream the player screen mounts.
    public func fetchLocalClip(
        for artwork: CanvasArtwork, session: URLSession = BitChordHTTP.session
    ) async -> URL? {
        // The fallback rendition gets its turn when the primary can't be had, as on the player.
        for url in artwork.playbackURLs where !Task.isCancelled {
            if url.isCanvasHLS {
                let key = url.appendingPathExtension("mp4")
                if let cached = localFile(for: key) { return cached }
                if let data = await HLSClipAssembler.assemble(master: url, session: session),
                   let stored = store(data, for: key) { return stored }
            } else {
                let served = await fetchClip(for: CanvasArtwork(url: url.absoluteString), session: session)
                if served.isFileURL { return served }
            }
        }
        return nil
    }

    /// What ``fetchLocalClip(for:session:)`` would answer without asking the network: nil until the
    /// clip is on disk.
    public func cachedLocalClip(for artwork: CanvasArtwork) -> URL? {
        for url in artwork.playbackURLs {
            if let cached = localFile(for: url.isCanvasHLS ? url.appendingPathExtension("mp4") : url) { return cached }
        }
        return nil
    }

    /// Remembers that `artwork` is the clip for the track `key` names, so the clip can be found
    /// again with no network. The clip's file arrives when the player or the lock screen
    /// fetches it; `remembered(forTrack:)` only answers once it is on disk.
    public func remember(_ artwork: CanvasArtwork, forTrack key: String) {
        guard !key.isEmpty else { return }
        lock.withLock {
            var saved = readSavedTracks()
            if let at = saved.firstIndex(where: { $0.key == key }) {
                if saved[at].artwork == artwork { return }
                saved.remove(at: at)
            }
            saved.append(SavedTrack(key: key, artwork: artwork))
            if saved.count > Self.savedTrackLimit {
                saved.removeAll { !hasPrimaryClipOnDisk($0.artwork) && $0.key != key }
                if saved.count > Self.savedTrackLimit {
                    saved.removeFirst(saved.count - Self.savedTrackLimit)
                }
            }
            writeSavedTracks(saved)
        }
    }

    /// The clip remembered for the track `key` names, only while its file is still on disk: a
    /// clip that was dropped to make room (or never finished downloading) answers nil. Asking is
    /// a use, so a track played offline keeps its clip out of the next eviction.
    public func remembered(forTrack key: String) -> CanvasArtwork? {
        guard !key.isEmpty else { return nil }
        let saved = lock.withLock { readSavedTracks() }
        guard let artwork = saved.first(where: { $0.key == key })?.artwork,
              let primary = artwork.playbackURLs.first,
              localFile(for: primary.isCanvasHLS ? primary.appendingPathExtension("mp4") : primary) != nil
        else { return nil }
        return artwork
    }

    /// Settles a track's canvas lookup against what is kept on disk. A clip found is remembered
    /// for the track; with nothing found (no connection, or the services have none), the clip
    /// remembered earlier answers instead, if its file is still here and it still answers to
    /// what is playing. A file with no catalogue identity, or no title or artist, passes as is.
    public func keeping(_ found: CanvasArtwork?, for song: Song) -> CanvasArtwork? {
        if song.videoId.isBlankForCanvas, song.localUri != nil || song.localPath != nil { return found }
        let title = CanvasText.cleanedTrackText(song.title)
        let artist = CanvasText.cleanedTrackText(song.artist)
        if title.isBlankForCanvas || artist.isBlankForCanvas { return found }
        let key = "\(title.normalizedForCanvasMatch)|\(artist.normalizedForCanvasMatch)"
        if let found {
            remember(found, forTrack: key)
            return found
        }
        guard let saved = remembered(forTrack: key),
              saved.matches(title: title, artist: artist, album: song.albumName) else { return nil }
        return saved
    }

    /// Drops every cached clip, and the record of whose they were.
    public func clear() {
        lock.withLock {
            for name in fileNames() {
                try? FileManager.default.removeItem(at: directory.appending(path: name))
            }
            try? FileManager.default.removeItem(at: savedTracksFile)
        }
    }

    /// Bytes currently on disk.
    public var currentBytes: Int64 {
        lock.withLock { totalBytes() }
    }

    // MARK: - Internals

    func fileURL(for remoteURL: URL) -> URL {
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        let suffix = remoteURL.pathExtension.lowercased() == "mp4" ? "mp4" : "clip"
        return directory.appending(path: "\(name).\(suffix)")
    }

    private func fileNames() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
        return names.filter { $0 != Self.savedTracksFileName }
    }

    private struct SavedTrack: Codable {
        var key: String
        var artwork: CanvasArtwork
    }

    private var savedTracksFile: URL {
        directory.appending(path: Self.savedTracksFileName)
    }

    private func readSavedTracks() -> [SavedTrack] {
        guard let data = try? Data(contentsOf: savedTracksFile),
              let saved = try? JSONDecoder().decode([SavedTrack].self, from: data)
        else { return [] }
        return saved
    }

    private func writeSavedTracks(_ saved: [SavedTrack]) {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: savedTracksFile, options: .atomic)
    }

    /// Whether the primary clip's file exists, without counting as a use.
    private func hasPrimaryClipOnDisk(_ artwork: CanvasArtwork) -> Bool {
        guard let primary = artwork.playbackURLs.first else { return false }
        let file = fileURL(for: primary.isCanvasHLS ? primary.appendingPathExtension("mp4") : primary)
        return FileManager.default.fileExists(atPath: file.path(percentEncoded: false))
    }

    private func fileSize(_ url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(
            atPath: url.path(percentEncoded: false)),
            let size = attributes[.size] as? NSNumber
        else { return 0 }
        return size.int64Value
    }

    private func totalBytes() -> Int64 {
        fileNames().reduce(0) { total, name in
            total + fileSize(directory.appending(path: name))
        }
    }

    private func evictIfNeeded() {
        lock.withLock {
            guard totalBytes() > limitBytes else { return }
            let files = fileNames().map { directory.appending(path: $0) }
            let byAge = files.sorted {
                modificationDate($0) ?? .distantPast < modificationDate($1) ?? .distantPast
            }
            var total = totalBytes()
            for file in byAge {
                if total <= limitBytes { break }
                let size = fileSize(file)
                if (try? FileManager.default.removeItem(at: file)) != nil { total -= size }
            }
        }
    }

    private func modificationDate(_ url: URL) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(
            atPath: url.path(percentEncoded: false))
        else { return nil }
        return attributes[.modificationDate] as? Date
    }
}

private extension URL {
    var isCanvasHLS: Bool {
        absoluteString.lowercased().contains(".m3u8")
    }
}
