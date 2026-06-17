import AppKit
import Combine

/// Tracks whether the island's window is currently visible to the user.
/// Set to `true` when a fullscreen app, Spaces switch, or display sleep
/// hides the menu bar — the LoadingSweep is paused while occluded so the
/// 30Hz TimelineView stops re-shading the conic gradient when nobody can
/// see it. Idle CPU drops to ~0% when the window is hidden.
@MainActor
final class WindowOcclusionStore: ObservableObject {
    static let shared = WindowOcclusionStore()

    @Published private(set) var isOccluded = false

    private init() {}

    func update(isVisible: Bool) {
        let occluded = !isVisible
        if occluded != isOccluded {
            isOccluded = occluded
        }
    }
}
