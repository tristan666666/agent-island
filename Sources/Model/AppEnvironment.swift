import Foundation

enum AppMode {
    case normal
    case demo
    case debug
}

enum AppEnvironment {
    static let current: AppMode = {
        let env = ProcessInfo.processInfo.environment
        if env["CODEXISLAND_DEMO"] == "1" { return .demo }
        if env["CODEXISLAND_DEBUG"] == "1" { return .debug }
        return .normal
    }()

    static var isDemo: Bool { current == .demo }
    static var isDebug: Bool { current == .debug }
}
