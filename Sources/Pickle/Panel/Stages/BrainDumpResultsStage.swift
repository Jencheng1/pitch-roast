import SwiftUI

/// The payoff of a brain dump: Pickle's synthesis of the founder's freeform
/// thinking — themes, the ideas hiding in the noise, the strongest bet, pains to
/// chase, open questions, next steps, and a pitch angle to practice.
struct BrainDumpResultsStage: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let s = app.brainResult {
            ScrollView {
                VStack(spacing: 14) {
                    header(s)
                    summary(s)
                    ideas(s)
                    bestBet(s)
                    themes(s)
                    bulletCard("Pains worth chasing", "person.crop.circle.badge.exclamationmark", Theme.warm, s.painPoints)
                    bulletCard("Open questions", "questionmark.bubble.fill", Theme.brass, s.openQuestions)
                    nextSteps(s)
                    pitchAngle(s)
                    transcriptDisclosure
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) { actionBar }
        } else {
            EmptyView()
        }
    }

    // MARK: Header

    private func header(_ s: BrainDumpSynthesis) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PickleMascotView(mood: app.mood, size: 52).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Chip(text: "BRAIN DUMP", systemImage: "brain.head.profile", tint: Theme.cool)
                Text(s.headline)
                    .font(.pickleHeadline(15)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func summary(_ s: BrainDumpSynthesis) -> some View {
        Text(s.summary)
            .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Ideas

    private func ideas(_ s: BrainDumpSynthesis) -> some View {
        Group {
            if !s.ideas.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(title: "Ideas on the table", systemImage: "lightbulb.fill", tint: Theme.brassBright)
                    ForEach(s.ideas) { idea in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(idea.name).font(.pickleHeadline(13)).foregroundStyle(.white)
                                Spacer()
                                Text("\(idea.conviction)")
                                    .font(.pickleCaption(11).monospacedDigit())
                                    .foregroundStyle(Theme.scoreColor(idea.conviction))
                            }
                            ProgressBar(value: idea.conviction)
                            ideaRow("Problem", idea.problem)
                            ideaRow("For", idea.audience)
                            ideaRow("Why now", idea.whyNow)
                            ideaRow("Promise", idea.valueProp)
                        }
                        .padding(11).glassCard()
                    }
                }
            }
        }
    }

    private func ideaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label.uppercased())
                .font(.pickleCaption(9)).tracking(0.5)
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 56, alignment: .leading)
            Text(value).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Best bet

    private func bestBet(_ s: BrainDumpSynthesis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Pickle's best bet", systemImage: "star.fill", tint: Theme.brassBright)
            HStack(alignment: .top, spacing: 10) {
                PickleMascotView(mood: .impressed, size: 44).frame(width: 48, height: 48)
                Text(s.bestBet)
                    .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Theme.brass.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(Theme.brass.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    // MARK: Themes

    private func themes(_ s: BrainDumpSynthesis) -> some View {
        Group {
            if !s.themes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Threads you kept circling", systemImage: "point.3.connected.trianglepath.dotted", tint: Theme.cool)
                    ForEach(s.themes) { theme in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.title).font(.pickleHeadline(12)).foregroundStyle(.white)
                            Text(theme.detail).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.68))
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

    private func nextSteps(_ s: BrainDumpSynthesis) -> some View {
        Group {
            if !s.nextSteps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Where to go next", systemImage: "figure.walk", tint: Theme.brassBright)
                    ForEach(Array(s.nextSteps.enumerated()), id: \.element.id) { idx, step in
                        HStack(alignment: .top, spacing: 9) {
                            Text("\(idx + 1)")
                                .font(.pickleHeadline(12)).foregroundStyle(Theme.pickleDeep)
                                .frame(width: 20, height: 20).background(Theme.brassGradient)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.action).font(.pickleHeadline(12)).foregroundStyle(.white)
                                Text(step.why).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.65))
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

    // MARK: Pitch angle bridge

    private func pitchAngle(_ s: BrainDumpSynthesis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "A pitch angle to try", systemImage: "mic.fill", tint: Theme.cool)
            Text(s.pitchAngle)
                .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.tap(); app.practiceAPitch()
            } label: {
                HStack(spacing: 5) {
                    Text("Practice this as a pitch")
                    Image(systemName: "arrow.right")
                }
                .font(.pickleCaption(11)).foregroundStyle(Theme.cool)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.cool.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(Theme.cool.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    private var transcriptDisclosure: some View {
        DisclosureGroup {
            Text(app.brainTranscript)
                .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        } label: {
            SectionLabel(title: "What you said", systemImage: "text.quote", tint: .white.opacity(0.6))
        }
        .tint(.white.opacity(0.6))
        .padding(12).glassCard()
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            PickleButton(title: "New", systemImage: "brain.head.profile", style: .ghost) {
                app.newBrainDump()
            }
            PickleButton(title: "Add more thinking", systemImage: "plus.bubble.fill", style: .primary) {
                app.addMoreToCurrent()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(VisualEffectBlur(material: .hudWindow).opacity(0.9))
    }
}
