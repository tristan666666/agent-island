import Foundation
import SwiftUI

@MainActor
final class IslandSpacingStore: ObservableObject {
    static let shared = IslandSpacingStore()

    enum Mode: String {
        case compact
        case notchStyle

        /// Per-mode width, exposed on `Mode` (not on the store) so consumers
        /// can compute width from a known mode value without round-tripping
        /// through `IslandSpacingStore.shared.mode`. Critical for the
        /// `@Published` sink path: subscribers receive the new mode value
        /// *during* willSet, before the store's own property has been
        /// assigned — reading `shared.mode` there returns the *old* value
        /// and produces inverted widths. Using `mode.width` on the closure
        /// parameter avoids the race entirely.
        var width: CGFloat {
            switch self {
            case .compact:    return IslandSpacingStore.compactWidth
            case .notchStyle: return IslandSpacingStore.notchStyleWidth
            }
        }

        var displayLabel: String {
            switch self {
            case .compact: return "No-notch Mac"
            case .notchStyle: return "Notched Mac"
            }
        }
    }

    /// Compact preset width — the new default for non-notch hardware.
    /// `nonisolated` so non-MainActor call sites (notably `NotchInfo`
    /// as a free `struct`) can read it. Trivially safe; a `CGFloat`
    /// literal with no shared mutable state.
    nonisolated static let compactWidth: CGFloat = 100

    /// Notch-style preset width — preserves the original look for
    /// users who prefer the wider silhouette.
    nonisolated static let notchStyleWidth: CGFloat = 200

    private static let key = "MacIsland.spacingMode"

    @Published var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.key) }
    }

    var width: CGFloat { mode.width }

    private init() {
        self.mode = Pref.enumValue(key: Self.key, default: .compact)
    }
}
