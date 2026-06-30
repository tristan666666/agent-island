import SwiftUI
import AppKit

struct MenuBarStatusLabel: View {
    @ObservedObject private var monitor = ActivityMonitor.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
    }

    private var icon: String {
        let state = strongestState
        switch state {
        case .authRequired: return "person.crop.circle.badge.exclamationmark"
        case .rateLimited: return "hourglass"
        case .stalled: return "exclamationmark.triangle.fill"
        case .needsYou: return "bell.fill"
        case .working: return "sparkles"
        case .idle: return "circle"
        }
    }

    private var label: String {
        let state = strongestState
        switch state {
        case .authRequired: return "AUTH"
        case .rateLimited: return "LIMIT"
        case .stalled: return "STALLED"
        case .needsYou: return "TURN"
        case .working: return "RUN"
        case .idle: return "AI"
        }
    }

    private var strongestState: ActivityMonitor.State {
        monitor.claude.rawValue >= monitor.codex.rawValue ? monitor.claude : monitor.codex
    }
}

struct MenuBarStatusView: View {
    @ObservedObject private var monitor = ActivityMonitor.shared
    @ObservedObject private var usage = UsageStore.shared

    var body: some View {
        Text("Agent Island")
        Divider()
        Text("Claude: \(monitor.claude.label)")
        Text("Codex: \(monitor.codex.label)")
        Divider()
        Button("Refresh usage") {
            usage.refresh()
        }
        Button("Open Settings") {
            SettingsWindowController.shared.show()
        }
        Divider()
        Button("Quit Agent Island") {
            NSApp.terminate(nil)
        }
    }
}
