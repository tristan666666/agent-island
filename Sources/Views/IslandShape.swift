import SwiftUI

/// The notch silhouette: flat top (sits flush with the screen edge) and
/// rounded bottom corners that mirror the physical notch's inner curves.
///
/// Uses `.continuous` (squircle) corners — curvature ramps in gradually
/// instead of jumping to a constant radius, matching how Apple draws the
/// hardware notch and the Dynamic Island. Plain circular arcs at this
/// scale show a visible kink at the tangent point.
struct IslandShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let radius: CGFloat = 14
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 0,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: 0
            ),
            style: .continuous
        ).path(in: r)
    }

    func inset(by amount: CGFloat) -> IslandShape {
        var s = self
        s.inset += amount
        return s
    }
}
