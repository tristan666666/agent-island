import AppKit
import SwiftUI

@MainActor
final class TurnAlarmWindowController: NSWindowController, NSWindowDelegate {
    static let shared = TurnAlarmWindowController()
    static let panelSize = NSSize(width: 520, height: 520)

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private let sound = TurnAlarmSoundLooper()

    func show(provider: AlertEngine.Provider, thread: ActivityMonitor.ActiveThread?) {
        let name = provider == .claude ? "Claude" : "Codex"
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = NSHostingController(
            rootView: TurnAlarmView(
                provider: provider,
                providerName: name,
                thread: thread,
                pauseSound: { [weak self] in self?.sound.stop() },
                dismiss: { [weak panel] in panel?.close() }
            )
        )
        panel.titleVisibility = .hidden
        panel.title = L10n.tr("Turn alarm")
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = NSColor(calibratedWhite: 0.03, alpha: 1)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        window?.close()
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        sound.start()
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as AnyObject? === window {
            sound.stop()
            window = nil
        }
    }
}
