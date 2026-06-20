import Foundation

/// Persists brain-dump sessions and their folders as JSON in Application Support
/// — the idea-history counterpart to `SessionStore`, with append + organize.
@MainActor
final class BrainDumpStore: ObservableObject {
    @Published private(set) var dumps: [BrainDumpRecord] = []
    @Published private(set) var folders: [BrainDumpFolder] = []

    private let dumpsURL: URL
    private let foldersURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pickle", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        dumpsURL = base.appendingPathComponent("braindumps.json")
        foldersURL = base.appendingPathComponent("braindump-folders.json")
        dumps = Self.read([BrainDumpRecord].self, from: dumpsURL) ?? []
        folders = Self.read([BrainDumpFolder].self, from: foldersURL) ?? []
    }

    // MARK: Dumps

    func add(_ record: BrainDumpRecord) {
        dumps.insert(record, at: 0)             // newest first
        saveDumps()
    }

    /// Replace an existing dump (by id) with an updated version, marking it
    /// touched and moving it to the front as most-recently-updated.
    func update(_ record: BrainDumpRecord) {
        var r = record
        r.updatedAt = Date()
        dumps.removeAll { $0.id == record.id }
        dumps.insert(r, at: 0)
        saveDumps()
    }

    /// Replace a record in place — same position, no "updated" bump. Used for
    /// background enrichment (e.g. live landscape) that isn't a user edit.
    func replace(_ record: BrainDumpRecord) {
        guard let i = dumps.firstIndex(where: { $0.id == record.id }) else { return }
        dumps[i] = record
        saveDumps()
    }

    func delete(_ record: BrainDumpRecord) {
        dumps.removeAll { $0.id == record.id }
        saveDumps()
    }

    /// Append a conversation turn in place (no reorder; bumps `updatedAt`).
    func appendTurn(_ turn: BrainDumpTurn, to id: UUID) {
        guard let i = dumps.firstIndex(where: { $0.id == id }) else { return }
        dumps[i].thread = (dumps[i].thread ?? []) + [turn]
        dumps[i].updatedAt = Date()
        saveDumps()
    }

    /// Attach supporting materials to a session in place (bumps `updatedAt`).
    func addAttachments(_ attachments: [Attachment], to id: UUID) {
        guard !attachments.isEmpty, let i = dumps.firstIndex(where: { $0.id == id }) else { return }
        dumps[i].attachments = (dumps[i].attachments ?? []) + attachments
        dumps[i].updatedAt = Date()
        saveDumps()
    }

    func removeAttachment(_ attachmentID: UUID, from id: UUID) {
        guard let i = dumps.firstIndex(where: { $0.id == id }) else { return }
        dumps[i].attachments?.removeAll { $0.id == attachmentID }
        dumps[i].updatedAt = Date()
        saveDumps()
    }

    func move(_ recordID: UUID, to folderID: UUID?) {
        guard let i = dumps.firstIndex(where: { $0.id == recordID }) else { return }
        dumps[i].folderID = folderID
        saveDumps()
    }

    var latest: BrainDumpRecord? { dumps.first }

    func record(_ id: UUID?) -> BrainDumpRecord? {
        guard let id else { return nil }
        return dumps.first { $0.id == id }
    }

    func count(in folderID: UUID?) -> Int {
        dumps.filter { $0.folderID == folderID }.count
    }

    // MARK: Folders

    @discardableResult
    func addFolder(_ name: String) -> BrainDumpFolder {
        let folder = BrainDumpFolder(name: name)
        folders.append(folder)
        saveFolders()
        return folder
    }

    func renameFolder(_ id: UUID, to name: String) {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[i].name = name
        saveFolders()
    }

    /// Delete a folder; its dumps become unfiled (not deleted).
    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        for i in dumps.indices where dumps[i].folderID == id { dumps[i].folderID = nil }
        saveFolders(); saveDumps()
    }

    func folderName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return folders.first { $0.id == id }?.name
    }

    // MARK: Persistence

    private func saveDumps() { Self.write(dumps, to: dumpsURL) }
    private func saveFolders() { Self.write(folders, to: foldersURL) }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
