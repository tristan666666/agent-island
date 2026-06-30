import Foundation
import UserNotifications

@MainActor
final class AgentReminderCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AgentReminderCenter()

    private var lastDelivered: [String: Date] = [:]
    private var activeNeedsYouKey: [String: String] = [:]
    private let duplicateCooldown: TimeInterval = 90

    private override init() {
        super.init()
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { granted, error in
            if let error {
                NSLog("AgentIsland reminder authorization failed: %@", error.localizedDescription)
            } else if !granted {
                NSLog("AgentIsland reminders not authorized")
            }
        }
    }

    func handle(
        provider: AlertEngine.Provider,
        old: ActivityMonitor.State,
        new: ActivityMonitor.State,
        thread: ActivityMonitor.ActiveThread?
    ) {
        guard AgentReminderStore.shared.enabled else { return }
        guard new == .needsYou else {
            activeNeedsYouKey[provider.rawValue] = nil
            return
        }
        let threadKey = thread?.transcriptPath ?? thread?.label ?? ""
        let turnKey = thread?.modified.timeIntervalSince1970 ?? 0
        let deliveryKey = "\(provider.rawValue)-\(new.rawValue)-\(threadKey)-\(turnKey)"
        guard old != .needsYou || activeNeedsYouKey[provider.rawValue] != deliveryKey else { return }
        activeNeedsYouKey[provider.rawValue] = deliveryKey
        if let last = lastDelivered[deliveryKey], Date().timeIntervalSince(last) < duplicateCooldown { return }
        lastDelivered[deliveryKey] = Date()
        pruneDelivered(before: Date().addingTimeInterval(-3600))
        deliver(provider: provider, state: new, thread: thread)
    }

    private func pruneDelivered(before cutoff: Date) {
        lastDelivered = lastDelivered.filter { $0.value >= cutoff }
    }

    private func deliver(provider: AlertEngine.Provider, state: ActivityMonitor.State, thread: ActivityMonitor.ActiveThread?) {
        let content = UNMutableNotificationContent()
        content.title = title(provider: provider, state: state)
        content.body = body(provider: provider, state: state, thread: thread)

        let request = UNNotificationRequest(
            identifier: "agent-island-\(provider.rawValue)-\(state.rawValue)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("AgentIsland reminder failed: %@", error.localizedDescription)
            }
        }
        TurnAlarmWindowController.shared.show(provider: provider, thread: thread)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }

    private func title(provider: AlertEngine.Provider, state: ActivityMonitor.State) -> String {
        let name = provider == .claude ? "Claude" : "Codex"
        switch state {
        case .needsYou: return L10n.tr("%@ is waiting for you", name)
        case .idle, .working, .stalled, .authRequired, .rateLimited: return name
        }
    }

    private func body(
        provider: AlertEngine.Provider,
        state: ActivityMonitor.State,
        thread: ActivityMonitor.ActiveThread?
    ) -> String {
        switch state {
        case .needsYou:
            if AgentReminderStore.shared.showSessionDetails, let thread {
                return L10n.tr("A background coding session finished a turn: %@.", thread.label)
            }
            return L10n.tr("A background coding session finished a turn. It is your turn.")
        case .idle, .working, .stalled, .authRequired, .rateLimited:
            return ""
        }
    }
}
