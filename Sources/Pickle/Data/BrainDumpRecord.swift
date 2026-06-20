import Foundation

/// A saved brain-dump session — the (accumulated) transcript plus Pickle's
/// latest synthesis. Stored separately from scored pitch runs. Can be added to
/// over time and filed into a folder.
struct BrainDumpRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date                 // first captured
    var updatedAt: Date?           // last added-to (nil = never updated)
    var durationSeconds: Double    // total time spoken across all sessions
    var transcript: String         // everything said so far, accumulated
    var synthesis: BrainDumpSynthesis
    var folderID: UUID?            // nil = unfiled

    init(id: UUID = UUID(),
         date: Date = Date(),
         updatedAt: Date? = nil,
         durationSeconds: Double,
         transcript: String,
         synthesis: BrainDumpSynthesis,
         folderID: UUID? = nil) {
        self.id = id
        self.date = date
        self.updatedAt = updatedAt
        self.durationSeconds = durationSeconds
        self.transcript = transcript
        self.synthesis = synthesis
        self.folderID = folderID
    }
}

/// A user-created folder for grouping brain dumps.
struct BrainDumpFolder: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
