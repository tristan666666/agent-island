import Foundation

enum TriggerTool: String {
    case claude
    case codex
}

enum ActivityMonitor {
    enum State: Int {
        case idle = 0
        case working = 1
        case needsYou = 2
        case stalled = 3
        case rateLimited = 4
        case authRequired = 5
    }
}
