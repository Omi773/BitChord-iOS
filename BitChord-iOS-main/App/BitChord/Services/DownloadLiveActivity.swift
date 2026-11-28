import ActivityKit
import BitChordCore
import Downloads
import Foundation

/// Keeps one Live Activity in step with the download queue: started when the first track is asked
/// for, updated as tracks finish, and ended a few seconds after the queue goes quiet.
///
/// Best effort throughout. The system may refuse (Live Activities switched off for the app, too many
/// running), and a download never depends on its card.
@MainActor
final class DownloadLiveActivity {
    /// What the card shows, as an `Equatable` so a tick that changes nothing visible is skipped.
    private struct Snapshot: Equatable {
        var title: String
        var artist: String
        var finished: Int
        var total: Int
        var failed: Int
        /// In 2% steps: a Live Activity is rate-limited by the system, and a finer bar is not visible.
        var step: Int
        var busy: Bool
    }

    private var tracker: ChangeTracker?
    private var activity: Activity<DownloadActivityAttributes>?
    private var updates: Task<Void, Never>?

    /// Follows `session` from now on.
    func follow(session: DownloadSession) {
        tracker?.cancel()
        tracker = ChangeTracker.track({ Self.snapshot(of: session.state) }) { [weak self] snapshot in
            self?.apply(snapshot)
        }
    }

    private static func snapshot(of state: DownloadSession.State) -> Snapshot {
        let current = state.items.first { item in
            if case .running = item.progress { return true }
            return false
        } ?? state.items.first { !$0.progress.settled } ?? state.items.last
        return Snapshot(
            title: current?.song.title ?? "",
            artist: current?.song.artist ?? "",
            finished: state.items.count { $0.progress.settled },
            total: state.items.count,
            failed: state.failed,
            step: Int((state.fraction * 50).rounded(.down)),
            busy: state.busy)
    }

    private func apply(_ snapshot: Snapshot) {
        let content = DownloadActivityAttributes.ContentState(
            title: snapshot.title,
            artist: snapshot.artist,
            finished: snapshot.finished,
            total: snapshot.total,
            failed: snapshot.failed,
            fraction: snapshot.busy ? Double(snapshot.step) / 50 : 1,
            isDone: !snapshot.busy)

        if snapshot.busy {
            if let activity {
                updates?.cancel()
                updates = Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
            } else {
                start(content)
            }
        } else if let activity {
            updates?.cancel()
            self.activity = nil
            // Left up briefly so the finish is seen, then removed by the system.
            Task {
                await activity.end(ActivityContent(state: content, staleDate: nil),
                                   dismissalPolicy: .after(Date().addingTimeInterval(8)))
            }
        }
    }

    private func start(_ content: DownloadActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            activity = try Activity.request(
                attributes: DownloadActivityAttributes(),
                content: ActivityContent(state: content, staleDate: nil),
                pushType: nil)
        } catch {
            DebugLog.w("Downloads", "could not start the download Live Activity", error: error)
        }
    }
}
