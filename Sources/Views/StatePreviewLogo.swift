import SwiftUI
import AppKit

/// A small, self-animating provider logo for the Settings status guide — it
/// shows the real behavior of each live state instead of a stand-in icon.
/// Demo only: a fixed state, not wired to the live monitor.
struct StatePreviewLogo: View {
    let state: ActivityMonitor.State
    var provider: AlertEngine.Provider = .claude

    @State private var pulse = false
    @State private var spin: Double = 0

    private static let claudeImage = Bundle.main.url(forResource: "claude_logo", withExtension: "pdf").flatMap { NSImage(contentsOf: $0) }
    private static let codexImage = Bundle.main.url(forResource: "openai_logo", withExtension: "pdf").flatMap { NSImage(contentsOf: $0) }
    private static let alarmRed = Color(red: 0.96, green: 0.34, blue: 0.29)

    private var image: NSImage? { provider == .claude ? Self.claudeImage : Self.codexImage }
    private var tint: Color {
        switch state {
        case .stalled, .rateLimited, .authRequired: return Self.alarmRed
        case .idle, .working, .needsYou:
            return provider == .claude ? IslandColor.claude : IslandColor.codex
        }
    }

    var body: some View {
        Group {
            if state == .needsYou {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                        }
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 22, height: 18)
                .shadow(color: tint.opacity(0.36), radius: 4)
            } else if let image {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(spin))
                    .shadow(color: tint.opacity(pulse ? 0.8 : 0.2), radius: glow)
            } else {
                Circle().fill(tint).frame(width: 12, height: 12)
            }
        }
        .frame(width: 26, height: 26)
        .onAppear(perform: animate)
    }

    private var scale: CGFloat {
        switch state {
        case .working:  return pulse ? 1.06 : 0.97
        case .needsYou: return 1.0
        case .stalled, .authRequired, .rateLimited:  return pulse ? 1.14 : 0.97
        case .idle:     return 1.0
        }
    }

    private var glow: CGFloat {
        switch state {
        case .working:  return pulse ? 5 : 2
        case .needsYou: return 0
        case .stalled, .authRequired, .rateLimited:  return pulse ? 10 : 3
        case .idle:     return 0
        }
    }

    private func animate() {
        let blocked = state == .stalled || state == .authRequired || state == .rateLimited
        if state == .working || blocked {
            let dur: Double = blocked ? 0.42 : 1.7
            withAnimation(.easeInOut(duration: dur).repeatForever(autoreverses: true)) { pulse = true }
        }
        if state == .working {
            let duration = 3.8
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                spin = (provider == .claude ? 1 : -1) * 360
            }
        }
    }
}
