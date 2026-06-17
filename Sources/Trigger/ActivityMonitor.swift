import Foundation
import AppKit

/// Watches active Claude and Codex sessions and classifies each provider's
/// live state for the island: breathing while working, a spin when a turn
/// finishes (your turn), red + beep when a session froze mid-turn (stalled).
///
/// Conservative on purpose: a session only ever goes red if we *watched* it go
/// from actively producing to frozen mid-turn, and stayed frozen past a long
/// threshold. Sessions that were already quiet (old / abandoned / mid long
/// tool call) don't flash red. All disk IO runs off the main actor.
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

    private var lastWorking: [String: Date] = [:]
    private var lastBeepAt: Date?
    private var timer: Timer?

    func start() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Snapshot state, do all the file IO + classification on a background
    /// task, then hop back to assign published state + beep.
    private func tick() {
        let snapshot = lastWorking
        let now = Date()
        Task.detached(priority: .utility) {
            let result = Scan.run(lastWorking: snapshot, now: now)
            await MainActor.run {
                self.lastWorking = result.lastWorking
                if result.claude == .stalled && self.claude != .stalled { self.beep() }
                self.claude = result.claude
                if result.codex == .stalled && self.codex != .stalled { self.beep() }
                self.codex = result.codex
            }
        }
    }

    private func beep() {
        guard StallSoundStore.shared.enabled else { return }
        if let last = lastBeepAt, Date().timeIntervalSince(last) < 30 { return }   // throttle
        lastBeepAt = Date()
        NSSound.beep()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { NSSound.beep() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) { NSSound.beep() }
    }
}

/// Pure, off-actor scan: no shared mutable state beyond the `lastWorking`
/// snapshot it's handed and returns.
private enum Scan {
    struct Result {
        let claude: ActivityMonitor.State
        let codex: ActivityMonitor.State
        let lastWorking: [String: Date]
    }

    static let activeWindow: TimeInterval = 18       // file grew within → working
    static let stallAfter: TimeInterval = 300        // frozen mid-turn 5 min → stalled
    static let stallCap: TimeInterval = 15 * 60      // beyond this it's idle, not a live stall
    static let needsYouCap: TimeInterval = 20 * 60   // "your turn" only stays fresh this long
    static let attentionWindow: TimeInterval = 30 * 60

    static func run(lastWorking: [String: Date], now: Date) -> Result {
        var lw = lastWorking
        let claudeF = claudeFiles()
        let codexF = codexFiles(now: now)
        let c = aggregate(classifyAll(claudeF, now: now, lw: &lw, turnDone: claudeTurnDone))
        let x = aggregate(classifyAll(codexF, now: now, lw: &lw, turnDone: codexTurnDone))
        // Prune: only keep entries for files we still consider candidates, so
        // the dictionary can't grow without bound across a long-running app.
        let live = Set(claudeF + codexF)
        lw = lw.filter { live.contains($0.key) }
        return Result(claude: c, codex: x, lastWorking: lw)
    }

    private static func aggregate(_ states: [ActivityMonitor.State]) -> ActivityMonitor.State {
        states.max(by: { $0.rawValue < $1.rawValue }) ?? .idle
    }

    private static func classifyAll(_ files: [String], now: Date, lw: inout [String: Date],
                                    turnDone: ([String]) -> Bool) -> [ActivityMonitor.State] {
        var out: [ActivityMonitor.State] = []
        for path in files {
            guard let m = mtime(path) else { continue }
            let age = now.timeIntervalSince(m)
            if age > attentionWindow { continue }
            out.append(classify(path: path, age: age, now: now, lw: &lw, turnDone: turnDone))
        }
        return out
    }

    private static func classify(path: String, age: TimeInterval, now: Date,
                                 lw: inout [String: Date], turnDone: ([String]) -> Bool) -> ActivityMonitor.State {
        if age < activeWindow {
            lw[path] = now
            return .working
        }
        if turnDone(tailLines(path)) {
            return age < needsYouCap ? .needsYou : .idle
        }
        if age < stallAfter { return .working }   // brief mid-turn pause / slow tool — still working
        if let seen = lw[path], now.timeIntervalSince(seen) < stallCap, age < stallCap {
            return .stalled
        }
        return .idle
    }

    // MARK: - Candidate files

    private static func claudeFiles() -> [String] {
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

    private static func codexFiles(now: Date) -> [String] {
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

    // MARK: - IO helpers

    /// Last ~128KB / 200 lines — wide enough that a recent turn-complete marker
    /// isn't scrolled out by a burst of tool output.
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

    private static func mtime(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
    }
}
