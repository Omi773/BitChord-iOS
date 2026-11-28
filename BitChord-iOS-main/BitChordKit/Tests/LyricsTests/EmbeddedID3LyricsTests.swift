import XCTest
@testable import Lyrics

/// MP3 files keep their lyrics in an ID3v2 tag; the reader has to find them there.
final class EmbeddedID3LyricsTests: XCTestCase {
    private let lrc = "[00:01.00]first line\n[00:05.00]second line"

    /// An ID3v2.3 tag around `frames`, with a few bytes of audio after it.
    private func tag(_ frames: [UInt8]) -> Data {
        let size = frames.count
        let syncsafe: [UInt8] = [
            UInt8((size >> 21) & 0x7F), UInt8((size >> 14) & 0x7F), UInt8((size >> 7) & 0x7F), UInt8(size & 0x7F),
        ]
        return Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00] + syncsafe + frames + [0xFF, 0xFB, 0x90, 0x00])
    }

    private func frame(_ id: String, _ payload: [UInt8]) -> [UInt8] {
        let size = payload.count
        let sizeBytes: [UInt8] = [UInt8((size >> 24) & 0xFF), UInt8((size >> 16) & 0xFF), UInt8((size >> 8) & 0xFF), UInt8(size & 0xFF)]
        return Array(id.utf8) + sizeBytes + [0x00, 0x00] + payload
    }

    func testAnUnsynchronisedFrameHoldingLRCReadsBack() {
        // encoding 3 (UTF-8), language "eng", empty description, then the text.
        let payload: [UInt8] = [0x03] + Array("eng".utf8) + [0x00] + Array(lrc.utf8)
        let data = tag(frame("USLT", payload))
        XCTAssertEqual(EmbeddedLyrics.fromBytes(data), lrc)
    }

    func testASynchronisedFrameBecomesLRC() {
        func entry(_ text: String, _ ms: Int) -> [UInt8] {
            Array(text.utf8) + [0x00] + [UInt8((ms >> 24) & 0xFF), UInt8((ms >> 16) & 0xFF), UInt8((ms >> 8) & 0xFF), UInt8(ms & 0xFF)]
        }
        // encoding 3, "eng", milliseconds, content type 1 (lyrics), empty description.
        let payload: [UInt8] = [0x03] + Array("eng".utf8) + [0x02, 0x01, 0x00]
            + entry("first line", 1_000) + entry("second line", 5_000)
        let data = tag(frame("SYLT", payload))
        XCTAssertEqual(EmbeddedLyrics.fromBytes(data), "[00:01.00]first line\n[00:05.00]second line")
    }

    func testTheSynchronisedFrameWinsOverThePlainOne() {
        func entry(_ text: String, _ ms: Int) -> [UInt8] {
            Array(text.utf8) + [0x00] + [0x00, 0x00, UInt8((ms >> 8) & 0xFF), UInt8(ms & 0xFF)]
        }
        let plain: [UInt8] = [0x03] + Array("eng".utf8) + [0x00] + Array("[00:09.00]plain".utf8)
        let synced: [UInt8] = [0x03] + Array("eng".utf8) + [0x02, 0x01, 0x00] + entry("synced", 2_000)
        let data = tag(frame("USLT", plain) + frame("SYLT", synced))
        XCTAssertEqual(EmbeddedLyrics.fromBytes(data), "[00:02.00]synced")
    }

    func testATagWithNoLyricsIsNil() {
        let title: [UInt8] = [0x03] + Array("A song".utf8)
        XCTAssertNil(EmbeddedLyrics.fromBytes(tag(frame("TIT2", title))))
    }
}
