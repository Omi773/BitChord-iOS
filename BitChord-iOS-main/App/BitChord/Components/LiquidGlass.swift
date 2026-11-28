import SwiftUI

// Liquid Glass plumbing. The app still deploys to iOS 17, so every iOS 26 API is reached through
// these helpers and older systems keep the look they had.

enum LiquidGlass {
    /// True where the system tab bar can carry the mini player as its bottom accessory (iOS 26):
    /// Liquid Glass, and it folds into the compact tab bar when the page scrolls, as in Apple Music.
    static var hostsMiniPlayerInTabBar: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }
}

extension View {
    /// A sheet that is system Liquid Glass on iOS 26 and wears `fallback` before it.
    /// `forceFallback` keeps the fallback on iOS 26 too (Reduce dynamic blur).
    @ViewBuilder
    func glassSheetBackground<S: ShapeStyle>(_ fallback: S, forceFallback: Bool = false) -> some View {
        if #available(iOS 26.0, *), !forceFallback {
            self
        } else {
            self.presentationBackground(fallback)
        }
    }

    /// The same, for a fallback background that is a view of its own.
    @ViewBuilder
    func glassSheetBackground<V: View>(@ViewBuilder fallback: () -> V) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            self.presentationBackground { fallback() }
        }
    }

    /// iOS 26 sheets carry their own concentric corners; earlier systems get `radius`.
    @ViewBuilder
    func glassSheetCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            self.presentationCornerRadius(radius)
        }
    }

    /// Hands the mini player to the system tab bar on iOS 26. Disabled (and so hidden) while
    /// nothing is loaded. A no-op earlier: the floating bar in `TabStack` is used there.
    @ViewBuilder
    func miniPlayerTabAccessory(isEnabled: Bool) -> some View {
        if #available(iOS 26.1, *) {
            self.tabViewBottomAccessory(isEnabled: isEnabled) { MiniPlayerAccessory() }
        } else if #available(iOS 26.0, *) {
            self.tabViewBottomAccessory { MiniPlayerAccessory() }
        } else {
            self
        }
    }
}

/// The mini player inside the tab bar's accessory slot. The system draws the Liquid Glass and
/// reports whether the bar is expanded or folded away (inline, between the tab buttons).
@available(iOS 26.0, *)
struct MiniPlayerAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(AppRouter.self) private var router

    var body: some View {
        MiniPlayer(tab: router.selectedTab, style: .accessory(inline: placement == .inline))
    }
}
