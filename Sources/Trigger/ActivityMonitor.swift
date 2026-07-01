import Foundation

@MainActor
final class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()
    private init() {}

    struct ActiveThread: Equatable {
        let sessionId: String
        let label: String
        let cwd: String
        let modified: Date
        let transcriptPath: String?
        let turnKey: String?
    }

    enum State: Int {
        case idle = 0
        case working = 1
        case needsYou = 2
        case stalled = 3
        case rateLimited = 4
        case authRequired = 5

        var isAttentionState: Bool {
            switch self {
            case .stalled, .rateLimited, .authRequired: return true
            case .idle, .working, .needsYou: return false
            }
        }

        var label: String {
            switch self {
            case .idle: return L10n.tr("idle")
            case .working: return L10n.tr("running")
            case .needsYou: return L10n.tr("your turn")
            case .stalled: return L10n.tr("stalled")
            case .rateLimited: return L10n.tr("rate limited")
            case .authRequired: return L10n.tr("auth required")
            }
        }
    }

    @Published private(set) var claude: State = .idle
    @Published private(set) var codex: State = .idle
    @Published private(set) var claudeThread: ActiveThread?
    @Published private(set) var codexThread: ActiveThread?
    @Published private var demoClaude: State?
    @Published private var demoCodex: State?
    private var rawClaude: State = .idle
    private var rawCodex: State = .idle
    private var lastWorking: [String: Date] = [:]

    func state(for provider: AlertEngine.Provider) -> State {
        if provider == .claude { return demoClaude ?? claude }
        return demoCodex ?? codex
    }

    func demo(_ state: State?) {
        demoClaude = state
        demoCodex = state
    }

    func thread(for provider: AlertEngine.Provider) -> ActiveThread? {
        provider == .claude ? claudeThread : codexThread
    }

    private var timer: Timer?

    func start() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        let lastWorkingSnapshot = lastWorking
        Task.detached(priority: .utility) {
            let sessions = SessionScanner.monitoringScan(now: now, lastWorking: lastWorkingSnapshot)
            await MainActor.run {
                let oldClaude = self.rawClaude
                let oldCodex = self.rawCodex
                let claudeResult = Self.bestSession(in: sessions, tool: .claude)
                let codexResult = Self.bestSession(in: sessions, tool: .codex)
                let claude = self.overlayUsageAttention(claudeResult.state, usage: UsageStore.shared.claude)
                let codex = self.overlayUsageAttention(codexResult.state, usage: UsageStore.shared.codex)
                self.updateLastWorking(from: sessions, now: now)
                self.rawClaude = claudeResult.state
                self.rawCodex = codexResult.state
                self.claudeThread = claudeResult.thread
                self.claude = claude
                AgentReminderCenter.shared.handle(provider: .claude, old: oldClaude, new: claudeResult.state, thread: claudeResult.thread)
                self.codexThread = codexResult.thread
                self.codex = codex
                AgentReminderCenter.shared.handle(provider: .codex, old: oldCodex, new: codexResult.state, thread: codexResult.thread)
            }
        }
    }

    private func updateLastWorking(from sessions: [ScannedSession], now: Date) {
        for session in sessions where session.status == .working {
            if let path = session.transcriptPath { lastWorking[path] = now }
        }
        let livePaths = Set(sessions.compactMap(\.transcriptPath))
        lastWorking = lastWorking.filter { livePaths.contains($0.key) }
    }

    private func overlayUsageAttention(_ state: State, usage: AppUsage) -> State {
        guard let attention = Self.usageAttentionState(usage) else { return state }
        return attention.rawValue > state.rawValue ? attention : state
    }

    private static func usageAttentionState(_ usage: AppUsage) -> State? {
        if usage.fiveHour.usedPercent >= 1 || usage.weekly.usedPercent >= 1 {
            return .rateLimited
        }
        let messages = [usage.fiveHour.error, usage.weekly.error].compactMap { $0?.lowercased() }
        if messages.contains(where: { $0.contains("rate limited") || $0.contains("rate_limit") }) {
            return .rateLimited
        }
        if messages.contains(where: { message in
            ClaudeCredentials.isAuthRecoverableError(message)
                || message.contains("auth")
                || message.contains("login")
                || message.contains("no codex")
        }) {
            return .authRequired
        }
        if messages.contains(where: isProviderOrNetworkError) {
            return .rateLimited
        }
        return nil
    }

    private static func isProviderOrNetworkError(_ message: String) -> Bool {
        message.hasPrefix("http ")
            || message.contains("bad response")
            || message.contains("parse error")
            || message.contains("timed out")
            || message.contains("timeout")
            || message.contains("offline")
            || message.contains("network")
            || message.contains("internet")
            || message.contains("connection")
            || message.contains("cannot connect")
            || message.contains("could not connect")
            || message.contains("not connected")
            || message.contains("dns")
            || message.contains("ssl")
            || message.contains("tls")
    }

    private static func bestSession(
        in sessions: [ScannedSession],
        tool: TriggerTool
    ) -> (state: State, thread: ActiveThread?) {
        guard let session = sessions
            .filter({ $0.tool == tool })
            .sorted(by: { lhs, rhs in
                if lhs.status.rawValue != rhs.status.rawValue {
                    return lhs.status.rawValue > rhs.status.rawValue
                }
                return lhs.modified > rhs.modified
            })
            .first
        else {
            return (.idle, nil)
        }
        let thread = session.status == .idle ? nil : ActiveThread(
            sessionId: session.sessionId,
            label: session.label,
            cwd: session.cwd,
            modified: session.modified,
            transcriptPath: session.transcriptPath,
            turnKey: session.turnKey
        )
        return (session.status, thread)
    }
}
