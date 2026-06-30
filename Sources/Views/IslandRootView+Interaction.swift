import AppKit
import SwiftUI

extension IslandRootView {
    func handleTap() {
        if NSEvent.modifierFlags.contains(.command) {
            switch ScreenPref.shared.screen {
            case .usage: StylePref.shared.cycle()
            case .cost: CostStylePref.shared.cycle()
            case .overview, .triggers: return
            }
            return
        }
        guard model.state == .peek || model.state == .compact else { return }
        withAnimation(.openMorph) {
            model.setState(.expanded)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard model.state == .expanded else { return }
            withAnimation(.strongEaseOut) {
                contentVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.18)) {
                pillsVisible = false
            }
        }
    }

    func handleHover(_ isHovering: Bool) {
        hovering = isHovering
        isHovering ? enterPeekFromHover() : exitPeekFromHover()
    }

    func handleAppear() {
        if claudeLogo == nil {
            claudeLogo = Bundle.main.url(forResource: "claude_logo", withExtension: "pdf")
                .flatMap { NSImage(contentsOf: $0) }
        }
        if openaiLogo == nil {
            openaiLogo = Bundle.main.url(forResource: "openai_logo", withExtension: "pdf")
                .flatMap { NSImage(contentsOf: $0) }
        }
        if alwaysShow.enabled && model.state == .compact {
            model.setState(.peek)
            pillsVisible = true
        }
    }

    func handleAlwaysShowChange(_ enabled: Bool) {
        guard !hovering, model.state != .expanded else { return }
        if enabled {
            enterPeekForAlwaysShow()
        } else {
            exitPeekForAlwaysShow()
        }
    }

    func handlePulse(_ event: AlertEngine.PulseEvent) {
        guard model.state != .expanded else { return }

        if model.state == .compact {
            withAnimation(.openMorph) {
                model.setState(.peek)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                guard model.state == .peek else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    pillsVisible = true
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            guard !hovering, model.state == .peek, !alwaysShow.enabled else { return }
            withAnimation(.easeOut(duration: 0.08)) {
                pillsVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                guard !hovering, model.state == .peek, !alwaysShow.enabled else { return }
                withAnimation(.closeMorph) {
                    model.setState(.compact)
                }
            }
        }
    }

    var restState: IslandModel.State {
        alwaysShow.enabled ? .peek : .compact
    }

    var accessibilityHintForState: String {
        switch model.state {
        case .compact:
            return alwaysShow.enabled
                ? L10n.tr("Click to expand. Command-click to cycle visualization.")
                : L10n.tr("Hover to peek usage. Click to expand. Command-click to cycle visualization.")
        case .peek:
            return L10n.tr("Click to expand. Command-click to cycle visualization.")
        case .expanded:
            return ScreenPref.shared.screen == .overview
                ? L10n.tr("Swipe to change pages.")
                : L10n.tr("Command-click to cycle visualization.")
        }
    }

    var logoEdgePadding: CGFloat {
        switch model.state {
        case .compact, .expanded: return 9
        case .peek: return model.pillSlotWidth + 9
        }
    }

    private func enterPeekFromHover() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        guard model.state == .compact else { return }
        withAnimation(.openMorph) {
            model.setState(.peek)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            guard model.state == .peek else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                pillsVisible = true
            }
        }
    }

    private func exitPeekFromHover() {
        if !alwaysShow.enabled {
            withAnimation(.easeOut(duration: 0.08)) {
                pillsVisible = false
            }
        }
        withAnimation(.easeOut(duration: 0.10)) {
            contentVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            guard !hovering else { return }
            let target = restState
            if model.state != target {
                withAnimation(.closeMorph) {
                    model.setState(target)
                }
            }
            if alwaysShow.enabled && !pillsVisible {
                withAnimation(.easeOut(duration: 0.18)) {
                    pillsVisible = true
                }
            }
        }
    }

    private func enterPeekForAlwaysShow() {
        guard model.state == .compact else { return }
        withAnimation(.openMorph) {
            model.setState(.peek)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            guard model.state == .peek, !hovering else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                pillsVisible = true
            }
        }
    }

    private func exitPeekForAlwaysShow() {
        guard model.state == .peek else { return }
        withAnimation(.easeOut(duration: 0.08)) {
            pillsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            guard !hovering, model.state == .peek, !alwaysShow.enabled else { return }
            withAnimation(.closeMorph) {
                model.setState(.compact)
            }
        }
    }
}
