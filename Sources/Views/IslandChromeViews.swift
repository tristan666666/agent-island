import SwiftUI
import AppKit

struct GlowLayer: View {
    let isExpanded: Bool
    let hovering: Bool

    @ObservedObject private var usageStore = UsageStore.shared
    @ObservedObject private var costStore = CostStore.shared
    @ObservedObject private var lowPower = LowPowerModeStore.shared
    @ObservedObject private var alerts = AlertEngine.shared
    @ObservedObject private var monitor = ActivityMonitor.shared
    @ObservedObject private var occlusion = WindowOcclusionStore.shared
    @State private var stallPulse = false

    var body: some View {
        ZStack {
            LoadingSweep(
                active: !occlusion.isOccluded
                    && (lowPower.effectiveEnabled ? glowEventActive : true),
                tint: glowColor
            )

            IslandShape()
                .fill(.black)
                .overlay {
                    IslandShape()
                        .strokeBorder(.white.opacity(isExpanded ? 0.12 : 0), lineWidth: 0.5)
                }
                .shadow(
                    color: glowColor.opacity(attentionActive
                        ? (stallPulse ? 0.85 : 0.35)
                        : (lowPower.effectiveEnabled ? (glowEventActive ? 0.35 : 0) : 0.35)),
                    radius: attentionActive ? (stallPulse ? 22 : 14) : 14,
                    y: 0
                )
                .animation(attentionActive
                    ? .easeInOut(duration: 0.42).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.25),
                    value: attentionActive ? stallPulse : glowEventActive)
                .onAppear { stallPulse = true }
                .animation(.easeInOut(duration: 0.45), value: alerts.severity)
                .shadow(color: isExpanded ? .black.opacity(0.5) : .clear, radius: 20, y: 10)
        }
    }

    private var glowEventActive: Bool {
        hovering || usageStore.loading || costStore.loading || alerts.severity != .none
    }

    private var glowColor: Color {
        if attentionActive { return IslandColor.alertRed }
        switch alerts.severity {
        case .none: return IslandColor.cobalt
        case .warning: return IslandColor.alertAmber
        case .critical: return IslandColor.alertRed
        }
    }

    private var attentionActive: Bool {
        monitor.claude.isAttentionState || monitor.codex.isAttentionState
    }
}

struct LogoOverlay: View {
    let image: NSImage?
    let color: Color
    let provider: AlertEngine.Provider
    let edgePadding: CGFloat
    let topPadding: CGFloat

    @ObservedObject private var visibility = ProviderVisibilityStore.shared
    @ObservedObject private var monitor = ActivityMonitor.shared
    @State private var pulse = false
    @State private var spinAngle: Double = 0

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .scaleEffect(scale)
                .rotationEffect(.degrees(spinAngle))
                .shadow(color: tint.opacity(pulse ? 0.9 : 0.25), radius: glowRadius)
                .padding(provider == .claude ? .leading : .trailing, edgePadding)
                .padding(.top, topPadding)
                .opacity(isVisible ? 1 : 0)
                .animation(.openMorph, value: isVisible)
                .animation(pulseAnimation, value: pulse)
                .animation(.easeInOut(duration: 0.3), value: st)
                .onAppear { pulse = true; updateSpin(st) }
                .onChange(of: st) { newState in
                    pulse = false
                    DispatchQueue.main.async { pulse = true }
                    updateSpin(newState)
                }
                .accessibilityLabel(isVisible ? providerLabel : L10n.tr("%@ (hidden)", providerLabel))
                .accessibilityHidden(!isVisible)
        }
    }

    private static let alarmRed = Color(red: 0.96, green: 0.34, blue: 0.29)

    private var tint: Color {
        switch st {
        case .stalled, .rateLimited, .authRequired: return Self.alarmRed
        case .idle, .working, .needsYou: return color
        }
    }

    private var st: ActivityMonitor.State {
        isVisible ? monitor.state(for: provider) : .idle
    }

    private var scale: CGFloat {
        switch st {
        case .idle, .needsYou: return 1.0
        case .working: return pulse ? 1.05 : 1.0
        case .stalled, .authRequired, .rateLimited: return pulse ? 1.16 : 1.0
        }
    }

    private var glowRadius: CGFloat {
        switch st {
        case .idle, .needsYou: return 0
        case .working: return pulse ? 5 : 2
        case .stalled, .authRequired, .rateLimited: return pulse ? 11 : 4
        }
    }

    private var pulseAnimation: Animation {
        switch st {
        case .idle, .needsYou: return .easeOut(duration: 0.3)
        case .working: return .easeInOut(duration: 1.7).repeatForever(autoreverses: true)
        case .stalled, .authRequired, .rateLimited: return .easeInOut(duration: 0.42).repeatForever(autoreverses: true)
        }
    }

    private var spinDirection: Double { provider == .claude ? 1 : -1 }

    private func updateSpin(_ state: ActivityMonitor.State) {
        guard state == .working else {
            withAnimation(.easeOut(duration: 0.35)) { spinAngle = 0 }
            return
        }
        spinAngle = 0
        DispatchQueue.main.async {
            withAnimation(.linear(duration: 3.8).repeatForever(autoreverses: false)) {
                spinAngle = spinDirection * 360
            }
        }
    }

    private var isVisible: Bool {
        visibility.effectiveVisible(provider: provider)
    }

    private var providerLabel: String {
        switch provider {
        case .claude: return "Claude"
        case .codex: return "OpenAI"
        }
    }
}

struct PeekPillOverlay: View {
    let provider: AlertEngine.Provider
    let slotWidth: CGFloat
    let topPadding: CGFloat
    let pillsVisible: Bool

    @ObservedObject private var visibility = ProviderVisibilityStore.shared
    @ObservedObject private var usageStore = UsageStore.shared
    @ObservedObject private var alerts = AlertEngine.shared

    var body: some View {
        let window = currentWindow
        NotchPeekPill(
            usage: window,
            loading: usageStore.loading,
            tint: tint,
            alignment: provider == .claude ? .leading : .trailing,
            severity: severity
        )
        .frame(width: pillContentWidth, alignment: provider == .claude ? .leading : .trailing)
        .padding(provider == .claude ? .leading : .trailing, 14)
        .padding(.top, topPadding)
        .opacity((pillsVisible && isVisible) ? 1 : 0)
        .animation(.openMorph, value: isVisible)
        .offset(x: pillsVisible ? 0 : (provider == .claude ? -6 : 6))
        .allowsHitTesting(false)
        .accessibilityLabel(peekLabel(for: window, provider: providerLabel))
        .accessibilityHidden(!(pillsVisible && isVisible))
    }

    private var isVisible: Bool {
        visibility.effectiveVisible(provider: provider)
    }

    private var pillContentWidth: CGFloat {
        max(0, slotWidth - 14)
    }

    private var currentWindow: WindowUsage {
        switch provider {
        case .claude: return usageStore.claude.fiveHour
        case .codex: return usageStore.codex.fiveHour
        }
    }

    private var severity: AlertEngine.Severity {
        switch provider {
        case .claude: return alerts.claudeSeverity
        case .codex: return alerts.codexSeverity
        }
    }

    private var tint: Color {
        switch provider {
        case .claude: return IslandColor.claude
        case .codex: return IslandColor.codex
        }
    }

    private var providerLabel: String {
        switch provider {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    private func peekLabel(for window: WindowUsage, provider: String) -> String {
        if window.error != nil && window.usedPercent == 0 {
            return L10n.tr("%@: no data for 5-hour window", provider)
        }
        let pct = window.percentInt
        guard let resetAt = window.resetAt else {
            return L10n.tr("%@: %d percent of 5-hour window used", provider, pct)
        }
        let remaining = max(0, resetAt.timeIntervalSinceNow)
        let resetPhrase: String = remaining >= 3600
            ? L10n.tr("resets in %d hours", Int((remaining / 3600).rounded(.down)))
            : L10n.tr("resets in %d minutes", max(1, Int((remaining / 60).rounded(.down))))
        return L10n.tr("%@: %d percent of 5-hour window used, %@", provider, pct, resetPhrase)
    }
}

struct LoadingSweep: View {
    let active: Bool
    let tint: Color

    var body: some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let rotation = (context.date.timeIntervalSinceReferenceDate * 100).truncatingRemainder(dividingBy: 360)
                IslandShape()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: tint.opacity(0.0), location: 0.55),
                                .init(color: tint, location: 0.78),
                                .init(color: .white.opacity(0.95), location: 0.92),
                                .init(color: tint.opacity(0.0), location: 1.00),
                            ]),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 4
                    )
                    .blur(radius: 3)
            }
        }
    }
}
