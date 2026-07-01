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
    let lines = [
        #"{"type":"assistant","uuid":"a1","message":{"stop_reason":"end_turn"}}"#,
        #"{"type":"custom-title","sessionId":"s1"}"#,
        #"{"type":"user","uuid":"u2","message":{"role":"user","content":"next turn"}}"#
    ]
    let state = SessionTurnState.claude(lines)
    try expect(state.isDone == false, "new user turn after assistant must suppress stale needs-you")
    try expect(state.key == "u2", "latest user event should become the turn key")
}

private func testClaudeMetadataAfterAssistantKeepsAssistantTurnKey() throws {
    let lines = [
        #"{"type":"assistant","uuid":"a1","message":{"stop_reason":"end_turn"}}"#,
        #"{"type":"mode","sessionId":"s1"}"#,
        #"{"type":"custom-title","sessionId":"s1"}"#
    ]
    let state = SessionTurnState.claude(lines)
    try expect(state.isDone == true, "metadata after assistant should not hide a completed turn")
    try expect(state.key == "a1", "metadata writes should not create a new delivery key")
}

private func testCodexUserAfterTaskCompleteIsNotNeedsYou() throws {
    let lines = [
        #"{"type":"event_msg","payload":{"type":"task_complete","turn_id":"t1"}}"#,
        #"{"type":"event_msg","payload":{"type":"user_message","turn_id":"t2","message":"next"}}"#
    ]
    let state = SessionTurnState.codex(lines)
    try expect(state.isDone == false, "new codex user message after task complete must suppress stale needs-you")
    try expect(state.key == "t2", "latest codex user event should become the turn key")
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
        #"{"type":"event_msg","payload":{"type":"task_started","turn_id":"t1"}}"#,
        #"{"type":"event_msg","payload":{"type":"task_complete","turn_id":"t1"}}"#
    ]
    let state = SessionTurnState.codex(lines)
    try expect(state.isDone == true, "codex task complete should be needs-you")
    try expect(state.key == "t1", "completed codex task should keep its turn id")
}

@main
private enum SessionTurnStateTestRunner {
    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("claude user after assistant suppresses stale alarm", testClaudeUserAfterAssistantIsNotNeedsYou),
            ("claude metadata does not change turn key", testClaudeMetadataAfterAssistantKeepsAssistantTurnKey),
            ("codex user after complete suppresses stale alarm", testCodexUserAfterTaskCompleteIsNotNeedsYou),
            ("codex start after complete suppresses stale alarm", testCodexTaskStartedAfterTaskCompleteIsNotNeedsYou),
            ("codex complete still triggers needs-you", testCodexTaskCompleteIsNeedsYou)
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
