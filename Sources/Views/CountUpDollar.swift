import SwiftUI

/// Count-up animated dollar number — the slot-machine reveal that gives
/// the cost screen its dopamine hit. Interpolates from `lastSeenTarget`
/// (or 0 on first appearance) to `target` over ~0.65s using a cubic
/// ease-out, driven by a 60Hz TimelineView.
///
/// Visually identical to the previous static text — same 38pt brand-color
/// monospace digits with the dual-shadow glow whose intensity is locked
/// to the *final* target so the halo settles cleanly when the count
/// finishes.
struct CountUpDollar: View {
    let target: Double
    let color: Color
    let glowOpacity: Double

    private static let duration: TimeInterval = 0.65

    @State private var animationStart: Date = Date()
    @State private var startValue: Double = 0
    @State private var lastSeenTarget: Double = 0
    /// Gates the 60Hz TimelineView. Once the count settles we render a
    /// plain `Text` so SwiftUI stops re-evaluating this body 60 times per
    /// second. Four cost cells each running idle TimelineViews adds up.
    @State private var animating: Bool = false
    @State private var animationToken: UUID = UUID()

    var body: some View {
        Group {
            if animating {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    let elapsed = context.date.timeIntervalSince(animationStart)
                    digits(formatted(interpolatedValue(elapsed: elapsed)))
                }
            } else {
                digits(formatted(lastSeenTarget))
            }
        }
        .onAppear {
            // Slot-machine reveal on first hover: rip from $0 up to current.
            startValue = 0
            animationStart = Date()
            lastSeenTarget = target
            startAnimation()
        }
        .onChange(of: target) { _ in
            // Smooth update during a refresh — count from where the eye
            // last saw the number, not from zero.
            startValue = lastSeenTarget
            animationStart = Date()
            lastSeenTarget = target
            startAnimation()
        }
    }

    @ViewBuilder
    private func digits(_ text: String) -> some View {
        Text(text)
            .font(Typography.bigNumber)
            .foregroundStyle(color)
            .shadow(color: color.opacity(glowOpacity), radius: 6)
            .shadow(color: color.opacity(glowOpacity * 0.5), radius: 14)
    }

    private func startAnimation() {
        animating = true
        let token = UUID()
        animationToken = token
        // Settle slightly past `duration` so the final frame definitely
        // renders the target value before the TimelineView is torn down.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.05) {
            guard animationToken == token else { return }
            animating = false
        }
    }

    private func interpolatedValue(elapsed: TimeInterval) -> Double {
        guard elapsed < Self.duration else { return target }
        let t = max(0, min(1, elapsed / Self.duration))
        let eased = 1 - pow(1 - t, 3)
        return startValue + (target - startValue) * eased
    }

    /// Cents under $100 (where they're meaningful); rounded above so a
    /// 7-digit month total fits the 38pt slot.
    private func formatted(_ v: Double) -> String {
        if v < 100 { return String(format: "%.2f", v) }
        return String(format: "%.0f", v)
    }
}
