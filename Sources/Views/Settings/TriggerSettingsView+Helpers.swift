import SwiftUI

extension TriggerSettingsView {
    var resetCaption: String? {
        let reset = (tool == .claude ? usage.claude : usage.codex).fiveHour.resetAt
        guard let reset else { return L10n.tr("%@: reset time loads with usage data.", tool.display) }
        return L10n.tr("%@ resets %@", tool.display, Self.rel.localizedString(for: reset, relativeTo: Date()))
    }

    func selectFirst() {
        selectedID = toolSessions.first?.id
    }

    func addTrigger() {
        guard let id = selectedID,
              let session = allSessions.first(where: { $0.id == id }) else { return }
        store.add(Trigger(
            tool: session.tool,
            sessionId: session.sessionId,
            label: session.label,
            cwd: session.cwd,
            message: message.isEmpty ? "继续" : message,
            mode: mode,
            everyHours: hours,
            enabled: true,
            lastFired: mode == .everyHours ? Date() : nil
        ))
    }

    func loadSessions() async {
        scanning = true
        let found = await Task.detached(priority: .userInitiated) { SessionScanner.scan() }.value
        allSessions = found
        if selectedID == nil || allSessions.first(where: { $0.id == selectedID }) == nil {
            selectFirst()
        }
        scanning = false
    }

    func subtitle(_ trigger: Trigger) -> String {
        let when = trigger.mode == .afterReset
            ? L10n.tr("after reset")
            : L10n.tr("every %dh", trigger.everyHours)
        var parts = ["「\(trigger.message)」", when]
        parts.append(safety.isAllowed(cwd: trigger.cwd) ? L10n.tr("resume allowed") : L10n.tr("resume not allowed"))
        parts.append(TriggerEngine.shared.preview(for: trigger))
        if let last = trigger.lastFired {
            parts.append(L10n.tr("fired %@", Self.rel.localizedString(for: last, relativeTo: Date())))
        }
        return parts.joined(separator: " · ")
    }

    func color(_ tool: TriggerTool) -> Color {
        tool == .claude ? IslandColor.claude : IslandColor.codex
    }

    @ViewBuilder
    func sectionLabel(_ text: String) -> some View {
        Text(L10n.tr(text))
            .font(Typography.sectionLabel)
            .tracking(1.05)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.34))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
    }

    @ViewBuilder
    func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(L10n.tr(label))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 52, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }
}
