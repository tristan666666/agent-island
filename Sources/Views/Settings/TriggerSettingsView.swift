import SwiftUI

/// Settings tab for auto-triggers. Choose a tool (Claude or Codex), pick one of
/// its active threads, set a message, and choose when it fires — at the real
/// 5h-window reset (the signal the island already tracks) or a fixed interval.
struct TriggerSettingsView: View {
    @ObservedObject private var store = TriggerStore.shared
    @ObservedObject private var usage = UsageStore.shared
    @ObservedObject private var safety = TriggerSafetyStore.shared

    @State private var allSessions: [ScannedSession] = []
    @State private var scanning = false
    @State private var tool: TriggerTool = .claude
    @State private var selectedID: String?
    @State private var message = "继续"
    @State private var mode: TriggerMode = .afterReset
    @State private var hours = 5

    private static let rel: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = L10n.locale
        f.unitsStyle = .abbreviated
        return f
    }()

    private var toolSessions: [ScannedSession] {
        allSessions.filter { $0.tool == tool }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            safetySection
            existingList
            addCard
            sessionsList
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .task { if allSessions.isEmpty { await loadSessions() } }
    }

    // MARK: - Header / intro

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Auto-Trigger")
            Text(L10n.tr("When your AI limit resets, auto-send a message so a session keeps running."))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.50))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
        }
        .padding(.bottom, 10)
    }

    // MARK: - Existing triggers (grouped by tool)

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Safety")
            SettingsRow(
                title: "Auto-resume kill switch",
                subtitle: "When off, Agent Island will never spawn Claude or Codex resume commands."
            ) {
                SettingsToggle(isOn: safety.executionEnabled) { safety.executionEnabled.toggle() }
            }
            SettingsRow(
                title: "Dry run",
                subtitle: "Write the command to the trigger log without running it."
            ) {
                SettingsToggle(isOn: safety.dryRun) { safety.dryRun.toggle() }
            }
            SettingsRow(
                title: "Trigger logs",
                subtitle: "Open the folder where every blocked, dry-run, or live trigger writes a log."
            ) {
                PillButton(label: "Logs") { TriggerEngine.shared.openLogsDirectory() }
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var existingList: some View {
        if store.triggers.isEmpty {
            Text(L10n.tr("No triggers yet — add one below."))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.36))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                groupRows(.claude)
                groupRows(.codex)
            }
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func groupRows(_ forTool: TriggerTool) -> some View {
        let rows = store.triggers.filter { $0.tool == forTool }
        if !rows.isEmpty {
            Text(forTool.display.uppercased())
                .font(Typography.chip)
                .tracking(1.0)
                .foregroundStyle(color(forTool).opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.top, 6)
            ForEach(rows) { trigger in
                SettingsRow(title: trigger.label, subtitle: subtitle(trigger)) {
                    HStack(spacing: 8) {
                        PillButton(label: safety.isAllowed(cwd: trigger.cwd) ? "Untrust" : "Trust") {
                            safety.setAllowed(cwd: trigger.cwd, !safety.isAllowed(cwd: trigger.cwd))
                        }
                        PillButton(label: "Run") { TriggerEngine.shared.fire(trigger) }
                        if !trigger.cwd.isEmpty {
                            PillButton(label: "Open") { TriggerEngine.shared.openProject(for: trigger) }
                        }
                        SettingsToggle(isOn: trigger.enabled) { store.setEnabled(trigger.id, !trigger.enabled) }
                        Button { store.remove(trigger.id) } label: {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.white.opacity(0.36))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.tr("Delete trigger"))
                    }
                }
            }
        }
    }

    // MARK: - New trigger

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("New trigger").padding(.top, 14)
            VStack(alignment: .leading, spacing: 13) {
                field("Tool") {
                    SegmentedControl(
                        items: TriggerTool.allCases,
                        selected: $tool,
                        label: { $0.display },
                        accessibilityPrefix: "Tool"
                    )
                    .onChange(of: tool) { _ in selectFirst() }
                }

                field("Thread") {
                    Picker("", selection: $selectedID) {
                        if toolSessions.isEmpty {
                            Text(L10n.tr(scanning ? "Scanning…" : "No active threads")).tag(String?.none)
                        }
                        ForEach(toolSessions) { session in
                            Text(session.label).tag(Optional(session.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    Button(action: { Task { await loadSessions() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(scanning ? 0.3 : 0.55))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.tr("Rescan"))
                }

                field("Message") {
                    TextField("继续", text: $message)
                        .textFieldStyle(.plain)
                        .font(Typography.label)
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white.opacity(0.05))
                                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.10), lineWidth: 0.5) }
                        }
                        .frame(maxWidth: 200)
                }

                field("When") {
                    SegmentedControl(
                        items: TriggerMode.allCases,
                        selected: $mode,
                        label: { $0 == .afterReset ? "After reset" : "Every Nh" },
                        accessibilityPrefix: "When"
                    )
                    if mode == .everyHours {
                        Stepper("\(hours)h", value: $hours, in: 1...24)
                            .font(Typography.label)
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize()
                    }
                }

                if mode == .afterReset, let caption = resetCaption {
                    Text(caption)
                        .font(Typography.label)
                        .foregroundStyle(.white.opacity(0.36))
                        .padding(.leading, 64)
                }

                Button(action: addTrigger) {
                    Text(L10n.tr("Add & enable"))
                        .font(Typography.button)
                        .foregroundStyle(selectedID == nil ? .white.opacity(0.4) : Color(red: 0.14, green: 0.11, blue: 0.02))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(selectedID == nil ? .white.opacity(0.06) : IslandColor.cobalt.opacity(0.9))
                        }
                }
                .buttonStyle(.plain)
                .disabled(selectedID == nil)
                .padding(.top, 2)
            }
            .padding(14)
            .background { RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.03)) }
            .padding(.horizontal, 10)
        }
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Active sessions").padding(.top, 14)
            if allSessions.isEmpty {
                Text(L10n.tr(scanning ? "Scanning…" : "No active threads found."))
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.36))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            } else {
                ForEach(Array(allSessions.prefix(8))) { session in
                    SettingsRow(
                        title: session.label,
                        subtitle: sessionSubtitle(session),
                        dot: color(session.tool),
                        chip: session.status.label.uppercased()
                    ) {
                        if !session.cwd.isEmpty {
                            PillButton(label: safety.isAllowed(cwd: session.cwd) ? "Trusted" : "Trust") {
                                safety.setAllowed(cwd: session.cwd, true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var resetCaption: String? {
        let reset = (tool == .claude ? usage.claude : usage.codex).fiveHour.resetAt
        guard let reset else { return L10n.tr("%@: reset time loads with usage data.", tool.display) }
        return L10n.tr("%@ resets %@", tool.display, Self.rel.localizedString(for: reset, relativeTo: Date()))
    }

    private func selectFirst() {
        selectedID = toolSessions.first?.id
    }

    private func addTrigger() {
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

    private func loadSessions() async {
        scanning = true
        let found = await Task.detached(priority: .userInitiated) { SessionScanner.scan() }.value
        allSessions = found
        if selectedID == nil || allSessions.first(where: { $0.id == selectedID }) == nil {
            selectFirst()
        }
        scanning = false
    }

    private func subtitle(_ trigger: Trigger) -> String {
        let when = trigger.mode == .afterReset
            ? L10n.tr("after reset")
            : L10n.tr("every %dh", trigger.everyHours)
        var parts = ["「\(trigger.message)」", when]
        parts.append(safety.isAllowed(cwd: trigger.cwd) ? L10n.tr("trusted") : L10n.tr("not trusted"))
        if safety.dryRun { parts.append(L10n.tr("dry-run")) }
        parts.append(TriggerEngine.shared.preview(for: trigger))
        if let last = trigger.lastFired {
            parts.append(L10n.tr("fired %@", Self.rel.localizedString(for: last, relativeTo: Date())))
        }
        return parts.joined(separator: " · ")
    }

    private func sessionSubtitle(_ session: ScannedSession) -> String {
        let time = Self.rel.localizedString(for: session.modified, relativeTo: Date())
        let cwd = session.cwd.isEmpty ? L10n.tr("no project directory") : session.cwd
        return "\(session.tool.display) · \(session.status.label) · \(time) · \(cwd)"
    }

    private func color(_ tool: TriggerTool) -> Color {
        tool == .claude ? IslandColor.claude : IslandColor.codex
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(L10n.tr(text))
            .font(Typography.sectionLabel)
            .tracking(1.05)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.34))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
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
