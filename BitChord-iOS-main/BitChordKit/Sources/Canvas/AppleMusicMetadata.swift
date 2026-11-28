import BitChordCore
import Foundation

/// Apple Music's own metadata for the songs a search returns.
///
/// YouTube Music's search rows are matched against Apple's catalogue (title, artist, duration)
/// and, on a match, the row's title, artist, album, cover art, duration and explicit flag are
/// replaced by Apple's, and its credit details (``SongCredits``) are attached. The `videoId`
/// is never touched: it is what plays.
///
/// A song Apple does not list is dropped from the results rather than shown with YouTube's
/// details. The one exception is when Apple could not be asked at all (no token, offline, a
/// rejected request, out of time): those rows are kept as they came, because an empty search
/// would be worse than an unconverted one.
///
/// It uses the same anonymous web-player token as ``AppleMusicCanvas`` — unofficial, and it can
/// stop working if Apple changes the web player.
public final class AppleMusicMetadata: Sendable {
    public static let shared = AppleMusicMetadata()

    /// Rows asked about at once.
    static let batchSize = 5
    /// No new batch starts after this long; the remaining rows are kept unchanged.
    static let budget: TimeInterval = 8
    /// A row clears this on artist + fuzzy title when its runtime also agrees.
    static let minimumScore = 17
    /// Without a runtime to confirm it, a row must match the title exactly.
    static let minimumScoreWithoutRuntime = 25
    static let runtimeToleranceMillis = 6_000

    private let http: CanvasHTTP
    private let tokens: CanvasAppleTokenStore
    private let storefront: String
    private let cache = AppleMetadataCache()

    public init(
        session: URLSession = BitChordHTTP.session,
        tokens: CanvasAppleTokenStore? = nil,
        storefront: String? = nil
    ) {
        http = CanvasHTTP(session: session)
        self.tokens = tokens ?? CanvasAppleTokenStore(session: session)
        self.storefront = storefront ?? AppleMusicCanvas.deviceStorefront
    }

    // MARK: - Rows

    /// `rows` with every song replaced by Apple's version of it. Songs Apple has no match for
    /// are dropped when `dropUnmatched` is true. Albums, artists and playlists pass through.
    public func enrich(_ rows: [SearchResult], dropUnmatched: Bool = true) async -> [SearchResult] {
        var songs: [Song] = []
        var seenIds = Set<String>()
        for row in rows {
            switch row {
            case .topTrack(let song), .track(let song):
                if !song.isVideo, seenIds.insert(song.videoId).inserted { songs.append(song) }
            case .browse:
                break
            }
        }

        var matches: [String: AppleMatch] = [:]
        let started = Date()
        var index = 0
        while index < songs.count {
            if Date().timeIntervalSince(started) > Self.budget { break }
            let batch = Array(songs[index..<min(index + Self.batchSize, songs.count)])
            index += batch.count
            await withTaskGroup(of: (String, AppleMatch).self) { group in
                for song in batch {
                    group.addTask { (song.videoId, await self.lookup(song)) }
                }
                for await (id, match) in group { matches[id] = match }
            }
        }

        var out: [SearchResult] = []
        var seenIsrc = Set<String>()
        func resolved(_ song: Song) -> Song? {
            if song.isVideo { return song }
            switch matches[song.videoId] {
            case .matched(let details):
                // Two uploads of one recording would now read identically; keep the first.
                if let isrc = details.credits.isrc, !isrc.isEmpty, !seenIsrc.insert(isrc).inserted {
                    return nil
                }
                return Self.apply(details, to: song)
            case .noMatch:
                return dropUnmatched ? nil : song
            case .unavailable, .none:
                return song
            }
        }
        for row in rows {
            switch row {
            case .topTrack(let song):
                if let song = resolved(song) { out.append(.topTrack(song)) }
            case .track(let song):
                if let song = resolved(song) { out.append(.track(song)) }
            case .browse:
                out.append(row)
            }
        }
        return out
    }

    /// What asking Apple about one song came to.
    public enum Outcome: Sendable {
        /// The song with Apple's title, artist, album, cover, explicit flag and credits.
        case matched(Song)
        /// Apple answered and does not list it.
        case noMatch
        /// Apple could not be asked just now (no token, offline, rejected); try again later.
        case unavailable
    }

    /// One song, matched against Apple's catalogue. The id is never touched.
    public func outcome(for song: Song) async -> Outcome {
        if song.isVideo { return .noMatch }
        switch await lookup(song) {
        case .matched(let details): return .matched(Self.apply(details, to: song))
        case .noMatch: return .noMatch
        case .unavailable: return .unavailable
        }
    }

    static func apply(_ details: AppleDetails, to song: Song) -> Song {
        var out = song
        out.title = details.title
        out.artist = details.artist
        out.albumName = details.album
        if let artwork = details.artworkUrl { out.thumbnailUrl = artwork }
        if let millis = details.durationMillis, millis > 0 {
            out.durationText = DurationText.format(millis: millis)
        }
        out.isExplicit = details.isExplicit
        out.credits = details.credits
        return out
    }

    // MARK: - One song

    private func lookup(_ song: Song) async -> AppleMatch {
        if let cached = await cache.get(song.videoId) { return cached }
        guard let bearer = await tokens.token() else { return .unavailable }

        var term = ""
        if !song.title.localizedCaseInsensitiveContains(song.artist) { term += song.artist + " " }
        term += song.title

        guard let url = CanvasURL.make(AppleMusicCanvas.catalog + "/\(storefront)/search", [
            ("term", term), ("types", "songs"), ("limit", "10"), ("include", "albums"),
        ]) else { return .unavailable }

        let (status, body) = await fetch(url, bearer: bearer)
        if status == 401 {
            await tokens.noteRejection(bearer)
            return .unavailable
        }
        guard status == 200, let body,
              let results = CanvasJSON.parse(body)?.object?["results"]?.object
        else { return .unavailable }

        let hits = results["songs"]?.object?["data"]?.array?.compactMap { $0.object } ?? []
        let needed = song.durationMillis > 0 ? Self.minimumScore : Self.minimumScoreWithoutRuntime

        var candidate: (score: Int, hit: [String: CanvasJSON])?
        for hit in hits {
            guard let score = AppleMusicCanvas.score(hit, title: song.title, artist: song.artist, album: song.albumName),
                  score >= needed,
                  Self.runtimeAgrees(hit, song: song)
            else { continue }
            if let current = candidate, current.score >= score { continue }
            candidate = (score, hit)
        }

        guard let best = candidate, var details = Self.details(from: best.hit) else {
            await cache.put(song.videoId, .noMatch)
            return .noMatch
        }

        // The album's own record carries the label and the ℗ line. Search only sometimes
        // expands it, so ask for it when it didn't come.
        if details.credits.recordLabel == nil, let albumId = AppleMusicCanvas.albumID(best.hit),
           let albumURL = CanvasURL.make(AppleMusicCanvas.catalog + "/\(storefront)/albums/\(albumId)", [])
        {
            let (albumStatus, albumBody) = await fetch(albumURL, bearer: bearer)
            if albumStatus == 200, let albumBody,
               let album = CanvasJSON.parse(albumBody)?.object?["data"]?.array?.first?.object?["attributes"]?.object
            {
                details.credits.recordLabel = album["recordLabel"]?.string
                details.credits.copyright = album["copyright"]?.string
            }
        }

        let match = AppleMatch.matched(details)
        await cache.put(song.videoId, match)
        return match
    }

    /// One GET, retried once after a short pause when Apple is busy (429), failing (5xx) or the
    /// connection dropped (-1).
    private func fetch(_ url: URL, bearer: String) async -> (Int, String?) {
        let headers = AppleMusicCanvas.authHeaders(bearer: bearer)
        var attempt = await http.getWithStatus(url, headers: headers)
        if attempt.0 == 429 || attempt.0 >= 500 || attempt.0 == -1 {
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return attempt }
            attempt = await http.getWithStatus(url, headers: headers)
        }
        return attempt
    }

    static func runtimeAgrees(_ hit: [String: CanvasJSON], song: Song) -> Bool {
        let wanted = song.durationMillis
        guard wanted > 0,
              let millis = hit["attributes"]?.object?["durationInMillis"]?.double
        else { return true }
        return abs(Int(millis) - wanted) <= runtimeToleranceMillis
    }

    static func details(from hit: [String: CanvasJSON]) -> AppleDetails? {
        let attributes = hit["attributes"]?.object ?? [:]
        guard let title = attributes["name"]?.string, !title.isEmpty,
              let artist = attributes["artistName"]?.string, !artist.isEmpty
        else { return nil }

        // With `include=albums` the album arrives expanded under the song's relationships.
        let albumAttributes = hit["relationships"]?.object?["albums"]?.object?["data"]?.array?
            .first?.object?["attributes"]?.object ?? [:]

        let genres = (attributes["genreNames"]?.array ?? [])
            .compactMap { $0.string }
            .filter { $0 != "Music" }
        let traits = (attributes["audioTraits"]?.array ?? []).compactMap { $0.string }

        let credits = SongCredits(
            composers: attributes["composerName"]?.string,
            isrc: attributes["isrc"]?.string,
            recordLabel: albumAttributes["recordLabel"]?.string,
            copyright: albumAttributes["copyright"]?.string,
            releaseDate: attributes["releaseDate"]?.string,
            genres: genres,
            appleMusicUrl: attributes["url"]?.string,
            audioTraits: traits)

        return AppleDetails(
            title: title,
            artist: artist,
            album: attributes["albumName"]?.string,
            artworkUrl: artworkURL(attributes["artwork"]?.object),
            durationMillis: attributes["durationInMillis"]?.double.map { Int($0) },
            isExplicit: attributes["contentRating"]?.string == "explicit",
            credits: credits)
    }

    /// Apple sends a template (`…/{w}x{h}bb.jpg`). Filled in large; `Artwork.resized` scales it
    /// down to whatever a surface actually draws.
    static func artworkURL(_ artwork: [String: CanvasJSON]?) -> String? {
        guard let template = artwork?["url"]?.string, !template.isEmpty else { return nil }
        return template
            .replacingOccurrences(of: "{w}", with: "1200")
            .replacingOccurrences(of: "{h}", with: "1200")
    }
}

struct AppleDetails: Sendable {
    var title: String
    var artist: String
    var album: String?
    var artworkUrl: String?
    var durationMillis: Int?
    var isExplicit: Bool
    var credits: SongCredits
}

enum AppleMatch: Sendable {
    case matched(AppleDetails)
    /// Apple answered and has no such song.
    case noMatch
    /// Apple could not be asked (or did not answer in time); the row stays as it was.
    case unavailable
}

/// What Apple said about a row, per video id, so scrolling back or searching again doesn't ask
/// twice. Only definite answers are kept, and a "no match" expires after a few minutes so one
/// odd answer can't hide a song for the rest of the session.
actor AppleMetadataCache {
    private struct Entry {
        let match: AppleMatch
        let at: Date
    }

    private var entries: [String: Entry] = [:]
    private var order: [String] = []
    private let capacity = 800
    private let noMatchLifetime: TimeInterval = 5 * 60

    func get(_ key: String) -> AppleMatch? {
        guard let entry = entries[key] else { return nil }
        if case .noMatch = entry.match, Date().timeIntervalSince(entry.at) > noMatchLifetime {
            entries[key] = nil
            order.removeAll { $0 == key }
            return nil
        }
        return entry.match
    }

    func put(_ key: String, _ value: AppleMatch) {
        if entries[key] == nil { order.append(key) }
        entries[key] = Entry(match: value, at: Date())
        if order.count > capacity {
            let oldest = order.removeFirst()
            entries[oldest] = nil
        }
    }
}
