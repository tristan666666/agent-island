import Foundation
import UserNotifications

@MainActor
final class AgentReminderCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AgentReminderCenter()

    private var deliveredNeedsYouKeys: [String: Date] = [:]
    private var activeNeedsYouKey: [String: String] = [:]
    private var acknowledgedNeedsYouKeys: [String: Date] = [:]
    private var observedProviders: Set<String> = []
    private let rememberedKeyLifetime: TimeInterval = 12 * 60 * 60
    private static let acknowledgedDefaultsKey = "AgentIsland.acknowledgedNeedsYouKeys"

    private override init() {
        acknowledgedNeedsYouKeys = Self.loadAcknowledgedKeys()
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
        let isFirstObservation = markObserved(provider)
        guard new == .needsYou else {
            activeNeedsYouKey[provider.rawValue] = nil
            return
        }
        let deliveryKey = deliveryKey(provider: provider, state: new, thread: thread)
        if isFirstObservation {
            baseline(provider: provider, deliveryKey: deliveryKey)
            return
        }
        guard acknowledgedNeedsYouKeys[deliveryKey] == nil,
              deliveredNeedsYouKeys[deliveryKey] == nil
        else {
            activeNeedsYouKey[provider.rawValue] = deliveryKey
            return
        }
        guard old != .needsYou || activeNeedsYouKey[provider.rawValue] != deliveryKey else { return }
        activeNeedsYouKey[provider.rawValue] = deliveryKey
        deliveredNeedsYouKeys[deliveryKey] = Date()
        deliver(provider: provider, state: new, thread: thread)
    }

    func acknowledge(provider: AlertEngine.Provider, thread: ActivityMonitor.ActiveThread?) {
        let deliveryKey = deliveryKey(provider: provider, state: .needsYou, thread: thread)
        acknowledgedNeedsYouKeys[deliveryKey] = Date()
        persistAcknowledgedKeys()
        activeNeedsYouKey[provider.rawValue] = deliveryKey
    }

    private func pruneRememberedKeys() {
        let cutoff = Date().addingTimeInterval(-rememberedKeyLifetime)
        let acknowledgedBefore = acknowledgedNeedsYouKeys
        deliveredNeedsYouKeys = deliveredNeedsYouKeys.filter { $0.value >= cutoff }
        acknowledgedNeedsYouKeys = acknowledgedNeedsYouKeys.filter { $0.value >= cutoff }
        if acknowledgedBefore.count != acknowledgedNeedsYouKeys.count {
            persistAcknowledgedKeys()
        }
    }

    private func markObserved(_ provider: AlertEngine.Provider) -> Bool {
        let providerKey = provider.rawValue
        guard !observedProviders.contains(providerKey) else { return false }
        observedProviders.insert(providerKey)
        return true
    }

    private func baseline(provider: AlertEngine.Provider, deliveryKey: String) {
        let providerKey = provider.rawValue
        acknowledgedNeedsYouKeys[deliveryKey] = Date()
        activeNeedsYouKey[providerKey] = deliveryKey
        persistAcknowledgedKeys()
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

    private func threadKey(_ thread: ActivityMonitor.ActiveThread?) -> String {
        guard let thread else { return "" }
        if let transcriptPath = thread.transcriptPath, !transcriptPath.isEmpty { return transcriptPath }
        if !thread.sessionId.isEmpty { return thread.sessionId }
        if !thread.cwd.isEmpty { return "\(thread.cwd):\(thread.label)" }
        return thread.label
    }

    private static func loadAcknowledgedKeys() -> [String: Date] {
        guard let stored = UserDefaults.standard.dictionary(forKey: acknowledgedDefaultsKey) as? [String: TimeInterval] else {
            return [:]
        }
        return stored.mapValues(Date.init(timeIntervalSince1970:))
    }

    private func persistAcknowledgedKeys() {
        let stored = acknowledgedNeedsYouKeys.mapValues(\.timeIntervalSince1970)
        UserDefaults.standard.set(stored, forKey: Self.acknowledgedDefaultsKey)
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
