import AppKit
import SwiftUI

struct TurnAlarmProviderMark: View {
    let provider: AlertEngine.Provider
    let providerColor: Color
    private static let claudeLogo = loadLogo("claude_logo")
    private static let openAILogo = loadLogo("openai_logo")
    @State private var glowPulse = false
    @State private var ringPulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(providerColor.opacity(glowPulse ? 0.12 : 0.20))
                .frame(width: 138, height: 138)
                .blur(radius: glowPulse ? 28 : 18)
                .scaleEffect(glowPulse ? 1.12 : 0.92)

            Circle()
                .stroke(providerColor.opacity(glowPulse ? 0.10 : 0.28), lineWidth: 1)
                .frame(width: 124, height: 124)
                .scaleEffect(glowPulse ? 1.16 : 0.82)
                .opacity(glowPulse ? 0.32 : 0.90)

            Circle()
                .stroke(providerColor.opacity(glowPulse ? 0.30 : 0.14), lineWidth: 0.75)
                .frame(width: 92, height: 92)
                .scaleEffect(glowPulse ? 0.96 : 1.08)

            providerLogo
                .frame(width: 76, height: 76)
                .foregroundStyle(providerColor)
                .scaleEffect(ringPulse ? 1.025 : 0.985)
                .shadow(color: providerColor.opacity(glowPulse ? 0.86 : 0.48), radius: glowPulse ? 30 : 18)
        }
        .frame(width: 148, height: 126)
        .onAppear(perform: startAnimations)
    }

    @ViewBuilder
    private var providerLogo: some View {
        if let image = logoImage {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: provider == .claude ? "sparkle" : "circle.hexagongrid.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    private var logoImage: NSImage? {
        provider == .claude ? Self.claudeLogo : Self.openAILogo
    }

    private static func loadLogo(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "pdf")
            .flatMap { NSImage(contentsOf: $0) }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
        withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
            ringPulse = true
        }
    }
}

struct TurnAlarmMetadata: View {
    let providerName: String
    let threadName: String
    let projectName: String?
    let providerColor: Color

    var body: some View {
        HStack(spacing: 0) {
            metadataColumn(title: "Alarm provider", value: providerName, showsDot: true)
            Divider().frame(height: 40).overlay(.white.opacity(0.08))
            metadataColumn(title: "Alarm thread", value: threadName)
            Divider().frame(height: 40).overlay(.white.opacity(0.08))
            metadataColumn(title: "Alarm project", value: projectName ?? L10n.tr("Unknown"))
        }
        .frame(width: 396)
    }

    private func metadataColumn(title: String, value: String, showsDot: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.tr(title))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.36))
            HStack(spacing: 7) {
                if showsDot {
                    Circle()
                        .fill(providerColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: providerColor.opacity(0.7), radius: 5)
                }
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
    }
}
