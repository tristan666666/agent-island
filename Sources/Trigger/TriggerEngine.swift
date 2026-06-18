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
    private init() {
        // Restore the reset boundaries we've already acted on. Persisting these
        // across launches is what lets a rollover that happens while the app is
        // closed or asleep get caught up on the next launch, instead of being
        // silently re-baselined and missed (the "didn't resume overnight" bug).
        lastReset = Self.loadBaselines()
    }

    private var subs: Set<AnyCancellable> = []
    private var lastReset: [TriggerTool: Date]
    private var intervalTimer: Timer?

    /// Per-tool "last reset boundary we've already fired on", persisted so the
    /// detection survives relaunches. Stored as rawValue → unix-seconds.
    private static let baselineKey = "AgentIsland.triggerResetBaselines"

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

    /// Fire `afterReset` triggers exactly once per genuine 5-hour rollover.
    ///
    /// A genuine reset is the window's `resetAt` advancing to a later time
    /// *after* the boundary we were tracking has actually elapsed
    /// (`previous <= now`). That one condition is the whole guard:
    ///  - the first window we ever see only seeds the baseline (no fire), so
    ///    launching mid-task never resumes;
    ///  - a `resetAt` that merely slides forward while still in the future
    ///    (demo recomputes it every refresh) is not a reset — ignored;
    ///  - because the baseline is persisted, a rollover missed while we were
    ///    closed or asleep is caught up once on the next launch.
    private func checkResets() {
        for tool in TriggerTool.allCases {
            guard let current = resetAt(tool) else { continue }
            guard let previous = lastReset[tool] else {
                setBaseline(current, for: tool)   // first sighting — seed only
                continue
            }
            guard current > previous, previous <= Date() else { continue }
            setBaseline(current, for: tool)
            for trigger in TriggerStore.shared.triggers
            where trigger.enabled && trigger.tool == tool && trigger.mode == .afterReset {
                fire(trigger)
            }
        }
    }

    private func setBaseline(_ date: Date, for tool: TriggerTool) {
        lastReset[tool] = date
        Self.saveBaselines(lastReset)
    }

    private static func loadBaselines() -> [TriggerTool: Date] {
        guard let raw = UserDefaults.standard.dictionary(forKey: baselineKey) as? [String: Double]
        else { return [:] }
        return raw.reduce(into: [:]) { acc, kv in
            if let tool = TriggerTool(rawValue: kv.key) {
                acc[tool] = Date(timeIntervalSince1970: kv.value)
            }
        }
    }

    private static func saveBaselines(_ map: [TriggerTool: Date]) {
        let raw = map.reduce(into: [String: Double]()) { acc, kv in
            acc[kv.key.rawValue] = kv.value.timeIntervalSince1970
        }
        UserDefaults.standard.set(raw, forKey: baselineKey)
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
        // Hard stop: never spawn a real resume process outside normal mode.
        // Demo/debug inject synthetic usage (resetAt jumps every refresh), so
        // firing there would burn real tokens on a loop. Demo is for
        // screenshots and the launch video only — it must never act.
        guard AppEnvironment.current == .normal else {
            NSLog("AgentIsland trigger: suppressed fire in non-normal mode (%@)", trigger.label)
            return
        }
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
