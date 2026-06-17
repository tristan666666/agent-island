import Foundation
import Combine

/// Fires auto-triggers. Subscribes to `UsageStore` and treats a changed
/// `fiveHour.resetAt` for a provider as that provider's window having reset —
/// the same signal `AlertEngine` keys crossings on — then resumes the target
/// session via the provider's CLI. Also runs a fixed-interval timer for
/// `everyHours` triggers.
@MainActor
final class TriggerEngine: ObservableObject {
    static let shared = TriggerEngine()
    private init() {}

    private var subs: Set<AnyCancellable> = []
    private var lastReset: [TriggerTool: Date] = [:]
    private var warmed: Set<TriggerTool> = []
    private var intervalTimer: Timer?

    func start() {
        let signals: [AnyPublisher<Void, Never>] = [
            UsageStore.shared.$claude.map { _ in () }.eraseToAnyPublisher(),
            UsageStore.shared.$codex.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(signals)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in Task { @MainActor in self?.checkResets() } }
            .store(in: &subs)

        intervalTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIntervals() }
        }
        checkResets()
    }

    private func resetAt(_ tool: TriggerTool) -> Date? {
        switch tool {
        case .claude: return UsageStore.shared.claude.fiveHour.resetAt
        case .codex: return UsageStore.shared.codex.fiveHour.resetAt
        }
    }

    /// A new `resetAt` later than the one we last saw means the window rolled
    /// over. The first observation per tool only seeds the baseline (no fire),
    /// so launching mid-window doesn't immediately resume.
    private func checkResets() {
        for tool in TriggerTool.allCases {
            guard let current = resetAt(tool) else { continue }
            let previous = lastReset[tool]
            lastReset[tool] = current
            if !warmed.contains(tool) {
                warmed.insert(tool)
                continue
            }
            guard let previous, current > previous else { continue }
            for trigger in TriggerStore.shared.triggers
            where trigger.enabled && trigger.tool == tool && trigger.mode == .afterReset {
                fire(trigger)
            }
        }
    }

    private func checkIntervals() {
        let now = Date()
        for trigger in TriggerStore.shared.triggers
        where trigger.enabled && trigger.mode == .everyHours {
            guard let last = trigger.lastFired else {
                // Seed the baseline so the first fire lands a full interval
                // after the trigger was created, not immediately.
                TriggerStore.shared.markFired(trigger.id, at: now)
                continue
            }
            let interval = Double(max(1, trigger.everyHours)) * 3600
            if now >= last.addingTimeInterval(interval) {
                fire(trigger)
            }
        }
    }

    /// Spawn the resume command detached and log to Application Support.
    func fire(_ trigger: Trigger) {
        guard let binary = CLILocator.path(for: trigger.tool) else {
            NSLog("AgentIsland trigger: %@ binary not found", trigger.tool.rawValue)
            return
        }

        let arguments: [String]
        switch trigger.tool {
        case .claude:
            arguments = ["--resume", trigger.sessionId, "-p", trigger.message,
                         "--dangerously-skip-permissions"]
        case .codex:
            arguments = ["exec", "resume", trigger.sessionId, trigger.message,
                         "--dangerously-bypass-approvals-and-sandbox", "--skip-git-repo-check"]
        }

        let task = Process()
        task.launchPath = binary
        task.arguments = arguments
        if !trigger.cwd.isEmpty, FileManager.default.fileExists(atPath: trigger.cwd) {
            task.currentDirectoryPath = trigger.cwd
        }
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["PATH"] = "/opt/homebrew/bin:\(home)/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = env

        if let handle = openLog(for: trigger) {
            task.standardOutput = handle
            task.standardError = handle
        } else {
            task.standardOutput = Pipe()
            task.standardError = Pipe()
        }
        task.standardInput = Pipe()

        do {
            try task.run()
            TriggerStore.shared.markFired(trigger.id)
            NSLog("AgentIsland trigger: fired %@ [%@] %@", trigger.label, trigger.tool.rawValue, trigger.sessionId)
        } catch {
            NSLog("AgentIsland trigger: spawn failed: %@", error.localizedDescription)
        }
    }

    private func openLog(for trigger: Trigger) -> FileHandle? {
        let dir = NSHomeDirectory() + "/Library/Application Support/AgentIsland/trigger-runs"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + "/\(trigger.id)_\(Int(Date().timeIntervalSince1970)).log"
        guard FileManager.default.createFile(atPath: path, contents: nil) else { return nil }
        return FileHandle(forWritingAtPath: path)
    }
}
