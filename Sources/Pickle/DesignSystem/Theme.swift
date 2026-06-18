import SwiftUI

/// Pickle's visual identity. Warm, briny, confident — a tiny investor with taste.
/// Not generic AI-slop: a pickle-green + cream palette with a brass accent,
/// tuned for a glass panel that floats over the desktop.
enum Theme {

    // MARK: Brand palette

    /// Deep brine green — Pickle's body.
    static let pickle       = Color(hex: 0x4E7C3A)
    static let pickleLight  = Color(hex: 0x7BAE52)
    static let pickleDeep   = Color(hex: 0x37562A)

    /// Warm cream — panel "paper", not stark white.
    static let cream        = Color(hex: 0xF4F1E8)

    /// Brass accent — the money color.
    static let brass        = Color(hex: 0xC9A24B)
    static let brassBright  = Color(hex: 0xE6C66E)

    /// Verdict colors — interest rating.
    static let hot          = Color(hex: 0xE3633B)   // sizzling / brutal
    static let warm         = Color(hex: 0xE6A23C)   // promising
    static let cool         = Color(hex: 0x4E9C8F)   // strong

    // MARK: Score → color ramp

    /// Map a 0–100 score onto the cool→warm→hot ramp.
    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case ..<40:  return hot
        case 40..<55: return Color(hex: 0xE6843C)
        case 55..<70: return warm
        case 70..<85: return Color(hex: 0x8FB94E)
        default:      return cool
        }
    }

    // MARK: Gradients

    static let pickleGradient = LinearGradient(
        colors: [pickleLight, pickle, pickleDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let brassGradient = LinearGradient(
        colors: [brassBright, brass],
        startPoint: .top, endPoint: .bottom
    )

    static func ringGradient(for score: Int) -> AngularGradient {
        let c = scoreColor(score)
        return AngularGradient(
            colors: [c.opacity(0.55), c, c.opacity(0.9)],
            center: .center
        )
    }

    // MARK: Shadows / corners

    static let panelCorner: CGFloat = 22
    static let cardCorner: CGFloat = 14
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8)  & 0xff) / 255,
            blue:  Double( hex        & 0xff) / 255,
            opacity: alpha
        )
    }
}
