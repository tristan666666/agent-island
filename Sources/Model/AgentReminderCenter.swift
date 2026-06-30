import Foundation
import UserNotifications

@MainActor
final class AgentReminderCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AgentReminderCenter()

    private var deliveredNeedsYouKeys: [String: Date] = [:]
    private var deliveredNeedsYouScopes: [String: Date] = [:]
    private var activeNeedsYouScope: [String: String] = [:]
    private var acknowledgedNeedsYouKeys: [String: Date] = [:]
    private var acknowledgedNeedsYouScopes: [String: Date] = [:]
    private var acknowledgedNeedsYouProviders: [String: Date] = [:]
    private let rememberedKeyLifetime: TimeInterval = 12 * 60 * 60

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
        pruneRememberedKeys()
        guard new == .needsYou else {
            activeNeedsYouScope[provider.rawValue] = nil
            clearNeedsYouScopes(for: provider)
            acknowledgedNeedsYouProviders[provider.rawValue] = nil
            return
        }
        let deliveryKey = deliveryKey(provider: provider, state: new, thread: thread)
        let scopeKey = needsYouScopeKey(provider: provider, thread: thread)
        guard acknowledgedNeedsYouProviders[provider.rawValue] == nil,
              acknowledgedNeedsYouKeys[deliveryKey] == nil,
              acknowledgedNeedsYouScopes[scopeKey] == nil,
              deliveredNeedsYouKeys[deliveryKey] == nil,
              deliveredNeedsYouScopes[scopeKey] == nil
        else {
            activeNeedsYouScope[provider.rawValue] = scopeKey
            return
        }
        guard old != .needsYou || activeNeedsYouScope[provider.rawValue] != scopeKey else { return }
        activeNeedsYouScope[provider.rawValue] = scopeKey
        deliveredNeedsYouKeys[deliveryKey] = Date()
        deliveredNeedsYouScopes[scopeKey] = Date()
        deliver(provider: provider, state: new, thread: thread)
    }

    func acknowledge(provider: AlertEngine.Provider, thread: ActivityMonitor.ActiveThread?) {
        let deliveryKey = deliveryKey(provider: provider, state: .needsYou, thread: thread)
        let scopeKey = needsYouScopeKey(provider: provider, thread: thread)
        acknowledgedNeedsYouKeys[deliveryKey] = Date()
        acknowledgedNeedsYouScopes[scopeKey] = Date()
        acknowledgedNeedsYouProviders[provider.rawValue] = Date()
        activeNeedsYouScope[provider.rawValue] = scopeKey
    }

    private func pruneRememberedKeys() {
        let cutoff = Date().addingTimeInterval(-rememberedKeyLifetime)
        deliveredNeedsYouKeys = deliveredNeedsYouKeys.filter { $0.value >= cutoff }
        deliveredNeedsYouScopes = deliveredNeedsYouScopes.filter { $0.value >= cutoff }
        acknowledgedNeedsYouKeys = acknowledgedNeedsYouKeys.filter { $0.value >= cutoff }
        acknowledgedNeedsYouScopes = acknowledgedNeedsYouScopes.filter { $0.value >= cutoff }
        acknowledgedNeedsYouProviders = acknowledgedNeedsYouProviders.filter { $0.value >= cutoff }
    }

    private func clearNeedsYouScopes(for provider: AlertEngine.Provider) {
        let prefix = "\(provider.rawValue)-\(ActivityMonitor.State.needsYou.rawValue)-"
        deliveredNeedsYouScopes = deliveredNeedsYouScopes.filter { !$0.key.hasPrefix(prefix) }
        acknowledgedNeedsYouScopes = acknowledgedNeedsYouScopes.filter { !$0.key.hasPrefix(prefix) }
    }

    private func deliveryKey(
        provider: AlertEngine.Provider,
        state: ActivityMonitor.State,
        thread: ActivityMonitor.ActiveThread?
    ) -> String {
        let threadKey = threadKey(thread)
        let turnKey = thread?.modified.timeIntervalSince1970 ?? 0
        return "\(provider.rawValue)-\(state.rawValue)-\(threadKey)-\(turnKey)"
    }

    private func needsYouScopeKey(provider: AlertEngine.Provider, thread: ActivityMonitor.ActiveThread?) -> String {
        "\(provider.rawValue)-\(ActivityMonitor.State.needsYou.rawValue)-\(threadKey(thread))"
    }

    private func threadKey(_ thread: ActivityMonitor.ActiveThread?) -> String {
        guard let thread else { return "" }
        if let transcriptPath = thread.transcriptPath, !transcriptPath.isEmpty { return transcriptPath }
        if !thread.sessionId.isEmpty { return thread.sessionId }
        if !thread.cwd.isEmpty { return "\(thread.cwd):\(thread.label)" }
        return thread.label
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
