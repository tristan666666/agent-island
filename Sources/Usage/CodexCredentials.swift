import Foundation

enum CodexCredentials {
    static func canPromptReauth() -> Bool {
        locateCodexBinary() != nil
    }

    static func authModificationStamp() -> Date? {
        let path = NSString("~/.codex/auth.json").expandingTildeInPath
        return (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
    }

    @discardableResult
    static func spawnReauth() -> Bool {
        guard let path = locateCodexBinary() else { return false }
        let command = "\(shellQuoted(path)) login"
        let script = """
        #!/bin/zsh
        echo "Agent Island is opening Codex login..."
        exec \(command)
        """
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("AgentIsland", isDirectory: true)
        let file = dir.appendingPathComponent("codex-login.command")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try script.write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        } catch {
            NSLog("AgentIsland: failed to prepare codex login command: %@", error.localizedDescription)
            return false
        }

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Terminal", file.path]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            return true
        } catch {
            NSLog("AgentIsland: failed to spawn codex login: %@", error.localizedDescription)
            return false
        }
    }

    private static func shellQuoted(_ raw: String) -> String {
        "'\(raw.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func locateCodexBinary() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.bun/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "\(home)/.local/bin/codex",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        let nvmRoot = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmRoot) {
            for version in versions.sorted(by: >) {
                let candidate = "\(nvmRoot)/\(version)/bin/codex"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        return nil
    }
}
