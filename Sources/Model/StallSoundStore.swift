import Foundation

/// Whether a stalled session plays the alarm beep. Default on; the user can
/// silence it from the Settings status guide. `ActivityMonitor` reads the same
/// UserDefaults key when deciding to beep.
@MainActor
final class StallSoundStore: ObservableObject {
    static let shared = StallSoundStore()

    static let key = "AgentIsland.stallSound"

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.key) }
    }

    private init() {
        enabled = UserDefaults.standard.object(forKey: Self.key) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.key)
    }
}
