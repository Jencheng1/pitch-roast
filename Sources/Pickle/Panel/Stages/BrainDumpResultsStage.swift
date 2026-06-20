import SwiftUI

/// The payoff of a brain dump: Pickle's synthesis of the founder's freeform
/// thinking — themes, the ideas hiding in the noise, the strongest bet, pains to
/// chase, open questions, next steps, and a pitch angle to practice.
struct BrainDumpResultsStage: View {
    @EnvironmentObject private var app: AppState
    @State private var recapExpanded = false

    var body: some View {
        if let s = app.brainResult {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        header(s)
                        if app.brainTurns.isEmpty {
                            // Fresh dump — show the full synthesis.
                            recapStack(s)
                        } else {
                            // Once a conversation is going, the thread leads and the
                            // original brainstorm collapses into a dropdown.
                            threadSection
                            recapDisclosure(s)
                        }
                        transcriptDisclosure
                    }
                    .padding(16)
                }
                .safeAreaInset(edge: .bottom) { actionBar }
                .onAppear { handleExpandRequest(proxy) }
                .onChange(of: app.expandRecap) { _, _ in handleExpandRequest(proxy) }
            }
        } else {
            EmptyView()
        }
    }

    /// Honor a request (e.g. from the competitor-scan toast): open the recap if
    /// it's collapsed, then scroll the landscape into view.
    private func handleExpandRequest(_ proxy: ScrollViewProxy) {
        guard app.expandRecap else { return }
        app.expandRecap = false
        withAnimation { recapExpanded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { proxy.scrollTo("landscape", anchor: .top) }
        }
    }

    // MARK: Recap (the original synthesis)

    @ViewBuilder private func recap(_ s: BrainDumpSynthesis) -> some View {
        summary(s)
        ideas(s)
        bestBet(s)
        if let l = s.landscape { landscape(l).id("landscape") }
        themes(s)
        bulletCard("Pains worth chasing", "person.crop.circle.badge.exclamationmark", Theme.warm, s.painPoints)
        bulletCard("Open questions", "questionmark.bubble.fill", Theme.brass, s.openQuestions)
        nextSteps(s)
        pitchAngle(s)
    }

    private func recapStack(_ s: BrainDumpSynthesis) -> some View {
        VStack(spacing: 14) { recap(s) }
    }

    /// Collapsed-by-default dropdown holding the original brainstorm.
    private func recapDisclosure(_ s: BrainDumpSynthesis) -> some View {
        DisclosureGroup(isExpanded: $recapExpanded) {
            recapStack(s).padding(.top, 10)
        } label: {
            SectionLabel(title: "The original brainstorm", systemImage: "sparkles", tint: Theme.brassBright)
        }
        .tint(Theme.brassBright)
        .padding(12).glassCard()
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

    // MARK: The ongoing thread (add-more replies)

    private var threadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "The thread", systemImage: "bubble.left.and.bubble.right.fill", tint: Theme.cool)
            ForEach(app.brainTurns) { turn in
                VStack(alignment: .leading, spacing: 7) {
                    Text("“\(turn.you)”")
                        .font(.pickleBody(12)).italic().foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 9) {
                        PickleMascotView(mood: .curious, size: 30).frame(width: 34, height: 34)
                        Text(turn.pickle)
                            .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Theme.cool.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(Theme.cool.opacity(0.22), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            }
        }
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

    // MARK: Landscape (startup discovery + competitive read)

    private func landscape(_ l: BrainDumpSynthesis.Landscape) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel(title: "Where it sits", systemImage: "map.fill", tint: Theme.brassBright)
                if app.landscapeLoading {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("scouting…").font(.pickleCaption(10)).foregroundStyle(Theme.cool)
                    }
                }
            }

            // Concise, scannable summary (default view, < 50 words).
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l.category).font(.pickleHeadline(13)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(saturationPhrase(l.saturation))
                        .font(.pickleCaption(10)).foregroundStyle(crowdColor(l.saturation))
                }

                if l.players.isEmpty {
                    Text("No clear direct competitors identified")
                        .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.7))
                } else {
                    competitorChips(l.players)
                }

                if let insight = keyInsight(l) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(Theme.brassBright)
                        Text(insight).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12).glassCard()

            // Detailed reasoning, on demand.
            if hasDetail(l) {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        if !l.marketRead.isEmpty {
                            Text(l.marketRead).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(l.players) { playerCard($0) }
                        bulletCard("Open lanes", "arrow.up.right.circle.fill", Theme.cool, l.whitespace)
                        bulletCard("Why it could win", "checkmark.seal.fill", Theme.brassBright, l.edge)
                    }
                    .padding(.top, 8)
                } label: {
                    Text("See full analysis").font(.pickleCaption(11)).foregroundStyle(Theme.cool)
                }
                .tint(Theme.cool)
                .padding(12).glassCard()
            }
        }
    }

    private func competitorChips(_ players: [BrainDumpSynthesis.Player]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(players.prefix(3)) { p in
                    Chip(text: p.name, tint: relationshipColor(p.relationship))
                }
                if players.count > 3 {
                    Chip(text: "+\(players.count - 3) more", tint: .white.opacity(0.4))
                }
            }
        }
    }

    private func playerCard(_ p: BrainDumpSynthesis.Player) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(p.name).font(.pickleHeadline(12)).foregroundStyle(.white)
                Spacer(minLength: 8)
                Chip(text: p.relationship, tint: relationshipColor(p.relationship))
            }
            Text(p.what).font(.pickleBody(12)).foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            Text("Gap: \(p.gap)").font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            if let url = p.url, let link = playerURL(url) {
                Link(destination: link) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                        Text(prettyDomain(url))
                    }
                    .font(.pickleCaption(10)).foregroundStyle(Theme.cool)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11).glassCard()
    }

    private func hasDetail(_ l: BrainDumpSynthesis.Landscape) -> Bool {
        !l.players.isEmpty || !l.marketRead.isEmpty || !l.whitespace.isEmpty || !l.edge.isEmpty
    }

    /// The single most useful takeaway, surfaced in the default view.
    private func keyInsight(_ l: BrainDumpSynthesis.Landscape) -> String? {
        if let edge = l.edge.first, !edge.isEmpty { return edge }
        if let lane = l.whitespace.first, !lane.isEmpty { return lane }
        let s = l.marketRead.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let dot = s.firstIndex(of: ".") { return String(s[...dot]) }  // first sentence
        return s
    }

    private func saturationPhrase(_ saturation: Int) -> String {
        switch min(max(saturation, 0), 100) {
        case ..<30:   return "wide open"
        case 30..<55: return "some players"
        case 55..<78: return "fairly crowded"
        default:      return "very crowded"
        }
    }

    /// High saturation reads "hot/contested"; low reads "open/green".
    private func crowdColor(_ saturation: Int) -> Color {
        Theme.scoreColor(100 - min(max(saturation, 0), 100))
    }

    private func relationshipColor(_ relationship: String) -> Color {
        let r = relationship.lowercased()
        if r.contains("direct") { return Theme.hot }
        if r.contains("incumbent") { return Theme.warm }
        if r.contains("diy") || r.contains("status") { return Theme.brass }
        return Theme.cool          // adjacent / alternative
    }

    /// A valid, openable URL (adds https:// if the model returned a bare domain).
    private func playerURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 3, trimmed.contains(".") else { return nil }
        let withScheme = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        return URL(string: withScheme)
    }

    /// Strip scheme + path to a clean domain for display.
    private func prettyDomain(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        for prefix in ["https://", "http://", "www."] where s.hasPrefix(prefix) {
            s.removeFirst(prefix.count)
        }
        return s.split(separator: "/").first.map(String.init) ?? s
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
