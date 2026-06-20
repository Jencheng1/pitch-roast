import SwiftUI

/// Stage 3 — Pickle is thinking. Shows the live transcript as it lands, then
/// rotating "what Pickle is weighing" lines while Claude analyzes.
struct AnalyzingStage: View {
    @EnvironmentObject private var app: AppState
    @State private var thoughtIndex = 0

    private let pitchThoughts = [
        "Reading between your filler words…",
        "Checking if the problem is actually a problem…",
        "Pressure-testing the market size…",
        "Wondering about your moat…",
        "Drafting the questions I'd ask in the room…",
        "Deciding how brutal to be…"
    ]
    private let brainThoughts = [
        "Replaying what you said…",
        "Pulling the ideas out of the noise…",
        "Spotting the threads you keep returning to…",
        "Ranking which one I'd actually chase…",
        "Sketching a pitch angle to try next…"
    ]
    private let replyThoughts = [
        "Hearing you out…",
        "Chewing on that…",
        "Reacting to your new thought…"
    ]
    private var thoughts: [String] {
        if app.mode == .brainDump { return app.isAddingOn ? replyThoughts : brainThoughts }
        return pitchThoughts
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            PickleMascotView(mood: .thinking, size: 96)

            Text(thoughts[thoughtIndex])
                .font(.pickleHeadline(14)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .transition(.opacity)
                .id(thoughtIndex)
                .frame(height: 40)
                .padding(.horizontal, 16)

            if !app.transcriptPreview.isEmpty {
                ScrollView {
                    Text("“\(app.transcriptPreview)”")
                        .font(.pickleBody(12))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 150)
                .glassCard()
                .padding(.horizontal, 4)
            }

            Spacer()
        }
        .padding(16)
        .onAppear { rotate() }
    }

    private func rotate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            guard app.stage == .analyzing else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                thoughtIndex = (thoughtIndex + 1) % thoughts.count
            }
            rotate()
        }
    }
}
