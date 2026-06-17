import Foundation

/// A resumable session discovered on disk, for the trigger picker.
struct ScannedSession: Identifiable, Hashable {
    var id: String { tool.rawValue + ":" + sessionId }
    let tool: TriggerTool
    let sessionId: String   // the id passed to `--resume` / `exec resume`
    let cwd: String
    let label: String       // clean display name
    let modified: Date
}

/// Discovers active Claude and Codex sessions. Claude names + archived state
/// come from the Claude desktop session store (so the picker shows real thread
/// titles like "MiniMax GEO project" and skips archived threads). Codex has no
/// titled store, so we fall back to the project folder name, one per project.
enum SessionScanner {
    static func scan() -> [ScannedSession] {
        var out = scanClaude()
        out += scanCodex()
        out.sort { $0.modified > $1.modified }
        return out
    }

    // MARK: - Claude: desktop session store (titles + archived flag)

    private static func scanClaude() -> [ScannedSession] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/Library/Application Support/Claude/claude-code-sessions"
        guard let enumerator = fm.enumerator(atPath: root) else { return [] }
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
            out.append(ScannedSession(
                tool: .claude,
                sessionId: resume,
                cwd: cwd,
                label: title.isEmpty ? fallback(cwd, resume) : title,
                modified: Date(timeIntervalSince1970: ms / 1000)
            ))
        }
        return out
    }

    // MARK: - Codex: ~/.codex/sessions, one entry per project folder

    private static func scanCodex(limit: Int = 30) -> [ScannedSession] {
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
                modified: mtime(path)
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

    private static func mtime(_ path: String) -> Date {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date else { return .distantPast }
        return date
    }
}
