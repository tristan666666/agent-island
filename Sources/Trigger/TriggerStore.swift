import Foundation

/// User-configured auto-triggers, persisted as JSON in UserDefaults.
///
/// Default empty: the feature does nothing until the user adds a trigger in
/// Settings, so existing installs see no behavior change on update.
@MainActor
final class TriggerStore: ObservableObject {
    static let shared = TriggerStore()

    private static let key = "AgentIsland.triggers"

    @Published var triggers: [Trigger] {
        didSet { persist() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([Trigger].self, from: data) {
            self.triggers = decoded
        } else {
            self.triggers = []
        }
    }

    func add(_ trigger: Trigger) {
        triggers.append(trigger)
    }

    func remove(_ id: String) {
        triggers.removeAll { $0.id == id }
    }

    func update(_ trigger: Trigger) {
        guard let index = triggers.firstIndex(where: { $0.id == trigger.id }) else { return }
        triggers[index] = trigger
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        guard let index = triggers.firstIndex(where: { $0.id == id }) else { return }
        triggers[index].enabled = enabled
    }

    func markFired(_ id: String, at date: Date = Date()) {
        guard let index = triggers.firstIndex(where: { $0.id == id }) else { return }
        triggers[index].lastFired = date
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(triggers) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
