import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Brain dump (read + continue the conversation)

struct BrainWorkspaceDetail: View {
    @EnvironmentObject private var app: AppState
    let record: BrainDumpRecord

    @State private var draft = ""
    @State private var pending: String?         // optimistic in-flight message
    @State private var pendingFiles: [Attachment] = []   // staged for next message
    @State private var dropTargeted = false
    @State private var composerTargeted = false
    @State private var showImporter = false
    @State private var importMode: ImportMode = .session
    @State private var enlarged: Attachment?

    private enum ImportMode { case session, composer }

    private var s: BrainDumpSynthesis { record.synthesis }

    /// File types Pickle can read: decks, images, notes, research, docs.
    private var allowedTypes: [UTType] {
        var t: [UTType] = [.pdf, .image, .plainText, .text, .rtf,
                           .commaSeparatedText, .json, .html, .xml]
        for ext in ["md", "markdown", "doc", "docx", "odt"] {
            if let u = UTType(filenameExtension: ext) { t.append(u) }
        }
        return t
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if !s.summary.isEmpty {
                        Text(s.summary).font(.pickleBody(15)).foregroundStyle(.white.opacity(0.9))
                    }
                    materials
                    ideas
                    bestBet
                    if let l = s.landscape { landscape(l) }
                    list("Pains worth chasing", s.painPoints, Theme.warm)
                    list("Open questions", s.openQuestions, Theme.brass)
                    steps
                    pitchAngle
                    thread
                }
                .textSelection(.enabled)                 // select + copy any text
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
            }
            .dropDestination(for: URL.self) { urls, _ in
                app.attachToSession(urls, dumpID: record.id); return true
            } isTargeted: { dropTargeted = $0 }
            .overlay(alignment: .top) { if dropTargeted { dropHint } }

            composer
        }
        .onChange(of: app.workspaceReplying) { _, replying in if !replying { pending = nil } }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: allowedTypes, allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            switch importMode {
            case .session:  app.attachToSession(urls, dumpID: record.id)
            case .composer: ingestIntoComposer(urls)
            }
        }
        .sheet(item: $enlarged) { item in
            AttachmentPreview(attachments: record.files, initial: item)
        }
    }

    private func pickFiles(_ mode: ImportMode) {
        importMode = mode
        showImporter = true
    }

    private var dropHint: some View {
        Label("Drop files to add to this idea", systemImage: "tray.and.arrow.down.fill")
            .font(.pickleHeadline(12)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.cool.opacity(0.9), in: Capsule())
            .padding(.top, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Chip(text: "BRAIN DUMP", systemImage: "brain.head.profile", tint: Theme.cool)
                Text(s.headline).font(.pickleTitle(24)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                iconButton("doc.on.doc", "Copy") { copyToClipboard(plainText(record)) }
                iconButton("mic.fill", "Add by voice") { app.continueBrainDump(record); app.showPanel() }
            }
        }
    }

    // MARK: Materials (attachments)

    private var materials: some View {
        section("Materials", "paperclip", Theme.cool) {
            if record.files.isEmpty {
                emptyDrop
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116, maximum: 150), spacing: 16)],
                          alignment: .leading, spacing: 16) {
                    ForEach(record.files) { tile($0) }
                    addTile
                }
            }
        }
    }

    private var emptyDrop: some View {
        Button { pickFiles(.session) } label: {
            VStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down").font(.system(size: 20)).foregroundStyle(Theme.cool)
                Text("Drag in a deck, screenshots, interview notes, or research")
                    .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.6))
                Text("or click to choose files").font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: Theme.cardCorner)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    /// Finder-style tile: image thumbnail or file-type icon, name beneath.
    /// Click to enlarge; ✕ to remove.
    private func tile(_ f: Attachment) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Button { enlarged = f } label: {
                    thumb(f)
                        .frame(width: 96, height: 96)
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain).help("Click to enlarge")

                Button { app.removeSessionAttachment(f.id, dumpID: record.id) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 15))
                        .symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain).padding(4).help("Remove")
            }
            Text(f.name).font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.75))
                .lineLimit(2).multilineTextAlignment(.center).frame(width: 100)
        }
    }

    @ViewBuilder private func thumb(_ f: Attachment) -> some View {
        if f.kind == .image, let img = decodedImage(f) {
            Image(nsImage: img).resizable().scaledToFill().frame(width: 96, height: 96).clipped()
        } else {
            VStack(spacing: 5) {
                Image(systemName: f.iconName).font(.system(size: 32, weight: .light)).foregroundStyle(Theme.cool)
                Text(kindLabel(f.kind).uppercased()).font(.pickleCaption(8)).tracking(0.5)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private var addTile: some View {
        Button { pickFiles(.session) } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.white.opacity(0.22))
                    .frame(width: 96, height: 96)
                    .overlay(Image(systemName: "plus").font(.system(size: 22)).foregroundStyle(.white.opacity(0.45)))
                Text("Add").font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }

    private func pill(_ f: Attachment) -> some View {
        HStack(spacing: 6) {
            Image(systemName: f.iconName).font(.system(size: 11)).foregroundStyle(Theme.cool)
            Text(f.name).font(.pickleCaption(11)).foregroundStyle(.white).lineLimit(1).frame(maxWidth: 150)
            Button { pendingFiles.removeAll { $0.id == f.id } } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(Theme.cool.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.cool.opacity(0.3), lineWidth: 1))
    }

    private func decodedImage(_ f: Attachment) -> NSImage? {
        guard let b = f.imageBase64, let data = Data(base64Encoded: b) else { return nil }
        return NSImage(data: data)
    }

    private func kindLabel(_ kind: Attachment.Kind) -> String {
        switch kind {
        case .image:    return "Image"
        case .pdf:      return "PDF"
        case .document: return "Document"
        case .text:     return "Text"
        }
    }

    /// Load dropped/imported files into the composer's staging tray.
    private func ingestIntoComposer(_ urls: [URL]) {
        app.workspaceError = nil
        for url in urls {
            do { pendingFiles.append(try AttachmentLoader.load(url: url)) }
            catch { app.workspaceError = (error as? LocalizedError)?.errorDescription ?? "Couldn't read that file." }
        }
    }

    // MARK: Sections

    private var ideas: some View {
        Group {
            if !s.ideas.isEmpty {
                section("Ideas on the table", "lightbulb.fill", Theme.brassBright) {
                    ForEach(s.ideas) { idea in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(idea.name).font(.pickleHeadline(14)).foregroundStyle(.white)
                                Spacer()
                                Text("\(idea.conviction)").font(.pickleCaption(12).monospacedDigit())
                                    .foregroundStyle(Theme.scoreColor(idea.conviction))
                            }
                            ProgressBar(value: idea.conviction)
                            kv("Problem", idea.problem); kv("For", idea.audience)
                            kv("Why now", idea.whyNow); kv("Promise", idea.valueProp)
                        }
                        .padding(13).glassCard()
                    }
                }
            }
        }
    }

    private var bestBet: some View {
        card(tint: Theme.brass) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Pickle's best bet", systemImage: "star.fill", tint: Theme.brassBright)
                Text(s.bestBet).font(.pickleBody(14)).foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func landscape(_ l: BrainDumpSynthesis.Landscape) -> some View {
        section("Where it sits", "map.fill", Theme.brassBright) {
            HStack(alignment: .firstTextBaseline) {
                Text(l.category).font(.pickleHeadline(14)).foregroundStyle(.white)
                Spacer()
                Text(saturationPhrase(l.saturation)).font(.pickleCaption(11)).foregroundStyle(crowdColor(l.saturation))
            }
            if !l.marketRead.isEmpty {
                Text(l.marketRead).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if l.players.isEmpty {
                Text("No clear direct competitors identified").font(.pickleBody(13)).foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(l.players) { p in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(p.name).font(.pickleHeadline(13)).foregroundStyle(.white)
                            Spacer()
                            Chip(text: p.relationship, tint: relationshipColor(p.relationship))
                        }
                        Text(p.what).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.78))
                        Text("Gap: \(p.gap)").font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.55))
                        if let url = p.url, let link = workspaceURL(url) {
                            Link(prettyHost(url), destination: link).font(.pickleCaption(11)).tint(Theme.cool)
                        }
                    }
                    .padding(11).glassCard()
                }
            }
            if !l.whitespace.isEmpty { miniList("Open lanes", l.whitespace) }
            if !l.edge.isEmpty { miniList("Why it could win", l.edge) }
        }
    }

    private var steps: some View {
        Group {
            if !s.nextSteps.isEmpty {
                section("Where to go next", "figure.walk", Theme.brassBright) {
                    ForEach(Array(s.nextSteps.enumerated()), id: \.element.id) { i, step in
                        HStack(alignment: .top, spacing: 9) {
                            Text("\(i + 1)").font(.pickleHeadline(12)).foregroundStyle(Theme.pickleDeep)
                                .frame(width: 20, height: 20).background(Theme.brassGradient).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.action).font(.pickleHeadline(13)).foregroundStyle(.white)
                                Text(step.why).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
    }

    private var pitchAngle: some View {
        card(tint: Theme.cool) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "A pitch angle to try", systemImage: "mic.fill", tint: Theme.cool)
                Text(s.pitchAngle).font(.pickleBody(14)).foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var thread: some View {
        Group {
            if !record.turns.isEmpty || pending != nil {
                section("The conversation", "bubble.left.and.bubble.right.fill", Theme.cool) {
                    ForEach(record.turns) { turn in turnView(you: turn.you, pickle: turn.pickle) }
                    if let pending { turnView(you: pending, pickle: nil) }
                }
            }
        }
    }

    private func turnView(you: String, pickle: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(you).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.6)).italic()
            HStack(alignment: .top, spacing: 9) {
                PickleMascotView(mood: .curious, size: 28).frame(width: 32, height: 32)
                if let pickle {
                    Text(pickle).font(.pickleBody(14)).foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Pickle is thinking…").font(.pickleBody(13)).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cool.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: 8) {
            if let err = app.workspaceError {
                Text(err).font(.pickleCaption(11)).foregroundStyle(Theme.warm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !pendingFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { ForEach(pendingFiles) { pill($0) } }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button { pickFiles(.composer) } label: {
                    Image(systemName: "paperclip").font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.6)).frame(height: 24)
                }
                .buttonStyle(.plain).help("Attach files")
                TextField("Ask a follow-up, or drop in a deck, screenshot, or notes…",
                          text: $draft, axis: .vertical)
                    .textFieldStyle(.plain).font(.pickleBody(14)).foregroundStyle(.white)
                    .lineLimit(1...6)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 24))
                        .foregroundStyle(canSend ? Theme.cool : .white.opacity(0.2))
                }
                .buttonStyle(.plain).disabled(!canSend)
            }
            .padding(12)
            .background(.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(composerTargeted ? Theme.cool : .white.opacity(0.12),
                              lineWidth: composerTargeted ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28).padding(.vertical, 14)
        .background(.black.opacity(0.25))
        .dropDestination(for: URL.self) { urls, _ in
            ingestIntoComposer(urls); return true
        } isTargeted: { composerTargeted = $0 }
    }

    private var canSend: Bool {
        guard !app.workspaceReplying else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingFiles.isEmpty
    }

    private func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let files = pendingFiles
        pending = optimisticLabel(text: text, files: files)
        draft = ""
        pendingFiles = []
        app.workspaceFollowup(dumpID: record.id, text: text, attachments: files)
    }

    private func optimisticLabel(text: String, files: [Attachment]) -> String {
        guard !files.isEmpty else { return text }
        let tag = "📎 " + files.map(\.name).joined(separator: ", ")
        return text.isEmpty ? tag : text + "\n" + tag
    }

    // MARK: Small building blocks

    private func section<C: View>(_ title: String, _ icon: String, _ tint: Color,
                                  @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: title, systemImage: icon, tint: tint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<C: View>(tint: Color, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(tint.opacity(0.28), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    private func list(_ title: String, _ items: [String], _ tint: Color) -> some View {
        Group {
            if !items.isEmpty {
                section(title, "circle.fill", tint) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(tint).frame(width: 5, height: 5).padding(.top, 6)
                            Text(item).font(.pickleBody(14)).foregroundStyle(.white.opacity(0.82))
                        }
                    }
                }
            }
        }
    }

    private func miniList(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(.pickleCaption(10)).tracking(0.6).foregroundStyle(Theme.cool)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text("• \(item)").font(.pickleBody(13)).foregroundStyle(.white.opacity(0.78))
            }
        }
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(k.uppercased()).font(.pickleCaption(9)).tracking(0.5).foregroundStyle(.white.opacity(0.4))
                .frame(width: 60, alignment: .leading)
            Text(v).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.8))
        }
    }

    private func iconButton(_ icon: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7)).frame(width: 30, height: 28)
                .background(.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain).help(help)
    }
}

// MARK: - Pitch (read-only)

struct PitchWorkspaceDetail: View {
    let record: SessionRecord
    private var a: PitchAnalysis { record.analysis }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 18) {
                    ScoreRing(score: a.overallScore, size: 96, caption: "OVERALL")
                    VStack(alignment: .leading, spacing: 6) {
                        Chip(text: record.length.title.uppercased(), tint: Theme.brass)
                        Text(a.verdict).font(.pickleHeadline(16)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(a.interestLabel).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                }

                block(tint: Theme.hot) {
                    SectionLabel(title: "The Roast", systemImage: "flame.fill", tint: Theme.hot)
                    Text(a.roast).font(.pickleBody(14)).foregroundStyle(.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 9) {
                    SectionLabel(title: "Scorecard", systemImage: "chart.bar.fill")
                    ForEach(a.dimensions.ordered, id: \.0) { name, dim in
                        VStack(spacing: 3) {
                            HStack {
                                Text(name).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.85))
                                Spacer()
                                Text("\(dim.score)").font(.pickleCaption(12).monospacedDigit())
                                    .foregroundStyle(Theme.scoreColor(dim.score))
                            }
                            ProgressBar(value: dim.score)
                        }
                    }
                }
                .padding(14).glassCard()

                highlights("Strengths", a.strengths, Theme.cool)
                highlights("Weaknesses", a.weaknesses, Theme.warm)
                bullets("Questions you'll get", a.likelyQuestions)
                recs

                DisclosureGroup("Transcript") {
                    Text(record.transcript).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                }
                .tint(.white.opacity(0.6)).padding(14).glassCard()
            }
            .textSelection(.enabled)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
    }

    private func highlights(_ title: String, _ items: [PitchAnalysis.Highlight], _ tint: Color) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: title, systemImage: "checkmark.seal.fill", tint: tint)
                    ForEach(items) { h in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.title).font(.pickleHeadline(13)).foregroundStyle(.white)
                            Text(h.detail).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(14).glassCard()
            }
        }
    }

    private func bullets(_ title: String, _ items: [String]) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: title, systemImage: "questionmark.bubble.fill", tint: Theme.brass)
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(Theme.brass).frame(width: 5, height: 5).padding(.top, 6)
                            Text(item).font(.pickleBody(14)).foregroundStyle(.white.opacity(0.82))
                        }
                    }
                }
                .padding(14).glassCard()
            }
        }
    }

    private var recs: some View {
        Group {
            if !a.recommendations.isEmpty {
                block(tint: Theme.brass) {
                    SectionLabel(title: "Fix this next", systemImage: "wand.and.stars", tint: Theme.brassBright)
                    ForEach(Array(a.recommendations.enumerated()), id: \.element.id) { i, rec in
                        HStack(alignment: .top, spacing: 9) {
                            Text("\(i + 1)").font(.pickleHeadline(12)).foregroundStyle(Theme.pickleDeep)
                                .frame(width: 20, height: 20).background(Theme.brassGradient).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.action).font(.pickleHeadline(13)).foregroundStyle(.white)
                                Text(rec.why).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
    }

    private func block<C: View>(tint: Color, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(tint.opacity(0.28), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }
}

// MARK: - Attachment enlarge (carousel)

/// A slideshow over a session's materials: arrows / arrow-keys / a thumbnail
/// strip step between them without leaving the view. Each frame shows the full
/// image or the extracted text Pickle reads.
struct AttachmentPreview: View {
    let attachments: [Attachment]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(attachments: [Attachment], initial: Attachment) {
        self.attachments = attachments
        _index = State(initialValue: attachments.firstIndex(of: initial) ?? 0)
    }

    private var current: Attachment? { attachments.indices.contains(index) ? attachments[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(.white.opacity(0.1))
            ZStack {
                if let current { content(current) }
                HStack {
                    navArrow("chevron.left", enabled: index > 0) { step(-1) }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                    Spacer()
                    navArrow("chevron.right", enabled: index < attachments.count - 1) { step(1) }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                }
                .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if attachments.count > 1 {
                Divider().overlay(.white.opacity(0.1))
                filmstrip
            }
        }
        .frame(width: 780, height: 660)
        .background(Theme.workspaceBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 9) {
            if let current {
                Image(systemName: current.iconName).foregroundStyle(Theme.cool)
                Text(current.name).font(.pickleHeadline(14)).foregroundStyle(.white).lineLimit(1)
            }
            Spacer()
            if attachments.count > 1 {
                Text("\(index + 1) of \(attachments.count)")
                    .font(.pickleCaption(11).monospacedDigit()).foregroundStyle(.white.opacity(0.5))
            }
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding(14)
    }

    @ViewBuilder private func content(_ f: Attachment) -> some View {
        if f.kind == .image, let img = image(for: f) {
            // Fit the whole image in the viewport — aspect ratio preserved, no scroll.
            Image(nsImage: img).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
        } else if let text = f.extractedText, !text.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extracted text Pickle reads")
                        .font(.pickleCaption(10)).tracking(0.6).foregroundStyle(Theme.cool)
                    Text(text).font(.pickleBody(13)).foregroundStyle(.white.opacity(0.9))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.questionmark").font(.system(size: 30)).foregroundStyle(.white.opacity(0.4))
                Text("No preview available for this file.")
                    .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(attachments.enumerated()), id: \.element.id) { i, f in
                        Button { index = i } label: {
                            miniThumb(f)
                                .frame(width: 54, height: 54)
                                .background(.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(i == index ? Theme.cool : .white.opacity(0.12),
                                                  lineWidth: i == index ? 2 : 1))
                        }
                        .buttonStyle(.plain).id(i)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .onChange(of: index) { _, n in withAnimation { proxy.scrollTo(n, anchor: .center) } }
        }
    }

    @ViewBuilder private func miniThumb(_ f: Attachment) -> some View {
        if f.kind == .image, let img = image(for: f) {
            Image(nsImage: img).resizable().scaledToFill().frame(width: 54, height: 54).clipped()
        } else {
            Image(systemName: f.iconName).font(.system(size: 20, weight: .light)).foregroundStyle(Theme.cool)
        }
    }

    private func navArrow(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 38, height: 38).background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.2)
    }

    private func step(_ delta: Int) {
        let n = index + delta
        if attachments.indices.contains(n) { index = n }
    }

    private func image(for f: Attachment) -> NSImage? {
        guard let b = f.imageBase64, let data = Data(base64Encoded: b) else { return nil }
        return NSImage(data: data)
    }
}

// MARK: - File-scoped helpers

private func copyToClipboard(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
}

private func plainText(_ r: BrainDumpRecord) -> String {
    let s = r.synthesis
    var out = "\(s.headline)\n\n\(s.summary)\n"
    if !s.ideas.isEmpty {
        out += "\nIDEAS\n" + s.ideas.map { "• \($0.name) (\($0.conviction)): \($0.valueProp) — \($0.problem)" }.joined(separator: "\n")
    }
    out += "\n\nBEST BET\n\(s.bestBet)\n"
    if let l = s.landscape {
        out += "\nWHERE IT SITS — \(l.category)\n"
        out += l.players.map { "• \($0.name) [\($0.relationship)]: \($0.what) (gap: \($0.gap))" }.joined(separator: "\n")
    }
    if !s.painPoints.isEmpty { out += "\n\nPAINS\n" + s.painPoints.map { "• \($0)" }.joined(separator: "\n") }
    if !s.openQuestions.isEmpty { out += "\n\nOPEN QUESTIONS\n" + s.openQuestions.map { "• \($0)" }.joined(separator: "\n") }
    if !s.nextSteps.isEmpty { out += "\n\nNEXT STEPS\n" + s.nextSteps.map { "• \($0.action): \($0.why)" }.joined(separator: "\n") }
    out += "\n\nPITCH ANGLE\n\(s.pitchAngle)"
    for t in r.turns { out += "\n\n— You: \(t.you)\n— Pickle: \(t.pickle)" }
    return out
}

private func saturationPhrase(_ saturation: Int) -> String {
    switch min(max(saturation, 0), 100) {
    case ..<30:   return "wide open"
    case 30..<55: return "some players"
    case 55..<78: return "fairly crowded"
    default:      return "very crowded"
    }
}

private func crowdColor(_ saturation: Int) -> Color { Theme.scoreColor(100 - min(max(saturation, 0), 100)) }

private func relationshipColor(_ relationship: String) -> Color {
    let r = relationship.lowercased()
    if r.contains("direct") { return Theme.hot }
    if r.contains("incumbent") { return Theme.warm }
    if r.contains("diy") || r.contains("status") { return Theme.brass }
    return Theme.cool
}

private func workspaceURL(_ raw: String) -> URL? {
    let t = raw.trimmingCharacters(in: .whitespaces)
    guard t.count > 3, t.contains(".") else { return nil }
    return URL(string: t.hasPrefix("http") ? t : "https://\(t)")
}

private func prettyHost(_ raw: String) -> String {
    var s = raw.trimmingCharacters(in: .whitespaces)
    for p in ["https://", "http://", "www."] where s.hasPrefix(p) { s.removeFirst(p.count) }
    return s.split(separator: "/").first.map(String.init) ?? s
}
