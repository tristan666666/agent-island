import Foundation
import AppKit

/// Watches active Claude and Codex sessions and classifies each provider's
/// live state, so the island can react: a breathing logo while working, an
/// attention pulse when a turn finishes ("your turn"), and a red alarm + beep
/// when a session has frozen mid-turn ("stalled").
///
/// State is derived from two signals per transcript: the file's mtime (it
/// grows while the agent streams) and the last turn marker in the tail
/// (Claude: assistant `stop_reason == end_turn`; Codex: a `task_complete`
/// event vs a dangling `task_started`).
@MainActor
final class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()
    private init() {}

    enum State: Int { case idle, working, needsYou, stalled }

    @Published private(set) var claude: State = .idle
    @Published private(set) var codex: State = .idle

    func state(for provider: AlertEngine.Provider) -> State {
        provider == .claude ? claude : codex
    }

    /// File grew within this window → actively producing output.
    private let activeWindow: TimeInterval = 18
    /// Quiet mid-turn for this long → stuck.
    private let stallAfter: TimeInterval = 150
    /// Only sessions touched within this window count as "active".
    private let attentionWindow: TimeInterval = 30 * 60

    private var timer: Timer?

    func start() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        let newClaude = aggregate(scanClaude(now: now))
        if newClaude == .stalled && claude != .stalled { beep() }
        claude = newClaude

        let newCodex = aggregate(scanCodex(now: now))
        if newCodex == .stalled && codex != .stalled { beep() }
        codex = newCodex
    }

    // MARK: - State derivation

    private func sessionState(age: TimeInterval, turnDone: Bool) -> State {
        if age < activeWindow { return .working }
        if turnDone { return .needsYou }
        if age >= stallAfter { return .stalled }
        return .working   // recently quiet mid-turn (deep thinking / slow tool) — not yet stuck
    }

    private func aggregate(_ states: [State]) -> State {
        states.max(by: { $0.rawValue < $1.rawValue }) ?? .idle
    }

    // MARK: - Scans

    private func scanClaude(now: Date) -> [State] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/.claude/projects"
        guard let projects = try? fm.contentsOfDirectory(atPath: root) else { return [] }
        var states: [State] = []
        for project in projects {
            let dir = root + "/" + project
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".jsonl") {
                if let s = classify(dir + "/" + entry, now: now, turnDone: claudeTurnDone) { states.append(s) }
            }
        }
        return states
    }

    private func scanCodex(now: Date) -> [State] {
        let cal = Calendar.current
        var states: [State] = []
        for offset in 0...1 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let c = cal.dateComponents([.year, .month, .day], from: day)
            guard let y = c.year, let mo = c.month, let d = c.day else { continue }
            let dir = String(format: "%@/.codex/sessions/%04d/%02d/%02d", NSHomeDirectory(), y, mo, d)
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".jsonl") {
                if let s = classify(dir + "/" + entry, now: now, turnDone: codexTurnDone) { states.append(s) }
            }
        }
        return states
    }

    private func classify(_ path: String, now: Date, turnDone: ([String]) -> Bool) -> State? {
        guard let m = mtime(path) else { return nil }
        let age = now.timeIntervalSince(m)
        guard age <= attentionWindow else { return nil }
        return sessionState(age: age, turnDone: turnDone(tailLines(path)))
    }

    // MARK: - Turn markers

    private func claudeTurnDone(_ lines: [String]) -> Bool {
        for line in lines.reversed() {
            guard let object = json(line) else { continue }
            switch object["type"] as? String {
            case "assistant":
                let stop = (object["message"] as? [String: Any])?["stop_reason"] as? String
                return stop == "end_turn"
            case "user":
                return false
            default:
                continue
            }
        }
        return false
    }

    private func codexTurnDone(_ lines: [String]) -> Bool {
        for line in lines.reversed() {
            guard let object = json(line), object["type"] as? String == "event_msg",
                  let type = (object["payload"] as? [String: Any])?["type"] as? String else { continue }
            if type == "task_complete" { return true }
            if type == "task_started" { return false }
        }
        return false
    }

    // MARK: - Helpers

    private func tailLines(_ path: String, bytes: UInt64 = 65_536, keep: Int = 60) -> [String] {
        guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > bytes ? size - bytes : 0)
        let data = (try? handle.readToEnd()) ?? Data()
        return Array(String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).suffix(keep))
    }

    private func json(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func mtime(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
    }

    private var soundOn: Bool {
        UserDefaults.standard.object(forKey: "AgentIsland.stallSound") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "AgentIsland.stallSound")
    }

    private func beep() {
        guard soundOn else { return }
        NSSound.beep()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { NSSound.beep() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) { NSSound.beep() }
    }
}
