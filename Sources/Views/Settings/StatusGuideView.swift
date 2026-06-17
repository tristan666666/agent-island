import SwiftUI

/// Settings tab (after Auto-Trigger) that explains what the island's logo
/// animations mean — each row shows the real logo demoing that state — plus a
/// switch to silence the stall beep.
struct StatusGuideView: View {
    @ObservedObject private var sound = StallSoundStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.tr("What the island's two logos are telling you."))
                .font(Typography.label)
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.bottom, 12)

            sectionLabel("Logo states")
            legendRow(.working, "Working", "The agent is producing output — its logo gently breathes.")
            legendRow(.needsYou, "Your turn", "A turn finished — the logo spins (Claude ↻, Codex ↺) so you know to reply.")
            legendRow(.stalled, "Stalled", "A session froze mid-conversation — the logo turns red and beeps.")

            sectionLabel("Sound").padding(.top, 14)
            SettingsRow(
                title: "Stall sound",
                subtitle: "Beep when a session stalls. Turn off for a silent red alert."
            ) {
                SettingsToggle(isOn: sound.enabled) { sound.enabled.toggle() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 16)
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
