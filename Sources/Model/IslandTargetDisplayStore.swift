import Foundation
import SwiftUI

/// User preference for which display the island appears on.
///
/// Default is `.auto` — preserves today's behavior (prefer a notched
/// screen if one is connected, else `NSScreen.main`). When the user
/// picks a specific display in Settings, we persist its CFUUID-derived
/// stable ID via `CGDisplayCreateUUIDFromDisplayID`. That ID survives
/// plug/unplug cycles, so a hand-picked display reattaches correctly.
@MainActor
final class IslandTargetDisplayStore: ObservableObject {
    static let shared = IslandTargetDisplayStore()

    enum Choice: Equatable {
        case auto
        case stable(id: String)

        var rawValue: String {
            switch self {
            case .auto:           return "auto"
            case .stable(let id): return id
            }
        }

        init(rawValue: String?) {
            switch rawValue {
            case nil, "auto", "":
                self = .auto
            case let id?:
                self = .stable(id: id)
            }
        }
    }

    private static let key = "MacIsland.targetDisplay"

    @Published var choice: Choice {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: Self.key) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.key)
        self.choice = Choice(rawValue: raw)
    }
}
