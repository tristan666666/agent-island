import Foundation
import AppKit
import UserNotifications

@MainActor
final class AgentReminderCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AgentReminderCenter()

    private var lastDelivered: [String: Date] = [:]
    private let cooldown: TimeInterval = 90

    private override init() {
        super.init()
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("AgentIsland reminder authorization failed: %@", error.localizedDescription)
            } else if !granted {
                NSLog("AgentIsland reminders not authorized")
            }
        }
    }

    func handle(provider: AlertEngine.Provider, old: ActivityMonitor.State, new: ActivityMonitor.State) {
        guard AgentReminderStore.shared.enabled else { return }
        guard new != old, new.isAttentionState else { return }
        let key = "\(provider.rawValue)-\(new.rawValue)"
        if let last = lastDelivered[key], Date().timeIntervalSince(last) < cooldown { return }
        lastDelivered[key] = Date()
        deliver(provider: provider, state: new)
    }

    private func deliver(provider: AlertEngine.Provider, state: ActivityMonitor.State) {
        let content = UNMutableNotificationContent()
        content.title = title(provider: provider, state: state)
        content.body = body(provider: provider, state: state)
        content.sound = .default

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
        if state == .needsYou {
            NSSound.beep()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func title(provider: AlertEngine.Provider, state: ActivityMonitor.State) -> String {
        let name = provider == .claude ? "Claude" : "Codex"
        switch state {
        case .needsYou: return L10n.tr("%@ is waiting for you", name)
        case .stalled: return L10n.tr("%@ looks stalled", name)
        case .authRequired: return L10n.tr("%@ needs login", name)
        case .rateLimited: return L10n.tr("%@ is rate limited", name)
        case .idle, .working: return name
        }
    }

    private func body(provider: AlertEngine.Provider, state: ActivityMonitor.State) -> String {
        switch state {
        case .needsYou:
            return L10n.tr("A background coding session finished a turn. It is your turn.")
        case .stalled:
            return L10n.tr("No output has appeared for a while. Check the session before auto-resuming.")
        case .authRequired:
            return provider == .claude
                ? L10n.tr("Open Settings and run Claude re-authentication.")
                : L10n.tr("Run codex login in Terminal, then refresh Agent Island.")
        case .rateLimited:
            return L10n.tr("Wait for the limit to recover before continuing.")
        case .idle, .working:
            return ""
        }
    }
}
