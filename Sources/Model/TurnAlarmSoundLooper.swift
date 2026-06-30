import AppKit

@MainActor
final class TurnAlarmSoundLooper {
    private var timer: Timer?
    private var current: NSSound?

    func start() {
        stop()
        guard AgentReminderStore.shared.soundEnabled else { return }
        play()
        timer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.play() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        current?.stop()
        current = nil
    }

    private func play() {
        guard AgentReminderStore.shared.soundEnabled else {
            stop()
            return
        }
        if current?.isPlaying == true { return }
        guard let sound = AgentReminderStore.shared.makeAlarmSound() else { return }
        sound.volume = Float(AgentReminderStore.shared.volume)
        current = sound
        sound.play()
    }
}
