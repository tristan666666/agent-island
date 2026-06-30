import Foundation

@MainActor
final class AgentReminderStore: ObservableObject {
    static let shared = AgentReminderStore()

    private static let key = "AgentIsland.agentReminders"

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.key) }
    }

    private init() {
        enabled = UserDefaults.standard.object(forKey: Self.key) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.key)
    }
}
