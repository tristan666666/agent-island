import SwiftUI
import AppKit

/// A small, self-animating provider logo for the Settings status guide — it
/// shows the *real* behavior of each live state (breathing while working,
/// spinning on your-turn, red pulse when stalled) instead of a stand-in icon.
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
        if state == .stalled { return Self.alarmRed }
        return provider == .claude ? IslandColor.claude : IslandColor.codex
    }

    var body: some View {
        Group {
            if let image {
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
        case .stalled:  return pulse ? 1.14 : 0.97
        case .idle:     return 1.0
        }
    }

    private var glow: CGFloat {
        switch state {
        case .working:  return pulse ? 5 : 2
        case .needsYou: return pulse ? 7 : 4
        case .stalled:  return pulse ? 10 : 3
        case .idle:     return 0
        }
    }

    private func animate() {
        let dur: Double = state == .stalled ? 0.42 : (state == .needsYou ? 1.0 : 1.7)
        withAnimation(.easeInOut(duration: dur).repeatForever(autoreverses: true)) { pulse = true }
        if state == .needsYou {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                spin = (provider == .claude ? 1 : -1) * 360
            }
        }
    }
}
