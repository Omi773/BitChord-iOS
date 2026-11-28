import AppIntents
import SwiftUI
import WidgetKit

/// A Play / Pause button for Control Center (iOS 18 and later). It runs TogglePlaybackIntent,
/// an AudioPlaybackIntent, so iOS starts BitChord in the background and plays even when the
/// app is closed. Add it from Control Center: Edit, then Add a Control, then BitChord.
@available(iOS 18.0, *)
struct PlayPauseControl: ControlWidget {
    static let kind = "com.music.bitchord.control.playpause"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TogglePlaybackIntent()) {
                Label("Play / Pause", systemImage: "playpause.fill")
            }
        }
        .displayName("Play / Pause")
        .description("Play or pause BitChord, even when the app is closed.")
    }
}
