import Foundation

/// A resumable session discovered on disk, for the trigger picker.
struct ScannedSession: Identifiable, Hashable {
    var id: String { tool.rawValue + ":" + sessionId }
    let tool: TriggerTool
    let sessionId: String
    let cwd: String
    let label: String
    let modified: Date
}

/// Discovers Claude Code and Codex sessions from their on-disk transcript
/// stores so a trigger can target any thread of either tool. Pure file IO —
/// call off the main thread.
enum SessionScanner {
    static func scan(limitPerTool: Int = 30) -> [ScannedSession] {
        var out = scanClaude(limit: limitPerTool)
        out += scanCodex(limit: limitPerTool)
        out.sort { $0.modified > $1.modified }
        return out
    }

    // MARK: - Claude: ~/.claude/projects/<slug>/<session-uuid>.jsonl

    private static func scanClaude(limit: Int) -> [ScannedSession] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/.claude/projects"
        guard let projects = try? fm.contentsOfDirectory(atPath: root) else { return [] }
        var files: [String] = []
        for project in projects {
            let dir = root + "/" + project
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".jsonl") {
                files.append(dir + "/" + entry)
            }
        }
        files.sort { mtime($0) > mtime($1) }
        return files.prefix(limit).map { path in
            let sid = (path as NSString).lastPathComponent
                .replacingOccurrences(of: ".jsonl", with: "")
            let (cwd, label) = claudeMeta(path)
            return ScannedSession(
                tool: .claude,
                sessionId: sid,
                cwd: cwd,
                label: label.isEmpty ? fallbackLabel(cwd, sid) : label,
                modified: mtime(path)
            )
        }
    }

    private static func claudeMeta(_ path: String) -> (cwd: String, label: String) {
        var cwd = "", label = ""
        for line in headLines(path) {
            guard let object = jsonObject(line) else { continue }
            if cwd.isEmpty, let c = object["cwd"] as? String { cwd = c }
            if label.isEmpty,
               object["type"] as? String == "user",
               let message = object["message"] as? [String: Any] {
                label = extractText(message["content"])
            }
            if !cwd.isEmpty && !label.isEmpty { break }
        }
        return (cwd, label)
    }

    // MARK: - Codex: ~/.codex/sessions/Y/M/D/rollout-<ts>-<uuid>.jsonl

    private static func scanCodex(limit: Int) -> [ScannedSession] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/.codex/sessions"
        guard let enumerator = fm.enumerator(atPath: root) else { return [] }
        var files: [String] = []
        for case let rel as String in enumerator where rel.hasSuffix(".jsonl") {
            files.append(root + "/" + rel)
        }
        files.sort { mtime($0) > mtime($1) }
        return files.prefix(limit).compactMap { codexSession($0) }
    }

    private static func codexSession(_ path: String) -> ScannedSession? {
        var sid = "", cwd = "", label = ""
        for line in headLines(path) {
            guard let object = jsonObject(line) else { continue }
            let type = object["type"] as? String
            if type == "session_meta", let payload = object["payload"] as? [String: Any] {
                if let id = payload["id"] as? String { sid = id }
                if let c = payload["cwd"] as? String { cwd = c }
            }
            if label.isEmpty,
               type == "response_item",
               let payload = object["payload"] as? [String: Any],
               payload["type"] as? String == "message",
               payload["role"] as? String == "user" {
                label = extractText(payload["content"])
            }
            if !sid.isEmpty && !cwd.isEmpty && !label.isEmpty { break }
        }
        guard !sid.isEmpty else { return nil }
        return ScannedSession(
            tool: .codex,
            sessionId: sid,
            cwd: cwd,
            label: label.isEmpty ? fallbackLabel(cwd, sid) : label,
            modified: mtime(path)
        )
    }

    // MARK: - Helpers

    /// Read only the first chunk — session metadata and the first user message
    /// live near the top, and some Claude transcripts are tens of MB.
    private static func headLines(_ path: String, bytes: Int = 131_072) -> [Substring] {
        guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: bytes)) ?? Data()
        guard !data.isEmpty else { return [] }
        let text = String(decoding: data, as: UTF8.self)
        return text.split(separator: "\n")
    }

    private static func jsonObject(_ line: Substring) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func extractText(_ content: Any?) -> String {
        if let string = content as? String { return clean(string) }
        if let parts = content as? [[String: Any]] {
            for part in parts {
                let type = part["type"] as? String ?? ""
                if type == "text" || type == "input_text", let text = part["text"] as? String {
                    let cleaned = clean(text)
                    if !cleaned.isEmpty { return cleaned }
                }
            }
        }
        return ""
    }

    /// Drops tool/system-injected blocks (which start with a tag like
    /// `<command…>` or `#` AGENTS preambles) so labels read like real prompts.
    private static func clean(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("<"), !trimmed.hasPrefix("#") else { return "" }
        return String(trimmed.prefix(60))
    }

    private static func fallbackLabel(_ cwd: String, _ sid: String) -> String {
        let base = (cwd as NSString).lastPathComponent
        return base.isEmpty ? String(sid.prefix(8)) : base
    }

    private static func mtime(_ path: String) -> Date {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date else { return .distantPast }
        return date
    }
}
