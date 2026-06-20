import SwiftUI

/// Stage 2 — live recording. A reactive waveform, the running clock against the
/// format target, and stop / cancel controls. Voice is the whole interaction.
struct RecordingStage: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)

            Text(brandLabel)
                .font(.pickleCaption(10)).tracking(1.2)
                .foregroundStyle(app.mode == .brainDump ? Theme.cool : Theme.brassBright)

            // Timer (vs target for pitches)
            VStack(spacing: 2) {
                Text(timeString(app.recorder.elapsed))
                    .font(.pickleScore(46)).foregroundStyle(.white)
                Text(app.mode == .brainDump
                     ? "talk freely · \(app.recorder.remaining)s left"
                     : "target \(timeString(TimeInterval(app.selectedLength.targetSeconds))) · \(app.recorder.remaining)s left")
                    .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.5))
            }

            Waveform(level: app.recorder.level)
                .frame(height: 64)
                .padding(.horizontal, 8)

            // Pacing hint
            Text(pacingHint)
                .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(height: 34)
                .animation(.easeInOut, value: pacingHint)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                PickleButton(title: "Discard", systemImage: "trash", style: .ghost) {
                    app.cancelRecording()
                }
                PickleButton(title: app.mode == .brainDump ? "Done · Synthesize" : "Done · Analyze",
                             systemImage: "checkmark", style: .primary) {
                    Haptics.success()
                    app.finishRecording()
                }
            }
        }
        .padding(16)
    }

    private var brandLabel: String {
        guard app.mode == .brainDump else { return app.selectedLength.title.uppercased() }
        return app.isAddingOn ? "ADDING ON" : "BRAIN DUMP"
    }

    private var pacingHint: String {
        if app.mode == .brainDump {
            switch Int(app.recorder.elapsed) {
            case ..<15:   return "What problem keeps nagging you?"
            case 15..<45: return "Who feels this pain? Keep going…"
            case 45..<90: return "Any ideas forming? Say them out loud."
            default:      return "Ramble on — I'm connecting the dots."
            }
        }
        let e = Int(app.recorder.elapsed), t = app.selectedLength.targetSeconds
        switch Double(e) / Double(t) {
        case ..<0.25:  return "Open strong — what's the problem?"
        case 0.25..<0.6: return "Good. Now the solution and why you."
        case 0.6..<0.95: return "Land the traction and the ask."
        case 0.95..<1.1: return "Right on time — wrap it up."
        default:       return "Over time — investors are checking their phones."
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

/// A symmetric reactive waveform driven by the live mic level.
struct Waveform: View {
    let level: CGFloat
    private let bars = 28
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(bars)
            HStack(alignment: .center, spacing: w * 0.35) {
                ForEach(0..<bars, id: \.self) { i in
                    Capsule()
                        .fill(Theme.brassGradient)
                        .frame(width: w * 0.55, height: barHeight(i, geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
        }
    }

    private func barHeight(_ i: Int, _ maxH: CGFloat) -> CGFloat {
        // Center-weighted shape, modulated by the live level + a gentle wobble.
        let center = CGFloat(bars) / 2
        let dist = 1 - abs(CGFloat(i) - center) / center            // 0…1
        let wobble = 0.5 + 0.5 * sin(phase + CGFloat(i) * 0.6)
        let amp = max(0.06, level) * (0.55 + 0.45 * wobble)
        return max(3, maxH * dist * amp)
    }
}
