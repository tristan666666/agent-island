import AppKit
import Foundation

@MainActor
enum TurnAlarmNavigator {
    static func open(provider: AlertEngine.Provider, thread: ActivityMonitor.ActiveThread?) {
        switch provider {
        case .codex:
            openCodex(thread: thread)
        case .claude:
            openClaude(thread: thread)
        }
    }

    private static func openCodex(thread: ActivityMonitor.ActiveThread?) {
        let fallback = {
            if let thread, openCLIResume(executable: "codex", arguments: ["resume", thread.sessionId], thread: thread) {
                return
            }
            activate(bundleIdentifier: "com.openai.codex")
        }
        if let id = sanitizedCodexThreadID(thread?.sessionId),
           let url = URL(string: "codex://threads/\(id)"),
           NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open(url, configuration: config) { app, error in
                Task { @MainActor in
                    if let app {
                        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    } else if error != nil {
                        fallback()
                    } else {
                        activate(bundleIdentifier: "com.openai.codex")
                    }
                }
            }
            return
        }
        fallback()
    }

    private static func sanitizedCodexThreadID(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard raw.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return raw
    }

    private static func openClaude(thread: ActivityMonitor.ActiveThread?) {
        if let thread, openCLIResume(executable: "claude", arguments: ["--resume", thread.sessionId], thread: thread) {
            return
        }
        activate(bundleIdentifier: "com.anthropic.claudefordesktop")
    }

    private static func activate(bundleIdentifier: String) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private static func openCLIResume(
        executable: String,
        arguments: [String],
        thread: ActivityMonitor.ActiveThread
    ) -> Bool {
        guard !thread.sessionId.isEmpty else { return false }
        let command = resumeCommand(executable: executable, arguments: arguments, cwd: thread.cwd)
        if runTerminalCommand(command) { return true }
        if openCommandFile(command: command, executable: executable, sessionId: thread.sessionId) { return true }
        return false
    }

    private static func runTerminalCommand(_ command: String) -> Bool {
        let script = """
        tell application "Terminal"
            activate
            do script "\(appleScriptString(command))"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func openCommandFile(command: String, executable: String, sessionId: String) -> Bool {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        let dir = root
            .appendingPathComponent("AgentIsland", isDirectory: true)
            .appendingPathComponent("ResumeCommands", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("resume-\(safeFileComponent(executable))-\(safeFileComponent(sessionId)).command")
            let body = """
            #!/bin/zsh
            \(command)
            """
            try body.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
            return NSWorkspace.shared.open(url)
        } catch {
            return false
        }
    }

    private static func resumeCommand(executable: String, arguments: [String], cwd: String) -> String {
        var parts = [
            "export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH\""
        ]
        if isUsableDirectory(cwd) {
            parts.append("cd \(shellQuote(cwd)) || exit 1")
        }
        parts.append("exec \(shellJoin([executable] + arguments))")
        return parts.joined(separator: "; ")
    }

    private static func isUsableDirectory(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func shellJoin(_ parts: [String]) -> String {
        parts.map(shellQuote).joined(separator: " ")
    }

    private static func shellQuote(_ raw: String) -> String {
        guard !raw.isEmpty else { return "''" }
        return "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptString(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func safeFileComponent(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let text = String(scalars)
        return text.isEmpty ? "session" : String(text.prefix(80))
    }
}
