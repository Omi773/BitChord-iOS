import SwiftUI
import UIKit

// Ports MainActivity.kt's entry point and BitChordApplication.kt's process start.

@main
struct BitChordApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// UIKit callbacks SwiftUI has no modifier for.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// A play tap in Control Center, on headphones or in a car can relaunch the app in the
    /// background with no window. Build the player right away so the play button has something
    /// to answer it (the window, when it opens, reuses the same app).
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        MainActor.assumeIsolated {
            _ = SystemAppAccess.model()
        }
        return true
    }

    /// Finished background downloads wake the app here; the download queue takes them over. A wake
    /// that launched the process has no window and so no model yet, which ``SystemAppAccess`` builds.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        MainActor.assumeIsolated {
            guard let model = SystemAppAccess.model() else {
                completionHandler()
                return
            }
            let done = UncheckedSendableBox(completionHandler)
            model.downloads.handleBackgroundEvents(identifier: identifier) { done.value() }
        }
    }
}

/// Carries a non-Sendable closure UIKit hands over across an isolation boundary it doesn't cross.
struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
