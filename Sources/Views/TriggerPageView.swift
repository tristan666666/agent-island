import SwiftUI

/// The 4th expanded-panel page. A quick auto-trigger surface: next-reset
/// countdowns per provider, the configured triggers with on/off + run-now,
/// and a shortcut into the full Settings page to add or edit.
struct TriggerPageView: View {
    @ObservedObject private var store = TriggerStore.shared
    @ObservedObject private var usage = UsageStore.shared

    private static let rel: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = L10n.locale
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            resetRow
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
            if store.triggers.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(store.triggers) { row($0) }
                    }
                    .padding(.bottom, 2)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var resetRow: some View {
        HStack(spacing: 16) {
            resetPill(.claude, IslandColor.claude, usage.claude.fiveHour.resetAt)
            resetPill(.codex, IslandColor.codex, usage.codex.fiveHour.resetAt)
            Spacer(minLength: 8)
            Button(action: openSettings) {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 10))
                    Text(L10n.tr("Manage")).font(Typography.label)
                }
                .foregroundStyle(.white.opacity(0.70))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func resetPill(_ tool: TriggerTool, _ color: Color, _ reset: Date?) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6).shadow(color: color.opacity(0.6), radius: 3)
            Text(tool.display).font(Typography.label).foregroundStyle(.white.opacity(0.82))
            Text(reset.map { Self.rel.localizedString(for: $0, relativeTo: Date()) } ?? "—")
                .font(Typography.bodyNumber).foregroundStyle(.white.opacity(0.50))
        }
    }

    private func row(_ trigger: Trigger) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(trigger.tool == .claude ? IslandColor.claude : IslandColor.codex)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(trigger.label).font(Typography.label).foregroundStyle(.white.opacity(0.92)).lineLimit(1)
                Text(subtitle(trigger)).font(Typography.micro).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: { TriggerEngine.shared.fire(trigger) }) {
                Image(systemName: "play.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.65))
                    .frame(width: 22, height: 22).background(Circle().fill(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("Run now"))
            SettingsToggle(isOn: trigger.enabled) { store.setEnabled(trigger.id, !trigger.enabled) }
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.035)))
    }

    private func subtitle(_ trigger: Trigger) -> String {
        let when = trigger.mode == .afterReset
            ? L10n.tr("after reset")
            : L10n.tr("every %dh", trigger.everyHours)
        return "「\(trigger.message)」 · \(when)"
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Text(L10n.tr("No triggers yet."))
                .font(Typography.label).foregroundStyle(.white.opacity(0.45))
            Button(action: openSettings) {
                Text(L10n.tr("Add a trigger"))
                    .font(Typography.button)
                    .foregroundStyle(Color(red: 0.14, green: 0.11, blue: 0.02))
                    .padding(.horizontal, 13).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(IslandColor.cobalt.opacity(0.9)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 16)
    }

    private func openSettings() {
        UserDefaults.standard.set("triggers", forKey: "Settings.activeTab")
        SettingsWindowController.shared.show()
    }
}
