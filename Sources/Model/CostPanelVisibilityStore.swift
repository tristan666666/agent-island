import Foundation

@MainActor
final class CostPanelVisibilityStore: ObservableObject {
    static let shared = CostPanelVisibilityStore()

    private static let key = "MacIsland.showCostPanelPage"

    @Published var showInTopPanel: Bool {
        didSet { UserDefaults.standard.set(showInTopPanel, forKey: Self.key) }
    }

    private init() {
        if UserDefaults.standard.object(forKey: Self.key) == nil {
            showInTopPanel = true
        } else {
            showInTopPanel = UserDefaults.standard.bool(forKey: Self.key)
        }
    }
}
