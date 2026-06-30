import Foundation

@MainActor
final class TriggerSafetyStore: ObservableObject {
    static let shared = TriggerSafetyStore()

    private static let enabledKey = "AgentIsland.triggerExecutionEnabled"
    private static let dryRunKey = "AgentIsland.triggerDryRun"
    private static let allowedRootsKey = "AgentIsland.triggerAllowedRoots"

    @Published var executionEnabled: Bool {
        didSet { UserDefaults.standard.set(executionEnabled, forKey: Self.enabledKey) }
    }

    @Published var dryRun: Bool {
        didSet { UserDefaults.standard.set(dryRun, forKey: Self.dryRunKey) }
    }

    @Published private(set) var allowedRoots: Set<String> {
        didSet { UserDefaults.standard.set(Array(allowedRoots).sorted(), forKey: Self.allowedRootsKey) }
    }

    private init() {
        executionEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.enabledKey)
        dryRun = UserDefaults.standard.bool(forKey: Self.dryRunKey)
        allowedRoots = Set(UserDefaults.standard.stringArray(forKey: Self.allowedRootsKey) ?? [])
    }

    func isAllowed(cwd: String) -> Bool {
        let root = normalized(cwd)
        return root.isEmpty || allowedRoots.contains(root)
    }

    func setAllowed(cwd: String, _ allowed: Bool) {
        let root = normalized(cwd)
        guard !root.isEmpty else { return }
        if allowed {
            allowedRoots.insert(root)
        } else {
            allowedRoots.remove(root)
        }
    }

    func normalized(_ cwd: String) -> String {
        guard !cwd.isEmpty else { return "" }
        return (cwd as NSString).standardizingPath
    }
}
