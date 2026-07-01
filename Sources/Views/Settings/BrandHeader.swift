import SwiftUI
import AppKit

/// The Settings window's brand row. Replaces the empty traffic-light
/// gutter and the duplicate "NOW" stats from the previous design.
///
/// Three elements left to right: the AgentIsland brand mark (the curly-
/// brace island glyph that ships in `Resources/agentisland_logo.png`,
/// rendered from a transparent template image), the
/// app name + tagline, and a version pill on the right.
struct BrandHeader: View {
    let version: String

    private var logo: NSImage? {
        Bundle.main.url(forResource: "agentisland_logo", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            mark

            VStack(alignment: .leading, spacing: 2) {
                Text("Agent Island")
                    .font(Typography.brand)
                    .tracking(-0.15)
                    .foregroundStyle(.white.opacity(0.92))
                Text(L10n.tr("A status companion for Claude Code and Codex"))
                    .font(Typography.label)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 8)

            Text("v\(version)")
                .font(Typography.bodyNumber)
                .foregroundStyle(.white.opacity(0.34))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(.white.opacity(0.04))
                )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private var mark: some View {
        if let logo {
            Image(nsImage: logo)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.4), radius: 5)
        } else {
            // Fallback if the resource is missing in the bundle: a plain
            // cobalt-glowing dot so the header layout doesn't collapse.
            Circle()
                .fill(IslandColor.cobalt)
                .frame(width: 10, height: 10)
                .shadow(color: IslandColor.cobalt.opacity(0.85), radius: 5)
                .frame(width: 26, height: 26)
        }
    }
}
