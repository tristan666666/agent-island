import Foundation
import AppKit

/// Watches active Claude and Codex sessions and classifies each provider's
/// live state, so the island can react: a breathing logo while working, a spin
/// when a turn finishes (your turn), and a red alarm + beep when a session has
/// frozen mid-turn (stalled).
///
/// Stall detection is deliberately conservative: a session is only ever marked
/// stalled if we watched it go from actively producing to frozen mid-turn,
/// within a bounded window. Sessions that were already quiet (old / abandoned /
/// never observed working) never flash red — that was the confusing case.
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

    private let activeWindow: TimeInterval = 18      // file grew within → working
    private let stallAfter: TimeInterval = 180       // frozen mid-turn this long → stalled
    private let stallCap: TimeInterval = 12 * 60     // beyond this, it's idle, not an active stall
    private let needsYouCap: TimeInterval = 20 * 60  // "your turn" only stays fresh this long
    private let attentionWindow: TimeInterval = 30 * 60

    /// path → last time we saw the transcript actively growing. A session is
    /// only "stalled" if it's in here (we watched it work) and then froze.
    private var lastWorking: [String: Date] = [:]
    private var timer: Timer?

    func start() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        let c = aggregate(scan(files: claudeFiles(), now: now, turnDone: claudeTurnDone))
        if c == .stalled && claude != .stalled { beep() }
        claude = c

        let x = aggregate(scan(files: codexFiles(now: now), now: now, turnDone: codexTurnDone))
        if x == .stalled && codex != .stalled { beep() }
        codex = x
    }

    private func aggregate(_ states: [State]) -> State {
        states.max(by: { $0.rawValue < $1.rawValue }) ?? .idle
    }

    private func scan(files: [String], now: Date, turnDone: ([String]) -> Bool) -> [State] {
        var out: [State] = []
        for path in files {
            guard let m = mtime(path) else { continue }
            let age = now.timeIntervalSince(m)
            if age > attentionWindow { lastWorking[path] = nil; continue }
            out.append(classify(path: path, age: age, turnDone: turnDone, now: now))
        }
        return out
    }

    private func classify(path: String, age: TimeInterval, turnDone: ([String]) -> Bool, now: Date) -> State {
        if age < activeWindow {
            lastWorking[path] = now
            return .working
        }
        // Stopped. Finished its turn, or frozen mid-turn?
        if turnDone(tailLines(path)) {
            return age < needsYouCap ? .needsYou : .idle
        }
        if age < stallAfter { return .working }   // brief mid-turn pause — still thinking
        // Frozen mid-turn. Only "stalled" if we actually watched it working and
        // it's still within the active-stall window; otherwise it's just idle.
        if let seen = lastWorking[path], now.timeIntervalSince(seen) < stallCap, age < stallCap {
            return .stalled
        }
        return .idle
    }

    // MARK: - Candidate files

    private func claudeFiles() -> [String] {
        let fm = FileManager.default
        let root = NSHomeDirectory() + "/.claude/projects"
        guard let projects = try? fm.contentsOfDirectory(atPath: root) else { return [] }
        var files: [String] = []
        for project in projects {
            let dir = root + "/" + project
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".jsonl") { files.append(dir + "/" + entry) }
        }
        return files
    }

    private func codexFiles(now: Date) -> [String] {
        let cal = Calendar.current
        var files: [String] = []
        for offset in 0...1 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            let c = cal.dateComponents([.year, .month, .day], from: day)
            guard let y = c.year, let mo = c.month, let d = c.day else { continue }
            let dir = String(format: "%@/.codex/sessions/%04d/%02d/%02d", NSHomeDirectory(), y, mo, d)
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".jsonl") { files.append(dir + "/" + entry) }
        }
        return files
    }

    // MARK: - Turn markers

    /// Verdict from the last ASSISTANT entry only. Trailing user / system /
    /// queue lines (injected reminders, queued prompts) are noise and must not
    /// flip a finished turn into a false stall.
    private func claudeTurnDone(_ lines: [String]) -> Bool {
        for line in lines.reversed() {
            guard let object = json(line), object["type"] as? String == "assistant" else { continue }
            let stop = (object["message"] as? [String: Any])?["stop_reason"] as? String
            return stop == "end_turn" || stop == "stop_sequence" || stop == "stop"
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

    private func beep() {
        guard StallSoundStore.shared.enabled else { return }
        NSSound.beep()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { NSSound.beep() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) { NSSound.beep() }
    }
}
