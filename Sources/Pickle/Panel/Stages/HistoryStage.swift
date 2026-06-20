import SwiftUI

/// Stage 5 — progress over time. The core retention loop: founders watch
/// confidence, readiness, and presentation quality climb across sessions.
struct HistoryStage: View {
    @EnvironmentObject private var app: AppState
    @State private var metric: ProgressTracker.Metric = .readiness
    @State private var tab: Tab = .pitches

    // Brain-dump folder filtering + inline folder creation.
    @State private var folderFilter: FolderFilter = .all
    @State private var addingFolder = false
    @State private var newFolderName = ""

    enum Tab: String, CaseIterable, Identifiable {
        case pitches = "Pitches"
        case brainDumps = "Brain Dumps"
        var id: String { rawValue }
    }

    enum FolderFilter: Equatable { case all, unfiled, folder(UUID) }

    private var filteredDumps: [BrainDumpRecord] {
        switch folderFilter {
        case .all:               return app.brainStore.dumps
        case .unfiled:           return app.brainStore.dumps.filter { $0.folderID == nil }
        case .folder(let id):    return app.brainStore.dumps.filter { $0.folderID == id }
        }
    }

    private var tracker: ProgressTracker { ProgressTracker(sessions: app.store.sessions) }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
            switch tab {
            case .pitches:    pitchTab
            case .brainDumps: brainTab
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: tab)
        .onAppear { tab = app.mode == .brainDump ? .brainDumps : .pitches }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { t in
                Button { Haptics.tap(); tab = t } label: {
                    Text(t.rawValue).font(.pickleCaption(11))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(tab == t ? AnyShapeStyle(Theme.pickleGradient) : AnyShapeStyle(.clear),
                                    in: Capsule())
                        .foregroundStyle(tab == t ? .white : .white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: Pitches tab

    @ViewBuilder private var pitchTab: some View {
        if app.store.sessions.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    metricPicker
                    trendCard
                    momentum
                    sessionList
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                actionBar("Pitch Again", "arrow.clockwise") { app.practiceAgain() }
            }
        }
    }

    // MARK: Brain Dumps tab

    @ViewBuilder private var brainTab: some View {
        if app.brainStore.dumps.isEmpty {
            brainEmptyState
        } else {
            VStack(spacing: 0) {
                folderBar
                    .padding(.horizontal, 16).padding(.bottom, 8)
                if addingFolder {
                    newFolderRow.padding(.horizontal, 16).padding(.bottom, 8)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if filteredDumps.isEmpty {
                            Text("Nothing in this folder yet.")
                                .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.4))
                                .frame(maxWidth: .infinity).padding(.top, 24)
                        } else {
                            ForEach(filteredDumps) { record in
                                BrainDumpRow(
                                    record: record,
                                    folders: app.brainStore.folders,
                                    folderName: app.brainStore.folderName(record.folderID),
                                    showFolderTag: folderFilter == .all,
                                    open: { app.openBrainDump(record) },
                                    addMore: { app.continueBrainDump(record) },
                                    move: { app.brainStore.move(record.id, to: $0) },
                                    delete: { app.brainStore.delete(record) })
                            }
                        }
                    }
                    .padding(16)
                }
                .safeAreaInset(edge: .bottom) {
                    actionBar("New Brain Dump", "brain.head.profile") { app.newBrainDump() }
                }
            }
        }
    }

    // MARK: Folder bar

    private var folderBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                folderChip("All", count: app.brainStore.dumps.count, filter: .all)
                folderChip("Unfiled", count: app.brainStore.count(in: nil), filter: .unfiled)
                ForEach(app.brainStore.folders) { f in
                    folderChip(f.name, count: app.brainStore.count(in: f.id), filter: .folder(f.id))
                        .contextMenu {
                            Button(role: .destructive) {
                                if folderFilter == .folder(f.id) { folderFilter = .all }
                                app.brainStore.deleteFolder(f.id)
                            } label: { Label("Delete folder", systemImage: "trash") }
                        }
                }
                Button { withAnimation { addingFolder.toggle() } } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(.white.opacity(0.05)).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func folderChip(_ title: String, count: Int, filter: FolderFilter) -> some View {
        let selected = folderFilter == filter
        return Button { withAnimation { folderFilter = filter } } label: {
            HStack(spacing: 4) {
                Text(title).font(.pickleCaption(11))
                Text("\(count)").font(.pickleCaption(9).monospacedDigit()).opacity(0.6)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(selected ? Theme.cool.opacity(0.22) : .white.opacity(0.05))
            .foregroundStyle(selected ? Theme.cool : .white.opacity(0.6))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(selected ? Theme.cool.opacity(0.4) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var newFolderRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.plus").foregroundStyle(Theme.cool).font(.system(size: 12))
            TextField("Folder name", text: $newFolderName)
                .textFieldStyle(.plain).font(.pickleBody(12)).foregroundStyle(.white)
                .onSubmit(commitFolder)
            Button("Add", action: commitFolder)
                .buttonStyle(.plain).font(.pickleCaption(11)).foregroundStyle(Theme.brassBright)
            Button { addingFolder = false; newFolderName = "" } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.4))
            }.buttonStyle(.plain)
        }
        .padding(10)
        .background(.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func commitFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let folder = app.brainStore.addFolder(name)
        newFolderName = ""; addingFolder = false
        withAnimation { folderFilter = .folder(folder.id) }
    }

    private func actionBar(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        PickleButton(title: title, systemImage: icon, style: .primary, action: action)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(VisualEffectBlur(material: .hudWindow).opacity(0.9))
    }

    private var brainEmptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            PickleMascotView(mood: .curious, size: 84)
            Text("No brain dumps yet").font(.pickleTitle(18)).foregroundStyle(.white)
            Text("Think out loud about a problem or idea and I'll save the synthesis here so you can revisit it.")
                .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 28)
            PickleButton(title: "Start a brain dump", systemImage: "brain.head.profile") { app.newBrainDump() }
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding(16)
    }

    // MARK: Metric picker

    private var metricPicker: some View {
        HStack(spacing: 6) {
            ForEach(ProgressTracker.Metric.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { metric = m }
                } label: {
                    Text(m.rawValue).font(.pickleCaption(11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)     // shrink before wrapping
                        .padding(.horizontal, 6).padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(metric == m ? Theme.brass.opacity(0.22) : .white.opacity(0.05))
                        .foregroundStyle(metric == m ? Theme.brassBright : .white.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: metric.systemImage).foregroundStyle(Theme.brassBright)
                Text("\(tracker.current(metric))")
                    .font(.pickleScore(40)).foregroundStyle(.white)
                if let d = tracker.delta(metric) {
                    DeltaTag(delta: d)
                }
                Spacer()
                Text("\(tracker.totalSessions) runs")
                    .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.5))
            }
            Sparkline(values: tracker.series(metric), tint: Theme.brassBright)
                .frame(height: 70)
        }
        .padding(14)
        .glassCard()
    }

    private var momentum: some View {
        HStack(spacing: 10) {
            PickleMascotView(mood: .curious, size: 38).frame(width: 42, height: 42)
            Text(tracker.momentumLine)
                .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12).glassCard()
    }

    // MARK: Session list

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Recent runs", systemImage: "list.bullet")
            ForEach(app.store.sessions) { record in
                Button {
                    app.openRecord(record)
                } label: {
                    HStack(spacing: 10) {
                        Text("\(record.analysis.overallScore)")
                            .font(.pickleScore(18))
                            .foregroundStyle(Theme.scoreColor(record.analysis.overallScore))
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(record.length.title) · \(Int(record.durationSeconds))s")
                                .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.85))
                            Text(record.date, style: .relative)
                                .font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(10).glassCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            PickleMascotView(mood: .idle, size: 84)
            Text("No runs yet").font(.pickleTitle(18)).foregroundStyle(.white)
            Text("Record your first pitch and I'll start tracking your confidence and readiness over time.")
                .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 28)
            PickleButton(title: "Record a pitch", systemImage: "mic.fill") { app.goWelcome() }
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding(16)
    }
}

private struct DeltaTag: View {
    let delta: Int
    var body: some View {
        let up = delta >= 0
        return HStack(spacing: 2) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
            Text("\(abs(delta))")
        }
        .font(.pickleCaption(10).monospacedDigit())
        .foregroundStyle(up ? Theme.cool : Theme.hot)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background((up ? Theme.cool : Theme.hot).opacity(0.16))
        .clipShape(Capsule())
    }
}

/// Hand-drawn sparkline so we ship no chart dependency.
struct Sparkline: View {
    let values: [Int]
    var tint: Color
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count > 1 {
                    // Fill under the line
                    linePath(pts, closed: true, in: geo.size)
                        .fill(LinearGradient(colors: [tint.opacity(0.25), .clear],
                                             startPoint: .top, endPoint: .bottom))
                    // Line
                    linePath(pts, closed: false, in: geo.size)
                        .trim(from: 0, to: progress)
                        .stroke(tint, style: .init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    // Last dot
                    if let last = pts.last {
                        Circle().fill(tint).frame(width: 7, height: 7)
                            .position(last).opacity(Double(progress))
                    }
                } else {
                    Text("Two runs needed to chart a trend.")
                        .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { progress = 1 }
            }
            .onChange(of: values) { _, _ in
                progress = 0
                withAnimation(.easeOut(duration: 0.6)) { progress = 1 }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let maxV = max(values.max() ?? 100, 1)
        let minV = min(values.min() ?? 0, maxV)
        let span = max(maxV - minV, 1)
        let stepX = values.count > 1 ? size.width / CGFloat(values.count - 1) : 0
        return values.enumerated().map { i, v in
            let x = CGFloat(i) * stepX
            let norm = CGFloat(v - minV) / CGFloat(span)
            let y = size.height - norm * (size.height - 8) - 4
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ pts: [CGPoint], closed: Bool, in size: CGSize) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        if closed { p.move(to: CGPoint(x: first.x, y: size.height)); p.addLine(to: first) }
        else { p.move(to: first) }
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        if closed, let last = pts.last {
            p.addLine(to: CGPoint(x: last.x, y: size.height)); p.closeSubpath()
        }
        return p
    }
}

/// A row in the brain-dump history list: the headline, the strongest idea, when
/// it was captured/updated, and an overflow menu to add on, file, or delete.
private struct BrainDumpRow: View {
    let record: BrainDumpRecord
    let folders: [BrainDumpFolder]
    let folderName: String?
    let showFolderTag: Bool
    let open: () -> Void
    let addMore: () -> Void
    let move: (UUID?) -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: open) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.cool)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.synthesis.headline)
                            .font(.pickleHeadline(12)).foregroundStyle(.white)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            if let idea = record.synthesis.topIdea {
                                Text(idea.name).font(.pickleCaption(10)).foregroundStyle(Theme.brassBright).lineLimit(1)
                                Text("·").foregroundStyle(.white.opacity(0.3))
                            }
                            Text(timeLabel).font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.45))
                            if showFolderTag, let folderName {
                                Chip(text: folderName, systemImage: "folder.fill", tint: Theme.cool)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button { addMore() } label: { Label("Add more thinking", systemImage: "plus.bubble") }
                Menu("Move to") {
                    Button { move(nil) } label: {
                        Label("Unfiled", systemImage: record.folderID == nil ? "checkmark" : "tray")
                    }
                    ForEach(folders) { f in
                        Button { move(f.id) } label: {
                            Label(f.name, systemImage: record.folderID == f.id ? "checkmark" : "folder")
                        }
                    }
                }
                Divider()
                Button(role: .destructive) { delete() } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.45))
                    .frame(width: 26, height: 26)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(10).glassCard()
    }

    private var timeLabel: String {
        if let updated = record.updatedAt {
            return "updated \(relative(updated))"
        }
        return relative(record.date)
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
