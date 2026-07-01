import SwiftUI

/// Page indicator that mirrors the active screen. Sits in the
/// expanded panel footer between the style chip and the live-status group.
/// Each dot is tappable so regular-mouse users (no trackpad swipe, no
/// horizontal wheel) have a click-to-page affordance.
struct PageIndicator: View {
    @ObservedObject var model: IslandModel
    @ObservedObject private var screenPref = ScreenPref.shared
    @ObservedObject private var costPanelVisibility = CostPanelVisibilityStore.shared

    var body: some View {
        HStack(spacing: 5) {
            ForEach(screenPref.visibleScreens, id: \.self) { screen in
                dot(for: screen)
            }
        }
        .animation(.strongEaseOut, value: screenPref.screen)
        .animation(.strongEaseOut, value: costPanelVisibility.showInTopPanel)
    }

    private func dot(for screen: ScreenPref.Screen) -> some View {
        let isActive = screenPref.screen == screen
        return Circle()
            .fill(.white.opacity(isActive ? 0.78 : 0.22))
            .frame(width: 5, height: 5)
            // Visual stays 5pt; hit area expands ~6pt outward so the dot
            // is reachable without pixel-precise aim.
            .contentShape(Rectangle().inset(by: -6))
            .onTapGesture { model.showScreen(screen) }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel(for: screen))
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func accessibilityLabel(for screen: ScreenPref.Screen) -> String {
        let screens = screenPref.visibleScreens
        let index = screens.firstIndex(of: screen) ?? 0
        return L10n.tr("%@ page, %d of %d", screen.pageLabel, index + 1, screens.count)
    }
}
