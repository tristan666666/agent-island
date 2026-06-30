import SwiftUI
import AppKit

struct IslandRootView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var alwaysShow = AlwaysShowUsageStore.shared
    @State var hovering = false
    @State var contentVisible = false
    @State var pillsVisible = false
    @State var pulseToken: UUID?

    /// Image decode from disk is ~150µs per call. Computed properties
    /// re-decoded both logos every render — inside a 120Hz TimelineView
    /// that's 240 main-thread decodes/sec. Cache once on appear.
    @State var claudeLogo: NSImage?
    @State var openaiLogo: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Only the rotating loading sweep needs per-frame re-renders
            // (its angle is a function of time). Everything else animates
            // via withAnimation springs paced by display sync, so wrapping
            // the whole tree in TimelineView would re-build every overlay
            // and every gesture closure 120 times per second — competing
            // with the spring for main-thread budget and showing up as
            // hover-spring jank.
            ZStack {
                GlowLayer(
                    isExpanded: model.state == .expanded,
                    hovering: hovering
                )

                if model.state == .expanded {
                    ExpandedView(model: model)
                        .opacity(contentVisible ? 1 : 0)
                        // Slide down from -8 → 0 on enter pairs with the
                        // 100ms→180ms opacity delay set in onHover. On
                        // exit the offset never matters because the
                        // content fully fades before the shape shrinks.
                        .offset(y: contentVisible ? 0 : -8)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .allowsHitTesting(contentVisible)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: model.size.width, height: model.size.height)
            .background {
                    // Frosted halo. ultraThinMaterial is a backdrop blur of
                    // whatever desktop content is behind the window. Lives
                    // in .background AFTER .frame so it doesn't push the
                    // ZStack's layout box larger than model.size — earlier
                    // attempts that put the halo as a sibling inside the
                    // ZStack with its own oversized .frame ended up
                    // expanding the parent bounds, throwing the logo
                    // overlays off and breaking the compact pill alignment
                    // with the physical notch.
                    //
                    // .padding(-9) extends only the rendering by 9pt past
                    // the silhouette on every side, no layout impact.
                    // Opacity tied to contentVisible so it fades alongside
                    // the panel content (220ms after hover-in, immediately
                    // on hover-out) and the .frame here tracks model.size,
                    // so the halo grows/shrinks with the spring morph.
                    IslandShape()
                        .fill(.ultraThinMaterial)
                        .padding(-9)
                        .blur(radius: 8)
                        .opacity(contentVisible ? 0.55 : 0)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    LogoOverlay(
                        image: claudeLogo,
                        color: IslandColor.claude,
                        provider: .claude,
                        edgePadding: logoEdgePadding,
                        topPadding: max(0, (model.notch.height - 20) / 2)
                    )
                }
                .overlay(alignment: .topTrailing) {
                    LogoOverlay(
                        image: openaiLogo,
                        color: IslandColor.codex,
                        provider: .codex,
                        edgePadding: logoEdgePadding,
                        topPadding: max(0, (model.notch.height - 20) / 2)
                    )
                }
                .overlay(alignment: .topLeading) {
                    // Pill lives in the new outboard slot (the 78pt the
                    // silhouette grew on entering peek). 14pt inset from the
                    // silhouette's new leading edge keeps it visually
                    // breathing inside the rounded corner.
                    if model.state != .compact {
                        PeekPillOverlay(
                            provider: .claude,
                            slotWidth: model.pillSlotWidth,
                            topPadding: max(0, (model.notch.height - 14) / 2),
                            pillsVisible: pillsVisible
                        )
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if model.state != .compact {
                        PeekPillOverlay(
                            provider: .codex,
                            slotWidth: model.pillSlotWidth,
                            topPadding: max(0, (model.notch.height - 14) / 2),
                            pillsVisible: pillsVisible
                        )
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    // Utility control, not dashboard status. Keep it in a
                    // quiet corner so the footer remains about live data.
                    if model.state == .expanded {
                        SettingsButton()
                            .opacity(contentVisible ? 1 : 0)
                            .padding(6)
                    }
                }
                .contentShape(IslandShape())
                .onTapGesture(perform: handleTap)
                .onHover(perform: handleHover)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.tr("AgentIsland panel"))
        .accessibilityHint(accessibilityHintForState)
        .onAppear(perform: handleAppear)
        .onChange(of: alwaysShow.enabled, perform: handleAlwaysShowChange)
        .onReceive(AlertEngine.shared.$pulseEvent) { event in
            guard let event, event.id != pulseToken else { return }
            pulseToken = event.id
            handlePulse(event)
            // Consume the event so a re-emission with the same id doesn't
            // re-trigger; the engine writes a fresh PulseEvent for each new
            // crossing tick.
            AlertEngine.shared.pulseEvent = nil
        }
    }

}
