import Foundation

/// The credit details Apple Music publishes for a recording. Carried on ``Song/credits`` once a
/// search row has been matched against Apple's catalogue (see `AppleMusicMetadata`).
///
/// Apple's public catalogue states the writers ("composer name"), not producers or engineers, so
/// those are not here.
public struct SongCredits: Codable, Hashable, Sendable {
    /// Songwriters, as Apple bills them ("A, B & C").
    public var composers: String?
    public var isrc: String?
    public var recordLabel: String?
    /// The ℗ / © line of the release.
    public var copyright: String?
    /// `YYYY-MM-DD` as Apple sends it.
    public var releaseDate: String?
    public var genres: [String]
    /// The song's page on music.apple.com.
    public var appleMusicUrl: String?
    /// Apple's audio traits for the track, e.g. `lossless`, `atmos`.
    public var audioTraits: [String]

    public init(
        composers: String? = nil,
        isrc: String? = nil,
        recordLabel: String? = nil,
        copyright: String? = nil,
        releaseDate: String? = nil,
        genres: [String] = [],
        appleMusicUrl: String? = nil,
        audioTraits: [String] = []
    ) {
        self.composers = composers
        self.isrc = isrc
        self.recordLabel = recordLabel
        self.copyright = copyright
        self.releaseDate = releaseDate
        self.genres = genres
        self.appleMusicUrl = appleMusicUrl
        self.audioTraits = audioTraits
    }

    /// True when there is nothing worth showing.
    public var isEmpty: Bool {
        func blank(_ value: String?) -> Bool {
            value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        }
        return blank(composers) && blank(isrc) && blank(recordLabel) && blank(copyright)
            && blank(releaseDate) && genres.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case composers, isrc, recordLabel, copyright, releaseDate, genres, appleMusicUrl, audioTraits
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        composers = try c.decodeIfPresent(String.self, forKey: .composers)
        isrc = try c.decodeIfPresent(String.self, forKey: .isrc)
        recordLabel = try c.decodeIfPresent(String.self, forKey: .recordLabel)
        copyright = try c.decodeIfPresent(String.self, forKey: .copyright)
        releaseDate = try c.decodeIfPresent(String.self, forKey: .releaseDate)
        genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        appleMusicUrl = try c.decodeIfPresent(String.self, forKey: .appleMusicUrl)
        audioTraits = try c.decodeIfPresent([String].self, forKey: .audioTraits) ?? []
    }
}
