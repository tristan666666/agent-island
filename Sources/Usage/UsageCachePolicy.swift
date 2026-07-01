import Foundation

struct UsageCacheSnapshot: Codable {
    var claude: AppUsage
    var codex: AppUsage
    var updatedAt: Date
    var claudeUpdatedAt: Date?
    var codexUpdatedAt: Date?

    init(claude: AppUsage,
         codex: AppUsage,
         updatedAt: Date,
         claudeUpdatedAt: Date? = nil,
         codexUpdatedAt: Date? = nil) {
        self.claude = claude
        self.codex = codex
        self.updatedAt = updatedAt
        self.claudeUpdatedAt = claudeUpdatedAt ?? updatedAt
        self.codexUpdatedAt = codexUpdatedAt ?? updatedAt
    }
}

enum UsageCachePolicy {
    static func snapshotForSave(claude: AppUsage,
                                codex: AppUsage,
                                existing: UsageCacheSnapshot?,
                                now: Date,
                                fetchedClaude: Bool = true,
                                fetchedCodex: Bool = true) -> UsageCacheSnapshot? {
        let claudeCandidate = providerForSave(
            current: claude,
            wasFetched: fetchedClaude,
            existing: existing?.claude,
            existingUpdatedAt: existing?.claudeUpdatedAt ?? existing?.updatedAt,
            now: now
        )
        let codexCandidate = providerForSave(
            current: codex,
            wasFetched: fetchedCodex,
            existing: existing?.codex,
            existingUpdatedAt: existing?.codexUpdatedAt ?? existing?.updatedAt,
            now: now
        )
        guard claudeCandidate?.isFresh == true || codexCandidate?.isFresh == true else { return nil }

        let snapshot = UsageCacheSnapshot(
            claude: claudeCandidate?.usage ?? .empty,
            codex: codexCandidate?.usage ?? .empty,
            updatedAt: max(claudeCandidate?.updatedAt, codexCandidate?.updatedAt) ?? now,
            claudeUpdatedAt: claudeCandidate?.updatedAt,
            codexUpdatedAt: codexCandidate?.updatedAt
        )
        return snapshot
    }

    static func restoredSnapshot(_ snapshot: UsageCacheSnapshot,
                                 now: Date,
                                 maxAge: TimeInterval) -> UsageCacheSnapshot? {
        guard now.timeIntervalSince(snapshot.updatedAt) <= maxAge else { return nil }
        let claudeCopy = restoredProvider(
            snapshot.claude,
            providerUpdatedAt: snapshot.claudeUpdatedAt,
            fallbackUpdatedAt: snapshot.updatedAt,
            now: now,
            maxAge: maxAge
        )
        let codexCopy = restoredProvider(
            snapshot.codex,
            providerUpdatedAt: snapshot.codexUpdatedAt,
            fallbackUpdatedAt: snapshot.updatedAt,
            now: now,
            maxAge: maxAge
        )
        guard claudeCopy != nil || codexCopy != nil else { return nil }
        return UsageCacheSnapshot(
            claude: claudeCopy ?? .empty,
            codex: codexCopy ?? .empty,
            updatedAt: max(snapshot.claudeUpdatedAt, snapshot.codexUpdatedAt) ?? snapshot.updatedAt,
            claudeUpdatedAt: claudeCopy == nil ? nil : (snapshot.claudeUpdatedAt ?? snapshot.updatedAt),
            codexUpdatedAt: codexCopy == nil ? nil : (snapshot.codexUpdatedAt ?? snapshot.updatedAt)
        )
    }

    static func cacheableCopy(_ usage: AppUsage) -> AppUsage? {
        guard usage.fiveHour.error == nil,
              usage.weekly.error == nil,
              hasUsageValues(usage) else {
            return nil
        }
        return AppUsage(
            fiveHour: WindowUsage(
                usedPercent: usage.fiveHour.usedPercent,
                resetAt: usage.fiveHour.resetAt,
                error: nil
            ),
            weekly: WindowUsage(
                usedPercent: usage.weekly.usedPercent,
                resetAt: usage.weekly.resetAt,
                error: nil
            ),
            plan: usage.plan
        )
    }

    private static func hasUsageValues(_ usage: AppUsage) -> Bool {
        usage.fiveHour.usedPercent > 0
            || usage.weekly.usedPercent > 0
            || usage.fiveHour.resetAt != nil
            || usage.weekly.resetAt != nil
    }

    private static func providerForSave(current: AppUsage,
                                        wasFetched: Bool,
                                        existing: AppUsage?,
                                        existingUpdatedAt: Date?,
                                        now: Date) -> (usage: AppUsage, updatedAt: Date, isFresh: Bool)? {
        if wasFetched, let copy = cacheableCopy(current) {
            return (copy, now, true)
        }
        guard let existing,
              let existingUpdatedAt,
              let copy = cacheableCopy(existing) else {
            return nil
        }
        return (copy, existingUpdatedAt, false)
    }

    private static func restoredProvider(_ usage: AppUsage,
                                         providerUpdatedAt: Date?,
                                         fallbackUpdatedAt: Date,
                                         now: Date,
                                         maxAge: TimeInterval) -> AppUsage? {
        let updatedAt = providerUpdatedAt ?? fallbackUpdatedAt
        guard now.timeIntervalSince(updatedAt) <= maxAge else { return nil }
        return cacheableCopy(usage)
    }

    private static func max(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (left?, right?): return left > right ? left : right
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }
}
