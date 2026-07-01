import Foundation

extension SessionScanner {
    private static let monitoringCodexLimit = 120

    static func monitoringScan(now: Date = Date(), lastWorking: [String: Date] = [:]) -> [ScannedSession] {
        var out = scanClaudeTranscripts(now: now, lastWorking: lastWorking)
        out += scanCodex(
            now: now,
            lastWorking: lastWorking,
            limit: monitoringCodexLimit,
            dedupeProjects: false
        )
        out.sort { $0.modified > $1.modified }
        return out
    }

    private static func scanClaudeTranscripts(now: Date, lastWorking: [String: Date]) -> [ScannedSession] {
        let desktopSessions = claudeDesktopIndex()
        return claudeTranscriptIndex().map { sid, path in
            let desktop = desktopSessions[sid]
            let cwd = desktop?.cwd ?? projectFromClaudeTranscript(path)
            let title = desktop?.title ?? ""
            let state = sessionState(for: path, now: now, lastWorking: lastWorking, turnState: SessionTurnState.claude)
            return ScannedSession(
                tool: .claude,
                sessionId: sid,
                cwd: cwd,
                label: title.isEmpty ? fallback(cwd, sid) : title,
                modified: mtime(path),
                status: state.status,
                transcriptPath: path,
                turnKey: state.turnKey
            )
        }
    }

    private static func claudeDesktopIndex() -> [String: (title: String, cwd: String)] {
        let root = NSHomeDirectory() + "/Library/Application Support/Claude/claude-code-sessions"
        guard let enumerator = FileManager.default.enumerator(atPath: root) else { return [:] }
        var out: [String: (title: String, cwd: String)] = [:]
        for case let rel as String in enumerator
        where rel.hasSuffix(".json") && (rel as NSString).lastPathComponent.hasPrefix("local_") {
            let path = root + "/" + rel
            guard let data = FileManager.default.contents(atPath: path),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sid = object["cliSessionId"] as? String,
                  !sid.isEmpty
            else { continue }
            out[sid] = (object["title"] as? String ?? "", object["cwd"] as? String ?? "")
        }
        return out
    }

    private static func projectFromClaudeTranscript(_ path: String) -> String {
        let parent = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
        let name = parent.replacingOccurrences(of: "-", with: "/")
        return name.isEmpty ? "" : "/" + name
    }
}
