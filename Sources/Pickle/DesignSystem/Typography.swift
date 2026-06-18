import SwiftUI

/// Type ramp. Rounded for warmth (companion feel), monospaced digits for scores.
extension Font {
    static func pickleTitle(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func pickleHeadline(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func pickleBody(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func pickleCaption(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func pickleScore(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }
}
