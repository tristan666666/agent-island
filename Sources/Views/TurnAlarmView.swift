import AppKit
import SwiftUI

struct TurnAlarmView: View {
    let provider: AlertEngine.Provider
    let providerName: String
    let thread: ActivityMonitor.ActiveThread?
    @ObservedObject var windowState: TurnAlarmWindowState
    let dismiss: () -> Void

    @ObservedObject private var reminders = AgentReminderStore.shared
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            alarmBackground

            VStack(spacing: 0) {
                Spacer(minLength: 42)

                TurnAlarmProviderMark(provider: provider, providerColor: providerColor)
                    .padding(.bottom, 20)

                VStack(spacing: 9) {
                    Text(L10n.tr("It's your turn"))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(waitingTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(providerColor)
                        .lineLimit(1)

                    Text(L10n.tr("The thread finished. Come back and reply."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.bottom, 24)

                if reminders.showSessionDetails {
                    TurnAlarmMetadata(
                        providerName: providerName,
                        threadName: threadName,
                        projectName: projectName,
                        providerColor: providerColor
                    )
                        .padding(.bottom, 22)
                }

                Button {
                    TurnAlarmNavigator.open(provider: provider, thread: thread)
                    dismiss()
                } label: {
                    Text(L10n.tr("Open thread"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 396, height: 48)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(buttonGradient)
                                .shadow(color: providerColor.opacity(0.46), radius: 18, y: 4)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text(L10n.tr("I know"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(width: 396, height: 42)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.08))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                                }
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 28)
        }
        .frame(width: windowState.size.width, height: windowState.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Color.clear)
        .preferredColorScheme(.dark)
        .onAppear(perform: startAnimations)
    }

    private var alarmBackground: some View {
        ZStack {
            Color(red: 0.020, green: 0.020, blue: 0.027)
            RadialGradient(
                colors: [
                    providerColor.opacity(glowPulse ? 0.34 : 0.20),
                    providerColor.opacity(glowPulse ? 0.11 : 0.05),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.15),
                startRadius: 16,
                endRadius: glowPulse ? 285 : 220
            )
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                providerColor.opacity(glowPulse ? 0.28 : 0.15),
                                providerColor.opacity(0.02),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 210)
                Spacer(minLength: 0)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 21)
                .strokeBorder(providerColor.opacity(glowPulse ? 0.56 : 0.30), lineWidth: glowPulse ? 1.25 : 0.8)
                .shadow(color: providerColor.opacity(glowPulse ? 0.52 : 0.24), radius: glowPulse ? 28 : 16)
                .padding(0.5)
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }

    private var providerColor: Color {
        provider == .claude ? IslandColor.claude : IslandColor.codex
    }

    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [providerColor.opacity(0.96), providerColor.opacity(0.72)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var waitingTitle: String {
        L10n.tr("%@ is waiting", headlineName)
    }

    private var headlineName: String {
        reminders.showSessionDetails ? threadName : providerName
    }

    private var threadName: String {
        guard let label = thread?.label, !label.isEmpty else {
            return L10n.tr("Demo thread")
        }
        return label
    }

    private var projectName: String? {
        guard let cwd = thread?.cwd, !cwd.isEmpty else { return nil }
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }
}
