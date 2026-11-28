import Foundation

/// The lyrics inside an MP3's ID3v2 tag, as the LRC text the rest of ``EmbeddedLyrics`` returns.
///
/// Three frames are read, best first:
///  - `TXXX` named `BITCHORD_LYRICS` (this app's own, with word timings);
///  - `SYLT`, the synchronised lyrics frame, turned into `[mm:ss.xx]` lines;
///  - `USLT`, the unsynchronised frame, which only helps when the writer put LRC in it (a
///    plain-text one has no stamps, parses to nothing and leaves the lookup to the network).
///
/// ID3v2.2, 2.3 and 2.4 are understood. Never throws; anything unreadable is nil.
enum EmbeddedID3Lyrics {

    static func isID3(_ bytes: [UInt8]) -> Bool {
        bytes.count >= 10 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33
    }

    static func lrc(from bytes: [UInt8]) -> String? {
        guard isID3(bytes) else { return nil }
        let major = Int(bytes[3])
        guard (2...4).contains(major) else { return nil }
        let flags = bytes[5]
        guard let tagSize = syncsafe(bytes, 6) else { return nil }
        let end = min(10 + tagSize, bytes.count)
        guard end > 10 else { return nil }
        var body = Array(bytes[10..<end])
        if flags & 0x80 != 0 { body = deunsynchronised(body) }

        var position = 0
        if flags & 0x40 != 0, major >= 3 {
            guard body.count >= 4 else { return nil }
            position = major == 4 ? (syncsafe(body, 0) ?? 0) : (plain32(body, 0) + 4)
        }

        let idLength = major == 2 ? 3 : 4
        let headerLength = major == 2 ? 6 : 10
        var word: String?
        var synced: String?
        var plain: String?

        while position + headerLength <= body.count {
            // Padding: the frames are over.
            if body[position] == 0 { break }
            let id = String(decoding: body[position..<(position + idLength)], as: UTF8.self)
            let size: Int
            if major == 2 {
                size = Int(body[position + 3]) << 16 | Int(body[position + 4]) << 8 | Int(body[position + 5])
            } else if major == 4 {
                guard let value = syncsafe(body, position + 4) else { break }
                size = value
            } else {
                size = plain32(body, position + 4)
            }
            let flagByte: UInt8 = major == 2 ? 0 : body[position + 9]
            let start = position + headerLength
            guard size >= 0, start + size <= body.count else { break }
            position = start + size
            var data = Array(body[start..<(start + size)])

            if major == 3 {
                // 0x80 compressed, 0x40 encrypted, 0x20 carries a grouping byte.
                if flagByte & 0xC0 != 0 { continue }
                if flagByte & 0x20 != 0, !data.isEmpty { data.removeFirst() }
            } else if major == 4 {
                // 0x08 compressed, 0x04 encrypted, 0x40 grouping byte, 0x01 length indicator,
                // 0x02 unsynchronised.
                if flagByte & 0x0C != 0 { continue }
                if flagByte & 0x40 != 0, !data.isEmpty { data.removeFirst() }
                if flagByte & 0x01 != 0 {
                    guard data.count >= 4 else { continue }
                    data.removeFirst(4)
                }
                if flagByte & 0x02 != 0 { data = deunsynchronised(data) }
            }

            switch id {
            case "TXXX", "TXX":
                if word == nil, let text = describedText(data, valueOffset: 1),
                   text.description.uppercased() == LRCFormat.wordLyricsField, !isBlank(text.value) {
                    word = text.value
                }
            case "SYLT", "SLT":
                if synced == nil { synced = syncedLRC(data) }
            case "USLT", "ULT":
                if plain == nil, let text = describedText(data, valueOffset: 4), !isBlank(text.value) {
                    plain = text.value
                }
            default:
                break
            }
        }
        return word ?? synced ?? plain
    }

    // MARK: Frames

    /// `encoding(1) [language(3)] description\0 value`: the layout `TXXX` and `USLT` share, with
    /// `valueOffset` the byte where the description starts (1 for `TXXX`, 4 for `USLT`).
    private static func describedText(_ data: [UInt8], valueOffset: Int) -> (description: String, value: String)? {
        guard data.count > valueOffset else { return nil }
        let encoding = data[0]
        guard let stop = terminator(in: data, from: valueOffset, encoding: encoding) else { return nil }
        let description = decode(data[valueOffset..<stop.index], encoding: encoding)
        let rest = stop.index + stop.width
        guard rest <= data.count else { return nil }
        var value = decode(data[rest...], encoding: encoding)
        while value.last == "\0" { value.removeLast() }
        return (description, value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
    }

    /// A `SYLT` frame as LRC. Only millisecond stamps (format 2) and lyrics content (0 or 1) are
    /// taken; a frame stamped in MPEG frames can't be placed on the timeline without the audio.
    private static func syncedLRC(_ data: [UInt8]) -> String? {
        guard data.count > 6 else { return nil }
        let encoding = data[0]
        let stampFormat = data[4]
        let contentType = data[5]
        guard stampFormat == 2, contentType == 0 || contentType == 1 else { return nil }
        guard let descriptor = terminator(in: data, from: 6, encoding: encoding) else { return nil }
        var position = descriptor.index + descriptor.width

        var entries: [(timeMs: Int, text: String)] = []
        while position < data.count {
            guard let stop = terminator(in: data, from: position, encoding: encoding),
                  stop.index + stop.width + 4 <= data.count else { break }
            let text = decode(data[position..<stop.index], encoding: encoding)
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            let at = stop.index + stop.width
            let time = Int(data[at]) << 24 | Int(data[at + 1]) << 16 | Int(data[at + 2]) << 8 | Int(data[at + 3])
            entries.append((time, text))
            position = at + 4
        }
        guard !entries.isEmpty else { return nil }

        // A new line is marked by a newline at the start of an entry. When no entry does that,
        // the writer put one line in each entry.
        let groupsByNewline = entries.contains { $0.text.hasPrefix("\n") }
        var lines: [(timeMs: Int, text: String)] = []
        if groupsByNewline {
            for entry in entries {
                if entry.text.hasPrefix("\n") || lines.isEmpty {
                    lines.append((entry.timeMs, entry.text))
                } else {
                    lines[lines.count - 1].text += entry.text
                }
            }
        } else {
            lines = entries
        }
        let rendered = lines.map { line in
            "[\(stamp(line.timeMs))]" + line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return rendered.joined(separator: "\n")
    }

    private static func stamp(_ ms: Int) -> String {
        let centiseconds = (ms % 1_000) / 10
        let seconds = (ms / 1_000) % 60
        let minutes = ms / 60_000
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    // MARK: Text

    /// Where the string that starts at `start` ends: one zero byte for ISO-8859-1 and UTF-8,
    /// two aligned zero bytes for the UTF-16 encodings.
    private static func terminator(in data: [UInt8], from start: Int, encoding: UInt8) -> (index: Int, width: Int)? {
        var i = start
        if encoding == 1 || encoding == 2 {
            while i + 1 < data.count {
                if data[i] == 0 && data[i + 1] == 0 { return (i, 2) }
                i += 2
            }
            return nil
        }
        while i < data.count {
            if data[i] == 0 { return (i, 1) }
            i += 1
        }
        return nil
    }

    private static func decode(_ bytes: ArraySlice<UInt8>, encoding: UInt8) -> String {
        let data = Data(bytes)
        switch encoding {
        case 0:
            return String(data: data, encoding: .isoLatin1) ?? ""
        case 1:
            return String(data: data, encoding: .utf16) ?? String(data: data, encoding: .utf16LittleEndian) ?? ""
        case 2:
            return String(data: data, encoding: .utf16BigEndian) ?? ""
        default:
            return String(decoding: data, as: UTF8.self)
        }
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Bytes

    /// Four bytes of seven bits each; nil if any byte uses the eighth.
    private static func syncsafe(_ bytes: [UInt8], _ offset: Int) -> Int? {
        guard offset + 4 <= bytes.count else { return nil }
        var value = 0
        for i in 0..<4 {
            let byte = bytes[offset + i]
            if byte & 0x80 != 0 { return nil }
            value = value << 7 | Int(byte)
        }
        return value
    }

    private static func plain32(_ bytes: [UInt8], _ offset: Int) -> Int {
        guard offset + 4 <= bytes.count else { return 0 }
        return Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
    }

    /// Undoes unsynchronisation: a zero byte that follows `0xFF` was inserted by the writer.
    private static func deunsynchronised(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            out.append(bytes[i])
            if bytes[i] == 0xFF, i + 1 < bytes.count, bytes[i + 1] == 0 { i += 2 } else { i += 1 }
        }
        return out
    }
}
