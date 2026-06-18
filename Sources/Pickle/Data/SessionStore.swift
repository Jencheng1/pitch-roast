import Foundation

/// Persists practice sessions as a single JSON file in Application Support.
/// Small, atomic, and good enough for thousands of runs; the API is deliberately
/// repository-shaped so a SwiftData/SQLite backend can replace it transparently.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionRecord] = []

    private let fileURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pickle", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("sessions.json")
        load()
    }

    func add(_ record: SessionRecord) {
        sessions.insert(record, at: 0)   // newest first
        save()
    }

    func delete(_ record: SessionRecord) {
        sessions.removeAll { $0.id == record.id }
        save()
    }

    var latest: SessionRecord? { sessions.first }

    /// Best overall score so far, for celebrating new personal bests.
    var bestOverall: Int { sessions.map(\.analysis.overallScore).max() ?? 0 }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sessions = (try? decoder.decode([SessionRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(sessions) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
