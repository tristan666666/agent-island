import SwiftUI

/// Settings tab for auto-triggers. Pick any Claude or Codex session, set a
/// message, and choose when it fires — at the provider's real 5h-window reset
/// (the same signal the island already tracks) or on a fixed interval.
struct TriggerSettingsView: View {
    @ObservedObject private var store = TriggerStore.shared
    @ObservedObject private var usage = UsageStore.shared

    @State private var sessions: [ScannedSession] = []
    @State private var scanning = false
    @State private var selectedID: String?
    @State private var message = "继续"
    @State private var mode: TriggerMode = .afterReset
    @State private var hours = 5

    private static let rel: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            existingSection
            addSection
        }
        .task { if sessions.isEmpty { await loadSessions() } }
    }

    // MARK: - Existing triggers

    private var existingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Auto-Trigger")
            if store.triggers.isEmpty {
                Text("No triggers yet — add one below.")
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.triggers) { trigger in
                    SettingsRow(
                        title: trigger.label,
                        subtitle: subtitle(trigger),
                        dot: color(trigger.tool),
                        chip: trigger.tool.display.uppercased()
                    ) {
                        HStack(spacing: 8) {
                            PillButton(label: "Run") { TriggerEngine.shared.fire(trigger) }
                            SettingsToggle(isOn: trigger.enabled) {
                                store.setEnabled(trigger.id, !trigger.enabled)
                            }
                            Button { store.remove(trigger.id) } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.40))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete trigger")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // MARK: - Add form

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("New trigger")
            VStack(alignment: .leading, spacing: 12) {
                fieldRow("Session") {
                    HStack(spacing: 8) {
                        Picker("", selection: $selectedID) {
                            if sessions.isEmpty {
                                Text(scanning ? "Scanning…" : "No sessions").tag(String?.none)
                            }
                            ForEach(sessions) { session in
                                Text("[\(session.tool.display)] \(session.label)")
                                    .tag(Optional(session.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        PillButton(label: scanning ? "…" : "Rescan") {
                            Task { await loadSessions() }
                        }
                    }
                }

                fieldRow("Message") {
                    TextField("继续", text: $message)
                        .textFieldStyle(.plain)
                        .font(Typography.label)
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(0.05))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                                }
                        }
                        .frame(maxWidth: 220)
                }

                fieldRow("When") {
                    HStack(spacing: 10) {
                        SegmentedControl(
                            items: TriggerMode.allCases,
                            selected: $mode,
                            label: { $0 == .afterReset ? "After reset" : "Every Nh" },
                            accessibilityPrefix: "Trigger timing"
                        )
                        if mode == .everyHours {
                            Stepper("\(hours)h", value: $hours, in: 1...24)
                                .font(Typography.label)
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize()
                        }
                    }
                }

                if mode == .afterReset, let caption = resetCaption {
                    Text(caption)
                        .font(Typography.label)
                        .foregroundStyle(.white.opacity(0.40))
                }

                HStack {
                    Spacer()
                    PillButton(label: "Add & enable") { addTrigger() }
                        .opacity(selectedID == nil ? 0.5 : 1)
                        .disabled(selectedID == nil)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.03))
            }
            .padding(.horizontal, 10)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    // MARK: - Helpers

    private var selectedTool: TriggerTool? {
        guard let id = selectedID else { return nil }
        return sessions.first(where: { $0.id == id })?.tool
    }

    /// Reassures the user the reset clock is live by showing the next reset
    /// for the selected session's provider.
    private var resetCaption: String? {
        guard let tool = selectedTool else { return nil }
        let reset = (tool == .claude ? usage.claude : usage.codex).fiveHour.resetAt
        guard let reset else { return "\(tool.display): reset time unknown yet — fires once usage data loads." }
        return "\(tool.display) resets \(Self.rel.localizedString(for: reset, relativeTo: Date())) — fires then."
    }

    private func addTrigger() {
        guard let id = selectedID,
              let session = sessions.first(where: { $0.id == id }) else { return }
        let trigger = Trigger(
            tool: session.tool,
            sessionId: session.sessionId,
            label: session.label,
            cwd: session.cwd,
            message: message.isEmpty ? "继续" : message,
            mode: mode,
            everyHours: hours,
            enabled: true,
            lastFired: mode == .everyHours ? Date() : nil
        )
        store.add(trigger)
    }

    private func loadSessions() async {
        scanning = true
        let found = await Task.detached(priority: .userInitiated) {
            SessionScanner.scan()
        }.value
        sessions = found
        if selectedID == nil { selectedID = found.first?.id }
        scanning = false
    }

    private func subtitle(_ trigger: Trigger) -> String {
        let when = trigger.mode == .afterReset
            ? "after reset"
            : "every \(trigger.everyHours)h"
        var parts = ["「\(trigger.message)」", when]
        if let last = trigger.lastFired {
            parts.append("fired \(Self.rel.localizedString(for: last, relativeTo: Date()))")
        }
        return parts.joined(separator: " · ")
    }

    private func color(_ tool: TriggerTool) -> Color {
        tool == .claude ? IslandColor.claude : IslandColor.codex
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.sectionLabel)
            .tracking(1.05)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.34))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 64, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }
}
