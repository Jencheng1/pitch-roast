import SwiftUI
import AppKit

/// Native macOS vibrancy (`NSVisualEffectView`) wrapped for SwiftUI — the real
/// glass behind every Pickle surface. Falls back gracefully if unavailable.
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        v.isEmphasized = true
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}

/// The signature glass card: vibrancy + cream tint + hairline highlight.
struct GlassPanel: ViewModifier {
    var corner: CGFloat = Theme.panelCorner
    var tint: Color = Theme.cream.opacity(0.10)

    func body(content: Content) -> some View {
        content
            .background(VisualEffectBlur(material: .hudWindow))
            .background(tint)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
    }
}

extension View {
    func glassPanel(corner: CGFloat = Theme.panelCorner,
                    tint: Color = Theme.cream.opacity(0.10)) -> some View {
        modifier(GlassPanel(corner: corner, tint: tint))
    }

    /// A lighter inset card used inside the panel for grouped content.
    func glassCard() -> some View {
        self
            .background(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }
}
