import SwiftUI

/// Stage 4 — the verdict. Scores, the roast, the eleven dimensions, strengths,
/// weaknesses, investor concerns, likely questions, and what to fix next.
struct ResultsStage: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let record = app.result {
            let a = record.analysis
            ScrollView {
                VStack(spacing: 14) {
                    scoreHeader(a)
                    verdict(a)
                    roast(a)
                    dimensions(a)
                    highlights("Strengths", "checkmark.seal.fill", Theme.cool, a.strengths)
                    highlights("Weaknesses", "exclamationmark.triangle.fill", Theme.warm, a.weaknesses)
                    bulletCard("Investor concerns", "eye.trianglebadge.exclamationmark", Theme.hot, a.investorConcerns)
                    bulletCard("Likely questions", "questionmark.bubble.fill", Theme.brass, a.likelyQuestions)
                    recommendations(a)
                    transcriptDisclosure(record)
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) { actionBar }
        } else {
            EmptyView()
        }
    }

    // MARK: Score header

    private func scoreHeader(_ a: PitchAnalysis) -> some View {
        HStack(spacing: 18) {
            ScoreRing(score: a.overallScore, size: 104, caption: "OVERALL")
            VStack(alignment: .leading, spacing: 8) {
                if app.isNewBest {
                    Chip(text: "NEW PERSONAL BEST", systemImage: "trophy.fill", tint: Theme.brassBright)
                }
                metric("Investor interest", a.investorInterest)
                Text(a.interestLabel)
                    .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(value)").font(.pickleCaption(11).monospacedDigit())
                    .foregroundStyle(Theme.scoreColor(value))
            }
            ProgressBar(value: value)
        }
        .frame(width: 150)
    }

    // MARK: Verdict + roast

    private func verdict(_ a: PitchAnalysis) -> some View {
        Text(a.verdict)
            .font(.pickleHeadline(15)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func roast(_ a: PitchAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SectionLabel(title: "The Roast", systemImage: "flame.fill", tint: Theme.hot)
                Button { app.replayVoice() } label: {
                    Image(systemName: app.voice.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.hot)
                }
                .buttonStyle(.plain)
                .help("Hear Pickle say it")
            }
            HStack(alignment: .top, spacing: 10) {
                PickleMascotView(mood: .roasting, size: 44).frame(width: 48, height: 48)
                Text(a.roast)
                    .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Theme.hot.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(Theme.hot.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    // MARK: Dimensions

    private func dimensions(_ a: PitchAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(title: "Scorecard", systemImage: "chart.bar.fill")
            ForEach(a.dimensions.ordered, id: \.0) { name, dim in
                VStack(spacing: 3) {
                    HStack {
                        Text(name).font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Text("\(dim.score)").font(.pickleCaption(11).monospacedDigit())
                            .foregroundStyle(Theme.scoreColor(dim.score))
                    }
                    ProgressBar(value: dim.score)
                }
            }
        }
        .padding(12)
        .glassCard()
    }

    // MARK: Highlights / bullets / recs

    private func highlights(_ title: String, _ icon: String, _ tint: Color, _ items: [PitchAnalysis.Highlight]) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: title, systemImage: icon, tint: tint)
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.pickleHeadline(12)).foregroundStyle(.white)
                            Text(item.detail).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12).glassCard()
            }
        }
    }

    private func bulletCard(_ title: String, _ icon: String, _ tint: Color, _ items: [String]) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: title, systemImage: icon, tint: tint)
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 7) {
                            Circle().fill(tint).frame(width: 5, height: 5).padding(.top, 5)
                            Text(item).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12).glassCard()
            }
        }
    }

    private func recommendations(_ a: PitchAnalysis) -> some View {
        Group {
            if !a.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Fix this next", systemImage: "wand.and.stars", tint: Theme.brassBright)
                    ForEach(Array(a.recommendations.enumerated()), id: \.element.id) { idx, rec in
                        HStack(alignment: .top, spacing: 9) {
                            Text("\(idx + 1)")
                                .font(.pickleHeadline(12)).foregroundStyle(Theme.pickleDeep)
                                .frame(width: 20, height: 20).background(Theme.brassGradient)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.action).font(.pickleHeadline(12)).foregroundStyle(.white)
                                Text(rec.why).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(Theme.brass.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(Theme.brass.opacity(0.25), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            }
        }
    }

    private func transcriptDisclosure(_ record: SessionRecord) -> some View {
        DisclosureGroup {
            Text(record.transcript)
                .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        } label: {
            SectionLabel(title: "What you said · \(Int(record.durationSeconds))s",
                         systemImage: "text.quote", tint: .white.opacity(0.6))
        }
        .tint(.white.opacity(0.6))
        .padding(12).glassCard()
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            PickleButton(title: "History", systemImage: "chart.line.uptrend.xyaxis", style: .ghost) {
                app.goHistory()
            }
            PickleButton(title: "Pitch Again", systemImage: "arrow.clockwise", style: .primary) {
                app.practiceAgain()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(VisualEffectBlur(material: .hudWindow).opacity(0.9))
    }
}

/// Slim rounded progress bar used throughout the results.
struct ProgressBar: View {
    let value: Int   // 0–100
    @State private var animated: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule().fill(Theme.scoreColor(value))
                    .frame(width: geo.size.width * animated)
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
                animated = CGFloat(min(max(value, 0), 100)) / 100
            }
        }
    }
}
