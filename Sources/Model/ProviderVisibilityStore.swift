import Foundation

/// Per-provider visibility for the menu-bar island and expanded panel.
/// Hiding a provider blanks its column in the panel and hides its brand
/// logo from the compact pill — the pill itself keeps its symmetric width
/// so the silhouette remains balanced over the physical notch.
@MainActor
final class ProviderVisibilityStore: ObservableObject {
    static let shared = ProviderVisibilityStore()

    private static let claudeKey = "MacIsland.claudeVisible"
    private static let codexKey = "MacIsland.codexVisible"

    @Published var claudeVisible: Bool {
        didSet { UserDefaults.standard.set(claudeVisible, forKey: Self.claudeKey) }
    }
    @Published var codexVisible: Bool {
        didSet { UserDefaults.standard.set(codexVisible, forKey: Self.codexKey) }
    }

    private init() {
        self.claudeVisible = Pref.seededBool(key: Self.claudeKey, default: true)
        self.codexVisible = Pref.seededBool(key: Self.codexKey, default: true)
    }

    /// Single accessor for call sites that have an `AlertEngine.Provider`
    /// in hand. Equivalent to reading `claudeVisible` / `codexVisible`
    /// directly; centralizes the lookup so the few provider-keyed call
    /// sites read uniformly.
    func effectiveVisible(provider: AlertEngine.Provider) -> Bool {
        switch provider {
        case .claude: return claudeVisible
        case .codex:  return codexVisible
        }
    }
}
