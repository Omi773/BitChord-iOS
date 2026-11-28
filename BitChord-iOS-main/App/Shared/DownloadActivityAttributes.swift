import ActivityKit
import Foundation

/// The Live Activity for songs being downloaded: on the Lock Screen and in the Dynamic Island while
/// the queue has work, then a short "done" before it goes. Compiled into the app (which starts and
/// updates it) and the widget extension (which draws it).
struct DownloadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The track being downloaded now.
        var title: String
        var artist: String
        /// Tracks finished, and in the batch, counting those that failed as settled.
        var finished: Int
        var total: Int
        var failed: Int
        /// How far through the whole batch, 0...1.
        var fraction: Double
        /// The queue has emptied; the card says so and then goes.
        var isDone: Bool
    }
}
