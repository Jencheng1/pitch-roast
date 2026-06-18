import SwiftUI

// MARK: - Score ring

/// Animated circular gauge for the 0–100 overall score / interest rating.
struct ScoreRing: View {
    let score: Int
    var size: CGFloat = 110
    var caption: String? = nil

    @State private var animated: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 10)

            Circle()
                .trim(from: 0, to: animated)
                .stroke(
                    Theme.ringGradient(for: score),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.scoreColor(score).opacity(0.5), radius: 6)

            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.pickleScore(size * 0.34))
                    .foregroundStyle(.white)
                if let caption {
                    Text(caption)
                        .font(.pickleCaption(size * 0.10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.8)) {
                animated = CGFloat(min(max(score, 0), 100)) / 100
            }
        }
    }
}

// MARK: - Chip

struct Chip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = Theme.brass

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 9, weight: .bold)) }
            Text(text).font(.pickleCaption(10))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(tint.opacity(0.18))
        .foregroundStyle(tint)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
    }
}

// MARK: - Primary button

struct PickleButton: View {
    let title: String
    var systemImage: String? = nil
    var style: Style = .primary
    let action: () -> Void

    enum Style { case primary, ghost, danger }

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.pickleHeadline(13))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .scaleEffect(hovering ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .primary: Theme.pickleGradient
        case .ghost:   Color.white.opacity(hovering ? 0.12 : 0.06)
        case .danger:  Theme.hot.opacity(hovering ? 0.9 : 0.8)
        }
    }
    private var foreground: Color {
        style == .ghost ? .white.opacity(0.9) : .white
    }
    private var border: Color {
        style == .ghost ? .white.opacity(0.15) : .white.opacity(0.25)
    }
}

// MARK: - Section header

struct SectionLabel: View {
    let title: String
    var systemImage: String
    var tint: Color = Theme.brass

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 11, weight: .bold))
            Text(title.uppercased()).font(.pickleCaption(10)).tracking(0.8)
            Spacer()
        }
        .foregroundStyle(tint)
    }
}
