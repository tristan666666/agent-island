import AppKit
import SwiftUI

private final class TurnAlarmPanel: NSPanel {
    var primaryAction: (() -> Void)?
    var dismissAction: (() -> Void)?
    var zoomAction: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            let point = event.locationInWindow
            if contains(closeHitRect, point: point) || contains(minimizeHitRect, point: point) {
                dismissAction?()
                return
            }
            if contains(zoomHitRect, point: point) {
                zoomAction?()
                return
            }
            if contains(dismissHitRect, point: point) {
                dismissAction?()
                return
            }
            if contains(primaryHitRect, point: point) {
                primaryAction?()
                return
            }
        }
        super.sendEvent(event)
    }

    private func contains(_ rect: NSRect, point: NSPoint) -> Bool {
        rect.contains(point) || flipped(rect).contains(point)
    }

    private func flipped(_ rect: NSRect) -> NSRect {
        NSRect(x: rect.minX, y: frame.height - rect.maxY, width: rect.width, height: rect.height)
    }

    private var primaryHitRect: NSRect {
        let width = frame.width
        return NSRect(x: (width - 396) / 2, y: 126 + verticalButtonOffset, width: 396, height: 62)
    }

    private var dismissHitRect: NSRect {
        let width = frame.width
        return NSRect(x: (width - 396) / 2, y: 54 + verticalButtonOffset, width: 396, height: 70)
    }

    private var verticalButtonOffset: CGFloat {
        max(0, frame.height - 520) * 0.34
    }

    private var closeHitRect: NSRect {
        NSRect(x: 14, y: frame.height - 34, width: 20, height: 20)
    }

    private var minimizeHitRect: NSRect {
        NSRect(x: 42, y: frame.height - 34, width: 20, height: 20)
    }

    private var zoomHitRect: NSRect {
        NSRect(x: 70, y: frame.height - 34, width: 20, height: 20)
    }
}

final class TurnAlarmWindowState: ObservableObject {
    @Published var size: NSSize

    init(size: NSSize) {
        self.size = size
    }
}

private final class TurnAlarmHostingView: NSHostingView<TurnAlarmView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class TurnAlarmWindowController: NSWindowController, NSWindowDelegate {
    static let shared = TurnAlarmWindowController()
    static let panelSize = NSSize(width: 520, height: 520)
    private static let expandedPanelSize = NSSize(width: 680, height: 620)
    private var isExpanded = false
    private var alarmPanel: NSPanel?
    private var windowState: TurnAlarmWindowState?
    private var currentProvider: AlertEngine.Provider?
    private var currentThread: ActivityMonitor.ActiveThread?
    private var didAcknowledgeCurrentAlarm = false

    private init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private let sound = TurnAlarmSoundLooper()

    func show(provider: AlertEngine.Provider, thread: ActivityMonitor.ActiveThread?) {
        let name = provider == .claude ? "Claude" : "Codex"
        isExpanded = false
        currentProvider = provider
        currentThread = thread
        didAcknowledgeCurrentAlarm = false
        let panel = TurnAlarmPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let state = TurnAlarmWindowState(size: Self.panelSize)
        let rootView = TurnAlarmView(
            provider: provider,
            providerName: name,
            thread: thread,
            windowState: state,
            dismiss: { [weak self, weak panel] in
                self?.dismissCurrentAlarm(panel)
            },
            zoom: { [weak self, weak panel] in
                self?.toggleZoom(panel)
            }
        )
        panel.contentView = TurnAlarmHostingView(rootView: rootView)
        panel.primaryAction = { [weak self, weak panel] in
            TurnAlarmNavigator.open(provider: provider, thread: thread)
            self?.dismissCurrentAlarm(panel)
        }
        panel.dismissAction = { [weak self, weak panel] in
            self?.dismissCurrentAlarm(panel)
        }
        panel.zoomAction = { [weak self, weak panel] in
            self?.toggleZoom(panel)
        }
        panel.setFrame(NSRect(origin: .zero, size: Self.panelSize), display: false)
        panel.title = L10n.tr("Turn alarm")
        panel.isMovableByWindowBackground = true
        panel.isRestorable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        alarmPanel?.delegate = nil
        alarmPanel?.close()
        alarmPanel = panel
        windowState = state
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        center(panel)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        sound.start()
    }

    private func dismissCurrentAlarm(_ panel: NSPanel?) {
        acknowledgeCurrentAlarm()
        sound.stop()
        panel?.orderOut(nil)
        panel?.close()
    }

    private func acknowledgeCurrentAlarm() {
        guard !didAcknowledgeCurrentAlarm, let currentProvider else { return }
        didAcknowledgeCurrentAlarm = true
        AgentReminderCenter.shared.acknowledge(provider: currentProvider, thread: currentThread)
    }

    private func center(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.visibleFrame ?? NSRect(origin: .zero, size: NSScreen.main?.frame.size ?? Self.panelSize)
        let targetFrame = NSRect(
            origin: NSPoint(
                x: frame.midX - Self.panelSize.width / 2,
                y: frame.midY - Self.panelSize.height / 2
            ),
            size: Self.panelSize
        )
        panel.setFrame(targetFrame, display: true)
        windowState?.size = Self.panelSize
    }

    private func toggleZoom(_ panel: NSPanel?) {
        guard let panel else { return }
        isExpanded.toggle()
        let target = isExpanded ? Self.expandedPanelSize : Self.panelSize
        var frame = panel.frame
        let center = NSPoint(x: frame.midX, y: frame.midY)
        frame.size = target
        frame.origin = NSPoint(x: center.x - target.width / 2, y: center.y - target.height / 2)
        windowState?.size = target
        panel.setFrame(frame, display: true, animate: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        acknowledgeCurrentAlarm()
        return true
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, panel === alarmPanel else { return }
        windowState?.size = panel.frame.size
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as AnyObject? === alarmPanel {
            sound.stop()
            alarmPanel = nil
            windowState = nil
            window = nil
            currentProvider = nil
            currentThread = nil
            didAcknowledgeCurrentAlarm = false
        }
    }
}
