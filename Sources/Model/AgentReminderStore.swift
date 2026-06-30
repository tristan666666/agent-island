import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AgentReminderStore: ObservableObject {
    static let shared = AgentReminderStore()

    enum AlarmSoundPreset: String, CaseIterable, Hashable {
        case basso = "Basso"
        case blow = "Blow"
        case bottle = "Bottle"
        case frog = "Frog"
        case funk = "Funk"
        case glass = "Glass"
        case hero = "Hero"
        case morse = "Morse"
        case ping = "Ping"
        case pop = "Pop"
        case purr = "Purr"
        case sosumi = "Sosumi"
        case submarine = "Submarine"
        case tink = "Tink"

        var soundName: NSSound.Name { NSSound.Name(rawValue) }
        var label: String { rawValue }
    }

    enum AlarmSoundChoice: Hashable {
        case preset(AlarmSoundPreset)
        case custom

        static var all: [AlarmSoundChoice] {
            AlarmSoundPreset.allCases.map { .preset($0) } + [.custom]
        }

        var storageValue: String {
            switch self {
            case .preset(let preset): return preset.rawValue
            case .custom: return "Custom"
            }
        }

        var label: String {
            switch self {
            case .preset(let preset): return preset.label
            case .custom: return "Custom sound"
            }
        }

        init?(storageValue: String) {
            if storageValue == "Custom" {
                self = .custom
            } else if let preset = AlarmSoundPreset(rawValue: storageValue) {
                self = .preset(preset)
            } else {
                return nil
            }
        }
    }

    private static let enabledKey = "AgentIsland.agentReminders"
    private static let soundEnabledKey = "AgentIsland.agentReminderSound"
    private static let volumeKey = "AgentIsland.agentReminderVolume"
    private static let soundPresetKey = "AgentIsland.agentReminderSoundPreset"
    private static let soundChoiceKey = "AgentIsland.agentReminderSoundChoice"
    private static let customSoundPathKey = "AgentIsland.agentReminderCustomSoundPath"
    private static let showSessionDetailsKey = "AgentIsland.agentReminderShowSessionDetails"
    private var previewSound: NSSound?

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Self.soundEnabledKey) }
    }

    @Published var volume: Double {
        didSet {
            let clamped = min(1, max(0, volume))
            UserDefaults.standard.set(clamped, forKey: Self.volumeKey)
        }
    }

    @Published var soundPreset: AlarmSoundPreset {
        didSet { UserDefaults.standard.set(soundPreset.rawValue, forKey: Self.soundPresetKey) }
    }

    @Published var soundChoice: AlarmSoundChoice {
        didSet { UserDefaults.standard.set(soundChoice.storageValue, forKey: Self.soundChoiceKey) }
    }

    @Published var customSoundPath: String? {
        didSet {
            if let customSoundPath, !customSoundPath.isEmpty {
                UserDefaults.standard.set(customSoundPath, forKey: Self.customSoundPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.customSoundPathKey)
            }
        }
    }

    @Published var showSessionDetails: Bool {
        didSet { UserDefaults.standard.set(showSessionDetails, forKey: Self.showSessionDetailsKey) }
    }

    private init() {
        enabled = UserDefaults.standard.object(forKey: Self.enabledKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.enabledKey)
        soundEnabled = UserDefaults.standard.object(forKey: Self.soundEnabledKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.soundEnabledKey)
        volume = UserDefaults.standard.object(forKey: Self.volumeKey) == nil
            ? 0.8
            : min(1, max(0, UserDefaults.standard.double(forKey: Self.volumeKey)))
        let preset = UserDefaults.standard.string(forKey: Self.soundPresetKey)
        let initialPreset = preset.flatMap(AlarmSoundPreset.init(rawValue:)) ?? .glass
        soundPreset = initialPreset
        let storedCustomSoundPath = UserDefaults.standard.string(forKey: Self.customSoundPathKey)
        customSoundPath = storedCustomSoundPath
        let storedChoice = UserDefaults.standard.string(forKey: Self.soundChoiceKey)
            .flatMap(AlarmSoundChoice.init(storageValue:))
        if let storedChoice, storedChoice != .custom || storedCustomSoundPath != nil {
            soundChoice = storedChoice
        } else if storedCustomSoundPath != nil {
            soundChoice = .custom
        } else {
            soundChoice = .preset(initialPreset)
        }
        showSessionDetails = UserDefaults.standard.bool(forKey: Self.showSessionDetailsKey)
    }

    var soundLabel: String {
        switch soundChoice {
        case .preset(let preset):
            return L10n.tr(preset.label)
        case .custom:
            guard let customSoundPath, !customSoundPath.isEmpty else {
                return L10n.tr("Custom sound")
            }
            return (customSoundPath as NSString).lastPathComponent
        }
    }

    func selectPreset(_ preset: AlarmSoundPreset) {
        soundPreset = preset
        soundChoice = .preset(preset)
    }

    func selectSoundChoice(_ choice: AlarmSoundChoice) {
        switch choice {
        case .preset(let preset):
            selectPreset(preset)
            previewSoundChoice(.preset(preset))
        case .custom:
            guard customSoundPath != nil, soundChoice != .custom else {
                chooseCustomSound()
                return
            }
            soundChoice = .custom
            previewSoundChoice(.custom)
        }
    }

    func chooseCustomSound() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.customSoundPath = url.path
                self?.soundChoice = .custom
                self?.previewSoundChoice(.custom)
            }
        }
    }

    func previewSoundChoice(_ choice: AlarmSoundChoice) {
        guard soundEnabled, let sound = makeSound(for: choice) else { return }
        previewSound?.stop()
        sound.volume = Float(volume)
        previewSound = sound
        sound.play()
    }

    func makeAlarmSound() -> NSSound? {
        makeSound(for: soundChoice)
            ?? makeSound(for: .preset(soundPreset))
            ?? NSSound(named: NSSound.Name("Glass"))
    }

    private func makeSound(for choice: AlarmSoundChoice) -> NSSound? {
        switch choice {
        case .preset(let preset):
            return NSSound(named: preset.soundName)
        case .custom:
            guard let path = customSoundPath,
                  FileManager.default.fileExists(atPath: path)
            else { return nil }
            return NSSound(contentsOf: URL(fileURLWithPath: path), byReference: true)
        }
    }
}
