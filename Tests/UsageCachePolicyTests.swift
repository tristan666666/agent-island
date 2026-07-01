import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message): return message
        }
    }
}

@discardableResult
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws -> Bool {
    guard condition() else { throw TestFailure.assertion(message) }
    return true
}

private func usage(fiveHour: Double = 0,
                   weekly: Double = 0,
                   fiveHourReset: Date? = nil,
                   weeklyReset: Date? = nil,
                   fiveHourError: String? = nil,
                   weeklyError: String? = nil,
                   plan: String? = nil) -> AppUsage {
    AppUsage(
        fiveHour: WindowUsage(
            usedPercent: fiveHour,
            resetAt: fiveHourReset,
            error: fiveHourError
        ),
        weekly: WindowUsage(
            usedPercent: weekly,
            resetAt: weeklyReset,
            error: weeklyError
        ),
        plan: plan
    )
}

private func testErrorBearingPreservedUsageIsNotCacheableAndDoesNotRenew() throws {
    let oldDate = Date(timeIntervalSince1970: 1_000)
    let now = Date(timeIntervalSince1970: 2_000)
    let existing = UsageCacheSnapshot(
        claude: usage(fiveHour: 0.64, weekly: 0.27, plan: "max"),
        codex: usage(fiveHour: 0.41, weekly: 0.19, plan: "pro"),
        updatedAt: oldDate
    )
    let preservedAfterFailure = usage(
        fiveHour: 0.64,
        weekly: 0.27,
        fiveHourError: "rate limited",
        weeklyError: "rate limited",
        plan: "max"
    )

    try expect(
        UsageCachePolicy.cacheableCopy(preservedAfterFailure) == nil,
        "error-bearing preserved usage must not produce a cache copy"
    )
    try expect(
        UsageCachePolicy.snapshotForSave(
            claude: preservedAfterFailure,
            codex: usage(plan: "pro"),
            existing: existing,
            now: now
        ) == nil,
        "failed refresh must not renew an existing snapshot timestamp"
    )
}

private func testPlanOnlyNoDataIsNotCacheableOrRestorable() throws {
    let planOnly = usage(plan: "pro")

    try expect(
        UsageCachePolicy.cacheableCopy(planOnly) == nil,
        "plan-only 0% usage must not be cacheable"
    )

    let restored = UsageCachePolicy.restoredSnapshot(
        UsageCacheSnapshot(claude: planOnly, codex: .empty, updatedAt: Date(timeIntervalSince1970: 1_000)),
        now: Date(timeIntervalSince1970: 1_100),
        maxAge: 24 * 60 * 60
    )
    try expect(restored == nil, "plan-only/no-data snapshots must not restore as clean 0%")
}

private func testRealUsageCachesAndStripsOnlyFreshNoErrorUsage() throws {
    let reset = Date(timeIntervalSince1970: 3_000)
    let fresh = usage(fiveHour: 0.12, weekly: 0, fiveHourReset: reset, plan: "pro")
    let copy = UsageCachePolicy.cacheableCopy(fresh)

    try expect(copy != nil, "fresh real usage must be cacheable")
    try expect(copy?.fiveHour.usedPercent == 0.12, "cache copy should preserve percent")
    try expect(copy?.fiveHour.resetAt == reset, "cache copy should preserve reset")
    try expect(copy?.fiveHour.error == nil && copy?.weekly.error == nil, "cache copy should strip errors")

    let withError = usage(fiveHour: 0.12, fiveHourReset: reset, fiveHourError: "stale", plan: "pro")
    try expect(
        UsageCachePolicy.cacheableCopy(withError) == nil,
        "error-bearing real usage must not cache as fresh"
    )
}

private func testMixedProviderPreservesExistingOnlyWhenPeerIsFresh() throws {
    let oldDate = Date(timeIntervalSince1970: 1_000)
    let now = Date(timeIntervalSince1970: 2_000)
    let existing = UsageCacheSnapshot(
        claude: usage(fiveHour: 0.74, weekly: 0.35, plan: "max"),
        codex: usage(fiveHour: 0.44, weekly: 0.22, plan: "pro"),
        updatedAt: oldDate
    )

    let freshClaude = usage(fiveHour: 0.82, weekly: 0.38, plan: "max")
    let updated = UsageCachePolicy.snapshotForSave(
        claude: freshClaude,
        codex: usage(fiveHourError: "offline", weeklyError: "offline", plan: "pro"),
        existing: existing,
        now: now
    )

    try expect(updated != nil, "fresh provider should allow snapshot save")
    try expect(updated?.claudeUpdatedAt == now, "fresh provider should renew only its own timestamp")
    try expect(updated?.codexUpdatedAt == oldDate, "failed provider should keep its original cache timestamp")
    try expect(updated?.claude.fiveHour.usedPercent == 0.82, "fresh provider should be updated")
    try expect(updated?.codex.fiveHour.usedPercent == 0.44, "other provider should be preserved from existing cache")

    let noFreshProvider = UsageCachePolicy.snapshotForSave(
        claude: usage(fiveHourError: "offline", weeklyError: "offline", plan: "max"),
        codex: usage(plan: "pro"),
        existing: existing,
        now: now
    )
    try expect(
        noFreshProvider == nil,
        "existing provider values should not be preserved when neither current provider has fresh data"
    )
}

private func testSingleProviderSaveDoesNotRenewUnfetchedPeer() throws {
    let oldDate = Date(timeIntervalSince1970: 1_000)
    let now = Date(timeIntervalSince1970: 2_000)
    let existing = UsageCacheSnapshot(
        claude: usage(fiveHour: 0.74, weekly: 0.35, plan: "max"),
        codex: usage(fiveHour: 0.44, weekly: 0.22, plan: "pro"),
        updatedAt: oldDate
    )

    let currentClaudeThatWasNotFetched = usage(fiveHour: 0.91, weekly: 0.64, plan: "max")
    let freshlyFetchedCodex = usage(fiveHour: 0.18, weekly: 0.07, plan: "pro")
    let updated = UsageCachePolicy.snapshotForSave(
        claude: currentClaudeThatWasNotFetched,
        codex: freshlyFetchedCodex,
        existing: existing,
        now: now,
        fetchedClaude: false,
        fetchedCodex: true
    )

    try expect(updated != nil, "fresh single-provider fetch should save a snapshot")
    try expect(updated?.codexUpdatedAt == now, "fetched provider should renew its own timestamp")
    try expect(updated?.claudeUpdatedAt == oldDate, "unfetched peer must keep its original timestamp")
    try expect(updated?.claude.fiveHour.usedPercent == 0.74, "unfetched peer must be preserved from cache")
    try expect(updated?.codex.fiveHour.usedPercent == 0.18, "fetched provider should be updated")
}

@main
private enum UsageCachePolicyTestRunner {
    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("error-bearing preserved usage is not cacheable", testErrorBearingPreservedUsageIsNotCacheableAndDoesNotRenew),
            ("plan-only no-data is not cacheable", testPlanOnlyNoDataIsNotCacheableOrRestorable),
            ("real usage caches only when fresh", testRealUsageCachesAndStripsOnlyFreshNoErrorUsage),
            ("mixed provider preserve policy", testMixedProviderPreservesExistingOnlyWhenPeerIsFresh),
            ("single-provider save does not renew peer", testSingleProviderSaveDoesNotRenewUnfetchedPeer)
        ]

        do {
            for (name, test) in tests {
                try test()
                print("PASS \(name)")
            }
            print("UsageCachePolicyTests GREEN")
        } catch {
            fputs("UsageCachePolicyTests RED: \(error)\n", stderr)
            exit(1)
        }
    }
}
