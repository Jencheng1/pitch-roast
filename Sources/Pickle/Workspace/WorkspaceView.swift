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

    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var renaming: BrainDumpFolder?
    @State private var renameText = ""

    private var unfiled: [BrainDumpRecord] { app.brainStore.dumps.filter { $0.folderID == nil } }

    var body: some View {
        List(selection: $app.workspaceSelection) {
            // One section per folder, then loose ("Unfiled") brain dumps.
            ForEach(app.brainStore.folders) { folder in
                let dumps = app.brainStore.dumps.filter { $0.folderID == folder.id }
                Section {
                    if dumps.isEmpty {
                        Text("Empty — move a brain dump here")
                            .font(.pickleCaption(10)).foregroundStyle(.secondary).italic()
                    } else {
                        ForEach(dumps) { d in brainRow(d).tag(WorkspaceSelection.brain(d.id)) }
                    }
                } header: { folderHeader(folder, count: dumps.count) }
            }

            if !unfiled.isEmpty {
                Section(app.brainStore.folders.isEmpty ? "Brain dumps" : "Unfiled") {
                    ForEach(unfiled) { d in brainRow(d).tag(WorkspaceSelection.brain(d.id)) }
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
            HStack(spacing: 8) {
                Button {
                    app.newBrainDump(); app.showPanel()
                } label: {
                    Label("New brain dump", systemImage: "plus")
                        .font(.pickleHeadline(12))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent).tint(Theme.pickle)

                Button {
                    newFolderName = ""; showNewFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13, weight: .semibold)).padding(.vertical, 6).padding(.horizontal, 2)
                }
                .buttonStyle(.bordered).tint(Theme.brass).help("New folder")
            }
            .padding(10)
        }
        .alert("New folder", isPresented: $showNewFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") { createFolder() }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
        .alert("Rename folder", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } })) {
            TextField("Folder name", text: $renameText)
            Button("Rename") {
                if let f = renaming {
                    let n = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !n.isEmpty { app.brainStore.renameFolder(f.id, to: n) }
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func folderHeader(_ folder: BrainDumpFolder, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill").font(.system(size: 10)).foregroundStyle(Theme.brass)
            Text(folder.name)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary)
        }
        .contextMenu {
            Button { renameText = folder.name; renaming = folder } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) { app.brainStore.deleteFolder(folder.id) } label: {
                Label("Delete folder", systemImage: "trash")
            }
        }
    }

    private func createFolder() {
        let n = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""
        guard !n.isEmpty else { return }
        app.brainStore.addFolder(n)
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
        .contextMenu {
            Menu("Move to") {
                Button {
                    app.brainStore.move(d.id, to: nil)
                } label: {
                    Label("Unfiled", systemImage: d.folderID == nil ? "checkmark" : "tray")
                }
                if !app.brainStore.folders.isEmpty { Divider() }
                ForEach(app.brainStore.folders) { f in
                    Button {
                        app.brainStore.move(d.id, to: f.id)
                    } label: {
                        Label(f.name, systemImage: d.folderID == f.id ? "checkmark" : "folder")
                    }
                }
            }
            Divider()
            Button(role: .destructive) { app.brainStore.delete(d) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
