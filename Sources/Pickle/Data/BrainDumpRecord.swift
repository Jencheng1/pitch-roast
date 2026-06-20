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
    var synthesis: BrainDumpSynthesis  // the snapshot from the first dump
    var thread: [BrainDumpTurn]?   // follow-up "add more thinking" exchanges
    var folderID: UUID?            // nil = unfiled
    var attachments: [Attachment]? // supporting materials Pickle can analyze

    init(id: UUID = UUID(),
         date: Date = Date(),
         updatedAt: Date? = nil,
         durationSeconds: Double,
         transcript: String,
         synthesis: BrainDumpSynthesis,
         thread: [BrainDumpTurn]? = nil,
         folderID: UUID? = nil,
         attachments: [Attachment]? = nil) {
        self.id = id
        self.date = date
        self.updatedAt = updatedAt
        self.durationSeconds = durationSeconds
        self.transcript = transcript
        self.synthesis = synthesis
        self.thread = thread
        self.folderID = folderID
        self.attachments = attachments
    }

    var turns: [BrainDumpTurn] { thread ?? [] }
    var files: [Attachment] { attachments ?? [] }
}

/// One follow-up exchange in a brain dump: what the founder added, and Pickle's
/// reply to that specific thought (no full re-synthesis).
struct BrainDumpTurn: Codable, Identifiable, Equatable {
    var id: UUID
    var you: String       // the new thought (transcribed)
    var pickle: String    // Pickle's reply

    init(id: UUID = UUID(), you: String, pickle: String) {
        self.id = id
        self.you = you
        self.pickle = pickle
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
