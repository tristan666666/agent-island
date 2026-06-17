import Foundation

enum AppMode {
    case normal
    case demo
    case debug
}

enum AppEnvironment {
    static let current: AppMode = {
        let env = ProcessInfo.processInfo.environment
        func on(_ keys: String...) -> Bool { keys.contains { env[$0] == "1" } }
        if on("AGENTISLAND_DEMO", "CODEXISLAND_DEMO") { return .demo }
        if on("AGENTISLAND_DEBUG", "CODEXISLAND_DEBUG") { return .debug }
        return .normal
    }()

    static var isDemo: Bool { current == .demo }
    static var isDebug: Bool { current == .debug }
}
