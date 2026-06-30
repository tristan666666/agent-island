import SwiftUI

struct StatusGuideView: View {
    @ObservedObject private var reminders = AgentReminderStore.shared
    @State private var soundPickerExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.tr("What the island's two logos are telling you."))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.bottom, 12)

            sectionLabel("Logo states")
            legendRow(.working, "Working", "The logo rotates while a session is running.")
            legendRow(.needsYou, "Your turn", "A thread finished — Agent Island opens an alarm window so you can reply.")
            legendRow(.authRequired, "Needs attention", "Limits, login, network, or provider errors make the logo pulse red.")

            sectionLabel("Reminders").padding(.top, 14)
            SettingsRow(
                title: "Turn alarm",
                subtitle: "Pop up a foreground alarm and system notification when a background run needs you."
            ) {
                SettingsToggle(isOn: reminders.enabled) { reminders.enabled.toggle() }
            }
            SettingsRow(
                title: "Show thread details",
                subtitle: "Show session and project names in alarms and notifications."
            ) {
                SettingsToggle(isOn: reminders.showSessionDetails) { reminders.showSessionDetails.toggle() }
            }
            SettingsRow(
                title: "Alarm sound",
                subtitle: "Choose a built-in sound or use your own file."
            ) {
                SettingsToggle(isOn: reminders.soundEnabled) { reminders.soundEnabled.toggle() }
            }
            if reminders.soundEnabled {
                SoundPickerHeader(isExpanded: $soundPickerExpanded)
                if soundPickerExpanded {
                    SoundChoiceList()
                }
                SettingsRow(
                    title: "Volume",
                    subtitle: "Adjust how loud the alarm sound is."
                ) {
                    Slider(value: $reminders.volume, in: 0...1)
                        .frame(width: 120)
                }
            }

            if AppEnvironment.isDemo || AppEnvironment.isDebug {
                sectionLabel("Demo — force a state on the notch").padding(.top, 16)
                HStack(spacing: 8) {
                    demoButton("Working", .working)
                    demoButton("Your turn", .needsYou)
                    demoButton("Auth", .authRequired)
                    demoButton("Rate", .rateLimited)
                    demoButton("Live", nil)
                }
                .padding(.horizontal, 10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func demoButton(_ label: String, _ state: ActivityMonitor.State?) -> some View {
        Button { ActivityMonitor.shared.demo(state) } label: {
            Text(L10n.tr(label))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func legendRow(_ state: ActivityMonitor.State, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            StatePreviewLogo(state: state)
                .frame(width: 30, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr(title))
                    .font(Typography.rowTitle).tracking(-0.07)
                    .foregroundStyle(.white.opacity(0.92))
                Text(L10n.tr(desc))
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
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
            .padding(.bottom, 6)
    }

}

private struct SoundPickerHeader: View {
    @Binding var isExpanded: Bool
    @ObservedObject private var reminders = AgentReminderStore.shared
    @State private var hovered = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Text(L10n.tr("Sound"))
                    .font(Typography.rowTitle)
                    .foregroundStyle(.white.opacity(0.92))
                Spacer(minLength: 8)
                Text(reminders.soundLabel)
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.white.opacity(hovered ? 0.035 : 0.015))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.bottom, isExpanded ? 4 : 8)
        .onHover { hovered = $0 }
    }
}

private struct SoundChoiceList: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(AgentReminderStore.AlarmSoundChoice.all, id: \.self) { choice in
                SoundChoiceRow(choice: choice)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
}

private struct SoundChoiceRow: View {
    let choice: AgentReminderStore.AlarmSoundChoice
    @ObservedObject private var reminders = AgentReminderStore.shared
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(L10n.tr(choice.label))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.72))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let actionLabel {
                Text(L10n.tr(actionLabel))
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.055))
                    }
            }
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IslandColor.cobalt)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background {
            Rectangle()
                .fill(.white.opacity(isSelected ? 0.055 : (hovered ? 0.028 : 0)))
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.045))
                .frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            reminders.selectSoundChoice(choice)
        }
        .onHover { inside in
            hovered = inside
            if inside {
                reminders.previewSoundChoice(choice)
            }
        }
        .animation(.easeOut(duration: 0.10), value: hovered)
        .animation(.easeOut(duration: 0.10), value: isSelected)
    }

    private var isSelected: Bool {
        reminders.soundChoice == choice
    }

    private var actionLabel: String? {
        guard choice == .custom else { return nil }
        if reminders.customSoundPath == nil { return "Choose" }
        return isSelected ? "Change" : nil
    }
}
