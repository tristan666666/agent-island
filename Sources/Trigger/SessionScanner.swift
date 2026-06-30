import Foundation

/// A resumable session discovered on disk, for the trigger picker.
struct ScannedSession: Identifiable, Hashable {
    var id: String { tool.rawValue + ":" + sessionId }
    let tool: TriggerTool
    let sessionId: String   // the id passed to `--resume` / `exec resume`
    let cwd: String
    let label: String       // clean display name
    let modified: Date
    let status: ActivityMonitor.State
    let transcriptPath: String?
}

/// Discovers active Claude and Codex sessions. Claude names + archived state
/// come from the Claude desktop session store (so the picker shows real thread
/// titles like "MiniMax GEO project" and skips archived threads). Codex has no
/// titled store, so we fall back to the project folder name, one per project.
enum SessionScanner {
    static func scan() -> [ScannedSession] {
        let now = Date()
        var out = scanClaude(now: now)
        out += scanCodex(now: now)
        out.sort { $0.modified > $1.modified }
        return out
    }

    // MARK: - Claude: desktop session store (titles + archived flag)

    private static func scanClaude(now: Date) -> [ScannedSession] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/Library/Application Support/Claude/claude-code-sessions"
        guard let enumerator = fm.enumerator(atPath: root) else { return [] }
        let transcripts = claudeTranscriptIndex()
        var out: [ScannedSession] = []
        for case let rel as String in enumerator
        where rel.hasSuffix(".json") && (rel as NSString).lastPathComponent.hasPrefix("local_") {
            let path = root + "/" + rel
            guard let data = fm.contents(atPath: path),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            // Skip archived threads — the picker only lists active ones.
            if object["isArchived"] as? Bool == true { continue }
            guard let resume = object["cliSessionId"] as? String, !resume.isEmpty else { continue }
            let cwd = object["cwd"] as? String ?? ""
            let title = object["title"] as? String ?? ""
            let ms = (object["lastActivityAt"] as? Double) ?? (object["createdAt"] as? Double) ?? 0
            let transcript = transcripts[resume]
            out.append(ScannedSession(
                tool: .claude,
                sessionId: resume,
                cwd: cwd,
                label: title.isEmpty ? fallback(cwd, resume) : title,
                modified: transcript.map(mtime) ?? Date(timeIntervalSince1970: ms / 1000),
                status: status(for: transcript, now: now, turnDone: claudeTurnDone),
                transcriptPath: transcript
            ))
        }
        return out
    }

    // MARK: - Codex: ~/.codex/sessions, one entry per project folder

    private static func scanCodex(now: Date, limit: Int = 30) -> [ScannedSession] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/.codex/sessions"
        guard let enumerator = fm.enumerator(atPath: root) else { return [] }
        var files: [String] = []
        for case let rel as String in enumerator where rel.hasSuffix(".jsonl") {
            files.append(root + "/" + rel)
        }
        files.sort { mtime($0) > mtime($1) }
        var out: [ScannedSession] = []
        var seenProjects = Set<String>()
        for path in files {
            guard let (sid, cwd) = codexMeta(path), !sid.isEmpty else { continue }
            let projectKey = cwd.isEmpty ? sid : cwd
            if seenProjects.contains(projectKey) { continue }
            seenProjects.insert(projectKey)
            out.append(ScannedSession(
                tool: .codex,
                sessionId: sid,
                cwd: cwd,
                label: cwd.isEmpty ? String(sid.prefix(8)) : (cwd as NSString).lastPathComponent,
                modified: mtime(path),
                status: status(for: path, now: now, turnDone: codexTurnDone),
                transcriptPath: path
            ))
            if out.count >= limit { break }
        }
        return out
    }

    /// Reads the first JSONL line in full. Codex's `session_meta` is line 1 but
    /// can be tens of KB (it embeds the full base instructions), so a fixed-size
    /// read truncates it — keep pulling chunks until the first newline.
    private static func codexMeta(_ path: String) -> (String, String)? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var buffer = Data()
        while buffer.firstIndex(of: 0x0A) == nil {
            guard let chunk = try? handle.read(upToCount: 65_536), !chunk.isEmpty else { break }
            buffer.append(chunk)
            if buffer.count > 2_000_000 { break }
        }
        let firstLine = buffer.firstIndex(of: 0x0A).map { buffer.prefix(upTo: $0) } ?? buffer.prefix(buffer.count)
        guard let object = try? JSONSerialization.jsonObject(with: Data(firstLine)) as? [String: Any],
              object["type"] as? String == "session_meta",
              let payload = object["payload"] as? [String: Any]
        else { return nil }
        return (payload["id"] as? String ?? "", payload["cwd"] as? String ?? "")
    }

    // MARK: - Helpers

    private static func fallback(_ cwd: String, _ sid: String) -> String {
        let base = (cwd as NSString).lastPathComponent
        return base.isEmpty ? String(sid.prefix(8)) : base
    }

    private static func claudeTranscriptIndex() -> [String: String] {
        let root = NSHomeDirectory() + "/.claude/projects"
        guard let enumerator = FileManager.default.enumerator(atPath: root) else { return [:] }
        var out: [String: String] = [:]
        for case let rel as String in enumerator where rel.hasSuffix(".jsonl") {
            let path = root + "/" + rel
            let sid = ((rel as NSString).lastPathComponent as NSString).deletingPathExtension
            out[sid] = path
        }
        return out
    }

    private static func status(
        for path: String?,
        now: Date,
        turnDone: ([String]) -> Bool
    ) -> ActivityMonitor.State {
        guard let path else { return .idle }
        let age = now.timeIntervalSince(mtime(path))
        if age > 30 * 60 { return .idle }
        let lines = tailLines(path)
        if age < 18 { return .working }
        if turnDone(lines) { return age < 20 * 60 ? .needsYou : .idle }
        if age < 5 * 60 { return .working }
        return age < 15 * 60 ? .stalled : .idle
    }

    private static func claudeTurnDone(_ lines: [String]) -> Bool {
        for line in lines.reversed() {
            guard let object = json(line), object["type"] as? String == "assistant" else { continue }
            let stop = (object["message"] as? [String: Any])?["stop_reason"] as? String
            return stop == "end_turn" || stop == "stop_sequence" || stop == "stop"
        }
        return false
    }

    private static func codexTurnDone(_ lines: [String]) -> Bool {
        for line in lines.reversed() {
            guard let object = json(line), object["type"] as? String == "event_msg",
                  let type = (object["payload"] as? [String: Any])?["type"] as? String else { continue }
            if type == "task_complete" { return true }
            if type == "task_started" { return false }
        }
        return false
    }

    private static func tailLines(_ path: String, bytes: UInt64 = 131_072, keep: Int = 200) -> [String] {
        guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > bytes ? size - bytes : 0)
        let data = (try? handle.readToEnd()) ?? Data()
        return Array(String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).suffix(keep))
    }

    private static func json(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func mtime(_ path: String) -> Date {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date else { return .distantPast }
        return date
    }
}
