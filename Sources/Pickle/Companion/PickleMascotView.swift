import SwiftUI

/// The star of the show: Pickle, drawn entirely in SwiftUI vectors so he scales
/// crisply and animates per-feature. He blinks, bobs, reacts to your voice while
/// recording, squints while thinking, and changes expression with his mood.
struct PickleMascotView: View {
    var mood: MascotMood = .idle
    /// 0…1 microphone level — only used while `.listening`, drives mouth + sway.
    var audioLevel: CGFloat = 0
    var size: CGFloat = 96

    @State private var bob: CGFloat = 0
    @State private var blink: Bool = false
    @State private var sparkle: Bool = false

    var body: some View {
        ZStack {
            // Soft mood halo
            Circle()
                .fill(moodTint.opacity(0.30))
                .frame(width: size * 1.25, height: size * 1.25)
                .blur(radius: size * 0.18)

            pickleBody
                .frame(width: size * 0.62, height: size)
                .offset(y: bob)
                .rotationEffect(.degrees(sway))

            if mood == .impressed || mood == .celebrating {
                sparkles
            }
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .onAppear { startIdleLoops() }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: mood)
    }

    // MARK: Body

    private var pickleBody: some View {
        ZStack {
            // Brine-green body with bumpy outline
            PickleShape()
                .fill(Theme.pickleGradient)
                .overlay(PickleShape().strokeBorder(Theme.pickleDeep.opacity(0.6), lineWidth: 2))
                .overlay(bumps)
                .overlay(highlight)

            // Face
            VStack(spacing: size * 0.045) {
                eyes
                mouth
            }
            .offset(y: -size * 0.04)
        }
    }

    private var bumps: some View {
        Canvas { ctx, rect in
            let dots: [(CGFloat, CGFloat)] = [(0.30,0.22),(0.66,0.30),(0.40,0.45),(0.70,0.58),(0.34,0.68),(0.60,0.78)]
            for (x, y) in dots {
                let r = rect.width * 0.045
                let p = CGRect(x: rect.width*x - r, y: rect.height*y - r, width: r*2, height: r*2)
                ctx.fill(Path(ellipseIn: p), with: .color(Theme.pickleDeep.opacity(0.25)))
            }
        }
    }

    private var highlight: some View {
        PickleShape()
            .fill(
                LinearGradient(colors: [.white.opacity(0.35), .clear],
                               startPoint: .topLeading, endPoint: .center)
            )
            .blendMode(.softLight)
    }

    // MARK: Eyes

    private var eyes: some View {
        HStack(spacing: size * 0.12) {
            eye
            eye
        }
    }

    private var eye: some View {
        ZStack {
            Capsule()
                .fill(.white)
                .frame(width: size * 0.16, height: blink ? size * 0.02 : eyeOpenHeight)
            if !blink {
                Circle()
                    .fill(.black.opacity(0.85))
                    .frame(width: size * 0.075, height: size * 0.075)
                    .offset(y: pupilOffset)
            }
        }
        .overlay(alignment: .top) {
            // skeptical / roasting brow
            if mood == .skeptical || mood == .roasting {
                Capsule().fill(Theme.pickleDeep)
                    .frame(width: size * 0.18, height: size * 0.03)
                    .rotationEffect(.degrees(mood == .roasting ? -12 : 8))
                    .offset(y: -size * 0.08)
            }
        }
    }

    private var eyeOpenHeight: CGFloat {
        switch mood {
        case .thinking:  return size * 0.03           // squinting
        case .listening: return size * 0.22           // wide
        case .impressed, .celebrating: return size * 0.20
        default:         return size * 0.15
        }
    }

    private var pupilOffset: CGFloat {
        switch mood {
        case .listening: return -size * 0.03          // looking up, attentive
        case .roasting:  return size * 0.02
        default:         return 0
        }
    }

    // MARK: Mouth

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .listening:
            // opens with your voice
            Capsule()
                .fill(Theme.pickleDeep)
                .frame(width: size * 0.14, height: size * (0.04 + 0.16 * audioLevel))
        case .thinking:
            Capsule().fill(Theme.pickleDeep)
                .frame(width: size * 0.10, height: size * 0.03)
                .offset(x: size * 0.06)               // pursed to one side
        case .impressed, .celebrating:
            Smile(curve: 0.9).stroke(Theme.pickleDeep, style: .init(lineWidth: 2.5, lineCap: .round))
                .frame(width: size * 0.26, height: size * 0.12)
        case .roasting:
            Smile(curve: 0.5).stroke(Theme.pickleDeep, style: .init(lineWidth: 2.5, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.08)
                .scaleEffect(x: 1, y: 1).rotationEffect(.degrees(-6))  // smirk
        case .skeptical:
            Capsule().fill(Theme.pickleDeep).frame(width: size * 0.16, height: size * 0.025)
        default:
            Smile(curve: 0.6).stroke(Theme.pickleDeep, style: .init(lineWidth: 2.5, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.10)
        }
    }

    // MARK: Sparkles

    private var sparkles: some View {
        ForEach(0..<5, id: \.self) { i in
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.12))
                .foregroundStyle(Theme.brassBright)
                .offset(sparkleOffset(i))
                .opacity(sparkle ? 1 : 0.2)
                .scaleEffect(sparkle ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.7).repeatForever().delay(Double(i) * 0.12), value: sparkle)
        }
    }

    private func sparkleOffset(_ i: Int) -> CGSize {
        let positions: [CGSize] = [
            .init(width: -size*0.5, height: -size*0.4),
            .init(width:  size*0.5, height: -size*0.3),
            .init(width: -size*0.45, height: size*0.35),
            .init(width:  size*0.5, height: size*0.4),
            .init(width:  0, height: -size*0.6)
        ]
        return positions[i % positions.count]
    }

    // MARK: Mood styling

    private var moodTint: Color {
        switch mood {
        case .impressed, .celebrating: return Theme.brassBright
        case .roasting:  return Theme.hot
        case .skeptical: return Theme.warm
        case .listening: return Theme.pickleLight
        case .thinking:  return Theme.cool
        default:         return Theme.pickle
        }
    }

    private var sway: Double {
        guard mood == .listening else { return 0 }
        return Double(audioLevel) * 6 - 3
    }

    // MARK: Animation loops

    private func startIdleLoops() {
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            bob = -size * 0.04
        }
        sparkle = true
        scheduleBlink()
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.4...5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.10)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.10)) { blink = false }
                scheduleBlink()
            }
        }
    }
}

// MARK: - Shapes

/// A friendly gherkin silhouette: a tapered, slightly curved capsule.
struct PickleShape: InsettableShape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> some InsettableShape {
        var s = self; s.inset += amount; return s
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        let w = r.width, h = r.height
        let topW = w * 0.74, botW = w * 0.92
        p.move(to: CGPoint(x: r.midX - topW/2, y: r.minY + h*0.10))
        // left side curving out toward the bottom
        p.addCurve(to: CGPoint(x: r.midX - botW/2, y: r.maxY - h*0.10),
                   control1: CGPoint(x: r.midX - topW/2 - w*0.06, y: r.minY + h*0.4),
                   control2: CGPoint(x: r.midX - botW/2 - w*0.02, y: r.maxY - h*0.4))
        // rounded bottom
        p.addCurve(to: CGPoint(x: r.midX + botW/2, y: r.maxY - h*0.10),
                   control1: CGPoint(x: r.midX - botW*0.25, y: r.maxY + h*0.02),
                   control2: CGPoint(x: r.midX + botW*0.25, y: r.maxY + h*0.02))
        // right side
        p.addCurve(to: CGPoint(x: r.midX + topW/2, y: r.minY + h*0.10),
                   control1: CGPoint(x: r.midX + botW/2 + w*0.02, y: r.maxY - h*0.4),
                   control2: CGPoint(x: r.midX + topW/2 + w*0.06, y: r.minY + h*0.4))
        // rounded top
        p.addCurve(to: CGPoint(x: r.midX - topW/2, y: r.minY + h*0.10),
                   control1: CGPoint(x: r.midX + topW*0.25, y: r.minY - h*0.02),
                   control2: CGPoint(x: r.midX - topW*0.25, y: r.minY - h*0.02))
        p.closeSubpath()
        return p
    }
}

/// A simple smile arc; `curve` 0…1 controls how big the grin is.
struct Smile: Shape {
    var curve: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * curve * 2)
        )
        return p
    }
}
