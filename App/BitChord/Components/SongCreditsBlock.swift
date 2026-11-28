import BitChordCore
import SwiftUI

/// The credit details Apple Music gives for a song, shown under the header of its menu.
struct SongCreditsBlock: View {
    let credits: SongCredits
    var album: String?
    var valueColor: Color = .primary
    var labelColor: Color = .secondary

    private struct Line: Identifiable {
        let id: String
        let value: String
    }

    private var lines: [Line] {
        var out: [Line] = []
        func add(_ label: String, _ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
            out.append(Line(id: label, value: value))
        }
        add("Written by", credits.composers)
        add("Album", album)
        add("Released", credits.releaseDate)
        add("Genre", credits.genres.isEmpty ? nil : credits.genres.joined(separator: ", "))
        add("Label", credits.recordLabel)
        add("Copyright", credits.copyright)
        add("ISRC", credits.isrc)
        add("Audio", credits.audioTraits.isEmpty ? nil : credits.audioTraits.joined(separator: ", "))
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines) { line in
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.id)
                        .font(.caption)
                        .foregroundStyle(labelColor)
                    Text(line.value)
                        .font(.footnote)
                        .foregroundStyle(valueColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
