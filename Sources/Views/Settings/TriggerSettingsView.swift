import SwiftUI

struct TriggerSettingsView: View {
    @ObservedObject var store = TriggerStore.shared
    @ObservedObject var usage = UsageStore.shared
    @ObservedObject var safety = TriggerSafetyStore.shared

    @State var allSessions: [ScannedSession] = []
    @State var scanning = false
    @State var tool: TriggerTool = .claude
    @State var selectedID: String?
    @State var message = "继续"
    @State var mode: TriggerMode = .afterReset
    @State var hours = 5

    static let rel: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = L10n.locale
        f.unitsStyle = .abbreviated
        return f
    }()

    var toolSessions: [ScannedSession] {
        allSessions.filter { $0.tool == tool }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            safetySection
            existingList
            addCard
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
                title: "Records",
                subtitle: "Open the folder with blocked and executed auto-resume records."
            ) {
                PillButton(label: "Open") { TriggerEngine.shared.openLogsDirectory() }
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
                        PillButton(label: safety.isAllowed(cwd: trigger.cwd) ? "Disallow resume" : "Allow resume") {
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

}
