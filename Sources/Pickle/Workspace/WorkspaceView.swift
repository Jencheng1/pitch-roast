import SwiftUI

/// The larger founder workspace — a real resizable window for reading, copying,
/// revisiting sessions, and continuing conversations with Pickle. The dock panel
/// stays the lightweight companion; this is the desk-scale surface.
struct WorkspaceView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar()
                .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 340)
        } detail: {
            WorkspaceDetail()
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 740, minHeight: 480)
        .preferredColorScheme(.dark)
        .tint(Theme.cool)
    }
}

// MARK: - Sidebar (revisit sessions)

struct WorkspaceSidebar: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        List(selection: $app.workspaceSelection) {
            if !app.brainStore.dumps.isEmpty {
                Section("Brain dumps") {
                    ForEach(app.brainStore.dumps) { d in
                        brainRow(d).tag(WorkspaceSelection.brain(d.id))
                    }
                }
            }
            if !app.store.sessions.isEmpty {
                Section("Pitches") {
                    ForEach(app.store.sessions) { p in
                        pitchRow(p).tag(WorkspaceSelection.pitch(p.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                app.newBrainDump(); app.showPanel()
            } label: {
                Label("New brain dump", systemImage: "plus")
                    .font(.pickleHeadline(12))
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent).tint(Theme.pickle)
            .padding(10)
        }
    }

    private func brainRow(_ d: BrainDumpRecord) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "brain.head.profile").foregroundStyle(Theme.cool).font(.system(size: 13))
            VStack(alignment: .leading, spacing: 1) {
                Text(d.synthesis.headline).font(.pickleBody(12)).lineLimit(1)
                Text((d.updatedAt ?? d.date), style: .relative)
                    .font(.pickleCaption(10)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func pitchRow(_ p: SessionRecord) -> some View {
        HStack(spacing: 9) {
            Text("\(p.analysis.overallScore)")
                .font(.pickleScore(14)).foregroundStyle(Theme.scoreColor(p.analysis.overallScore))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(p.length.title) pitch").font(.pickleBody(12)).lineLimit(1)
                Text(p.date, style: .relative).font(.pickleCaption(10)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail routing

struct WorkspaceDetail: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            Theme.workspaceBackground.ignoresSafeArea()
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch app.workspaceSelection {
        case .brain(let id):
            if let rec = app.brainStore.record(id) {
                BrainWorkspaceDetail(record: rec)
            } else { WorkspaceEmpty(text: "This brain dump is no longer available.") }
        case .pitch(let id):
            if let rec = app.store.sessions.first(where: { $0.id == id }) {
                PitchWorkspaceDetail(record: rec)
            } else { WorkspaceEmpty(text: "This pitch is no longer available.") }
        case nil:
            WorkspaceEmpty(text: "Pick a session on the left to read, copy, and keep exploring the idea with Pickle.")
        }
    }
}

struct WorkspaceEmpty: View {
    let text: String
    var body: some View {
        VStack(spacing: 16) {
            PickleMascotView(mood: .curious, size: 96)
            Text("Your idea workspace").font(.pickleTitle(22)).foregroundStyle(.white)
            Text(text)
                .font(.pickleBody(14)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
