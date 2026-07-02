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

private func testClaudeUserAfterAssistantIsNotNeedsYou() throws {
    let expected = try date("2026-07-02T01:15:42.000Z")
    let lines = [
        #"{"type":"assistant","uuid":"a1","timestamp":"2026-06-25T16:27:50.585Z","message":{"stop_reason":"end_turn"}}"#,
        #"{"type":"custom-title","sessionId":"s1"}"#,
        #"{"type":"user","uuid":"u2","timestamp":"2026-07-02T01:15:42.000Z","message":{"role":"user","content":"next turn"}}"#
    ]
    let state = SessionTurnState.claude(lines)
    try expect(state.isDone == false, "new user turn after assistant must suppress stale needs-you")
    try expect(state.key == "u2", "latest user event should become the turn key")
    try expect(state.activityDate == expected, "latest user event should carry its timestamp")
}

private func testClaudeMetadataAfterAssistantKeepsAssistantTurnKey() throws {
    let expected = try date("2026-06-25T16:27:50.585Z")
    let lines = [
        #"{"type":"assistant","uuid":"a1","timestamp":"2026-06-25T16:27:50.585Z","message":{"stop_reason":"end_turn"}}"#,
        #"{"type":"mode","sessionId":"s1"}"#,
        #"{"type":"custom-title","sessionId":"s1"}"#
    ]
    let state = SessionTurnState.claude(lines)
    try expect(state.isDone == true, "metadata after assistant should not hide a completed turn")
    try expect(state.key == "a1", "metadata writes should not create a new delivery key")
    try expect(state.activityDate == expected, "metadata writes should not change semantic activity time")
}

private func testCodexUserAfterTaskCompleteIsNotNeedsYou() throws {
    let expected = try date("2026-07-02T01:15:42.000Z")
    let lines = [
        #"{"timestamp":"2026-07-02T01:14:00.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"t1"}}"#,
        #"{"timestamp":"2026-07-02T01:15:42.000Z","type":"event_msg","payload":{"type":"user_message","turn_id":"t2","message":"next"}}"#
    ]
    let state = SessionTurnState.codex(lines)
    try expect(state.isDone == false, "new codex user message after task complete must suppress stale needs-you")
    try expect(state.key == "t2", "latest codex user event should become the turn key")
    try expect(state.activityDate == expected, "latest codex user event should carry its timestamp")
}

private func testCodexTaskStartedAfterTaskCompleteIsNotNeedsYou() throws {
    let lines = [
        #"{"type":"event_msg","payload":{"type":"task_complete","turn_id":"t1"}}"#,
        #"{"type":"event_msg","payload":{"type":"task_started","turn_id":"t2"}}"#
    ]
    let state = SessionTurnState.codex(lines)
    try expect(state.isDone == false, "new codex task start after completion must suppress stale needs-you")
    try expect(state.key == "t2", "latest codex task start should become the turn key")
}

private func testCodexTaskCompleteIsNeedsYou() throws {
    let lines = [
        #"{"timestamp":"2026-07-02T01:14:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"t1"}}"#,
        #"{"timestamp":"2026-07-02T01:15:42.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"t1"}}"#
    ]
    let state = SessionTurnState.codex(lines)
    try expect(state.isDone == true, "codex task complete should be needs-you")
    try expect(state.key == "t1", "completed codex task should keep its turn id")
}

private func testMetadataTouchedOldClaudeTranscriptIsIdle() throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("agent-island-session-state-\(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: tmp) }
    let old = try date("2026-06-25T16:27:50.585Z")
    let now = try date("2026-07-02T01:15:42.000Z")
    let lines = [
        #"{"type":"assistant","uuid":"a1","timestamp":"2026-06-25T16:27:50.585Z","message":{"stop_reason":"end_turn"}}"#,
        #"{"type":"custom-title","sessionId":"s1"}"#,
        #"{"type":"mode","sessionId":"s1"}"#
    ].joined(separator: "\n")
    try lines.write(to: tmp, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: tmp.path)
    let state = SessionScanner.sessionState(
        for: tmp.path,
        now: now,
        lastWorking: [:],
        turnState: SessionTurnState.claude
    )
    try expect(state.status == .idle, "metadata-only file writes must not resurrect old completed Claude turns")
    try expect(state.modified == old, "semantic modified time should come from the last real turn")
}

private func date(_ raw: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: raw) else {
        throw TestFailure.assertion("bad test date \(raw)")
    }
    return date
}

@main
private enum SessionTurnStateTestRunner {
    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("claude user after assistant suppresses stale alarm", testClaudeUserAfterAssistantIsNotNeedsYou),
            ("claude metadata does not change turn key", testClaudeMetadataAfterAssistantKeepsAssistantTurnKey),
            ("codex user after complete suppresses stale alarm", testCodexUserAfterTaskCompleteIsNotNeedsYou),
            ("codex start after complete suppresses stale alarm", testCodexTaskStartedAfterTaskCompleteIsNotNeedsYou),
            ("codex complete still triggers needs-you", testCodexTaskCompleteIsNeedsYou),
            ("metadata-touched old claude transcript is idle", testMetadataTouchedOldClaudeTranscriptIsIdle)
        ]

        do {
            for (name, test) in tests {
                try test()
                print("PASS \(name)")
            }
            print("SessionTurnStateTests GREEN")
        } catch {
            fputs("SessionTurnStateTests RED: \(error)\n", stderr)
            exit(1)
        }
    }
}
