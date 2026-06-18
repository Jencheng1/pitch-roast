import Foundation

/// A single completed practice run, persisted to disk. This is the unit the
/// progress tracker aggregates over time.
///
/// (Persistence uses a Codable JSON store for a clean, dependency-free build.
///  Swapping in SwiftData later is a drop-in: make this an `@Model` class and
///  back `SessionStore` with a `ModelContext` — the rest of the app is unchanged.)
struct SessionRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var length: PitchLength
    var durationSeconds: Double
    var transcript: String
    var analysis: PitchAnalysis

    init(id: UUID = UUID(),
         date: Date = Date(),
         length: PitchLength,
         durationSeconds: Double,
         transcript: String,
         analysis: PitchAnalysis) {
        self.id = id
        self.date = date
        self.length = length
        self.durationSeconds = durationSeconds
        self.transcript = transcript
        self.analysis = analysis
    }
}
