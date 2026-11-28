import ActivityKit
import SwiftUI
import WidgetKit

/// The download Live Activity: Lock Screen card and Dynamic Island. Text and a progress bar only,
/// so it never waits on an image.
struct DownloadLiveActivityWidget: Widget {
    private static let accent = Color(red: 0.90, green: 0.25, blue: 0.31)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            LockScreenCard(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isDone ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Self.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Self.countText(context.state))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(Self.headline(context.state))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if !context.state.isDone, !context.state.artist.isEmpty {
                            Text(context.state.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.fraction)
                        .tint(Self.accent)
                }
            } compactLeading: {
                Image(systemName: context.state.isDone ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(Self.accent)
            } compactTrailing: {
                Text(Self.countText(context.state))
                    .font(.caption.weight(.semibold).monospacedDigit())
            } minimal: {
                Image(systemName: context.state.isDone ? "checkmark" : "arrow.down")
                    .foregroundStyle(Self.accent)
            }
            .keylineTint(Self.accent)
        }
    }

    static func countText(_ state: DownloadActivityAttributes.ContentState) -> String {
        "\(min(state.finished, state.total))/\(state.total)"
    }

    static func headline(_ state: DownloadActivityAttributes.ContentState) -> String {
        if state.isDone {
            return state.failed > 0
                ? "Downloaded \(state.total - state.failed) of \(state.total)"
                : "Downloaded \(state.total) song\(state.total == 1 ? "" : "s")"
        }
        return state.title.isEmpty ? "Downloading" : state.title
    }

    private struct LockScreenCard: View {
        let state: DownloadActivityAttributes.ContentState

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: state.isDone ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DownloadLiveActivityWidget.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DownloadLiveActivityWidget.headline(state))
                            .font(.headline)
                            .lineLimit(1)
                        if !state.isDone {
                            Text(state.artist.isEmpty ? "Downloading" : state.artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(DownloadLiveActivityWidget.countText(state))
                        .font(.headline.monospacedDigit())
                }
                ProgressView(value: state.fraction)
                    .tint(DownloadLiveActivityWidget.accent)
            }
        }
    }
}
