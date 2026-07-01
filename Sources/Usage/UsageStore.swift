import Foundation
import Combine
import Network

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()
    private init() {
        guard !AppEnvironment.isDemo,
              let snapshot = Self.loadCachedSnapshot() else { return }
        claude = snapshot.claude
        codex = snapshot.codex
        lastUpdated = snapshot.updatedAt
    }

    @Published var claude: AppUsage = .empty
    @Published var codex: AppUsage = .empty
    @Published var lastUpdated: Date?
    @Published var refreshWarning: String?
    @Published var loading = false
    /// Set while a `claude auth login` flow is in progress (spawned + still
    /// polling for the keychain to update). The UI hides the re-auth button
    /// during this window so users don't double-tap and spawn duplicate CLI
    /// processes; the click ends up no-ops anyway because the spawn check
    /// gates on this.
    @Published var claudeReauthInProgress = false
    @Published var codexReauthInProgress = false

    private var refreshTask: Task<Void, Never>?
    private var reauthPollTask: Task<Void, Never>?
    private var codexReauthPollTask: Task<Void, Never>?
    private var pollTimer: Timer?
    private var intervalCancellable: AnyCancellable?
    private var netMonitor: NWPathMonitor?
    private let netQueue = DispatchQueue(label: "UsageStore.network")
    private var lastNetStatus: NWPath.Status?
    private static let cacheKey = "UsageStore.lastSuccessfulUsage.v1"
    private static let cacheMaxAge: TimeInterval = 24 * 60 * 60

    /// Anthropic's /api/oauth/usage is aggressively rate-limited per token.
    /// `RefreshIntervalStore` enforces a 5-minute floor (300/900/1800).
    private var pollInterval: TimeInterval {
        TimeInterval(RefreshIntervalStore.shared.seconds)
    }

    func refresh() {
        if loading { return }
        // Demo mode for screen recordings: skip the network entirely and
        // inject hand-tuned values that read as "real, healthy heavy-user
        // data". Reset times are recomputed each refresh so the countdowns
        // tick down naturally on camera. Off by default — only fires when
        // CODEXISLAND_DEMO=1 is set in the launching env.
        if AppEnvironment.isDemo {
            let now = Date()
            let claudeFiveHour = Self.demoDouble("AGENTISLAND_DEMO_CLAUDE_5H", fallback: 0.73)
            let claudeWeekly = Self.demoDouble("AGENTISLAND_DEMO_CLAUDE_WEEKLY", fallback: 0.81)
            let codexFiveHour = Self.demoDouble("AGENTISLAND_DEMO_CODEX_5H", fallback: 0.67)
            let codexWeekly = Self.demoDouble("AGENTISLAND_DEMO_CODEX_WEEKLY", fallback: 0.76)
            let claudeReset = Self.demoMinutes("AGENTISLAND_DEMO_CLAUDE_RESET_MINUTES", fallback: 107)
            let codexReset = Self.demoMinutes("AGENTISLAND_DEMO_CODEX_RESET_MINUTES", fallback: 143)
            self.claude = AppUsage(
                fiveHour: WindowUsage(
                    usedPercent: claudeFiveHour,
                    resetAt: now.addingTimeInterval(TimeInterval(claudeReset * 60)),
                    error: nil
                ),
                weekly: WindowUsage(
                    usedPercent: claudeWeekly,
                    resetAt: now.addingTimeInterval(4 * 86400 + 11 * 3600),
                    error: nil
                ),
                plan: "max"
            )
            self.codex = AppUsage(
                fiveHour: WindowUsage(
                    usedPercent: codexFiveHour,
                    resetAt: now.addingTimeInterval(TimeInterval(codexReset * 60)),
                    error: nil
                ),
                weekly: WindowUsage(
                    usedPercent: codexWeekly,
                    resetAt: now.addingTimeInterval(4 * 86400 + 18 * 3600),
                    error: nil
                ),
                plan: "pro"
            )
            self.lastUpdated = now
            self.refreshWarning = nil
            return
        }

        loading = true
        refreshTask?.cancel()
        refreshTask = Task {
            async let codexResult = UsageFetcher.fetchCodex()
            async let claudeResult = UsageFetcher.fetchClaude()
            let c = await codexResult
            let cl = await claudeResult

            // Cancellation = network monitor saw the path come up while we
            // were mid-flight on a dead one. The fetched values are the
            // dead-path errors — drop them so the supersedes refresh
            // doesn't have a brief "cancelled" caption flash to overwrite.
            if Task.isCancelled {
                self.loading = false
                return
            }

            // Don't clobber existing good values when a fetch returns an
            // all-error result. A transient 429 shouldn't blank the panel
            // back to "0%" — that's worse than slightly stale data. Preserve
            // the last useful percentages, but carry the new error forward so
            // the UI admits the values are stale instead of showing a fake
            // fresh reset countdown. But if
            // the existing value is itself error-only (cold start sitting
            // on `.empty`, or a series of failures), let the new error
            // through — otherwise a single bad first fetch sticks "no data"
            // permanently even after the network recovers.
            let codexFailed = UsageStore.isErrorOnly(c)
            let claudeFailed = UsageStore.isErrorOnly(cl)

            let mergedCodex = UsageStore.mergedUsage(existing: self.codex, fetched: c)
            let mergedClaude = UsageStore.mergedUsage(existing: self.claude, fetched: cl)
            self.codex = mergedCodex
            self.claude = mergedClaude
            UsageStore.saveCachedSnapshot(claude: mergedClaude, codex: mergedCodex)
            self.refreshWarning = UsageStore.refreshWarning(codexFailed: codexFailed, claudeFailed: claudeFailed)
            self.lastUpdated = Date()
            self.loading = false
        }
    }

    private static func demoDouble(_ key: String, fallback: Double) -> Double {
        guard let raw = ProcessInfo.processInfo.environment[key],
              let value = Double(raw) else { return fallback }
        return min(1, max(0, value))
    }

    private static func demoMinutes(_ key: String, fallback: Int) -> Int {
        guard let raw = ProcessInfo.processInfo.environment[key],
              let value = Int(raw) else { return fallback }
        return max(1, value)
    }

    /// True when both windows have errors and zero values — nothing useful
    /// to show, so we keep whatever we had before.
    private static func isErrorOnly(_ u: AppUsage) -> Bool {
        u.fiveHour.error != nil && u.weekly.error != nil
            && u.fiveHour.usedPercent == 0 && u.weekly.usedPercent == 0
    }

    private static func mergedUsage(existing: AppUsage, fetched: AppUsage) -> AppUsage {
        guard isErrorOnly(fetched), !isErrorOnly(existing) else { return fetched }
        let error = fetched.fiveHour.error ?? fetched.weekly.error
        return AppUsage(
            fiveHour: WindowUsage(
                usedPercent: existing.fiveHour.usedPercent,
                resetAt: existing.fiveHour.resetAt,
                error: error
            ),
            weekly: WindowUsage(
                usedPercent: existing.weekly.usedPercent,
                resetAt: existing.weekly.resetAt,
                error: error
            ),
            plan: existing.plan
        )
    }

    private static func refreshWarning(codexFailed: Bool, claudeFailed: Bool) -> String? {
        switch (claudeFailed, codexFailed) {
        case (true, true): return L10n.tr("Usage refresh failed")
        case (true, false): return L10n.tr("Claude stale")
        case (false, true): return L10n.tr("Codex stale")
        case (false, false): return nil
        }
    }

    private static func loadCachedSnapshot() -> UsageCacheSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let snapshot = try? JSONDecoder().decode(UsageCacheSnapshot.self, from: data) else {
            return nil
        }
        return UsageCachePolicy.restoredSnapshot(snapshot, now: Date(), maxAge: cacheMaxAge)
    }

    private static func saveCachedSnapshot(claude: AppUsage,
                                           codex: AppUsage,
                                           fetchedClaude: Bool = true,
                                           fetchedCodex: Bool = true) {
        let existing = loadCachedSnapshot()
        guard let snapshot = UsageCachePolicy.snapshotForSave(
            claude: claude,
            codex: codex,
            existing: existing,
            now: Date(),
            fetchedClaude: fetchedClaude,
            fetchedCodex: fetchedCodex
        ), let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    /// Replace current usage values with hand-tuned percentages so the
    /// alert engine's pulse + tint behavior can be exercised without
    /// waiting for a real provider crossing. Auto-refresh continues — the
    /// next scheduled poll will overwrite these values with real data.
    /// Each call uses fresh `resetAt` timestamps so the alert engine
    /// treats it as a new reset window and re-evaluates crossings.
    func injectPreviewUsage(claudeFiveHour: Double, codexFiveHour: Double) {
        let now = Date()
        let fiveHourReset = now.addingTimeInterval(2 * 3600 + 14 * 60)
        let weeklyReset = now.addingTimeInterval(4 * 86400 + 6 * 3600)
        self.claude = AppUsage(
            fiveHour: WindowUsage(
                usedPercent: claudeFiveHour,
                resetAt: fiveHourReset,
                error: nil
            ),
            weekly: WindowUsage(
                usedPercent: 0.45,
                resetAt: weeklyReset,
                error: nil
            ),
            plan: claude.plan ?? "max"
        )
        self.codex = AppUsage(
            fiveHour: WindowUsage(
                usedPercent: codexFiveHour,
                resetAt: fiveHourReset,
                error: nil
            ),
            weekly: WindowUsage(
                usedPercent: 0.30,
                resetAt: weeklyReset,
                error: nil
            ),
            plan: codex.plan ?? "pro"
        )
        self.lastUpdated = now
        self.refreshWarning = nil
    }

    /// Spawn `claude auth login` and wait for the keychain to update.
    ///
    /// We can't `await` the OAuth flow directly — it happens in Terminal and
    /// may involve a browser tab, localhost callback listener, SSO, or manual
    /// input. Poll the keychain metadata first, then hit the usage API once
    /// after credentials change. Polling the usage endpoint every few seconds
    /// can itself trigger Anthropic's rate limit, which hides the real auth
    /// recovery behind a fresh `rate limited` error.
    func reauthenticateClaude() {
        guard !claudeReauthInProgress else { return }
        let initialStamp = ClaudeCredentials.keychainModificationStamp()
        guard ClaudeCredentials.spawnReauth() else { return }
        claudeReauthInProgress = true
        reauthPollTask?.cancel()
        reauthPollTask = Task { [weak self, initialStamp] in
            // ~2 minutes total. The keychain check is local and cheap; the
            // usage API is called only once when the credentials actually
            // change, plus one final fallback call before giving up.
            for _ in 0..<40 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { return }
                let currentStamp = ClaudeCredentials.keychainModificationStamp()
                guard currentStamp != nil, currentStamp != initialStamp else {
                    continue
                }
                await self?.finishClaudeReauthWithSingleFetch()
                return
            }
            await self?.finishClaudeReauthWithSingleFetch()
        }
    }

    func reauthenticateCodex() {
        guard !codexReauthInProgress else { return }
        let initialStamp = CodexCredentials.authModificationStamp()
        guard CodexCredentials.spawnReauth() else { return }
        codexReauthInProgress = true
        codexReauthPollTask?.cancel()
        codexReauthPollTask = Task { [weak self, initialStamp] in
            for _ in 0..<40 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { return }
                let currentStamp = CodexCredentials.authModificationStamp()
                guard currentStamp != nil, currentStamp != initialStamp else {
                    continue
                }
                await self?.finishCodexReauthWithSingleFetch()
                return
            }
            await self?.finishCodexReauthWithSingleFetch()
        }
    }

    private func finishCodexReauthWithSingleFetch() async {
        let c = await UsageFetcher.fetchCodex()
        await MainActor.run {
            let mergedCodex = UsageStore.mergedUsage(existing: self.codex, fetched: c)
            self.codex = mergedCodex
            UsageStore.saveCachedSnapshot(
                claude: self.claude,
                codex: mergedCodex,
                fetchedClaude: false,
                fetchedCodex: true
            )
            self.refreshWarning = UsageStore.isErrorOnly(c) ? L10n.tr("Codex stale") : nil
            if !UsageStore.isErrorOnly(c) {
                self.lastUpdated = Date()
            }
            self.codexReauthInProgress = false
        }
    }

    private func finishClaudeReauthWithSingleFetch() async {
        let cl = await UsageFetcher.fetchClaude()
        await MainActor.run {
            let mergedClaude = UsageStore.mergedUsage(existing: self.claude, fetched: cl)
            self.claude = mergedClaude
            UsageStore.saveCachedSnapshot(
                claude: mergedClaude,
                codex: self.codex,
                fetchedClaude: true,
                fetchedCodex: false
            )
            self.refreshWarning = UsageStore.isErrorOnly(cl) ? L10n.tr("Claude stale") : nil
            if !UsageStore.isErrorOnly(cl) {
                self.lastUpdated = Date()
            }
            self.claudeReauthInProgress = false
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refresh()
        armTimer()
        // Re-arm whenever the user changes the refresh interval. We
        // dropFirst() the initial @Published replay so we don't re-fire
        // refresh() on subscription.
        intervalCancellable = RefreshIntervalStore.shared.$seconds
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.armTimer() }
            }
        startNetworkMonitor()
    }

    func stopAutoRefresh() {
        pollTimer?.invalidate()
        pollTimer = nil
        intervalCancellable?.cancel()
        intervalCancellable = nil
        netMonitor?.cancel()
        netMonitor = nil
        lastNetStatus = nil
    }

    private func armTimer() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Trigger an immediate refresh whenever the network transitions from
    /// unsatisfied to satisfied — closes the launch-at-login race where
    /// Wi-Fi is still associating when our first refresh fires. Without
    /// this, the panel sits at the empty cold-start state until the next
    /// scheduled poll (5–30 minutes away). The initial path callback fires
    /// with the current state and is deliberately ignored (lastNetStatus
    /// starts nil) — startAutoRefresh's own refresh() already covers
    /// cold-start, and acting on the initial callback would double-fire.
    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let was = self.lastNetStatus
                self.lastNetStatus = path.status
                guard path.status == .satisfied,
                      let prior = was, prior != .satisfied else { return }
                // Cancel any in-flight refresh — its URLSession call was
                // started on the dead path and is going to return an
                // error. Wait for it to finalize so its loading=false
                // lands before we start the replacement, otherwise our
                // refresh() hits the `if loading { return }` guard.
                self.refreshTask?.cancel()
                await self.refreshTask?.value
                self.refresh()
            }
        }
        monitor.start(queue: netQueue)
        netMonitor = monitor
    }
}
